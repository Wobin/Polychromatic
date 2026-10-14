#!/usr/bin/env python3
import argparse
import base64
import hashlib
from http.client import HTTPException
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.request
from decimal import Decimal, InvalidOperation
from pathlib import Path

API_BASE = (os.environ.get("NEXUSMODS_API_BASE") or "https://api.nexusmods.com/v3").strip().rstrip("/")
MULTIPART_THRESHOLD = int(os.environ.get("NEXUS_MULTIPART_THRESHOLD") or 100 * 1024 * 1024)
HTTP_TIMEOUT = float(os.environ.get("NEXUS_HTTP_TIMEOUT") or 60)
TRANSFER_TIMEOUT = float(os.environ.get("NEXUS_TRANSFER_TIMEOUT") or 600)
POLL_INTERVAL = float(os.environ.get("NEXUS_POLL_INTERVAL") or 2)
POLL_MAX_INTERVAL = 30.0
POLL_TIMEOUT = float(os.environ.get("NEXUS_POLL_TIMEOUT") or 900)
TRANSFER_ATTEMPTS = 3
USER_AGENT = "Polychromatic-nexus-uploader/1"

NAME_RE = re.compile(r"^[a-zA-Z0-9 _'().-]+$")
VERSION_RE = re.compile(r"^[a-zA-Z0-9.-]+$")
FULL_ZIP = "Polychromatic.zip"
BASE_ZIP = "Polychromatic_Empty.zip"
MODULE_ZIP_RE = re.compile(r"^Polychromatic - (.+)\.zip$")


class NexusError(Exception):
    def __init__(self, msg, status=None):
        super().__init__(msg)
        self.status = status


def api_key():
    key = (os.environ.get("NEXUSMODS_APIKEY") or "").strip()
    if not key:
        raise NexusError("NEXUSMODS_APIKEY is not set")
    return key


def redact(text):
    key = (os.environ.get("NEXUSMODS_APIKEY") or "").strip()
    if key and text:
        text = text.replace(key, "***")
    return text


def log(msg):
    print(redact(msg), file=sys.stderr, flush=True)


def describe_error_body(raw):
    text = raw.decode("utf-8", "replace").strip()
    try:
        doc = json.loads(text)
    except ValueError:
        return text[:500]
    if isinstance(doc, dict):
        parts = [str(doc[k]) for k in ("title", "detail") if doc.get(k)]
        errors = doc.get("errors")
        if errors:
            parts.append(json.dumps(errors)[:500])
        if parts:
            return ": ".join(parts)
    return text[:500]


def http(method, url, body=None, headers=None, timeout=HTTP_TIMEOUT, label=None):
    label = label or "%s %s" % (method, url)
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, dict(resp.headers.items()), resp.read()
    except urllib.error.HTTPError as e:
        try:
            detail = describe_error_body(e.read())
        except Exception:
            detail = ""
        raise NexusError(redact("%s failed: HTTP %d %s%s" % (label, e.code, e.reason, (": " + detail) if detail else "")), e.code)
    except urllib.error.URLError as e:
        raise NexusError(redact("%s failed: %s" % (label, e.reason)))
    except (TimeoutError, OSError) as e:
        raise NexusError(redact("%s failed: %s" % (label, e or "timed out")))
    except HTTPException as e:
        raise NexusError(redact("%s failed: %s %s" % (label, type(e).__name__, str(e)[:200])))


def api(method, path, payload=None, expect=(200, 201), bare=False):
    headers = {"apikey": api_key(), "Accept": "application/json, application/problem+json", "User-Agent": USER_AGENT}
    body = None
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    label = "%s %s" % (method, path)
    if method == "GET":
        status, _, raw = with_retries(lambda: http(method, API_BASE + path, body, headers, label=label))
    else:
        status, _, raw = http(method, API_BASE + path, body, headers, label=label)
    if status not in expect:
        raise NexusError("%s %s returned unexpected HTTP %d" % (method, path, status))
    if not raw:
        return {}
    try:
        doc = json.loads(raw)
    except ValueError:
        raise NexusError("%s %s returned invalid JSON" % (method, path))
    if bare and isinstance(doc, dict):
        inner = doc.get("data")
        return inner if isinstance(inner, dict) and "target_mod_file" in inner else doc
    if not isinstance(doc, dict) or "data" not in doc:
        raise NexusError("%s %s response has no data" % (method, path))
    return doc["data"]


def transfer(method, url, body, headers, label):
    return with_retries(lambda: http(method, url, body, headers, timeout=TRANSFER_TIMEOUT, label=label))


def with_retries(call):
    last = None
    for attempt in range(1, TRANSFER_ATTEMPTS + 1):
        try:
            return call()
        except NexusError as e:
            last = e
            if e.status is not None and 400 <= e.status < 500:
                break
            if attempt < TRANSFER_ATTEMPTS:
                log("%s; retrying (%d/%d)" % (e, attempt + 1, TRANSFER_ATTEMPTS))
                time.sleep(min(2 ** attempt, 10))
    raise last


def file_md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.digest()


_CRC64_POLY = 0x9A6C9329AC4BC9B5
_CRC64_TABLE = []
for _i in range(256):
    _c = _i
    for _ in range(8):
        _c = (_c >> 1) ^ _CRC64_POLY if _c & 1 else _c >> 1
    _CRC64_TABLE.append(_c)


def crc64nvme(data, crc=0):
    table = _CRC64_TABLE
    crc ^= 0xFFFFFFFFFFFFFFFF
    for b in data:
        crc = table[(crc ^ b) & 0xFF] ^ (crc >> 8)
    return crc ^ 0xFFFFFFFFFFFFFFFF


def file_crc64nvme_b64(path):
    crc = 0
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            crc = crc64nvme(chunk, crc)
    return base64.b64encode(crc.to_bytes(8, "big")).decode("ascii")


def upload_single(path, size):
    digest = file_md5(path)
    filename = path.name
    data = api("POST", "/uploads", {"size_bytes": size, "filename": filename, "md5": digest.hex()}, expect=(201,))
    upload_id, url = data.get("id"), data.get("presigned_url")
    if not upload_id or not url:
        raise NexusError("POST /uploads response lacks id or presigned_url")
    log("Upload %s created (single part, %d bytes)" % (upload_id, size))
    body = path.read_bytes()
    if len(body) != size:
        raise NexusError("%s changed size while uploading" % path)
    transfer("PUT", url, body, {
        "Content-Type": "application/octet-stream",
        "Content-Disposition": 'attachment; filename="%s"' % filename,
        "Content-MD5": base64.b64encode(digest).decode("ascii"),
    }, label="PUT presigned upload")
    return upload_id


def upload_multipart(path, size, use_crc=True):
    filename = path.name
    req = {"size_bytes": size, "filename": filename}
    crc = file_crc64nvme_b64(path) if use_crc else None
    if crc:
        req["crc64nvme"] = crc
    data = api("POST", "/uploads/multipart", req, expect=(201,))
    upload_id = data.get("id")
    part_size = data.get("part_size_bytes")
    urls = data.get("part_presigned_urls") or []
    complete = data.get("complete_presigned_url")
    if not upload_id or not complete or not isinstance(part_size, int) or part_size <= 0:
        raise NexusError("POST /uploads/multipart response lacks id, part_size_bytes or complete_presigned_url")
    expected = max(1, math.ceil(size / part_size))
    if len(urls) < expected:
        raise NexusError("multipart upload offers %d part URLs, file needs %d parts of %d bytes"
                         % (len(urls), expected, part_size))
    urls = urls[:expected]
    log("Upload %s created (multipart, %d parts of %d bytes)" % (upload_id, expected, part_size))
    etags = []
    with open(path, "rb") as f:
        for n, url in enumerate(urls, 1):
            chunk = f.read(part_size)
            if (n < expected and len(chunk) != part_size) or not chunk:
                raise NexusError("short read on part %d" % n)
            _, headers, _ = transfer("PUT", url, chunk, {"Content-Type": "application/octet-stream"},
                                     label="PUT part %d/%d" % (n, expected))
            etag = next((v for k, v in headers.items() if k.lower() == "etag"), None)
            if not etag:
                raise NexusError("no ETag returned for part %d" % n)
            etags.append(etag.replace('"', ""))
            log("Uploaded part %d/%d (%d bytes)" % (n, expected, len(chunk)))
    xml = "<CompleteMultipartUpload>\n%s\n</CompleteMultipartUpload>" % "\n".join(
        "  <Part>\n    <PartNumber>%d</PartNumber>\n    <ETag>%s</ETag>\n  </Part>" % (n, e)
        for n, e in enumerate(etags, 1))
    headers = {"Content-Type": "application/xml"}
    if crc:
        headers["x-amz-checksum-crc64nvme"] = crc
    _, _, raw = transfer("POST", complete, xml.encode("utf-8"), headers, label="POST multipart complete")
    if b"<Error>" in raw:
        raise NexusError("multipart complete rejected: " + raw.decode("utf-8", "replace")[:500])
    return upload_id


def wait_available(upload_id, state):
    deadline = time.monotonic() + POLL_TIMEOUT
    delay = POLL_INTERVAL
    while state != "available":
        if time.monotonic() + delay > deadline:
            raise NexusError("upload %s not available after %ds (state %s)" % (upload_id, POLL_TIMEOUT, state))
        time.sleep(delay)
        delay = min(delay * 1.5, POLL_MAX_INTERVAL)
        state = api("GET", "/uploads/%s" % upload_id, expect=(200,)).get("state")
        log("Upload %s state: %s" % (upload_id, state))


def upload_file(path, use_crc=True):
    path = Path(path)
    if not path.is_file():
        raise NexusError("file not found: %s" % path)
    size = path.stat().st_size
    if size <= 0:
        raise NexusError("file is empty: %s" % path)
    if size > MULTIPART_THRESHOLD:
        upload_id = upload_multipart(path, size, use_crc)
    else:
        upload_id = upload_single(path, size)
    state = api("POST", "/uploads/%s/finalise" % upload_id, expect=(200,)).get("state")
    log("Upload %s finalised (state %s)" % (upload_id, state))
    wait_available(upload_id, state)
    return upload_id


def check_name(name):
    if not name or len(name) > 50 or not NAME_RE.match(name):
        raise NexusError("file name %r must be 1-50 characters of letters, digits, space and _'().-" % name)


def check_version(version):
    if not version or len(version) > 50 or not VERSION_RE.match(version):
        raise NexusError("version %r must be 1-50 characters of letters, digits, . and -" % version)


def check_changelog(text):
    if len(text) > 65535:
        raise NexusError("changelog is %d characters, the API maximum is 65535" % len(text))


def add_changelog(mod_id, version, text):
    api("POST", "/mods/%s/changelogs" % mod_id, {"version": version, "changelog": text}, expect=(201,))
    log("Changelog added to mod %s for %s" % (mod_id, version))


def set_output(name, value):
    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as f:
            f.write("%s=%s\n" % (name, value))


def cmd_upload(a):
    api_key()
    name = a.display_name or Path(a.zip).name
    description = a.description or None
    changelog = a.changelog or None
    check_name(name)
    check_version(a.version)
    if changelog:
        check_changelog(changelog)
        if not a.mod_id:
            raise NexusError("--mod-id is required with --changelog")
    if not Path(a.zip).is_file():
        raise NexusError("file not found: %s" % a.zip)
    existing = existing_version(a.file_id, a.version)
    if existing:
        log("Mod file %s already has version %s (%s); not uploading it again" % (a.file_id, a.version, existing))
        if changelog:
            log("Changelog not added: it is only added in the run that creates the version")
        set_output("version_id", existing)
        print(existing)
        return
    upload_id = upload_file(a.zip, not a.no_crc64)
    body = {
        "upload_id": upload_id,
        "name": name,
        "version": a.version,
        "file_category": a.category,
        "archive_existing_file": False,
        "update_mod_version": bool(a.update_mod_version),
    }
    if description:
        body["description"] = description
    data = api("POST", "/mod-files/%s/versions" % a.file_id, body, expect=(201,))
    version_id = (data.get("version") or {}).get("id")
    if not version_id:
        raise NexusError("POST /mod-files/%s/versions response lacks version.id" % a.file_id)
    log("Mod file %s: version %s created as %s" % (a.file_id, a.version, version_id))
    if changelog:
        add_changelog(a.mod_id, a.version, changelog)
    set_output("version_id", version_id)
    print(version_id)


def existing_version(file_id, version):
    data = api("GET", "/mod-files/%s/versions" % file_id, expect=(200,))
    versions = data.get("versions")
    if not isinstance(versions, list):
        raise NexusError("GET /mod-files/%s/versions response lacks versions" % file_id)
    for v in versions:
        if isinstance(v, dict) and v.get("version") == version and v.get("category") != "removed":
            return str(v.get("id") or "existing")
    return None


def display_base(key):
    if key in ("Polychromatic", "Polychromatic_Empty"):
        return key
    return "Polychromatic - %s" % key


def display_name(key, version):
    return "%s %s" % (display_base(key), version)


def load_rows(dist, matrix):
    dist = Path(dist)
    if not dist.is_dir():
        raise NexusError("dist folder not found: %s" % dist)
    mpath = Path(matrix) if matrix else dist / "matrix.json"
    if mpath.is_file():
        try:
            rows = json.loads(mpath.read_text(encoding="utf-8"))
        except ValueError:
            raise NexusError("%s is not valid JSON" % mpath)
        out = []
        for r in rows:
            if not isinstance(r, dict) or not all(isinstance(r.get(k), str) for k in ("key", "file", "category")):
                raise NexusError("%s row lacks key, file or category: %r" % (mpath, r))
            out.append(r)
    elif matrix:
        raise NexusError("matrix not found: %s" % mpath)
    else:
        out = []
        modules = []
        for z in sorted(dist.glob("*.zip")):
            if z.name == FULL_ZIP:
                out.insert(0, {"key": "Polychromatic", "file": z.name, "category": "main"})
            elif z.name == BASE_ZIP:
                out.append({"key": "Polychromatic_Empty", "file": z.name, "category": "main"})
            else:
                m = MODULE_ZIP_RE.match(z.name)
                if not m:
                    raise NexusError("unexpected zip in %s: %s" % (dist, z.name))
                modules.append({"key": m.group(1), "file": z.name, "category": "optional"})
        out.sort(key=lambda r: 0 if r["key"] == "Polychromatic" else 1)
        out.extend(modules)
    if not out:
        raise NexusError("no zips found in %s" % dist)
    keys = [r["key"] for r in out]
    if len(set(keys)) != len(keys):
        raise NexusError("duplicate keys in matrix: %s" % keys)
    for r in out:
        if r["category"] not in ("main", "optional"):
            raise NexusError("row %s has category %r" % (r["key"], r["category"]))
        if not (dist / r["file"]).is_file():
            raise NexusError("zip missing from %s: %s" % (dist, r["file"]))
    return dist, out


def default_version():
    info = Path(__file__).resolve().parents[2] / "info.json"
    try:
        return json.loads(info.read_text(encoding="utf-8"))["version"]
    except (OSError, ValueError, KeyError):
        raise NexusError("no --version given and %s has no version" % info)


def existing_file_ids(mod_id):
    data = api("GET", "/mods/%s/files" % mod_id, expect=(200,))
    files = data.get("mod_files")
    if not isinstance(files, list):
        raise NexusError("GET /mods/%s/files response lacks mod_files" % mod_id)
    return [(f.get("name") or "", str(f.get("id"))) for f in files
            if isinstance(f, dict) and f.get("id") is not None and f.get("is_active", True) is not False]


def cmd_files(a):
    api_key()
    data = api("GET", "/mods/%s/files" % a.mod_id, expect=(200,))
    files = data.get("mod_files")
    if not isinstance(files, list):
        raise NexusError("GET /mods/%s/files response lacks mod_files" % a.mod_id)
    for f in files:
        if isinstance(f, dict):
            print(json.dumps(f, sort_keys=True))


def find_existing(files, base):
    pat = re.compile(r"^%s(?: v?\d[a-zA-Z0-9.-]*)?$" % re.escape(base), re.I)
    return [fid for name, fid in files if pat.match(name.strip())]


def cmd_create(a):
    api_key()
    version = a.version or default_version()
    check_version(version)
    dist, rows = load_rows(a.dist, a.matrix)
    for r in rows:
        check_name(display_name(r["key"], version))
    files = existing_file_ids(a.mod_id)
    result = {}
    try:
        for r in rows:
            base = display_base(r["key"])
            found = find_existing(files, base)
            if found and not a.allow_duplicate:
                if len(found) > 1:
                    raise NexusError("mod %s already has %d files named %r (%s); set NEXUS_FILE_IDS by hand"
                                     % (a.mod_id, len(found), base, ", ".join(found)))
                log("%s: file %r already exists as %s, not creating it again" % (r["key"], base, found[0]))
                result[r["key"]] = found[0]
                continue
            upload_id = upload_file(dist / r["file"], not a.no_crc64)
            body = {
                "upload_id": upload_id,
                "mod_id": str(a.mod_id),
                "name": display_name(r["key"], version),
                "version": version,
                "file_category": r["category"],
            }
            if a.description:
                body["description"] = a.description
            before = set(i for _, i in existing_file_ids(a.mod_id))
            api("POST", "/mod-files", body, expect=(201,))
            named = [i for n, i in existing_file_ids(a.mod_id) if n == body["name"] and i not in before]
            if len(named) != 1:
                raise NexusError("created %r but GET /mods/%s/files lists %d files with that name; set NEXUS_FILE_IDS by hand"
                                 % (body["name"], a.mod_id, len(named)))
            fid = named[0]
            log("%s: created mod file %s (%s)" % (r["key"], fid, body["name"]))
            result[r["key"]] = str(fid)
    except NexusError:
        if result:
            log("Partial NEXUS_FILE_IDS before the failure: " + json.dumps(result))
        raise
    print(json.dumps(result))


def cmd_resolve_mod(a):
    api_key()
    data = api("GET", "/games/%s/mods/%s" % (a.game, a.mod), expect=(200,))
    mid = data.get("id")
    if not mid:
        raise NexusError("GET /games/%s/mods/%s response lacks id" % (a.game, a.mod))
    set_output("mod_id", mid)
    print(mid)


def check_file_name(name):
    if not name or len(name) > 255 or not NAME_RE.match(name):
        raise NexusError("file name %r must be 1-255 characters of letters, digits, space and _'().-" % name)


def position_key(v):
    try:
        return Decimal(str(v.get("position")))
    except (InvalidOperation, ValueError):
        return Decimal(0)


def list_versions(file_id):
    data = api("GET", "/mod-files/%s/versions" % file_id, expect=(200,))
    versions = data.get("versions")
    if not isinstance(versions, list):
        raise NexusError("GET /mod-files/%s/versions response lacks versions" % file_id)
    return sorted((v for v in versions if isinstance(v, dict)), key=position_key)


def version_line(v):
    parts = [str(v.get("id")), str(v.get("version")), str(v.get("category")), str(v.get("name"))]
    created = v.get("uploaded_at") or v.get("created_at")
    if created:
        parts.append(str(created))
    if v.get("category") in ("removed", "archived") or v.get("removed") or v.get("archived"):
        parts.append("[REMOVED/ARCHIVED]")
    return "\t".join(parts)


def print_versions(file_id):
    for v in list_versions(file_id):
        print(version_line(v))


def cmd_versions(a):
    api_key()
    print_versions(a.file_id)


def version_file(version_id):
    v = api("GET", "/mod-file-versions/%s" % version_id, expect=(200,))
    f = v.get("file")
    if not isinstance(f, dict) or f.get("id") is None:
        raise NexusError("GET /mod-file-versions/%s response lacks file.id" % version_id)
    return str(f["id"]), f.get("name") or ""


def cmd_move(a):
    api_key()
    ids = [i.strip() for i in a.version_ids.split(",") if i.strip()]
    if not ids:
        raise NexusError("--version-ids needs at least one id")
    if len(set(ids)) != len(ids):
        raise NexusError("--version-ids has duplicates")
    if a.target_version in ids:
        raise NexusError("--target-version cannot be one of the versions being moved")
    target_fid, target_name = version_file(a.target_version)
    sources = {}
    for vid in ids:
        fid, name = version_file(vid)
        sources.setdefault(fid, [name, []])[1].append(vid)
    print("Move %d version(s) %s version %s into mod file %s (%s)"
          % (len(ids), a.placement, a.target_version, target_fid, target_name))
    emptied = []
    for fid, (name, moved) in sources.items():
        print("  source mod file %s (%s): %s" % (fid, name, ", ".join(moved)))
        if fid != target_fid:
            if not [v for v in list_versions(fid) if str(v.get("id")) not in moved]:
                emptied.append(fid)
    for fid in emptied:
        print("  WARNING: source mod file %s would be left with NO versions" % fid)
    print("WARNING: A SOURCE MOD FILE LEFT WITH NO VERSIONS IS DELETED AUTOMATICALLY BY NEXUS. THIS CANNOT BE UNDONE.")
    if not a.yes:
        raise NexusError("not moving anything: re-run with --yes to proceed")
    body = {"version_ids": ids, "target": {"target_version_id": a.target_version, "relative_placement": a.placement}}
    data = api("POST", "/mod-file-versions/move", body, expect=(200,), bare=True)
    deleted = data.get("deleted_source_mod_file_ids") or []
    tid = str((data.get("target_mod_file") or {}).get("id") or target_fid)
    log("Moved %d version(s); target mod file %s" % (len(ids), tid))
    print_versions(tid)
    print("deleted_source_mod_file_ids: %s" % (", ".join(str(d) for d in deleted) if deleted else "none"))


def cmd_rename(a):
    api_key()
    check_file_name(a.name)
    api("PUT", "/mod-files/%s" % a.file_id, {"name": a.name}, expect=(200, 204))
    log("Mod file %s renamed to %r" % (a.file_id, a.name))


def parser():
    ap = argparse.ArgumentParser(prog="nexus.py", description="Nexus Mods v3 uploader (API key from NEXUSMODS_APIKEY)")
    sub = ap.add_subparsers(dest="cmd", required=True)

    u = sub.add_parser("upload", help="upload a zip as a new version of an existing mod file")
    u.add_argument("--file-id", required=True)
    u.add_argument("--zip", required=True)
    u.add_argument("--version", required=True)
    u.add_argument("--category", required=True, choices=("main", "optional"))
    u.add_argument("--display-name")
    u.add_argument("--description")
    u.add_argument("--changelog")
    u.add_argument("--mod-id", help="global mod id (needed for --changelog)")
    u.add_argument("--update-mod-version", action="store_true")
    u.add_argument("--no-crc64", action="store_true", help="skip the multipart crc64nvme checksum")
    u.set_defaults(func=cmd_upload)

    c = sub.add_parser("create", help="create one new mod file per zip and print NEXUS_FILE_IDS")
    c.add_argument("--mod-id", required=True, help="global mod id")
    c.add_argument("--dist", required=True)
    c.add_argument("--matrix")
    c.add_argument("--version", help="default: version in info.json")
    c.add_argument("--description")
    c.add_argument("--allow-duplicate", action="store_true")
    c.add_argument("--no-crc64", action="store_true")
    c.set_defaults(func=cmd_create)

    r = sub.add_parser("resolve-mod", help="print the global mod id for a game-scoped mod id")
    r.add_argument("--game", required=True)
    r.add_argument("--mod", required=True)
    r.set_defaults(func=cmd_resolve_mod)

    f = sub.add_parser("files", help="print every mod file of a mod as JSON, one per line")
    f.add_argument("--mod-id", required=True)
    f.set_defaults(func=cmd_files)

    v = sub.add_parser("versions", help="list a mod file's versions, earliest to latest")
    v.add_argument("--file-id", required=True)
    v.set_defaults(func=cmd_versions)

    m = sub.add_parser("move", help="move versions before/after a target version (may delete emptied source files)")
    m.add_argument("--version-ids", required=True, help="comma-separated, earliest to latest")
    m.add_argument("--target-version", required=True)
    m.add_argument("--placement", required=True, choices=("before", "after"))
    m.add_argument("--yes", action="store_true", help="confirm the move")
    m.set_defaults(func=cmd_move)

    n = sub.add_parser("rename", help="rename a mod file")
    n.add_argument("--file-id", required=True)
    n.add_argument("--name", required=True)
    n.set_defaults(func=cmd_rename)
    return ap


def main(argv=None):
    a = parser().parse_args(argv)
    try:
        a.func(a)
    except NexusError as e:
        log("nexus.py: error: %s" % e)
        return 1
    except KeyboardInterrupt:
        log("nexus.py: interrupted")
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())

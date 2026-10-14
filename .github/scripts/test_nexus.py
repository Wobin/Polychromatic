#!/usr/bin/env python3
import base64
import hashlib
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = Path(os.environ.get("NEXUS_SCRIPT") or HERE / "nexus.py")
KEY = "test-key-7f3a9c1e5d"
MD5_RE = re.compile(r"^[0-9a-fA-F]{32}$")
CRC_RE = re.compile(r"^[A-Za-z0-9+/]{11}=$")
NAME_RE = re.compile(r"^[a-zA-Z0-9 _'().-]+$")
VERSION_RE = re.compile(r"^[a-zA-Z0-9.-]+$")

import importlib.util

sys.dont_write_bytecode = True

_spec = importlib.util.spec_from_file_location("nexus_under_test", SCRIPT)
nexus = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(nexus)


def problem(status, title, detail):
    return status, {"type": "about:blank", "title": title, "status": status, "detail": detail, "instance": "/x"}


class Mock:
    def __init__(self):
        self.lock = threading.Lock()
        self.log = []
        self.uploads = {}
        self.mod_files = {}
        self.changelogs = []
        self.part_size = 1024
        self.polls_before_ready = 2
        self.require_md5 = True
        self.fail = {}
        self.hang = set()
        self.echo_key_on_error = False
        self.versions = {}
        self.extra_part_urls = 0
        self.truncate = {}
        self.base = None
        self.renames = {}

    def record(self, method, path, headers, body):
        with self.lock:
            self.log.append({"method": method, "path": path, "headers": headers, "body": body})

    def calls(self, method, prefix):
        return [c for c in self.log if c["method"] == method and c["path"].startswith(prefix)]

    def exact(self, method, path):
        return [c for c in self.log if c["method"] == method and c["path"] == path]


def make_handler(mock):
    class H(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *a):
            pass

        def _send(self, status, doc=None, headers=None, ctype="application/json", raw=None):
            body = raw if raw is not None else (json.dumps(doc).encode() if doc is not None else b"")
            self.send_response(status)
            if body:
                self.send_header("Content-Type", ctype)
            for k, v in (headers or {}).items():
                self.send_header(k, v)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _problem(self, status, title, detail):
            if mock.echo_key_on_error:
                detail = detail + " key=" + self.headers.get("apikey", "")
            _, doc = problem(status, title, detail)
            self._send(status, doc, ctype="application/problem+json")

        def _json(self, body):
            try:
                return json.loads(body or b"{}")
            except ValueError:
                return None

        def handle_any(self, method):
            n = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(n) if n else b""
            path = self.path
            headers = {k.lower(): v for k, v in self.headers.items()}
            mock.record(method, path, headers, body)
            route = "%s %s" % (method, path)
            for pat in mock.hang:
                if re.match(pat, route):
                    time.sleep(3)
            for pat in list(mock.truncate):
                if re.match(pat, route) and mock.truncate[pat] > 0:
                    mock.truncate[pat] -= 1
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", "100")
                    self.end_headers()
                    self.wfile.write(b'{"data"')
                    self.wfile.flush()
                    self.close_connection = True
                    return
            for pat, (status, doc) in mock.fail.items():
                if re.match(pat, route):
                    return self._problem(status, doc["title"], doc["detail"])
            if path.startswith("/v3/"):
                if headers.get("apikey") != KEY:
                    return self._problem(403, "Forbidden", "bad api key")
                return self.api(method, path[3:], headers, body)
            if path.startswith("/s3/"):
                if "apikey" in headers:
                    return self._send(400, raw=b"<Error><Code>Leak</Code></Error>", ctype="application/xml")
                return self.s3(method, path[4:], headers, body)
            self._send(404, {"error": "no route"})

        def do_GET(self):
            self.handle_any("GET")

        def do_POST(self):
            self.handle_any("POST")

        def do_PUT(self):
            self.handle_any("PUT")

        def api(self, method, path, headers, body):
            m = re.match
            if method == "POST" and path == "/uploads":
                req = self._json(body)
                if not isinstance(req, dict) or not isinstance(req.get("size_bytes"), int) or not req.get("filename"):
                    return self._problem(400, "Bad Request", "size_bytes and filename required")
                md5 = req.get("md5")
                if md5 is not None and not MD5_RE.match(md5):
                    return self._problem(422, "Unprocessable Entity", "md5 must be 32 hex characters")
                if md5 is None and mock.require_md5:
                    return self._problem(422, "Unprocessable Entity", "md5 is required")
                if req["size_bytes"] > 100 * 1024 * 1024:
                    return self._problem(422, "Unprocessable Entity", "use multipart")
                uid = str(uuid.uuid4())
                mock.uploads[uid] = {"kind": "single", "req": req, "data": None, "state": "created",
                                     "finalised": False, "polls": 0}
                return self._send(201, {"data": {"id": uid, "user": {"id": "1"}, "state": "created",
                                                 "presigned_url": mock.base + "/s3/single/" + uid}})
            if method == "POST" and path == "/uploads/multipart":
                req = self._json(body)
                if not isinstance(req, dict) or not isinstance(req.get("size_bytes"), int) or not req.get("filename"):
                    return self._problem(400, "Bad Request", "size_bytes and filename required")
                if "md5" in req:
                    return self._problem(422, "Unprocessable Content", "md5 is not a multipart field")
                crc = req.get("crc64nvme")
                if crc is not None and not CRC_RE.match(crc):
                    return self._problem(422, "Unprocessable Content", "bad crc64nvme")
                uid = str(uuid.uuid4())
                count = max(1, math.ceil(req["size_bytes"] / mock.part_size)) + mock.extra_part_urls
                mock.uploads[uid] = {"kind": "multi", "req": req, "parts": {}, "data": None, "state": "created",
                                     "finalised": False, "polls": 0}
                return self._send(201, {"data": {
                    "id": uid, "user": {"id": "1"}, "state": "created", "part_size_bytes": mock.part_size,
                    "part_presigned_urls": [mock.base + "/s3/part/%s/%d" % (uid, i) for i in range(1, count + 1)],
                    "complete_presigned_url": mock.base + "/s3/complete/" + uid}})
            r = m(r"^/uploads/([0-9a-f-]+)/finalise$", path)
            if method == "POST" and r:
                up = mock.uploads.get(r.group(1))
                if not up:
                    return self._problem(404, "Not Found", "no upload")
                if up["data"] is None:
                    return self._problem(422, "Unprocessable Entity", "no data uploaded")
                up["finalised"] = True
                return self._send(200, {"data": {"id": r.group(1), "user": {"id": "1"}, "state": up["state"]}})
            r = m(r"^/uploads/([0-9a-f-]+)$", path)
            if method == "GET" and r:
                up = mock.uploads.get(r.group(1))
                if not up:
                    return self._problem(404, "Not Found", "no upload")
                if up["finalised"]:
                    up["polls"] += 1
                    if up["polls"] >= mock.polls_before_ready:
                        up["state"] = "available"
                return self._send(200, {"data": {"id": r.group(1), "user": {"id": "1"}, "state": up["state"]}})
            r = m(r"^/mod-files/([^/]+)/versions$", path)
            if method == "POST" and r:
                req = self._json(body) or {}
                err = self.check_file_body(req, ("upload_id", "name", "version", "file_category"))
                if err:
                    return self._problem(422, "Unprocessable Content", err)
                fid = r.group(1)
                vid = "ver-" + req["upload_id"][:8]
                mock.versions.setdefault(fid, []).append({
                    "id": vid, "file": {"id": fid, "name": req["name"]}, "position": "2", "game_scoped_id": "77",
                    "name": req["name"], "version": req["version"], "category": req["file_category"],
                    "uploaded_at": "2026-10-14T00:00:00Z"})
                return self._send(201, {"data": {
                    "file": {"id": fid, "game_scoped_id": "77", "name": req["name"], "file_category": req["file_category"]},
                    "version": {"id": "ver-" + req["upload_id"][:8], "position": "2"}}})
            if method == "GET" and r:
                return self._send(200, {"data": {"versions": mock.versions.get(r.group(1), [])}})
            if method == "POST" and path == "/mod-file-versions/move":
                req = self._json(body) or {}
                tgt = req.get("target") or {}
                if not req.get("version_ids") or tgt.get("relative_placement") not in ("before", "after"):
                    return self._problem(422, "Unprocessable Content", "bad move")
                found = {v["id"]: (fid, v) for fid, vs in mock.versions.items() for v in vs}
                if tgt.get("target_version_id") not in found or any(i not in found for i in req["version_ids"]):
                    return self._problem(404, "Not Found", "no version")
                tfid = found[tgt["target_version_id"]][0]
                moved = [found[i][1] for i in req["version_ids"]]
                sources = {found[i][0] for i in req["version_ids"]}
                for fid in sources:
                    mock.versions[fid] = [v for v in mock.versions[fid] if v["id"] not in req["version_ids"]]
                lst = mock.versions[tfid]
                at = [v["id"] for v in lst].index(tgt["target_version_id"])
                at = at if tgt["relative_placement"] == "before" else at + 1
                lst[at:at] = moved
                for i, v in enumerate(lst):
                    v["position"] = str(i + 1)
                    v["file"] = {"id": tfid, "name": v["file"]["name"]}
                deleted = sorted(f for f in sources if f != tfid and not mock.versions[f])
                for f in deleted:
                    del mock.versions[f]
                return self._send(200, {"versions": moved, "deleted_source_mod_file_ids": deleted,
                                        "target_mod_file": {"id": tfid, "name": "t", "is_active": True,
                                                            "last_file_uploaded_at": None, "versions_count": len(lst),
                                                            "archived_count": 0, "removed_count": 0}})
            if method == "POST" and path == "/mod-files":
                req = self._json(body) or {}
                err = self.check_file_body(req, ("upload_id", "mod_id", "name", "version", "file_category"))
                if err:
                    return self._problem(422, "Unprocessable Entity", err)
                files = mock.mod_files.setdefault(req["mod_id"], [])
                fid = "mf-%d" % (100 + sum(len(v) for v in mock.mod_files.values()))
                files.append({"id": fid, "name": req["name"]})
                return self._send(201, {"data": {"id": "ver-" + fid[3:], "game_scoped_id": fid[3:], "name": req["name"],
                                                 "file_category": req["file_category"]}})
            r = m(r"^/mod-file-versions/([^/]+)$", path)
            if method == "GET" and r:
                for vs in mock.versions.values():
                    for v in vs:
                        if v["id"] == r.group(1):
                            return self._send(200, {"data": v})
                return self._problem(404, "Not Found", "no version")
            r = m(r"^/mod-files/([^/]+)$", path)
            if method == "PUT" and r:
                req = self._json(body)
                name = req.get("name") if isinstance(req, dict) else None
                if set(req or {}) != {"name"} or not name or len(name) > 255 or not NAME_RE.match(name):
                    return self._problem(422, "Unprocessable Content", "bad name")
                mock.renames[r.group(1)] = name
                return self._send(204)
            r = m(r"^/mods/([^/]+)/files$", path)
            if method == "GET" and r:
                files = [dict({"is_active": True}, **f, last_file_uploaded_at=None, versions_count=1, archived_count=0,
                              removed_count=0) for f in mock.mod_files.get(r.group(1), [])]
                return self._send(200, {"data": {"mod_files": files}})
            r = m(r"^/mods/([^/]+)/changelogs$", path)
            if method == "POST" and r:
                req = self._json(body) or {}
                if not VERSION_RE.match(req.get("version") or "") or not req.get("changelog"):
                    return self._problem(422, "Unprocessable Content", "version and changelog required")
                mock.changelogs.append((r.group(1), req["version"], req["changelog"]))
                return self._send(201, {"data": {"version": req["version"], "changelog": req["changelog"]}})
            r = m(r"^/games/([^/]+)/mods/([^/]+)$", path)
            if method == "GET" and r:
                if r.group(1) != "warhammer40kdarktide":
                    return self._problem(404, "Not Found", "no game")
                return self._send(200, {"data": {"id": "998877", "game_scoped_id": r.group(2), "game_id": "4943",
                                                 "name": "Polychromatic"}})
            return self._problem(404, "Not Found", "no route " + path)

        def check_file_body(self, req, required):
            for k in required:
                if not req.get(k):
                    return "%s is required" % k
            up = mock.uploads.get(req["upload_id"])
            if not up or up["state"] != "available":
                return "upload is not available"
            if len(req["name"]) > 50 or not NAME_RE.match(req["name"]):
                return "bad name"
            if len(req["version"]) > 50 or not VERSION_RE.match(req["version"]):
                return "bad version"
            if req["file_category"] not in ("main", "optional", "miscellaneous"):
                return "bad category"
            return None

        def s3(self, method, path, headers, body):
            r = re.match(r"^single/([0-9a-f-]+)$", path)
            if method == "PUT" and r:
                up = mock.uploads.get(r.group(1))
                want = 'attachment; filename="%s"' % up["req"]["filename"]
                if headers.get("content-disposition") != want:
                    return self._send(403, raw=b"<Error><Code>SignatureDoesNotMatch</Code></Error>", ctype="application/xml")
                md5 = up["req"].get("md5")
                if md5:
                    b64 = base64.b64encode(bytes.fromhex(md5)).decode()
                    if headers.get("content-md5") != b64:
                        return self._send(403, raw=b"<Error><Code>SignatureDoesNotMatch</Code></Error>", ctype="application/xml")
                    if hashlib.md5(body).hexdigest() != md5.lower():
                        return self._send(400, raw=b"<Error><Code>BadDigest</Code></Error>", ctype="application/xml")
                if len(body) != up["req"]["size_bytes"]:
                    return self._send(400, raw=b"<Error><Code>IncompleteBody</Code></Error>", ctype="application/xml")
                up["data"] = body
                return self._send(200, headers={"ETag": '"%s"' % hashlib.md5(body).hexdigest()})
            r = re.match(r"^part/([0-9a-f-]+)/(\d+)$", path)
            if method == "PUT" and r:
                up = mock.uploads[r.group(1)]
                up["parts"][int(r.group(2))] = body
                return self._send(200, headers={"ETag": '"%s"' % hashlib.md5(body).hexdigest()})
            r = re.match(r"^complete/([0-9a-f-]+)$", path)
            if method == "POST" and r:
                up = mock.uploads[r.group(1)]
                nums = [int(x) for x in re.findall(rb"<PartNumber>(\d+)</PartNumber>", body)]
                tags = [x.decode() for x in re.findall(rb"<ETag>([^<]+)</ETag>", body)]
                if nums != sorted(up["parts"]) or len(tags) != len(nums):
                    return self._send(400, raw=b"<Error><Code>InvalidPart</Code></Error>", ctype="application/xml")
                for n, t in zip(nums, tags):
                    if hashlib.md5(up["parts"][n]).hexdigest() != t:
                        return self._send(400, raw=b"<Error><Code>InvalidPart</Code></Error>", ctype="application/xml")
                data = b"".join(up["parts"][n] for n in nums)
                crc = up["req"].get("crc64nvme")
                if crc:
                    actual = base64.b64encode(nexus.crc64nvme(data).to_bytes(8, "big")).decode()
                    if headers.get("x-amz-checksum-crc64nvme") != crc or actual != crc:
                        return self._send(400, raw=b"<Error><Code>BadDigest</Code></Error>", ctype="application/xml")
                up["data"] = data
                return self._send(200, raw=b"<CompleteMultipartUploadResult/>", ctype="application/xml")
            return self._send(404, raw=b"<Error/>", ctype="application/xml")

    return H


class QuietServer(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        pass


class NexusTest(unittest.TestCase):
    def setUp(self):
        self.mock = Mock()
        self.server = QuietServer(("127.0.0.1", 0), make_handler(self.mock))
        self.mock.base = "http://127.0.0.1:%d" % self.server.server_address[1]
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.tmp.cleanup()

    def run_cli(self, *args, key=KEY, **env_extra):
        env = {k: v for k, v in os.environ.items()
               if not k.startswith("NEXUS") and k != "GITHUB_OUTPUT" and not k.lower().endswith("_proxy")}
        env.update({"NEXUSMODS_API_BASE": self.mock.base + "/v3", "NEXUS_POLL_INTERVAL": "0.01",
                    "NEXUS_POLL_TIMEOUT": "5", "NEXUS_HTTP_TIMEOUT": "5", "NEXUS_TRANSFER_TIMEOUT": "5",
                    "NO_PROXY": "*", "no_proxy": "*"})
        if key is not None:
            env["NEXUSMODS_APIKEY"] = key
        env.update({k: str(v) for k, v in env_extra.items()})
        p = subprocess.run([sys.executable, str(SCRIPT)] + list(args), env=env, capture_output=True, text=True,
                           timeout=60)
        if key:
            self.assertNotIn(key, p.stdout)
            self.assertNotIn(key, p.stderr)
        return p

    def zip(self, name, size, folder=None):
        folder = folder or self.dir
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / name
        path.write_bytes(bytes((i * 31 + 7) % 251 for i in range(size)))
        return path

    def assert_order(self, uid):
        seq = [c["method"] + " " + c["path"] for c in self.mock.log if uid in c["path"]]
        fin = seq.index("POST /v3/uploads/%s/finalise" % uid)
        polls = [i for i, s in enumerate(seq) if s == "GET /v3/uploads/%s" % uid]
        self.assertTrue(polls and all(i > fin for i in polls), seq)

    def test_single_part_upload_md5_headers_version_and_changelog(self):
        z = self.zip("Polychromatic.zip", 5000)
        p = self.run_cli("upload", "--file-id", "4242", "--zip", str(z), "--version", "v2.0.0", "--category", "main",
                         "--display-name", "Polychromatic v2.0.0", "--description=- notes",
                         "--changelog=- Fixed things", "--mod-id", "998877", "--update-mod-version")
        self.assertEqual(p.returncode, 0, p.stderr)
        create = self.mock.exact("POST", "/v3/uploads")
        self.assertEqual(len(create), 1)
        req = json.loads(create[0]["body"])
        digest = hashlib.md5(z.read_bytes())
        self.assertEqual(req, {"size_bytes": 5000, "filename": "Polychromatic.zip", "md5": digest.hexdigest()})
        self.assertEqual(create[0]["headers"]["content-type"], "application/json")
        put = self.mock.calls("PUT", "/s3/single/")
        self.assertEqual(len(put), 1)
        self.assertEqual(put[0]["headers"]["content-md5"], base64.b64encode(digest.digest()).decode())
        self.assertEqual(put[0]["headers"]["content-disposition"], 'attachment; filename="Polychromatic.zip"')
        self.assertNotIn("apikey", put[0]["headers"])
        self.assertFalse(self.mock.calls("POST", "/v3/uploads/multipart"))
        uid = next(iter(self.mock.uploads))
        self.assert_order(uid)
        self.assertEqual(len(self.mock.calls("GET", "/v3/uploads/")), self.mock.polls_before_ready)
        ver = self.mock.calls("POST", "/v3/mod-files/4242/versions")
        self.assertEqual(len(ver), 1)
        self.assertEqual(json.loads(ver[0]["body"]), {
            "upload_id": uid, "name": "Polychromatic v2.0.0", "version": "v2.0.0", "file_category": "main",
            "archive_existing_file": False, "update_mod_version": True, "description": "- notes"})
        self.assertEqual(self.mock.changelogs, [("998877", "v2.0.0", "- Fixed things")])
        self.assertEqual(p.stdout.strip(), "ver-" + uid[:8])

    def test_no_changelog_and_no_update_flag(self):
        z = self.zip("Polychromatic - Guns.zip", 300)
        p = self.run_cli("upload", "--file-id", "1", "--zip", str(z), "--version", "1.0.0", "--category", "optional",
                         "--changelog=")
        self.assertEqual(p.returncode, 0, p.stderr)
        body = json.loads(self.mock.calls("POST", "/v3/mod-files/1/versions")[0]["body"])
        self.assertEqual(body["name"], "Polychromatic - Guns.zip")
        self.assertIs(body["update_mod_version"], False)
        self.assertNotIn("description", body)
        self.assertFalse(self.mock.calls("POST", "/v3/mods/"))

    def test_github_output_written(self):
        z = self.zip("a.zip", 10)
        out = self.dir / "gh_out"
        p = self.run_cli("upload", "--file-id", "1", "--zip", str(z), "--version", "1.0.0", "--category", "main",
                         GITHUB_OUTPUT=out)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertRegex(out.read_text(), r"^version_id=ver-[0-9a-f]{8}\n$")

    def test_multipart_above_threshold_part_sizes_and_crc(self):
        z = self.zip("big.zip", 2500)
        p = self.run_cli("upload", "--file-id", "9", "--zip", str(z), "--version", "1.0.0", "--category", "main",
                         NEXUS_MULTIPART_THRESHOLD=1000)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse(self.mock.calls("POST", "/v3/uploads/multipart") == [])
        self.assertEqual(self.mock.exact("POST", "/v3/uploads"), [])
        req = json.loads(self.mock.calls("POST", "/v3/uploads/multipart")[0]["body"])
        crc = base64.b64encode(nexus.crc64nvme(z.read_bytes()).to_bytes(8, "big")).decode()
        self.assertEqual(req, {"size_bytes": 2500, "filename": "big.zip", "crc64nvme": crc})
        parts = self.mock.calls("PUT", "/s3/part/")
        self.assertEqual([len(c["body"]) for c in parts], [1024, 1024, 452])
        self.assertEqual([c["path"].rsplit("/", 1)[1] for c in parts], ["1", "2", "3"])
        comp = self.mock.calls("POST", "/s3/complete/")
        self.assertEqual(len(comp), 1)
        self.assertEqual(comp[0]["headers"]["x-amz-checksum-crc64nvme"], crc)
        self.assertEqual(comp[0]["headers"]["content-type"], "application/xml")
        uid = next(iter(self.mock.uploads))
        self.assertEqual(self.mock.uploads[uid]["data"], z.read_bytes())
        self.assert_order(uid)
        self.assertEqual(len(self.mock.calls("POST", "/v3/mod-files/9/versions")), 1)

    def test_multipart_without_crc(self):
        z = self.zip("big.zip", 2048)
        p = self.run_cli("upload", "--file-id", "9", "--zip", str(z), "--version", "1.0.0", "--category", "main",
                         "--no-crc64", NEXUS_MULTIPART_THRESHOLD=1000)
        self.assertEqual(p.returncode, 0, p.stderr)
        req = json.loads(self.mock.calls("POST", "/v3/uploads/multipart")[0]["body"])
        self.assertNotIn("crc64nvme", req)
        self.assertEqual([len(c["body"]) for c in self.mock.calls("PUT", "/s3/part/")], [1024, 1024])
        self.assertNotIn("x-amz-checksum-crc64nvme", self.mock.calls("POST", "/s3/complete/")[0]["headers"])

    def test_single_part_at_exact_threshold(self):
        z = self.zip("edge.zip", 1000)
        p = self.run_cli("upload", "--file-id", "9", "--zip", str(z), "--version", "1.0.0", "--category", "main",
                         NEXUS_MULTIPART_THRESHOLD=1000)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse(self.mock.calls("POST", "/v3/uploads/multipart"))
        self.assertEqual(len(self.mock.calls("PUT", "/s3/single/")), 1)

    @unittest.skipIf("NEXUS_MULTIPART_THRESHOLD" in os.environ, "threshold overridden in this environment")
    def test_default_threshold_is_100_mib(self):
        self.assertEqual(nexus.MULTIPART_THRESHOLD, 100 * 1024 * 1024)

    def test_crc64nvme_check_value(self):
        self.assertEqual(nexus.crc64nvme(b"123456789"), 0xAE8B14860A799888)

    def dist(self):
        d = self.dir / "dist"
        for name in ("Polychromatic.zip", "Polychromatic_Empty.zip", "Polychromatic - Guns.zip",
                     "Polychromatic - Staves.zip"):
            self.zip(name, 200 + len(name), d)
        return d

    def test_create_prints_file_ids_and_refuses_duplicates(self):
        d = self.dist()
        p = self.run_cli("create", "--mod-id", "998877", "--dist", str(d), "--version", "2.0.0")
        self.assertEqual(p.returncode, 0, p.stderr)
        ids = json.loads(p.stdout)
        self.assertEqual(list(ids), ["Polychromatic", "Polychromatic_Empty", "Guns", "Staves"])
        bodies = [json.loads(c["body"]) for c in self.mock.exact("POST", "/v3/mod-files")]
        self.assertEqual([(b["name"], b["file_category"], b["mod_id"], b["version"]) for b in bodies], [
            ("Polychromatic 2.0.0", "main", "998877", "2.0.0"),
            ("Polychromatic_Empty 2.0.0", "main", "998877", "2.0.0"),
            ("Polychromatic - Guns 2.0.0", "optional", "998877", "2.0.0"),
            ("Polychromatic - Staves 2.0.0", "optional", "998877", "2.0.0")])
        self.assertEqual(sorted(ids.values()), sorted(f["id"] for f in self.mock.mod_files["998877"]))
        self.assertEqual(len(self.mock.calls("PUT", "/s3/single/")), 4)
        for c in self.mock.exact("POST", "/v3/uploads"):
            self.assertRegex(json.loads(c["body"])["md5"], MD5_RE)

        before = len(self.mock.log)
        again = self.run_cli("create", "--mod-id", "998877", "--dist", str(d), "--version", "2.0.0")
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual(json.loads(again.stdout), ids)
        new = self.mock.log[before:]
        self.assertEqual([c["method"] + " " + c["path"] for c in new], ["GET /v3/mods/998877/files"])
        self.assertIn("already exists", again.stderr)

        dup = self.run_cli("create", "--mod-id", "998877", "--dist", str(d), "--version", "2.0.0",
                           "--allow-duplicate")
        self.assertEqual(dup.returncode, 0, dup.stderr)
        self.assertEqual(len(self.mock.mod_files["998877"]), 8)
        self.assertNotEqual(json.loads(dup.stdout), ids)

    def test_create_duplicate_match_ignores_version_suffix_only(self):
        self.mock.mod_files["5"] = [{"id": "old-1", "name": "Polychromatic v1.9.0"},
                                    {"id": "old-2", "name": "Polychromatic_Empty"}]
        d = self.dist()
        p = self.run_cli("create", "--mod-id", "5", "--dist", str(d), "--version", "2.0.0")
        self.assertEqual(p.returncode, 0, p.stderr)
        ids = json.loads(p.stdout)
        self.assertEqual(ids["Polychromatic"], "old-1")
        self.assertEqual(ids["Polychromatic_Empty"], "old-2")
        self.assertEqual(len(self.mock.exact("POST", "/v3/mod-files")), 2)

    def test_create_ambiguous_existing_names_fail(self):
        self.mock.mod_files["5"] = [{"id": "a", "name": "Polychromatic"},
                                    {"id": "b", "name": "Polychromatic 1.0.0"}]
        p = self.run_cli("create", "--mod-id", "5", "--dist", str(self.dist()), "--version", "2.0.0")
        self.assertEqual(p.returncode, 1)
        self.assertIn("already has 2 files", p.stderr)
        self.assertFalse(self.mock.calls("POST", "/v3/uploads"))

    def test_create_uses_matrix_json_and_info_json_version(self):
        d = self.dist()
        (d / "matrix.json").write_text(json.dumps([
            {"key": "Polychromatic", "file": "Polychromatic.zip", "category": "main"},
            {"key": "Guns", "file": "Polychromatic - Guns.zip", "category": "optional"}]))
        p = self.run_cli("create", "--mod-id", "998877", "--dist", str(d))
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(list(json.loads(p.stdout)), ["Polychromatic", "Guns"])
        version = json.loads((HERE.parents[1] / "info.json").read_text(encoding="utf-8"))["version"]
        self.assertTrue(all(json.loads(c["body"])["version"] == version
                            for c in self.mock.exact("POST", "/v3/mod-files")))

    def test_create_partial_failure_reports_ids(self):
        self.mock.fail[r"POST /v3/mod-files$"] = problem(422, "Unprocessable Entity", "nope")
        p = self.run_cli("create", "--mod-id", "998877", "--dist", str(self.dist()), "--version", "2.0.0")
        self.assertEqual(p.returncode, 1)
        self.assertIn("POST /mod-files failed: HTTP 422", p.stderr)
        self.assertIn("nope", p.stderr)
        self.assertEqual(p.stdout, "")

    def test_resolve_mod(self):
        p = self.run_cli("resolve-mod", "--game", "warhammer40kdarktide", "--mod", "1346")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout.strip(), "998877")
        self.assertEqual(self.mock.log[0]["path"], "/v3/games/warhammer40kdarktide/mods/1346")
        self.assertEqual(self.mock.log[0]["headers"]["apikey"], KEY)

    def test_resolve_mod_not_found(self):
        p = self.run_cli("resolve-mod", "--game", "nope", "--mod", "1346")
        self.assertEqual(p.returncode, 1)
        self.assertIn("HTTP 404", p.stderr)

    def test_api_problem_details_surface_and_key_redacted(self):
        self.mock.echo_key_on_error = True
        self.mock.fail[r"POST /v3/mod-files/7/versions"] = problem(422, "Unprocessable Content", "name too long")
        z = self.zip("a.zip", 10)
        p = self.run_cli("upload", "--file-id", "7", "--zip", str(z), "--version", "1.0.0", "--category", "main")
        self.assertEqual(p.returncode, 1)
        self.assertIn("POST /mod-files/7/versions failed: HTTP 422", p.stderr)
        self.assertIn("name too long", p.stderr)
        self.assertIn("key=***", p.stderr)

    def test_missing_api_key(self):
        z = self.zip("a.zip", 10)
        p = self.run_cli("upload", "--file-id", "7", "--zip", str(z), "--version", "1.0.0", "--category", "main",
                         key=None)
        self.assertEqual(p.returncode, 1)
        self.assertIn("NEXUSMODS_APIKEY is not set", p.stderr)
        self.assertEqual(self.mock.log, [])

    def test_wrong_api_key_forbidden(self):
        z = self.zip("a.zip", 10)
        p = self.run_cli("upload", "--file-id", "7", "--zip", str(z), "--version", "1.0.0", "--category", "main",
                         key="other-key-123456")
        self.assertEqual(p.returncode, 1)
        self.assertIn("GET /mod-files/7/versions failed: HTTP 403", p.stderr)

    def test_http_timeout(self):
        self.mock.hang.add(r"POST /v3/uploads$")
        z = self.zip("a.zip", 10)
        t = time.monotonic()
        p = self.run_cli("upload", "--file-id", "7", "--zip", str(z), "--version", "1.0.0", "--category", "main",
                         NEXUS_HTTP_TIMEOUT=0.5)
        self.assertEqual(p.returncode, 1)
        self.assertIn("POST /uploads failed", p.stderr)
        self.assertIn("timed out", p.stderr)
        self.assertLess(time.monotonic() - t, 10)

    def test_presigned_put_timeout_retries_then_fails(self):
        self.mock.hang.add(r"PUT /s3/single/")
        z = self.zip("a.zip", 10)
        p = self.run_cli("upload", "--file-id", "7", "--zip", str(z), "--version", "1.0.0", "--category", "main",
                         NEXUS_TRANSFER_TIMEOUT=0.5)
        self.assertEqual(p.returncode, 1)
        self.assertEqual(len(self.mock.calls("PUT", "/s3/single/")), 3)
        self.assertIn("PUT presigned upload failed", p.stderr)
        self.assertFalse(self.mock.calls("POST", "/v3/mod-files"))

    def test_presigned_put_4xx_not_retried(self):
        self.mock.fail[r"PUT /s3/single/"] = problem(403, "SignatureDoesNotMatch", "sig")
        z = self.zip("a.zip", 10)
        p = self.run_cli("upload", "--file-id", "7", "--zip", str(z), "--version", "1.0.0", "--category", "main")
        self.assertEqual(p.returncode, 1)
        self.assertEqual(len(self.mock.calls("PUT", "/s3/single/")), 1)

    def test_poll_is_bounded(self):
        self.mock.polls_before_ready = 10 ** 9
        z = self.zip("a.zip", 10)
        t = time.monotonic()
        p = self.run_cli("upload", "--file-id", "7", "--zip", str(z), "--version", "1.0.0", "--category", "main",
                         NEXUS_POLL_TIMEOUT=0.5)
        self.assertEqual(p.returncode, 1)
        self.assertIn("not available after", p.stderr)
        self.assertLess(time.monotonic() - t, 10)
        self.assertFalse(self.mock.calls("POST", "/v3/mod-files"))

    def test_local_validation_errors(self):
        z = self.zip("a.zip", 10)
        cases = [
            (["--version", "1.0.0 beta"], "version"),
            (["--version", "1.0.0", "--display-name", "Bad: name"], "file name"),
            (["--version", "1.0.0", "--changelog", "x"], "--mod-id is required"),
        ]
        for extra, msg in cases:
            p = self.run_cli("upload", "--file-id", "7", "--zip", str(z), "--category", "main", *extra)
            self.assertEqual(p.returncode, 1, extra)
            self.assertIn(msg, p.stderr)
        p = self.run_cli("upload", "--file-id", "7", "--zip", str(self.dir / "missing.zip"), "--version", "1",
                         "--category", "main")
        self.assertEqual(p.returncode, 1)
        self.assertIn("file not found", p.stderr)
        self.assertEqual(self.mock.log, [])

    def full_upload(self, z):
        return self.run_cli("upload", "--file-id", "11", "--zip", str(z), "--version", "v2.0.0", "--category",
                            "main", "--display-name", "Polychromatic v2.0.0", "--changelog=- notes",
                            "--mod-id", "998877", "--update-mod-version")

    def test_upload_rerun_skips_existing_version_and_changelog(self):
        z = self.zip("Polychromatic.zip", 400)
        first = self.full_upload(z)
        self.assertEqual(first.returncode, 0, first.stderr)
        before = len(self.mock.log)
        again = self.full_upload(z)
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual(again.stdout.strip(), first.stdout.strip())
        self.assertIn("already has version v2.0.0", again.stderr)
        self.assertEqual([c["method"] + " " + c["path"] for c in self.mock.log[before:]],
                         ["GET /v3/mod-files/11/versions"])
        self.assertEqual(len(self.mock.versions["11"]), 1)
        self.assertEqual(len(self.mock.changelogs), 1)

    def test_upload_rerun_after_changelog_failure_does_not_duplicate_version(self):
        self.mock.fail[r"POST /v3/mods/998877/changelogs"] = problem(500, "Server Error", "boom")
        z = self.zip("Polychromatic.zip", 400)
        first = self.full_upload(z)
        self.assertEqual(first.returncode, 1)
        del self.mock.fail[r"POST /v3/mods/998877/changelogs"]
        again = self.full_upload(z)
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual(len(self.mock.versions["11"]), 1)
        self.assertEqual(self.mock.changelogs, [])
        self.assertIn("Changelog not added", again.stderr)

    def test_upload_ignores_removed_version_with_same_string(self):
        self.mock.versions["11"] = [{"id": "old", "version": "v2.0.0", "category": "removed"}]
        z = self.zip("Polychromatic.zip", 400)
        p = self.full_upload(z)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(len(self.mock.versions["11"]), 2)
        self.assertEqual(len(self.mock.changelogs), 1)

    def test_multipart_accepts_extra_part_urls(self):
        self.mock.extra_part_urls = 2
        z = self.zip("big.zip", 2500)
        p = self.run_cli("upload", "--file-id", "9", "--zip", str(z), "--version", "1.0.0", "--category", "main",
                         NEXUS_MULTIPART_THRESHOLD=1000)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual([len(c["body"]) for c in self.mock.calls("PUT", "/s3/part/")], [1024, 1024, 452])
        comp = self.mock.calls("POST", "/s3/complete/")[0]["body"]
        self.assertEqual(re.findall(rb"<PartNumber>(\d+)</PartNumber>", comp), [b"1", b"2", b"3"])

    def test_multipart_too_few_part_urls_fails(self):
        self.mock.extra_part_urls = -1
        z = self.zip("big.zip", 2500)
        p = self.run_cli("upload", "--file-id", "9", "--zip", str(z), "--version", "1.0.0", "--category", "main",
                         NEXUS_MULTIPART_THRESHOLD=1000)
        self.assertEqual(p.returncode, 1)
        self.assertIn("offers 2 part URLs, file needs 3", p.stderr)

    def test_create_ignores_inactive_files(self):
        self.mock.mod_files["5"] = [{"id": "gone", "name": "Polychromatic", "is_active": False}]
        p = self.run_cli("create", "--mod-id", "5", "--dist", str(self.dist()), "--version", "2.0.0")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNotEqual(json.loads(p.stdout)["Polychromatic"], "gone")
        self.assertEqual(len(self.mock.exact("POST", "/v3/mod-files")), 4)

    def test_incomplete_read_on_api_call_is_clean_error(self):
        self.mock.truncate[r"POST /v3/uploads$"] = 1
        z = self.zip("a.zip", 10)
        p = self.run_cli("upload", "--file-id", "7", "--zip", str(z), "--version", "1.0.0", "--category", "main")
        self.assertEqual(p.returncode, 1)
        self.assertIn("POST /uploads failed: IncompleteRead", p.stderr)
        self.assertNotIn("Traceback", p.stderr)

    def test_incomplete_read_on_get_and_put_is_retried(self):
        self.mock.truncate[r"GET /v3/mod-files/7/versions"] = 1
        self.mock.truncate[r"PUT /s3/single/"] = 1
        z = self.zip("a.zip", 10)
        p = self.run_cli("upload", "--file-id", "7", "--zip", str(z), "--version", "1.0.0", "--category", "main")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(len(self.mock.calls("GET", "/v3/mod-files/7/versions")), 2)
        self.assertEqual(len(self.mock.calls("PUT", "/s3/single/")), 2)
        self.assertIn("retrying", p.stderr)
        self.assertNotIn("Traceback", p.stderr)

    def test_accept_header_includes_problem_json(self):
        p = self.run_cli("resolve-mod", "--game", "warhammer40kdarktide", "--mod", "1346")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.mock.log[0]["headers"]["accept"], "application/json, application/problem+json")

    def test_bad_category_rejected_by_argparse(self):
        z = self.zip("a.zip", 10)
        p = self.run_cli("upload", "--file-id", "7", "--zip", str(z), "--version", "1", "--category", "update")
        self.assertEqual(p.returncode, 2)

    def seed_two_files(self):
        def ver(vid, fid, fname, pos, num, cat="main"):
            return {"id": vid, "file": {"id": fid, "name": fname}, "position": pos, "game_scoped_id": "1",
                    "name": fname, "version": num, "category": cat, "uploaded_at": "2026-01-0%sT00:00:00Z" % pos}
        self.mock.versions["f1"] = [ver("v2", "f1", "Old", "2", "1.1.0"), ver("v1", "f1", "Old", "1", "1.0.0"),
                                    ver("v3", "f1", "Old", "3", "1.2.0", "removed")]
        self.mock.versions["f2"] = [ver("t1", "f2", "New", "1", "2.0.0"), ver("t2", "f2", "New", "2", "2.1.0")]

    def test_versions_lists_earliest_to_latest_and_marks_removed(self):
        self.seed_two_files()
        p = self.run_cli("versions", "--file-id", "f1")
        self.assertEqual(p.returncode, 0, p.stderr)
        lines = p.stdout.strip().splitlines()
        self.assertEqual([l.split("\t")[0] for l in lines], ["v1", "v2", "v3"])
        self.assertIn("1.0.0\tmain\tOld\t2026-01-01T00:00:00Z", lines[0])
        self.assertIn("REMOVED/ARCHIVED", lines[2])
        self.assertNotIn("REMOVED", lines[0])

    def test_move_requires_yes_and_warns(self):
        self.seed_two_files()
        p = self.run_cli("move", "--version-ids", "v1,v2,v3", "--target-version", "t1", "--placement", "after")
        self.assertEqual(p.returncode, 1)
        self.assertIn("DELETED AUTOMATICALLY", p.stdout)
        self.assertIn("would be left with NO versions", p.stdout)
        self.assertIn("--yes", p.stderr)
        self.assertFalse(self.mock.exact("POST", "/v3/mod-file-versions/move"))

    def test_move_sends_exact_body_and_prints_deleted_ids(self):
        self.seed_two_files()
        p = self.run_cli("move", "--version-ids", "v1,v2,v3", "--target-version", "t1", "--placement", "before",
                         "--yes")
        self.assertEqual(p.returncode, 0, p.stderr)
        calls = self.mock.exact("POST", "/v3/mod-file-versions/move")
        self.assertEqual(len(calls), 1)
        self.assertEqual(json.loads(calls[0]["body"]), {
            "version_ids": ["v1", "v2", "v3"],
            "target": {"target_version_id": "t1", "relative_placement": "before"}})
        self.assertIn("deleted_source_mod_file_ids: f1", p.stdout)
        self.assertEqual([l.split("\t")[0] for l in p.stdout.splitlines() if l[:2] in ("v1", "v2", "v3", "t1", "t2")],
                         ["v1", "v2", "v3", "t1", "t2"])

    def test_move_partial_source_not_emptied(self):
        self.seed_two_files()
        p = self.run_cli("move", "--version-ids", "v1", "--target-version", "t2", "--placement", "after", "--yes")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNotIn("would be left with NO versions", p.stdout)
        self.assertIn("deleted_source_mod_file_ids: none", p.stdout)

    def test_move_rejects_target_in_moved_set_and_bad_placement(self):
        self.seed_two_files()
        p = self.run_cli("move", "--version-ids", "v1,t1", "--target-version", "t1", "--placement", "after", "--yes")
        self.assertEqual(p.returncode, 1)
        self.assertFalse(self.mock.exact("POST", "/v3/mod-file-versions/move"))
        p = self.run_cli("move", "--version-ids", "v1", "--target-version", "t1", "--placement", "middle", "--yes")
        self.assertEqual(p.returncode, 2)

    def test_rename_sends_exact_body(self):
        p = self.run_cli("rename", "--file-id", "f9", "--name", "Polychromatic - Guns (v2.0)")
        self.assertEqual(p.returncode, 0, p.stderr)
        calls = self.mock.exact("PUT", "/v3/mod-files/f9")
        self.assertEqual(len(calls), 1)
        self.assertEqual(json.loads(calls[0]["body"]), {"name": "Polychromatic - Guns (v2.0)"})
        self.assertEqual(self.mock.renames, {"f9": "Polychromatic - Guns (v2.0)"})

    def test_rename_validates_name_locally(self):
        for bad in ("Bad: name", "", "x" * 256, "semi;colon"):
            p = self.run_cli("rename", "--file-id", "f9", "--name", bad)
            self.assertEqual(p.returncode, 1, bad)
            self.assertIn("file name", p.stderr)
        self.assertEqual(self.mock.log, [])
        p = self.run_cli("rename", "--file-id", "f9", "--name", "x" * 255)
        self.assertEqual(p.returncode, 0, p.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)

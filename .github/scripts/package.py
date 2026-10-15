#!/usr/bin/env python3
import argparse
import hashlib
import io
import json
import re
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

ROOT = "Polychromatic"
FULL = "Polychromatic.zip"
BASE = "Polychromatic_Empty.zip"
FORBIDDEN = (".git", "install_stage", ".github")
LABEL_RE = re.compile(r'^\s*label\s*=\s*"([^"]+)"', re.M)


def fail(msg):
    print("package.py: " + msg, file=sys.stderr)
    sys.exit(1)


def read_archive(rev, repo):
    data = subprocess.run(
        ["git", "-C", str(repo), "archive", "--format=tar", "--prefix=" + ROOT + "/", rev],
        check=True, stdout=subprocess.PIPE,
    ).stdout
    files = {}
    with tarfile.open(fileobj=io.BytesIO(data)) as tar:
        for m in tar.getmembers():
            if m.issym() or m.islnk():
                fail("symlink in archive: " + m.name)
            if m.isfile():
                files[m.name] = (tar.extractfile(m).read(), m.mtime)
    return files


def tree_blobs(rev, repo):
    out = subprocess.run(
        ["git", "-C", str(repo), "ls-tree", "-r", "-z", "--full-tree", rev],
        check=True, stdout=subprocess.PIPE,
    ).stdout
    blobs = {}
    for rec in out.split(b"\0"):
        if not rec:
            continue
        meta, path = rec.split(b"\t", 1)
        mode, kind, oid = meta.split(b" ")
        if kind == b"blob":
            blobs[path.decode("utf-8")] = oid.decode("ascii")
    return blobs


def fingerprint(names, blobs):
    h = hashlib.sha256()
    for name in sorted(names):
        rel = name[len(ROOT) + 1:]
        oid = blobs.get(rel)
        if oid is None:
            fail("archive entry %s has no blob in the tree" % name)
        h.update(rel.encode("utf-8") + b"\0" + oid.encode("ascii") + b"\n")
    return h.hexdigest()


def module_labels(files, strict):
    modules = {}
    prefix = ROOT + "/modules/"
    for name in files:
        if name.startswith(prefix):
            parts = name[len(prefix):].split("/")
            if len(parts) > 1:
                modules.setdefault(parts[0], None)
    if strict and not modules:
        fail("no modules found")
    labels = {}
    for mid in modules:
        entry = files.get(prefix + mid + "/module.lua")
        m = entry and LABEL_RE.search(entry[0].decode("utf-8", "replace"))
        if m:
            labels[mid] = m.group(1)
        elif strict:
            fail("module %s has %s" % (mid, "no label" if entry else "no module.lua"))
    if strict and len(set(labels.values())) != len(labels):
        fail("duplicate module labels")
    return labels


def plan_zips(files, labels):
    prefix = ROOT + "/modules/"
    zips = [
        {"key": "Polychromatic", "file": FULL, "category": "main", "names": list(files)},
        {"key": "Polychromatic_Empty", "file": BASE, "category": "main",
         "names": [n for n in files if not n.startswith(prefix)]},
    ]
    for mid in sorted(labels, key=lambda k: labels[k]):
        label = labels[mid]
        zips.append({"key": label, "file": "Polychromatic - %s.zip" % label, "category": "optional",
                     "names": [n for n in files if n.startswith(prefix + mid + "/")]})
    return zips


def matrix_rows(rev, repo, strict=True):
    files = read_archive(rev, repo)
    labels = module_labels(files, strict)
    zips = plan_zips(files, labels)
    blobs = tree_blobs(rev, repo)
    for z in zips:
        z["fingerprint"] = fingerprint(z["names"], blobs)
    return files, labels, zips


def write_zip(path, entries):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in sorted(entries):
            data, mtime = entries[name]
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, data)


def verify(path, must_have, must_lack_prefix=None, only_prefix=None):
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        if z.testzip() is not None:
            fail(path.name + ": corrupt zip")
    if not names:
        fail(path.name + ": empty")
    for n in names:
        if not n.startswith(ROOT + "/"):
            fail("%s: entry outside %s/: %s" % (path.name, ROOT, n))
        parts = n.split("/")
        if any(p in FORBIDDEN or p.startswith(".git") for p in parts):
            fail("%s: forbidden entry %s" % (path.name, n))
        if only_prefix and not n.startswith(only_prefix):
            fail("%s: entry outside %s: %s" % (path.name, only_prefix, n))
        if must_lack_prefix and n.startswith(must_lack_prefix):
            fail("%s: unexpected entry %s" % (path.name, n))
    for need in must_have:
        if need not in names:
            fail("%s: missing %s" % (path.name, need))
    return len(names)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rev", default="HEAD")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--out", required=True)
    ap.add_argument("--fingerprints-only", action="store_true",
                    help="write only matrix.json (rows and fingerprints), no zips and no layout checks")
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)

    if a.fingerprints_only:
        _, _, zips = matrix_rows(a.rev, a.repo, strict=False)
        rows = [{k: z[k] for k in ("key", "file", "category", "fingerprint")} for z in zips if z["names"]]
        (out / "matrix.json").write_text(json.dumps(rows), encoding="utf-8")
        for row in rows:
            print("%-34s %s" % (row["file"], row["fingerprint"][:12]))
        return

    files, labels, zips = matrix_rows(a.rev, a.repo, strict=True)
    mod = files.get(ROOT + "/Polychromatic.mod")
    if mod is None or not mod[0].strip():
        fail("Polychromatic.mod missing or empty in archive")
    prefix = ROOT + "/modules/"

    matrix = []
    for z in zips:
        write_zip(out / z["file"], {n: files[n] for n in z["names"]})
        matrix.append({k: z[k] for k in ("key", "file", "category", "fingerprint")})

    verify(out / FULL, [ROOT + "/Polychromatic.mod", ROOT + "/bin/asset-redirect.dll"])
    verify(out / BASE, [ROOT + "/Polychromatic.mod", ROOT + "/bin/asset-redirect.dll"],
           must_lack_prefix=prefix)
    for mid in labels:
        verify(out / ("Polychromatic - %s.zip" % labels[mid]),
               [prefix + mid + "/module.lua"], only_prefix=prefix + mid + "/")

    (out / "matrix.json").write_text(json.dumps(matrix), encoding="utf-8")
    for row in matrix:
        print("%-9s %-34s %7d bytes  %s" % (row["category"], row["file"],
                                           (out / row["file"]).stat().st_size, row["fingerprint"][:12]))
    print("OK: %d zips" % len(matrix))


if __name__ == "__main__":
    main()

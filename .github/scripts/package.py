#!/usr/bin/env python3
import argparse
import io
import json
import re
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

ROOT = "Polychromatic"
FULL = "Polychromatic - Full.zip"
BASE = "Polychromatic.zip"
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
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)

    files = read_archive(a.rev, a.repo)
    mod = files.get(ROOT + "/Polychromatic.mod")
    if mod is None or not mod[0].strip():
        fail("Polychromatic.mod missing or empty in archive")

    modules = {}
    prefix = ROOT + "/modules/"
    for name in files:
        if name.startswith(prefix):
            parts = name[len(prefix):].split("/")
            if len(parts) > 1:
                modules.setdefault(parts[0], None)
    if not modules:
        fail("no modules found")
    for mid in modules:
        entry = files.get(prefix + mid + "/module.lua")
        if entry is None:
            fail("module %s has no module.lua" % mid)
        m = LABEL_RE.search(entry[0].decode("utf-8"))
        if not m:
            fail("module %s has no label" % mid)
        modules[mid] = m.group(1)
    if len(set(modules.values())) != len(modules):
        fail("duplicate module labels")

    matrix = []
    write_zip(out / FULL, files)
    base = {n: v for n, v in files.items() if not n.startswith(prefix)}
    write_zip(out / BASE, base)
    matrix.append({"key": "Full", "file": FULL, "category": "main"})
    matrix.append({"key": "Polychromatic", "file": BASE, "category": "main"})
    for mid in sorted(modules, key=lambda k: modules[k]):
        label = modules[mid]
        fname = "Polychromatic - %s.zip" % label
        sub = {n: v for n, v in files.items() if n.startswith(prefix + mid + "/")}
        write_zip(out / fname, sub)
        matrix.append({"key": label, "file": fname, "category": "optional"})

    verify(out / FULL, [ROOT + "/Polychromatic.mod", ROOT + "/bin/asset-redirect.dll"])
    verify(out / BASE, [ROOT + "/Polychromatic.mod", ROOT + "/bin/asset-redirect.dll"],
           must_lack_prefix=prefix)
    for mid in modules:
        verify(out / ("Polychromatic - %s.zip" % modules[mid]),
               [prefix + mid + "/module.lua"], only_prefix=prefix + mid + "/")

    (out / "matrix.json").write_text(json.dumps(matrix), encoding="utf-8")
    for row in matrix:
        print("%-9s %-34s %7d bytes" % (row["category"], row["file"], (out / row["file"]).stat().st_size))
    print("OK: %d zips" % len(matrix))


main()

#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

FULL_KEY = "Polychromatic"
VERSION_RE = re.compile(r"^[A-Za-z0-9.-]{1,50}$")


class PlanError(Exception):
    pass


def parse_only(text, keys):
    if not text or not text.strip():
        return None
    wanted = [k.strip() for k in text.split(",") if k.strip()]
    if not wanted:
        return None
    unknown = [k for k in wanted if k not in keys]
    if unknown:
        raise PlanError("only: unknown row key(s) %s; valid keys: %s"
                        % (", ".join(unknown), ", ".join(keys)))
    return set(wanted)


def plan(current, previous, force=False, only=None, previous_tag=None):
    keys = [r["key"] for r in current]
    selected = parse_only(only, keys)
    prev = None if previous is None else {r["key"]: r.get("fingerprint") for r in previous}
    rows = []
    for r in current:
        row = dict(r)
        key = r["key"]
        if selected is not None:
            row["upload"] = key in selected
            row["reason"] = "selected by only" if row["upload"] else "not selected by only"
        elif force:
            row["upload"], row["reason"] = True, "force"
        elif prev is None:
            row["upload"], row["reason"] = True, "no previous release tag"
        elif key not in prev:
            row["upload"], row["reason"] = True, "new row (absent at %s)" % previous_tag
        elif prev[key] != r["fingerprint"]:
            row["upload"], row["reason"] = True, "content changed since %s" % previous_tag
        else:
            row["upload"], row["reason"] = False, "content unchanged since %s" % previous_tag
        row["changelog"] = False
        rows.append(row)
    uploading = [row for row in rows if row["upload"]]
    if uploading:
        full = [row for row in uploading if row["key"] == FULL_KEY]
        (full or uploading)[0]["changelog"] = True
    return rows


def describe(rows):
    lines = []
    for row in rows:
        lines.append("%-6s %-20s %s%s" % ("UPLOAD" if row["upload"] else "SKIP", row["key"], row["reason"],
                                         ", changelog" if row["changelog"] else ""))
    if not any(row["upload"] for row in rows):
        lines.append("No row uploads to Nexus; the changelog is not added.")
    return lines


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo)] + list(args), check=True,
                          stdout=subprocess.PIPE).stdout.decode("utf-8")


def previous_tag(repo, rev, release_tags, exclude=None):
    eligible = {t for t in release_tags if t and t != exclude}
    if not eligible:
        return None
    by_commit = {}
    for line in git(repo, "for-each-ref", "--format=%(refname:short) %(*objectname) %(objectname)",
                    "refs/tags").splitlines():
        parts = line.split()
        if len(parts) == 3:
            name, peeled, oid = parts
        elif len(parts) == 2:
            name, oid = parts
            peeled = ""
        else:
            continue
        if name in eligible:
            by_commit.setdefault(peeled or oid, []).append(name)
    for commit in git(repo, "rev-list", "--topo-order", rev).split():
        if commit in by_commit:
            return sorted(by_commit[commit], key=version_key)[-1]
    return None


def version_key(tag):
    return [(0, int(p), "") if p.isdigit() else (1, 0, p) for p in re.split(r"[.-]", tag)]


def main(argv=None):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("previous-tag")
    p.add_argument("--repo", default=".")
    p.add_argument("--rev", default="HEAD")
    p.add_argument("--tags-file", required=True, help="release tag names (not prerelease, not draft), one per line")
    p.add_argument("--exclude", default="", help="the current release's tag")
    q = sub.add_parser("plan")
    q.add_argument("--current", required=True)
    q.add_argument("--previous", default="", help="matrix.json at the previous release tag; empty when none")
    q.add_argument("--previous-tag", default="")
    q.add_argument("--force", default="false")
    q.add_argument("--only", default="")
    q.add_argument("--out", required=True)
    a = ap.parse_args(argv)
    try:
        if a.cmd == "previous-tag":
            tags = [t.strip() for t in Path(a.tags_file).read_text(encoding="utf-8").splitlines()]
            tags = [t for t in tags if VERSION_RE.match(t)]
            print(previous_tag(a.repo, a.rev, tags, a.exclude) or "")
            return 0
        current = json.loads(Path(a.current).read_text(encoding="utf-8"))
        previous = json.loads(Path(a.previous).read_text(encoding="utf-8")) if a.previous else None
        rows = plan(current, previous, force=a.force.strip().lower() == "true", only=a.only,
                    previous_tag=a.previous_tag or None)
    except PlanError as e:
        print("release_plan.py: %s" % e, file=sys.stderr)
        return 1
    Path(a.out).write_text(json.dumps(rows), encoding="utf-8")
    for line in describe(rows):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())

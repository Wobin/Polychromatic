#!/usr/bin/env python3
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


package = load("package_under_test", "package.py")
release_plan = load("release_plan_under_test", "release_plan.py")

GIT_ENV = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.invalid",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.invalid",
               GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")


class Repo:
    def __init__(self):
        self.path = Path(tempfile.mkdtemp(prefix="pc-plan-"))
        self.git("init", "-q", "-b", "main")
        self.write(".gitattributes", "README.md export-ignore\n.gitattributes export-ignore\ndocs/ export-ignore\n* -text\n")
        self.write("Polychromatic.mod", "return {}\n")
        self.write("bin/asset-redirect.dll", "dll")
        self.write("scripts/base.lua", "base 1\n")
        self.write("README.md", "readme 1\n")
        self.write("docs/notes.md", "notes 1\n")
        self.write("modules/grenades/module.lua", 'return {\n  label = "Grenades",\n}\n')
        self.write("modules/grenades/fx.lua", "g 1\n")
        self.write("modules/staves/module.lua", 'return {\n  label = "Staves",\n}\n')
        self.write("modules/staves/fx.lua", "s 1\n")
        self.commit("one")

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.path)] + list(args), check=True, env=GIT_ENV,
                              stdout=subprocess.PIPE).stdout.decode()

    def write(self, rel, text):
        p = self.path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(text.encode())

    def remove(self, rel):
        shutil.rmtree(self.path / rel)

    def commit(self, msg):
        self.git("add", "-A")
        self.git("commit", "-q", "--allow-empty", "-m", msg)
        return self.git("rev-parse", "HEAD").strip()

    def fingerprints(self, rev="HEAD"):
        _, _, zips = package.matrix_rows(rev, self.path, strict=False)
        return {z["key"]: z["fingerprint"] for z in zips}

    def cleanup(self):
        shutil.rmtree(self.path, ignore_errors=True)


class FingerprintTests(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()
        self.base = self.repo.fingerprints()

    def tearDown(self):
        self.repo.cleanup()

    def build(self, out):
        subprocess.run([sys.executable, str(HERE / "package.py"), "--rev", "HEAD", "--repo", str(self.repo.path),
                        "--out", str(out)], check=True, stdout=subprocess.PIPE)
        return json.loads((out / "matrix.json").read_text(encoding="utf-8"))

    def test_rows_and_keys(self):
        self.assertEqual(sorted(self.base), ["Grenades", "Polychromatic", "Polychromatic_Empty", "Staves"])
        self.assertEqual(len(set(self.base.values())), 4)

    def test_stable_across_two_builds_of_the_same_rev(self):
        a = self.build(self.repo.path.parent / (self.repo.path.name + "-a"))
        os.utime(self.repo.path / "scripts" / "base.lua", (1, 1))
        b = self.build(self.repo.path.parent / (self.repo.path.name + "-b"))
        for d in ("-a", "-b"):
            shutil.rmtree(str(self.repo.path) + d)
        self.assertEqual(a, b)
        self.assertEqual({r["key"]: r["fingerprint"] for r in a}, self.base)

    def test_new_commit_with_same_content_keeps_fingerprints(self):
        self.repo.commit("empty")
        self.assertEqual(self.repo.fingerprints(), self.base)

    def test_module_change_affects_that_module_and_full_only(self):
        self.repo.write("modules/grenades/fx.lua", "g 2\n")
        self.repo.commit("grenades")
        now = self.repo.fingerprints()
        self.assertNotEqual(now["Grenades"], self.base["Grenades"])
        self.assertNotEqual(now["Polychromatic"], self.base["Polychromatic"])
        self.assertEqual(now["Staves"], self.base["Staves"])
        self.assertEqual(now["Polychromatic_Empty"], self.base["Polychromatic_Empty"])

    def test_base_change_affects_full_and_empty_not_modules(self):
        self.repo.write("scripts/base.lua", "base 2\n")
        self.repo.commit("base")
        now = self.repo.fingerprints()
        self.assertNotEqual(now["Polychromatic"], self.base["Polychromatic"])
        self.assertNotEqual(now["Polychromatic_Empty"], self.base["Polychromatic_Empty"])
        self.assertEqual(now["Grenades"], self.base["Grenades"])
        self.assertEqual(now["Staves"], self.base["Staves"])

    def test_added_base_file_changes_full_and_empty(self):
        self.repo.write("scripts/extra.lua", "x\n")
        self.repo.commit("extra")
        now = self.repo.fingerprints()
        self.assertNotEqual(now["Polychromatic_Empty"], self.base["Polychromatic_Empty"])
        self.assertEqual(now["Grenades"], self.base["Grenades"])

    def test_renamed_file_changes_fingerprint(self):
        self.repo.git("mv", "modules/staves/fx.lua", "modules/staves/fx2.lua")
        self.repo.commit("rename")
        self.assertNotEqual(self.repo.fingerprints()["Staves"], self.base["Staves"])

    def test_export_ignored_files_do_not_count(self):
        self.repo.write("README.md", "readme 2\n")
        self.repo.write("docs/notes.md", "notes 2\n")
        self.repo.write("docs/new.md", "new\n")
        self.repo.commit("docs")
        self.assertEqual(self.repo.fingerprints(), self.base)

    def test_export_ignore_rule_added_removes_path_from_fingerprint(self):
        self.repo.write("scripts/dev.lua", "dev\n")
        self.repo.commit("dev")
        with_dev = self.repo.fingerprints()["Polychromatic_Empty"]
        self.repo.write(".gitattributes", (self.repo.path / ".gitattributes").read_text() + "scripts/dev.lua export-ignore\n")
        self.repo.commit("ignore dev")
        self.assertNotEqual(with_dev, self.base["Polychromatic_Empty"])
        self.assertEqual(self.repo.fingerprints()["Polychromatic_Empty"], self.base["Polychromatic_Empty"])

    def test_fingerprints_only_tolerates_old_layout(self):
        self.repo.remove("modules")
        self.repo.commit("no modules")
        out = self.repo.path.parent / (self.repo.path.name + "-fp")
        subprocess.run([sys.executable, str(HERE / "package.py"), "--rev", "HEAD", "--repo", str(self.repo.path),
                        "--out", str(out), "--fingerprints-only"], check=True, stdout=subprocess.PIPE)
        rows = json.loads((out / "matrix.json").read_text(encoding="utf-8"))
        shutil.rmtree(out)
        self.assertEqual([r["key"] for r in rows], ["Polychromatic", "Polychromatic_Empty"])
        self.assertFalse(any(out.glob("*.zip")) if out.exists() else False)


def rows(**fps):
    out = []
    for key, fp in fps.items():
        out.append({"key": key, "file": key + ".zip", "category": "main", "fingerprint": fp})
    return out


CUR = rows(Polychromatic="F2", Polychromatic_Empty="E1", Grenades="G2", Staves="S1")


def decide(previous, **kw):
    r = release_plan.plan(CUR, previous, previous_tag="1.0.0", **kw)
    return ({x["key"] for x in r if x["upload"]}, [x["key"] for x in r if x["changelog"]], r)


class PlanTests(unittest.TestCase):
    PREV = rows(Polychromatic="F1", Polychromatic_Empty="E1", Grenades="G1", Staves="S1")

    def test_only_changed_rows_upload(self):
        up, cl, r = decide(self.PREV)
        self.assertEqual(up, {"Polychromatic", "Grenades"})
        self.assertEqual(cl, ["Polychromatic"])
        self.assertIn("unchanged since 1.0.0", [x for x in r if x["key"] == "Staves"][0]["reason"])

    def test_no_change_uploads_nothing_and_no_changelog(self):
        up, cl, r = decide(CUR)
        self.assertEqual(up, set())
        self.assertEqual(cl, [])
        self.assertIn("changelog is not added", release_plan.describe(r)[-1])

    def test_no_previous_tag_uploads_everything(self):
        up, cl, _ = decide(None)
        self.assertEqual(up, {"Polychromatic", "Polychromatic_Empty", "Grenades", "Staves"})
        self.assertEqual(cl, ["Polychromatic"])

    def test_new_module_uploads(self):
        prev = [r for r in CUR if r["key"] != "Staves"]
        up, cl, r = decide(prev)
        self.assertEqual(up, {"Staves"})
        self.assertEqual(cl, ["Staves"])
        self.assertIn("new row", r[-1]["reason"])

    def test_removed_module_produces_no_row(self):
        prev = self.PREV + rows(Hazards="H1")
        _, _, r = decide(prev)
        self.assertNotIn("Hazards", [x["key"] for x in r])

    def test_force_uploads_everything(self):
        up, cl, _ = decide(CUR, force=True)
        self.assertEqual(len(up), 4)
        self.assertEqual(cl, ["Polychromatic"])

    def test_only_uploads_listed_rows_even_if_unchanged(self):
        up, cl, _ = decide(CUR, only=" Staves , Polychromatic_Empty")
        self.assertEqual(up, {"Staves", "Polychromatic_Empty"})
        self.assertEqual(cl, ["Polychromatic_Empty"])

    def test_only_overrides_force(self):
        up, _, _ = decide(CUR, only="Grenades", force=True)
        self.assertEqual(up, {"Grenades"})

    def test_only_rejects_unknown_keys(self):
        with self.assertRaises(release_plan.PlanError) as e:
            decide(CUR, only="Grenades,Nope")
        self.assertIn("Nope", str(e.exception))

    def test_blank_only_is_ignored(self):
        up, _, _ = decide(self.PREV, only=" , ")
        self.assertEqual(up, {"Polychromatic", "Grenades"})

    def test_changelog_falls_to_first_uploading_row_when_full_skipped(self):
        prev = rows(Polychromatic="F2", Polychromatic_Empty="E0", Grenades="G0", Staves="S1")
        up, cl, _ = decide(prev)
        self.assertEqual(up, {"Polychromatic_Empty", "Grenades"})
        self.assertEqual(cl, ["Polychromatic_Empty"])

    def test_changelog_prefers_full_row_wherever_it_sits(self):
        cur = list(reversed(CUR))
        r = release_plan.plan(cur, None)
        self.assertEqual([x["key"] for x in r if x["changelog"]], ["Polychromatic"])

    def test_cli_rejects_unknown_only_and_writes_nothing(self):
        d = Path(tempfile.mkdtemp(prefix="pc-plan-cli-"))
        try:
            (d / "cur.json").write_text(json.dumps(CUR), encoding="utf-8")
            rc = release_plan.main(["plan", "--current", str(d / "cur.json"), "--only", "Bogus",
                                    "--out", str(d / "plan.json")])
            self.assertEqual(rc, 1)
            self.assertFalse((d / "plan.json").exists())
            rc = release_plan.main(["plan", "--current", str(d / "cur.json"), "--force", "true",
                                    "--out", str(d / "plan.json")])
            self.assertEqual(rc, 0)
            self.assertTrue(all(r["upload"] for r in json.loads((d / "plan.json").read_text())))
        finally:
            shutil.rmtree(d)


class PreviousTagTests(unittest.TestCase):
    def setUp(self):
        self.repo = Repo()
        self.repo.git("tag", "1.0.0")
        self.repo.commit("two")
        self.repo.git("tag", "-a", "-m", "pre", "1.1.0-rc1")
        self.repo.commit("three")
        self.repo.git("tag", "-a", "-m", "rel", "1.1.0")
        self.repo.commit("four")
        self.repo.git("tag", "1.2.0")

    def tearDown(self):
        self.repo.cleanup()

    def prev(self, tags, exclude="1.2.0", rev="HEAD"):
        return release_plan.previous_tag(self.repo.path, rev, tags, exclude)

    def test_most_recent_reachable_release(self):
        self.assertEqual(self.prev(["1.0.0", "1.1.0", "1.2.0"]), "1.1.0")

    def test_prerelease_tags_are_not_in_the_release_list(self):
        self.assertEqual(self.prev(["1.0.0", "1.2.0"]), "1.0.0")
        self.assertEqual(self.prev(["1.0.0", "1.1.0-rc1", "1.2.0"]), "1.1.0-rc1")

    def test_no_previous_release(self):
        self.assertIsNone(self.prev(["1.2.0"]))
        self.assertIsNone(self.prev([]))
        self.assertIsNone(self.prev(["1.0.0", "1.1.0"], exclude="1.0.0", rev="1.0.0"))

    def test_unreachable_tags_are_ignored(self):
        self.repo.git("checkout", "-q", "-b", "side", "1.0.0")
        self.repo.commit("side")
        self.repo.git("tag", "9.9.9")
        self.repo.git("checkout", "-q", "main")
        self.assertEqual(self.prev(["1.0.0", "1.1.0", "9.9.9"]), "1.1.0")


if __name__ == "__main__":
    unittest.main()

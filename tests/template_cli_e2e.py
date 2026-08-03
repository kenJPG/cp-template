from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
CLI = REPO_ROOT / "commands" / "template_cli.py"


def run_cli(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(CLI), *args],
        text=True,
        capture_output=True,
        cwd=cwd or REPO_ROOT,
        check=False,
    )


class TemplateCliE2E(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory(prefix="cp-template-cli-")
        self.root = Path(self.temp_dir.name)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_cpp_default_target(self) -> None:
        result = run_cli("cpp", cwd=self.root)
        self.assertEqual(result.returncode, 0, result.stderr)
        created = self.root / "main.cpp"
        self.assertTrue(created.is_file())
        self.assertIn("Created:", result.stdout)
        self.assertIn("g++ -std=gnu++20", result.stdout)

    def test_windows_wrappers_exist(self) -> None:
        for name, language in (("templatecpp.cmd", "cpp"), ("templatejava.cmd", "java"), ("templatepy.cmd", "py")):
            content = (REPO_ROOT / name).read_text(encoding="utf-8")
            self.assertIn(f"CP_TEMPLATE_LANGUAGE={language}", content)
            self.assertIn("..\\commands\\template_cli.py", content)

    def test_extension_appending_and_python_content(self) -> None:
        target = self.root / "practice"
        result = run_cli("py", str(target))
        self.assertEqual(result.returncode, 0, result.stderr)
        created = target.with_suffix(".py")
        self.assertTrue(created.is_file())
        self.assertIn("def solve() -> None:", created.read_text(encoding="utf-8"))

    def test_custom_spaced_path_and_java_class_substitution(self) -> None:
        target = self.root / "folder with spaces" / "PracticeSession.java"
        result = run_cli("java", str(target))
        self.assertEqual(result.returncode, 0, result.stderr)
        content = target.read_text(encoding="utf-8")
        self.assertIn("public class PracticeSession {", content)
        self.assertNotIn("{{CLASS_NAME}}", content)
        self.assertIn("javac --release 17", result.stdout)

    def test_directory_target_uses_language_default(self) -> None:
        target_dir = self.root / "nested" / "dir-target"
        target_dir.mkdir(parents=True)
        result = run_cli("java", str(target_dir))
        self.assertEqual(result.returncode, 0, result.stderr)
        created = target_dir / "Main.java"
        self.assertTrue(created.is_file())

    def test_existing_target_refused_without_force(self) -> None:
        target = self.root / "main.py"
        original = "keep me\n"
        target.write_text(original, encoding="utf-8", newline="\n")
        result = run_cli("py", str(target))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing to overwrite existing file", result.stderr)
        self.assertEqual(target.read_text(encoding="utf-8"), original)

    def test_force_overwrites_existing_target(self) -> None:
        target = self.root / "main.py"
        target.write_text("old\n", encoding="utf-8", newline="\n")
        result = run_cli("py", str(target), "--force")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("def solve() -> None:", target.read_text(encoding="utf-8"))

    def test_help(self) -> None:
        result = run_cli("cpp", "--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Create a cpp source template safely", result.stdout)
        self.assertIn("--force", result.stdout)

    def test_invalid_java_identifier_is_rejected(self) -> None:
        target = self.root / "123bad.java"
        result = run_cli("java", str(target))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("is not a valid public class name", result.stderr)
        self.assertFalse(target.exists())

    def test_java_reserved_word_is_rejected(self) -> None:
        target = self.root / "exports.java"
        result = run_cli("java", str(target))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("is not a valid public class name", result.stderr)
        self.assertFalse(target.exists())

    @unittest.skipUnless(shutil.which("g++"), "g++ not available")
    def test_generated_cpp_compiles_and_runs(self) -> None:
        target = self.root / "main.cpp"
        run_cli("cpp", str(target))
        exe = self.root / ("main.exe" if sys.platform.startswith("win") else "main.out")
        compile_result = subprocess.run(
            ["g++", "-std=gnu++20", str(target), "-o", str(exe)],
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
        run_result = subprocess.run([str(exe)], input="0\n", text=True, capture_output=True, check=False)
        self.assertEqual(run_result.returncode, 0, run_result.stderr)

    @unittest.skipUnless(shutil.which("javac") and shutil.which("java"), "Java compiler/runtime not available")
    def test_generated_java_compiles_and_runs(self) -> None:
        target = self.root / "PracticeSession.java"
        run_cli("java", str(target))
        compile_result = subprocess.run(
            ["javac", "--release", "17", str(target)],
            text=True,
            capture_output=True,
            cwd=target.parent,
            check=False,
        )
        self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
        run_result = subprocess.run(
            ["java", "-cp", str(target.parent), "PracticeSession"],
            text=True,
            capture_output=True,
            cwd=target.parent,
            check=False,
        )
        self.assertEqual(run_result.returncode, 0, run_result.stderr)
        self.assertEqual(run_result.stdout, "")

    @unittest.skipUnless(shutil.which(sys.executable), "Python runtime not available")
    def test_generated_python_runs(self) -> None:
        target = self.root / "main.py"
        run_cli("py", str(target))
        run_result = subprocess.run([sys.executable, str(target)], text=True, capture_output=True, check=False)
        self.assertEqual(run_result.returncode, 0, run_result.stderr)
        self.assertEqual(run_result.stdout, "")


if __name__ == "__main__":
    unittest.main(verbosity=2)

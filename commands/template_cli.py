from __future__ import annotations

import argparse
import os
import string
import sys
from pathlib import Path


LANGUAGES = {
    "cpp": {
        "suffix": ".cpp",
        "default_name": "main.cpp",
        "template": "cpp.cpp",
    },
    "java": {
        "suffix": ".java",
        "default_name": "Main.java",
        "template": "java.java",
    },
    "py": {
        "suffix": ".py",
        "default_name": "main.py",
        "template": "python.py",
    },
}

JAVA_KEYWORDS = {
    "abstract",
    "assert",
    "boolean",
    "break",
    "byte",
    "case",
    "catch",
    "char",
    "class",
    "const",
    "continue",
    "default",
    "do",
    "double",
    "else",
    "enum",
    "extends",
    "final",
    "finally",
    "float",
    "for",
    "goto",
    "if",
    "implements",
    "import",
    "instanceof",
    "int",
    "interface",
    "long",
    "native",
    "new",
    "package",
    "private",
    "protected",
    "public",
    "return",
    "short",
    "static",
    "strictfp",
    "super",
    "switch",
    "synchronized",
    "this",
    "throw",
    "throws",
    "transient",
    "try",
    "void",
    "volatile",
    "while",
    "_",
    "exports",
    "module",
    "non-sealed",
    "open",
    "opens",
    "permits",
    "provides",
    "record",
    "requires",
    "sealed",
    "to",
    "transitive",
    "uses",
    "var",
    "when",
    "with",
    "yield",
    "true",
    "false",
    "null",
}


def fail(message: str) -> int:
    print(f"error: {message}", file=sys.stderr)
    return 1


def detect_language(argv: list[str]) -> tuple[str, list[str], str]:
    env_language = os.environ.get("CP_TEMPLATE_LANGUAGE")
    if env_language in LANGUAGES:
        tool_name = os.environ.get("CP_TEMPLATE_TOOL_NAME", f"template{env_language}")
        return env_language, argv[1:], tool_name

    if len(argv) > 1 and argv[1] in LANGUAGES:
        language = argv[1]
        return language, argv[2:], f"template{language}"

    print("usage: template_cli.py {cpp,java,py} [target] [-f|--force]", file=sys.stderr)
    raise SystemExit(2)


def build_parser(language: str, prog: str) -> argparse.ArgumentParser:
    meta = LANGUAGES[language]
    parser = argparse.ArgumentParser(
        prog=prog,
        description=f"Create a {language} source template safely from the shared cp-template toolkit.",
    )
    parser.add_argument(
        "target",
        nargs="?",
        help=(
            f"Output file or directory. Defaults to {meta['default_name']}. "
            f"When omitted or suffix-less, {meta['suffix']} is used."
        ),
    )
    parser.add_argument("-f", "--force", action="store_true", help="Overwrite the target file if it already exists.")
    return parser


def project_root() -> Path:
    return Path(__file__).resolve().parent.parent


def template_path(language: str) -> Path:
    path = project_root() / "templates" / LANGUAGES[language]["template"]
    if not path.is_file():
        raise FileNotFoundError(f"Shared template not found: {path}")
    return path


def resolve_target(language: str, raw_target: str | None) -> Path:
    meta = LANGUAGES[language]
    target = Path(raw_target) if raw_target else Path(meta["default_name"])
    if target.exists() and target.is_dir():
        target = target / meta["default_name"]
    if target.suffix == "":
        target = target.with_suffix(meta["suffix"])
    target.parent.mkdir(parents=True, exist_ok=True)
    return target.resolve(strict=False)


def is_valid_java_identifier(name: str) -> bool:
    if not name or name in JAVA_KEYWORDS:
        return False
    if name[0] not in "_$" + string.ascii_letters:
        return False
    return all(ch in "_$" + string.ascii_letters + string.digits for ch in name)


def render_template(language: str, output_path: Path) -> str:
    content = template_path(language).read_text(encoding="utf-8")
    if language == "java":
        class_name = output_path.stem or "Main"
        if not is_valid_java_identifier(class_name):
            raise ValueError(
                f"Java output stem '{class_name}' is not a valid public class name. "
                "Use a Java identifier such as Main or PracticeSession."
            )
        content = content.replace("{{CLASS_NAME}}", class_name)
    return content


def quoted(path: Path) -> str:
    return f'"{path}"'


def success_hint(language: str, output_path: Path) -> str:
    if language == "cpp":
        exe_path = output_path.with_suffix(".exe")
        return (
            f"Next: g++ -std=gnu++20 -O2 -Wall -Wextra {quoted(output_path)} -o {quoted(exe_path)}"
        )
    if language == "java":
        return (
            f"Next: javac --release 17 {quoted(output_path)} && "
            f"java -cp {quoted(output_path.parent)} {output_path.stem}"
        )
    return f"Next: python {quoted(output_path)}"


def write_template(language: str, output_path: Path, force: bool) -> None:
    content = render_template(language, output_path)
    if force:
        output_path.write_text(content, encoding="utf-8", newline="\n")
        return

    try:
        with output_path.open("x", encoding="utf-8", newline="\n") as output_file:
            output_file.write(content)
    except FileExistsError as exc:
        raise FileExistsError(
            f"Refusing to overwrite existing file: {output_path}. Re-run with --force to replace it."
        ) from exc


def main(argv: list[str] | None = None) -> int:
    argv = argv or sys.argv
    try:
        language, parser_argv, prog = detect_language(argv)
        parser = build_parser(language, prog)
        args = parser.parse_args(parser_argv)
        output_path = resolve_target(language, args.target)
        write_template(language, output_path, args.force)
    except FileExistsError as exc:
        return fail(str(exc))
    except FileNotFoundError as exc:
        return fail(str(exc))
    except ValueError as exc:
        return fail(str(exc))
    except OSError as exc:
        return fail(f"Could not create the template: {exc}")

    print(f"Created: {output_path}")
    print(success_hint(language, output_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

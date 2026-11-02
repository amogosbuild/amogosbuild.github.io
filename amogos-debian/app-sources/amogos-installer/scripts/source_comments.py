# Normalize native template comments and verify one comment per maintained source file.
import io
import pathlib
import re
import sys
import tokenize

ROOT = pathlib.Path(__file__).resolve().parents[1]


def strip_c(text):
    output = []
    i = 0
    quote = None
    while i < len(text):
        char = text[i]
        if quote:
            output.append(char)
            if char == "\\" and i + 1 < len(text):
                i += 1
                output.append(text[i])
            elif char == quote:
                quote = None
            i += 1
        elif char in ("'", '"'):
            quote = char
            output.append(char)
            i += 1
        elif text.startswith("//", i):
            end = text.find("\n", i)
            i = len(text) if end < 0 else end
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end < 0:
                raise ValueError("Unclosed comment")
            output.append("\n" * text[i:end + 2].count("\n"))
            i = end + 2
        else:
            output.append(char)
            i += 1
    return "".join(output)


def maintained():
    for name in ("pubspec.yaml", "analysis_options.yaml"):
        yield ROOT / name
    folders = ("lib", "test", "tool", "backend", "scripts", "packaging", "linux", "windows", "boot")
    for folder in folders:
        for path in (ROOT / folder).rglob("*"):
            if path.is_file() and not any(x in path.parts for x in ("ephemeral", ".plugin_symlinks", "__pycache__")):
                yield path


if "--normalize" in sys.argv:
    for path in maintained():
        text = path.read_text(errors="replace") if path.suffix in (".cc", ".cpp", ".h", ".rc", ".cmake") or path.name == "CMakeLists.txt" else None
        if text is None:
            continue
        if path.suffix in (".cc", ".cpp", ".h", ".rc"):
            text = "// Native AmogOS installer runner and playback integration.\n" + strip_c(text).lstrip()
        else:
            text = "# Native build configuration for AmogOS Installer.\n" + re.sub(r"(?m)^\s*#[^\n]*(?:\n|$)", "", text).lstrip()
        path.write_text(text, newline="\n")

errors = []
count = 0
for path in maintained():
    if path.suffix not in (".dart", ".py", ".cc", ".cpp", ".h", ".rc", ".sh", ".ps1", ".yaml", ".cmake", ".desktop", ".policy", ".script", ".plymouth") and path.name not in ("CMakeLists.txt", "amogos-installer", "amogos-installer-helper"):
        continue
    text = path.read_text()
    if path.suffix == ".py":
        comments = sum(t.type == tokenize.COMMENT for t in tokenize.generate_tokens(io.StringIO(text).readline))
    elif path.suffix in (".dart", ".cc", ".cpp", ".h", ".rc"):
        comments = len(re.findall(r"(?m)^\s*//", text)) + len(re.findall(r"/\*", text))
    elif path.suffix == ".policy":
        comments = text.count("<!--")
    else:
        comments = len(re.findall(r"(?m)^\s*#", text))
    count += 1
    if comments != 1:
        errors.append(f"{path.relative_to(ROOT)}: {comments} comments")
if errors:
    raise SystemExit("\n".join(errors))
print(f"One-comment rule passed for {count} source files.")

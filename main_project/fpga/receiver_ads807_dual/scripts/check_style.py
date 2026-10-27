"""Check the user's line-level declaration/assignment contract on hand-written HDL."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    problems = []
    files = sorted((ROOT / "rtl").rglob("*.v")) + sorted((ROOT / "tests").rglob("*.v"))
    for path in files:
        source = re.sub(r"/\*.*?\*/", "", path.read_text(encoding="utf-8"), flags=re.S)
        for number, raw in enumerate(source.splitlines(), 1):
            line = raw.split("//", 1)[0].strip()
            declaration = re.match(r"^(input|output|inout|wire|reg|integer|real|parameter|localparam)\b(.*)", line)
            if declaration:
                body = declaration[2].rstrip(",;")
                if "," in body or re.search(r";\s*\S", line):
                    problems.append(f"{path.name}:{number}: multiple declarations")
                if declaration[1] == "wire" and re.search(r"(?<![=!<>])=(?!=)", body):
                    problems.append(f"{path.name}:{number}: wire initializer")
            if not line.startswith("for ") and line.count(";") > 1:
                problems.append(f"{path.name}:{number}: multiple statements")
    if problems:
        raise SystemExit("\n".join(problems))
    print(f"STYLE_PASS: {len(files)} hand-written HDL files; one declaration/statement per line")


if __name__ == "__main__":
    main()

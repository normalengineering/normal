import json
import subprocess
import sys

LOW_COVERAGE_FILES = 10


def xccov_report(bundle: str) -> dict | None:
    try:
        out = subprocess.run(
            ["xcrun", "xccov", "view", "--report", "--json", bundle],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None


def pct(value: float) -> str:
    return f"{value * 100:.1f}%"


def bar(value: float, width: int = 20) -> str:
    filled = round(value * width)
    return "█" * filled + "░" * (width - filled)


def main() -> None:
    if len(sys.argv) < 2:
        print("## ⚠️ No coverage bundle provided")
        return

    bundle = sys.argv[1]
    title = sys.argv[2] if len(sys.argv) > 2 else "Code coverage"

    report = xccov_report(bundle)
    if not report or not report.get("targets"):
        print(f"## ⚠️ No coverage data found ({title})")
        return

    # Ignore test bundles; they skew the numbers and aren't what we ship.
    targets = [
        t
        for t in report["targets"]
        if not t.get("name", "").lower().endswith((".xctest", "tests.xctest"))
        and "test" not in t.get("name", "").lower()
    ]
    if not targets:
        targets = report["targets"]

    covered = sum(t.get("coveredLines", 0) for t in targets)
    executable = sum(t.get("executableLines", 0) for t in targets)
    overall = covered / executable if executable else 0.0

    print(f"## 📊 {title}: {pct(overall)}")
    print()
    print(f"`{bar(overall)}` {covered:,} / {executable:,} lines")
    print()
    print("| Target | Coverage | Covered | Lines |")
    print("|:-------|---------:|--------:|------:|")
    for t in sorted(targets, key=lambda t: t.get("lineCoverage", 0)):
        name = t.get("name", "?")
        cov = t.get("lineCoverage", 0.0)
        print(f"| {name} | {pct(cov)} | {t.get('coveredLines', 0):,} | {t.get('executableLines', 0):,} |")

    files = [
        f
        for t in targets
        for f in t.get("files", [])
        if f.get("executableLines", 0) > 0
    ]
    low = sorted(files, key=lambda f: f.get("lineCoverage", 0))[:LOW_COVERAGE_FILES]
    if low:
        print()
        print(f"<details><summary>Least-covered files (bottom {len(low)})</summary>")
        print()
        print("| File | Coverage | Covered | Lines |")
        print("|:-----|---------:|--------:|------:|")
        for f in low:
            print(
                f"| {f.get('name', '?')} | {pct(f.get('lineCoverage', 0))} "
                f"| {f.get('coveredLines', 0):,} | {f.get('executableLines', 0):,} |"
            )
        print()
        print("</details>")


if __name__ == "__main__":
    main()

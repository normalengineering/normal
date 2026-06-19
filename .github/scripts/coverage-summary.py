import json
import subprocess
import sys

LOW_COVERAGE_FILES = 10

LAYER_RULES = [
    ("/Views/", "Views"),
    ("/Shared/Components/", "Components"),
    ("/Modifiers/", "Modifiers"),
    ("/Models/", "Models"),
    ("/Services/", "Services"),
    ("/App/", "App"),
    ("/Extensions/", "Extensions"),
    ("/Diagnostics/", "Diagnostics"),
    ("/Shared/", "Shared"),
    ("/NormalMonitor/", "Monitor"),
    ("/NormalWidget/", "Widget"),
]
UI_LAYERS = {"Views", "Components", "Modifiers"}


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


def layer_for(path: str) -> str:
    for needle, label in LAYER_RULES:
        if needle in path:
            return label
    return "Other"


def pct(covered: int, executable: int) -> str:
    return f"{(covered / executable * 100):.1f}%" if executable else "—"


def bar(covered: int, executable: int, width: int = 20) -> str:
    ratio = covered / executable if executable else 0.0
    filled = round(ratio * width)
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

    targets = [t for t in report["targets"] if "test" not in t.get("name", "").lower()]
    if not targets:
        targets = report["targets"]

    by_path: dict[str, dict] = {}
    for t in targets:
        for f in t.get("files", []):
            if f.get("executableLines", 0) <= 0:
                continue
            path = f.get("path", f.get("name", ""))
            if f.get("coveredLines", 0) > by_path.get(path, {}).get("coveredLines", -1):
                by_path[path] = f
    files = list(by_path.values())

    # Aggregate per layer.
    layers: dict[str, list[int]] = {}
    for f in files:
        cov, ex = f.get("coveredLines", 0), f.get("executableLines", 0)
        bucket = layers.setdefault(layer_for(f.get("path", "")), [0, 0])
        bucket[0] += cov
        bucket[1] += ex

    total_cov = sum(b[0] for b in layers.values())
    total_ex = sum(b[1] for b in layers.values())
    logic_cov = sum(b[0] for name, b in layers.items() if name not in UI_LAYERS)
    logic_ex = sum(b[1] for name, b in layers.items() if name not in UI_LAYERS)

    print(f"## 📊 {title} — logic {pct(logic_cov, logic_ex)}")
    print()
    print(f"`{bar(logic_cov, logic_ex)}` **{pct(logic_cov, logic_ex)}** logic "
          f"({logic_cov:,}/{logic_ex:,}) · {pct(total_cov, total_ex)} overall "
          f"({total_cov:,}/{total_ex:,})")
    print()
    print("> _Logic excludes the UI layer (" + ", ".join(sorted(UI_LAYERS)) + "), "
          "which is largely declarative SwiftUI._")
    print()
    print("| Layer | Coverage | Covered | Lines |")
    print("|:------|---------:|--------:|------:|")
    for name in sorted(layers, key=lambda n: (n in UI_LAYERS, layers[n][0] / layers[n][1] if layers[n][1] else 0)):
        cov, ex = layers[name]
        tag = " _(UI)_" if name in UI_LAYERS else ""
        print(f"| {name}{tag} | {pct(cov, ex)} | {cov:,} | {ex:,} |")

    low = sorted(
        (f for f in files if layer_for(f.get("path", "")) not in UI_LAYERS),
        key=lambda f: f.get("lineCoverage", 0),
    )[:LOW_COVERAGE_FILES]
    if low:
        print()
        print(f"<details><summary>Least-covered logic files (bottom {len(low)})</summary>")
        print()
        print("| File | Coverage | Covered | Lines |")
        print("|:-----|---------:|--------:|------:|")
        for f in low:
            print(
                f"| {f.get('name', '?')} | {pct(f.get('coveredLines', 0), f.get('executableLines', 0))} "
                f"| {f.get('coveredLines', 0):,} | {f.get('executableLines', 0):,} |"
            )
        print()
        print("</details>")


if __name__ == "__main__":
    main()

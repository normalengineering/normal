import glob
import sys
import xml.etree.ElementTree as ET

paths: list[str] = []
for arg in sys.argv[1:]:
    paths.extend(glob.glob(arg))

tests = failures = errors = skipped = 0
failed: list[str] = []

for path in paths:
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, FileNotFoundError, OSError):
        continue
    for ts in root.iter("testsuite"):
        tests += int(ts.get("tests") or 0)
        failures += int(ts.get("failures") or 0)
        errors += int(ts.get("errors") or 0)
        skipped += int(ts.get("skipped") or 0)
        for tc in ts.iter("testcase"):
            if tc.find("failure") is not None or tc.find("error") is not None:
                name = f"{tc.get('classname', '')}.{tc.get('name', '')}".strip(".")
                failed.append(name)

if not paths or tests == 0:
    print("## ⚠️ No test results found")
    sys.exit(0)

bad = failures + errors
passed = tests - bad - skipped
status = "✅ All tests passed" if bad == 0 else f"❌ {bad} test(s) failed"

print(f"## {status}")
print()
print("| Total | Passed | Failed | Skipped |")
print("|------:|-------:|-------:|--------:|")
print(f"| {tests} | {passed} | {bad} | {skipped} |")

if failed:
    print()
    print("### Failed tests")
    for name in failed:
        print(f"- `{name}`")

"""Verify the reviewed versions and revisions of every AuthKit dependency."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
expected = json.loads((root / "Scripts/dependencies.json").read_text())
pins = json.loads((root / "Package.resolved").read_text())["pins"]
actual = {pin["identity"]: pin["state"] for pin in pins}
assert actual == expected, (actual, expected)
print("All exact versions and commit SHAs match the reviewed dependency record")

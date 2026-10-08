#!/usr/bin/env python3
"""Validate source data and run Godot regressions with isolated user data."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str], environment: dict[str, str]) -> str:
    try:
        result = subprocess.run(command, cwd=ROOT, env=environment, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        raise RuntimeError(
            f"Command timed out: {command[0]}\n{output}"
        ) from error
    if result.returncode or "SCRIPT ERROR:" in result.stdout or re.search(r"^ERROR:", result.stdout, re.M):
        raise RuntimeError(result.stdout or f"Command failed: {command[0]}")
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot") or shutil.which("godot4"))
    args = parser.parse_args()
    if not args.godot:
        parser.error("Godot 4.6 executable not found; provide --godot /path/to/godot")
    environment = os.environ.copy()
    with tempfile.TemporaryDirectory(prefix="advancefour-check-") as scratch:
        environment["XDG_DATA_HOME"] = str(Path(scratch) / "user_data")
        source = ROOT / "tools/data_source/module_data.xlsx"
        with zipfile.ZipFile(source) as workbook:
            corrupt = workbook.testzip()
            if corrupt:
                raise RuntimeError(f"Corrupt workbook entry: {corrupt}")
        parsed_path = Path(scratch) / "modules.json"
        print(run([sys.executable, "tools/import/import_excel.py", str(source), str(parsed_path)], environment).strip())
        parsed = json.loads(parsed_path.read_text(encoding="utf-8"))
        cached = json.loads((ROOT / "tools/cache/modules.json").read_text(encoding="utf-8"))
        if parsed != cached:
            raise RuntimeError("Excel source differs from modules.json; run the data importer")
        print("Workbook archive and source/cache parity: OK")
        bridge_source = ROOT / "tools/data_source/bridge_data.xlsx"
        with zipfile.ZipFile(bridge_source) as workbook:
            invalid = workbook.testzip()
            if invalid:
                raise RuntimeError(f"Corrupt bridge workbook entry: {invalid}")
        bridge_parsed_path = Path(scratch) / "bridge.json"
        print(run([sys.executable, "tools/import/import_bridge.py", str(bridge_source), str(bridge_parsed_path)], environment).strip())
        bridge_parsed = json.loads(bridge_parsed_path.read_text(encoding="utf-8"))
        bridge_cached = json.loads((ROOT / "tools/cache/bridge.json").read_text(encoding="utf-8"))
        if bridge_parsed != bridge_cached:
            raise RuntimeError("Bridge Excel source differs from bridge.json; run the bridge importer")
        print("Bridge workbook source/cache parity: OK")
        print(run([sys.executable, "-m", "unittest", "discover", "-s", "tools/import", "-p", "test_*.py"], environment).strip())

        database_text = (ROOT / "data/modules/module_database.tres").read_text(encoding="utf-8")
        for module in parsed["modules"]:
            folder = module["module_type"].lower()
            resource_path = ROOT / "data/modules" / folder / f"{module['id']}.tres"
            if not resource_path.exists():
                raise RuntimeError(f"Module resource is missing: {resource_path.relative_to(ROOT)}")
            resource_text = resource_path.read_text(encoding="utf-8")
            texture_paths = [module["texture_path"]]
            if module["module_type"] == "WEAPON":
                texture_paths.append(module["turret_texture_path"])
                icon_texture_path = f"res://data/assets/modules/{module['id']}_icon.png"
                if (ROOT / icon_texture_path.removeprefix("res://")).exists():
                    texture_paths.append(icon_texture_path)
            for texture_path in texture_paths:
                if texture_path not in resource_text:
                    raise RuntimeError(
                        f"Module resource {resource_path.relative_to(ROOT)} does not reference {texture_path}"
                    )
                if texture_path not in database_text:
                    raise RuntimeError(
                        f"ModuleDatabase does not reference module texture {texture_path}"
                    )
        print("Module texture references: OK")

        run([args.godot, "--headless", "--editor", "--path", str(ROOT), "--import"], environment)
        for label, script in [
            ("Ship", "game/ship/dev/ship_regression_test.gd"),
            ("Combat", "game/combat/dev/combat_regression_test.gd"),
            ("Run", "game/run/dev/run_regression_test.gd"),
        ]:
            result = run([args.godot, "--headless", "--path", str(ROOT), "--script", script], environment)
            summary = re.search(rf"{label} regression: \d+ checks, 0 failures", result)
            if not summary:
                raise RuntimeError(f"Godot regression did not complete:\n{result}")
            print(summary.group())
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, subprocess.TimeoutExpired, OSError, zipfile.BadZipFile) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)

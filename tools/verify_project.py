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
    result = subprocess.run(command, cwd=ROOT, env=environment, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
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
        source = ROOT / "tools/data_import/source/game_data.xlsx"
        with zipfile.ZipFile(source) as workbook:
            corrupt = workbook.testzip()
            if corrupt:
                raise RuntimeError(f"Corrupt workbook entry: {corrupt}")
        parsed_path = Path(scratch) / "modules.json"
        print(run([sys.executable, "tools/data_import/import_excel.py", str(source), str(parsed_path)], environment).strip())
        parsed = json.loads(parsed_path.read_text(encoding="utf-8"))
        cached = json.loads((ROOT / "tools/data_import/cache/modules.json").read_text(encoding="utf-8"))
        if parsed != cached:
            raise RuntimeError("Excel source differs from modules.json; run the data importer")
        print("Workbook archive and source/cache parity: OK")
        run([args.godot, "--headless", "--editor", "--path", str(ROOT), "--import"], environment)
        result = run([args.godot, "--headless", "--path", str(ROOT), "--script",
                      "game/ship/dev/ship_regression_test.gd"], environment)
        summary = re.search(r"Ship regression: \d+ checks, 0 failures", result)
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

#!/usr/bin/env python3
"""Advance Four data importer: six module sheets in game_data.xlsx -> JSON cache.
Uses only Python standard library so no openpyxl dependency is required.

Sheet mapping:
Energy      -> ENERGY      + energy_output
Propulsion  -> PROPULSION  + thrust
Weapon      -> WEAPON      + firepower / range / interval / turret / projectile parameters
Defense     -> DEFENSE     + protection
Function    -> FUNCTION    + no type-specific field
Core        -> CORE        + no type-specific field
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

NS_MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
NS_REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS_PKG_REL = "http://schemas.openxmlformats.org/package/2006/relationships"

SHEET_SCHEMAS = {
    "Energy": {
        "module_type": "ENERGY",
        "type_field": "energy_output",
    },
    "Propulsion": {
        "module_type": "PROPULSION",
        "type_field": "thrust",
    },
    "Weapon": {
        "module_type": "WEAPON",
        "type_field": "firepower",
    },
    "Defense": {
        "module_type": "DEFENSE",
        "type_field": "protection",
    },
    "Function": {
        "module_type": "FUNCTION",
        "type_field": None,
    },
    "Core": {
        "module_type": "CORE",
        "type_field": None,
    },
}

BASE_COLUMNS = [
    "id", "display_name", "description",
    "width", "height", "mass", "energy_cost", "hp",
]
TYPE_FIELDS = ["energy_output", "thrust", "firepower", "protection"]
WEAPON_FIELDS = [
    "attack_range", "fire_interval", "turn_speed_degrees",
    "fire_angle_tolerance_degrees", "projectile_speed",
]
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")


def col_to_index(ref: str) -> int:
    letters = "".join(c for c in ref if c.isalpha()).upper()
    result = 0
    for c in letters:
        result = result * 26 + (ord(c) - ord("A") + 1)
    return result - 1


def read_shared_strings(zf: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in zf.namelist():
        return []
    root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
    values: list[str] = []
    for si in root.findall(f"{{{NS_MAIN}}}si"):
        pieces = []
        for t in si.iter(f"{{{NS_MAIN}}}t"):
            pieces.append(t.text or "")
        values.append("".join(pieces))
    return values


def resolve_sheet_path(zf: zipfile.ZipFile, sheet_name: str) -> str:
    wb = ET.fromstring(zf.read("xl/workbook.xml"))
    rid = None
    sheets = wb.find(f"{{{NS_MAIN}}}sheets")
    if sheets is None:
        raise ValueError("Excel 中没有工作表")
    for sheet in sheets:
        if sheet.attrib.get("name") == sheet_name:
            rid = sheet.attrib.get(f"{{{NS_REL}}}id")
            break
    if not rid:
        raise ValueError(f"找不到工作表：{sheet_name}")

    rels = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
    target = None
    for rel in rels.findall(f"{{{NS_PKG_REL}}}Relationship"):
        if rel.attrib.get("Id") == rid:
            target = rel.attrib.get("Target")
            break
    if not target:
        raise ValueError(f"无法解析工作表路径：{sheet_name}")
    target = target.lstrip("/")
    if target.startswith("xl/"):
        return target
    return "xl/" + target


def parse_cell(cell: ET.Element, shared: list[str]) -> Any:
    cell_type = cell.attrib.get("t")
    if cell_type == "inlineStr":
        is_node = cell.find(f"{{{NS_MAIN}}}is")
        if is_node is None:
            return ""
        return "".join((t.text or "") for t in is_node.iter(f"{{{NS_MAIN}}}t"))

    v = cell.find(f"{{{NS_MAIN}}}v")
    if v is None or v.text is None:
        return ""
    raw = v.text
    if cell_type == "s":
        idx = int(raw)
        return shared[idx] if 0 <= idx < len(shared) else ""
    if cell_type == "b":
        return raw == "1"
    if cell_type == "str":
        return raw
    try:
        n = float(raw)
        return int(n) if n.is_integer() else n
    except ValueError:
        return raw


def read_sheet_rows(xlsx: Path, sheet_name: str) -> list[list[Any]]:
    with zipfile.ZipFile(xlsx, "r") as zf:
        shared = read_shared_strings(zf)
        path = resolve_sheet_path(zf, sheet_name)
        root = ET.fromstring(zf.read(path))
        sheet_data = root.find(f"{{{NS_MAIN}}}sheetData")
        if sheet_data is None:
            return []
        result: list[list[Any]] = []
        for row in sheet_data.findall(f"{{{NS_MAIN}}}row"):
            values: dict[int, Any] = {}
            max_index = -1
            for cell in row.findall(f"{{{NS_MAIN}}}c"):
                idx = col_to_index(cell.attrib.get("r", "A1"))
                values[idx] = parse_cell(cell, shared)
                max_index = max(max_index, idx)
            result.append([values.get(i, "") for i in range(max_index + 1)] if max_index >= 0 else [])
        return result


def as_float(value: Any, field: str, sheet: str, row_number: int, errors: list[str]) -> float:
    if value == "" or value is None:
        return 0.0
    try:
        return float(value)
    except (TypeError, ValueError):
        errors.append(f"{sheet}!第 {row_number} 行：{field} 必须是数字，当前值为 {value!r}")
        return 0.0


def as_int(value: Any, field: str, sheet: str, row_number: int, errors: list[str]) -> int:
    f = as_float(value, field, sheet, row_number, errors)
    i = int(f)
    if f != i:
        errors.append(f"{sheet}!第 {row_number} 行：{field} 必须是整数，当前值为 {value!r}")
    return i


def find_header_row(rows: list[list[Any]], required_columns: list[str]) -> int | None:
    """Allow an optional note row before the header row."""
    for idx, row in enumerate(rows[:10]):
        headers = [str(x).strip() for x in row]
        if all(c in headers for c in required_columns):
            return idx
    return None


def parse_sheet(
    xlsx: Path,
    sheet_name: str,
    module_type: str,
    type_field: str | None,
    seen_ids: set[str],
    errors: list[str],
    warnings: list[str],
) -> list[dict[str, Any]]:
    rows = read_sheet_rows(xlsx, sheet_name)
    required_columns = list(BASE_COLUMNS)
    if type_field:
        required_columns.append(type_field)
    if module_type == "WEAPON":
        required_columns.extend(WEAPON_FIELDS)

    if not rows:
        errors.append(f"{sheet_name} 工作表为空")
        return []

    header_idx = find_header_row(rows, required_columns)
    if header_idx is None:
        errors.append(f"{sheet_name} 工作表找不到有效表头，必须包含：{', '.join(required_columns)}")
        return []

    headers = [str(x).strip() for x in rows[header_idx]]
    missing = [c for c in required_columns if c not in headers]
    if missing:
        errors.append(f"{sheet_name} 缺少列：{', '.join(missing)}")
        return []

    col = {name: headers.index(name) for name in required_columns}
    modules: list[dict[str, Any]] = []

    for row_idx, row in enumerate(rows[header_idx + 1:], start=header_idx + 2):
        def get(name: str) -> Any:
            idx = col[name]
            return row[idx] if idx < len(row) else ""

        raw_id = str(get("id") or "").strip()
        if not raw_id:
            if not any(str(v).strip() for v in row):
                continue
            errors.append(f"{sheet_name}!第 {row_idx} 行：id 不能为空")
            continue

        display_name = str(get("display_name") or "").strip()
        description = str(get("description") or "").strip()
        width = as_int(get("width"), "width", sheet_name, row_idx, errors)
        height = as_int(get("height"), "height", sheet_name, row_idx, errors)
        mass = as_float(get("mass"), "mass", sheet_name, row_idx, errors)
        energy_cost = as_float(get("energy_cost"), "energy_cost", sheet_name, row_idx, errors)
        hp = as_float(get("hp"), "hp", sheet_name, row_idx, errors)

        if not ID_PATTERN.match(raw_id):
            errors.append(f"{sheet_name}!第 {row_idx} 行：id '{raw_id}' 只能使用小写英文、数字和下划线，并以字母开头")
        if raw_id in seen_ids:
            errors.append(f"{sheet_name}!第 {row_idx} 行：id '{raw_id}' 在六类模块中重复")
        seen_ids.add(raw_id)
        if not display_name:
            errors.append(f"{sheet_name}!第 {row_idx} 行：display_name 不能为空")
        if width <= 0 or height <= 0:
            errors.append(f"{sheet_name}!第 {row_idx} 行：width 和 height 必须 > 0")
        if mass < 0 or energy_cost < 0:
            errors.append(f"{sheet_name}!第 {row_idx} 行：mass 和 energy_cost 不能为负数")
        if hp <= 0:
            errors.append(f"{sheet_name}!第 {row_idx} 行：hp 必须 > 0")

        type_value = 0.0
        if type_field:
            type_value = as_float(get(type_field), type_field, sheet_name, row_idx, errors)
            if type_value <= 0:
                errors.append(f"{sheet_name}!第 {row_idx} 行：{module_type} 模块必须填写 {type_field} > 0")

        module = {
            "id": raw_id,
            "display_name": display_name,
            "module_type": module_type,
            "description": description,
            "width": width,
            "height": height,
            "mass": mass,
            "energy_cost": energy_cost,
            "hp": hp,
            "energy_output": 0.0,
            "thrust": 0.0,
            "firepower": 0.0,
            "protection": 0.0,
        }
        if type_field:
            module[type_field] = type_value
        if module_type == "WEAPON":
            for field in WEAPON_FIELDS:
                raw = get(field)
                if raw == "" or raw is None:
                    errors.append(f"{sheet_name}!第 {row_idx} 行：{field} 不能为空")
                value = as_float(raw, field, sheet_name, row_idx, errors)
                if not math.isfinite(value):
                    errors.append(f"{sheet_name}!第 {row_idx} 行：{field} 必须是有限数字")
                elif field == "fire_angle_tolerance_degrees":
                    if not 0 <= value <= 180:
                        errors.append(f"{sheet_name}!第 {row_idx} 行：{field} 必须在 0~180 度之间")
                elif field == "turn_speed_degrees":
                    if value < 0:
                        errors.append(f"{sheet_name}!第 {row_idx} 行：{field} 不能为负数")
                elif value <= 0:
                    errors.append(f"{sheet_name}!第 {row_idx} 行：{field} 必须 > 0")
                module[field] = value
        modules.append(module)

    if not modules:
        warnings.append(f"{sheet_name} 工作表目前没有模块数据")
    return modules


def parse_modules(xlsx: Path) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    modules: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    counts: dict[str, int] = {}

    for sheet_name, schema in SHEET_SCHEMAS.items():
        before = len(modules)
        try:
            parsed = parse_sheet(
                xlsx,
                sheet_name,
                schema["module_type"],
                schema["type_field"],
                seen_ids,
                errors,
                warnings,
            )
            modules.extend(parsed)
            counts[sheet_name] = len(modules) - before
        except Exception as exc:
            errors.append(f"读取 {sheet_name} 工作表失败：{exc}")
            counts[sheet_name] = 0

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "counts": counts,
        "modules": modules,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_xlsx", type=Path)
    parser.add_argument("output_json", type=Path)
    args = parser.parse_args()

    try:
        payload = parse_modules(args.input_xlsx)
    except Exception as exc:
        payload = {
            "ok": False,
            "errors": [f"读取 Excel 失败：{exc}"],
            "warnings": [],
            "counts": {},
            "modules": [],
        }

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    if payload["ok"]:
        count_text = ", ".join(f"{k}={v}" for k, v in payload.get("counts", {}).items())
        print(f"OK: {len(payload['modules'])} modules ({count_text})")
        for warning in payload.get("warnings", []):
            print("WARNING:", warning)
        return 0

    for e in payload["errors"]:
        print("ERROR:", e, file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

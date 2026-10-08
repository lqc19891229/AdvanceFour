#!/usr/bin/env python3
"""Validate bridge_data.xlsx (Chips, Crew, Effects, BridgeConfig) into bridge.json."""
from __future__ import annotations
import argparse
import json
import math
import re
from pathlib import Path
from import_excel import read_sheet_rows, find_header_row

IDENT = re.compile(r"^[a-z][a-z0-9_]*$")
STATS = {"weapon_damage", "weapon_range", "weapon_fire_interval", "thrust", "turn_speed", "energy_output", "protection", "repair_cost"}
OPERATIONS = {"FLAT", "PERCENT_ADD", "MULTIPLIER"}
RARITIES = {"COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"}
SHEETS = {
    "Chips": ["chip_id", "display_name", "rarity", "description", "icon_path"],
    "Crew": ["crew_id", "display_name", "race", "rarity", "description", "portrait_path"],
    "Effects": ["effect_id", "owner_id", "stat", "operation", "value", "target_filter", "condition_id"],
    "BridgeConfig": ["bridge_id", "crew_slots", "chip_slots"],
}

def rows(path: Path, sheet: str, required: list[str]) -> list[dict]:
    source = read_sheet_rows(path, sheet)
    index = find_header_row(source, required)
    if index is None:
        raise ValueError(f"{sheet}: missing columns: {', '.join(required)}")
    headers = [str(x).strip() for x in source[index]]
    if len(headers) != len(set(headers)):
        raise ValueError(f"{sheet}: duplicate headers")
    result = []
    for number, values in enumerate(source[index + 1:], start=index + 2):
        if not any(str(v).strip() for v in values):
            continue
        row = {key: values[i] if i < len(values) else "" for i, key in enumerate(headers)}
        row["_row"] = number
        result.append(row)
    return result

def parse(path: Path) -> dict:
    errors: list[str] = []
    payload = {"ok": False, "errors": errors, "chips": [], "crew": [], "effects": [], "bridge_configs": []}
    try:
        source = {sheet: rows(path, sheet, cols) for sheet, cols in SHEETS.items()}
    except Exception as exc:
        errors.append(str(exc))
        return payload
    owners: set[str] = set()
    for sheet, output, key in (("Chips", "chips", "chip_id"), ("Crew", "crew", "crew_id")):
        seen: set[str] = set()
        for row in source[sheet]:
            ctx = f"{sheet}!row {row['_row']}"
            item_id = str(row[key]).strip()
            if not IDENT.fullmatch(item_id) or item_id in owners or item_id in seen:
                errors.append(f"{ctx}: invalid or duplicate ID {item_id!r}")
            seen.add(item_id)
            owners.add(item_id)
            if not str(row["display_name"]).strip():
                errors.append(f"{ctx}: missing display_name")
            rarity = str(row["rarity"]).upper().strip()
            if rarity not in RARITIES:
                errors.append(f"{ctx}: invalid rarity {rarity!r}")
            item = {k: str(row.get(k, "")).strip() for k in SHEETS[sheet]}
            item["rarity"] = rarity
            if sheet == "Crew" and not IDENT.fullmatch(item["race"].lower()):
                errors.append(f"{ctx}: invalid race")
            for field in (["icon_path"] if sheet == "Chips" else ["portrait_path"]):
                if item[field] and not (item[field].startswith("res://data/assets/") and item[field].lower().endswith(".png")):
                    errors.append(f"{ctx}: {field} must be a res://data/assets/*.png path")
            payload[output].append(item)
    effect_ids: set[str] = set()
    for row in source["Effects"]:
        ctx = f"Effects!row {row['_row']}"
        effect_id = str(row["effect_id"]).strip()
        owner = str(row["owner_id"]).strip()
        stat = str(row["stat"]).strip().lower()
        op = str(row["operation"]).strip().upper()
        if not IDENT.fullmatch(effect_id) or effect_id in effect_ids:
            errors.append(f"{ctx}: invalid/duplicate effect_id")
        effect_ids.add(effect_id)
        if owner not in owners:
            errors.append(f"{ctx}: owner_id {owner!r} does not exist")
        if stat not in STATS:
            errors.append(f"{ctx}: unsupported stat {stat!r}")
        if op not in OPERATIONS:
            errors.append(f"{ctx}: unsupported operation {op!r}")
        try:
            value = float(row["value"])
            if not math.isfinite(value) or abs(value) > 100000:
                raise ValueError
            if op == "MULTIPLIER" and value <= 0:
                raise ValueError
        except (ValueError, TypeError, OverflowError):
            errors.append(f"{ctx}: invalid finite numeric value")
            value = 0.0
        target = str(row.get("target_filter", "") or "").strip().upper()
        condition = str(row.get("condition_id", "") or "").strip()
        if target not in ("", "ALL", "WEAPON", "CANNON", "PROPULSION", "ENERGY", "DEFENSE"):
            errors.append(f"{ctx}: unsupported target_filter")
        if condition:
            errors.append(f"{ctx}: conditional effects are reserved for future versions")
        payload["effects"].append({"effect_id": effect_id, "owner_id": owner, "stat": stat, "operation": op, "value": value, "target_filter": target, "condition_id": condition})
    bridge_ids: set[str] = set()
    for row in source["BridgeConfig"]:
        ctx = f"BridgeConfig!row {row['_row']}"
        bid = str(row["bridge_id"]).strip()
        if not IDENT.fullmatch(bid) or bid in bridge_ids:
            errors.append(f"{ctx}: invalid/duplicate bridge_id")
        bridge_ids.add(bid)
        item = {"bridge_id": bid}
        for field in ("crew_slots", "chip_slots"):
            try:
                number = float(row[field])
                if not number.is_integer() or not 0 <= number <= 32:
                    raise ValueError
                item[field] = int(number)
            except (ValueError, TypeError, OverflowError):
                errors.append(f"{ctx}: {field} must be integer in range 0..32")
                item[field] = 0
        payload["bridge_configs"].append(item)
    if not payload["bridge_configs"]:
        errors.append("BridgeConfig requires at least one row")
    payload["ok"] = not errors
    return payload

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = parse(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    for error in result["errors"]:
        print("ERROR:", error)
    print(f"Bridge: {len(result['chips'])} chips, {len(result['crew'])} crew, {len(result['effects'])} effects")
    return 0 if result["ok"] else 2

if __name__ == "__main__":
    raise SystemExit(main())

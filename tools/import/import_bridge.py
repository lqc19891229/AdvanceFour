#!/usr/bin/env python3
"""Validate two-sheet bridge_data.xlsx (Chips, Crew) into bridge.json."""
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
EFFECT_FIELDS = ["stat", "operation", "value", "target_filter"]
SHEETS = {
    "Chips": ["chip_id", "display_name", "rarity", "description", "icon_path", "effects"],
    "Crew": ["crew_id", "display_name", "race", "rarity", "description", "portrait_path", "effects"],
}

def records(path: Path, sheet: str, required: list[str]) -> list[dict]:
    rows = read_sheet_rows(path, sheet)
    index = find_header_row(rows, required)
    if index is None:
        raise ValueError(f"{sheet}: missing columns: {', '.join(required)}")
    headers = [str(x).strip() for x in rows[index]]
    if len(headers) != len(set(headers)):
        raise ValueError(f"{sheet}: duplicate headers")
    result = []
    for number, values in enumerate(rows[index + 1:], start=index + 2):
        if not any(str(v).strip() for v in values):
            continue
        item = {key: values[i] if i < len(values) else "" for i, key in enumerate(headers)}
        item["_row"] = number
        result.append(item)
    return result

def parse(path: Path) -> dict:
    errors: list[str] = []
    payload = {"ok": False, "errors": errors, "chips": [], "crew": []}
    seen_ids: set[str] = set()
    try:
        source = {sheet: records(path, sheet, fields) for sheet, fields in SHEETS.items()}
    except Exception as exc:
        errors.append(str(exc))
        return payload
    for sheet, target, key in (("Chips", "chips", "chip_id"), ("Crew", "crew", "crew_id")):
        for row in source[sheet]:
            ctx = f"{sheet}!row {row['_row']}"
            item_id = str(row.get(key, "")).strip()
            if not IDENT.fullmatch(item_id) or item_id in seen_ids:
                errors.append(f"{ctx}: invalid or duplicate ID {item_id!r}")
            seen_ids.add(item_id)
            rarity = str(row.get("rarity", "")).strip().upper()
            if rarity not in RARITIES:
                errors.append(f"{ctx}: invalid rarity")
            if not str(row.get("display_name", "")).strip():
                errors.append(f"{ctx}: missing display_name")
            item = {k: str(row.get(k, "") or "").strip() for k in SHEETS[sheet] if k != "effects"}
            item["rarity"] = rarity
            if sheet == "Crew" and not IDENT.fullmatch(item["race"].lower()):
                errors.append(f"{ctx}: invalid race")
            art_field = "icon_path" if sheet == "Chips" else "portrait_path"
            art_path = item[art_field]
            if art_path and not (art_path.startswith("res://data/assets/") and art_path.lower().endswith(".png")):
                errors.append(f"{ctx}: invalid {art_field}")
            try:
                raw_effects = json.loads(str(row.get("effects", "[]") or "[]"))
                if not isinstance(raw_effects, list):
                    raise ValueError("effects must be a JSON array")
            except (ValueError, TypeError) as exc:
                errors.append(f"{ctx}: effects must be valid JSON array: {exc}")
                raw_effects = []
            item["effects"] = []
            for index, effect in enumerate(raw_effects, start=1):
                effect_ctx = f"{ctx} effects[{index}]"
                if not isinstance(effect, dict):
                    errors.append(f"{effect_ctx}: effect must be object")
                    continue
                forbidden = {"effect_id", "owner_id", "condition_id"} & set(effect)
                if forbidden:
                    errors.append(f"{effect_ctx}: obsolete fields {sorted(forbidden)}")
                values = {key: effect.get(key, "") for key in EFFECT_FIELDS}
                stat = str(values["stat"]).strip().lower()
                op = str(values["operation"]).strip().upper()
                if stat not in STATS or op not in OPERATIONS:
                    errors.append(f"{effect_ctx}: invalid stat or operation")
                try:
                    value = float(values["value"])
                    if not math.isfinite(value) or abs(value) > 100000 or (op == "MULTIPLIER" and value <= 0):
                        raise ValueError
                except (ValueError, TypeError, OverflowError):
                    errors.append(f"{effect_ctx}: invalid numeric value")
                    value = 0.0
                target_filter = str(values["target_filter"] or "").upper().strip()
                if target_filter not in ("", "ALL", "WEAPON", "CANNON", "PROPULSION", "ENERGY", "DEFENSE"):
                    errors.append(f"{effect_ctx}: unsupported target_filter")
                item["effects"].append({"stat": stat, "operation": op, "value": value, "target_filter": target_filter})
            payload[target].append(item)
    payload["ok"] = not errors
    return payload

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    parsed = parse(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(parsed, ensure_ascii=False, indent=2), encoding="utf-8")
    for error in parsed["errors"]:
        print("ERROR:", error)
    print(f"Bridge: {len(parsed['chips'])} chips, {len(parsed['crew'])} crew")
    return 0 if parsed["ok"] else 2

if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Parse battle_data.xlsx into validated encounter JSON (standard library only)."""
from __future__ import annotations
import argparse
import json
import re
from pathlib import Path
from import_excel import read_sheet_rows, find_header_row

FIELDS = {
    "关卡ID": "battle_id", "关卡名称": "display_name",
    "战斗类型": "encounter_type", "难度": "difficulty_tier",
    "星区ID": "sector_id", "准备秒数": "preparation_seconds",
    "波次间隔秒": "intermission_seconds", "默认刷怪间隔秒": "spawn_interval_seconds",
    "刷怪半径": "spawn_radius", "能量结晶": "reward_energy_crystals",
    "零件": "reward_parts", "船体格": "reward_hull_cells",
    "掉落表路径": "loot_table_path",
    "波次": "wave_index", "敌舰路径": "enemy_path",
    "数量": "count", "刷怪间隔秒": "wave_spawn_interval_seconds",
}
BATTLE_COLUMNS = ["battle_id", "display_name", "encounter_type", "difficulty_tier", "sector_id"]
WAVE_COLUMNS = ["battle_id", "wave_index", "enemy_path", "count"]
TYPES = {"NORMAL": 0, "ELITE": 1, "BOSS": 2}
ID = re.compile(r"^[a-z][a-z0-9_]*$")


def records(path: Path, sheet: str, required: list[str]) -> list[dict]:
    rows = read_sheet_rows(path, sheet)
    header_row = find_header_row([[FIELDS.get(str(c).strip(), str(c).strip()) for c in row] for row in rows], required)
    if header_row is None:
        raise ValueError(f"{sheet} 缺少必填表头：{', '.join(required)}")
    headers = [FIELDS.get(str(c).strip(), str(c).strip()) for c in rows[header_row]]
    if len(headers) != len(set(headers)):
        raise ValueError(f"{sheet} 有重复表头")
    result = []
    for number, values in enumerate(rows[header_row + 1:], header_row + 2):
        if not any(str(v).strip() for v in values):
            continue
        item = dict(zip(headers, values))
        item["_row"] = number
        result.append(item)
    return result


def integer(value, name, ctx, errors, minimum=0, maximum=None):
    try:
        f = float(value)
        if not f.is_integer():
            raise ValueError
        n = int(f)
        if n < minimum or (maximum is not None and n > maximum):
            raise ValueError
        return n
    except (ValueError, TypeError, OverflowError):
        errors.append(f"{ctx}：{name} 必须是范围内整数")
        return minimum


def number(value, name, ctx, errors, default=0, minimum=0):
    import math
    if value == "" or value is None:
        return default
    try:
        n = float(value)
        if not math.isfinite(n) or n < minimum:
            raise ValueError
        return n
    except (ValueError, TypeError):
        errors.append(f"{ctx}：{name} 必须是 >= {minimum} 的有限数字")
        return default


def parse(path: Path) -> dict:
    errors = []
    battles = {}
    waves = {}
    try:
        battle_rows = records(path, "Battles", BATTLE_COLUMNS)
        wave_rows = records(path, "Waves", WAVE_COLUMNS)
    except Exception as exc:
        return {"ok": False, "errors": [str(exc)], "battles": []}
    for row in battle_rows:
        ctx = f"Battles!第 {row['_row']} 行"
        bid = str(row.get("battle_id", "")).strip()
        label = str(row.get("display_name", "")).strip()
        kind = str(row.get("encounter_type", "")).strip().upper()
        sector = str(row.get("sector_id", "")).strip()
        if not ID.fullmatch(bid) or bid in battles:
            errors.append(f"{ctx}：关卡ID 无效或重复 {bid!r}")
            continue
        if not label or kind not in TYPES or not ID.fullmatch(sector):
            errors.append(f"{ctx}：名称、战斗类型或星区ID 无效")
        d = {"battle_id": bid, "display_name": label,
             "encounter_type": TYPES.get(kind, 0),
             "difficulty_tier": integer(row.get("difficulty_tier"), "难度", ctx, errors, 1, 10),
             "sector_id": sector, "waves": []}
        for key, default, minimum in [
            ("preparation_seconds", 2, 0), ("intermission_seconds", 3, 0),
            ("spawn_interval_seconds", 1.25, 0), ("spawn_radius", 460, 0.001)]:
            d[key] = number(row.get(key, ""), key, ctx, errors, default, minimum)
        for key in ("reward_energy_crystals", "reward_parts", "reward_hull_cells"):
            d[key] = integer(row.get(key, 0) or 0, key, ctx, errors)
        loot = str(row.get("loot_table_path", "") or "").strip()
        if loot and (not loot.startswith("res://") or not loot.endswith(".tres")):
            errors.append(f"{ctx}：掉落表必须为 res://...tres")
        d["loot_table_path"] = loot
        battles[bid] = d
    for row in wave_rows:
        ctx = f"Waves!第 {row['_row']} 行"
        bid = str(row.get("battle_id", "")).strip()
        if bid not in battles:
            errors.append(f"{ctx}：找不到关卡 {bid}")
            continue
        index = integer(row.get("wave_index"), "波次", ctx, errors, 1)
        count = integer(row.get("count"), "数量", ctx, errors, 1)
        path_value = str(row.get("enemy_path", "")).strip()
        if not path_value.startswith("res://data/enemies/") or not path_value.endswith(".tres"):
            errors.append(f"{ctx}：敌舰路径必须在 res://data/enemies/ 下")
        rate = number(row.get("wave_spawn_interval_seconds", ""), "波次刷怪间隔", ctx, errors, -1, -1)
        waves.setdefault(bid, {}).setdefault(index, []).append({
            "enemy_path": path_value, "count": count, "spawn_interval_seconds": rate
        })
    for bid, battle in battles.items():
        sequence = waves.get(bid, {})
        if not sequence or sorted(sequence) != list(range(1, len(sequence) + 1)):
            errors.append(f"关卡 {bid}：波次必须从 1 连续编号且至少一波")
            continue
        for index in sorted(sequence):
            members = sequence[index]
            rates = {m["spawn_interval_seconds"] for m in members}
            if len(rates) > 1:
                errors.append(f"关卡 {bid} 波次 {index}：同波次刷怪间隔不一致")
            battle["waves"].append({"enemies": members, "spawn_interval_seconds": members[0]["spawn_interval_seconds"]})
    return {"ok": not errors, "errors": errors, "battles": list(battles.values())}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        payload = parse(args.input)
    except Exception as exc:
        payload = {"ok": False, "errors": [str(exc)], "battles": []}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(("OK" if payload["ok"] else "FAIL") + ": " + str(len(payload["battles"])) + " battles")
    for error in payload["errors"]:
        print("ERROR:", error)
    return 0 if payload["ok"] else 2


if __name__ == "__main__":
    raise SystemExit(main())

"""Weapon source validation, including missing fields and supported zero values."""
from copy import deepcopy
from pathlib import Path
import unittest
from unittest.mock import patch

import import_excel as importer


class WeaponImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = Path(__file__).parent / "source/game_data.xlsx"
        cls.sheets = {name: importer.read_sheet_rows(cls.source, name)
                      for name in importer.SHEET_SCHEMAS}

    def parse(self, field=None, value=None, missing_header=False):
        sheets = deepcopy(self.sheets)
        if field:
            column = sheets["Weapon"][1].index(field)
            if missing_header:
                sheets["Weapon"][1][column] = "missing_field"
            else:
                sheets["Weapon"][2][column] = value
        with patch.object(importer, "read_sheet_rows", side_effect=lambda _, name: sheets[name]):
            return importer.parse_modules(self.source)

    def test_valid_source_and_nonweapon_scope(self):
        payload = self.parse()
        self.assertTrue(payload["ok"], payload["errors"])
        for row in payload["modules"]:
            for field in importer.WEAPON_FIELDS:
                self.assertEqual(field in row, row["module_type"] == "WEAPON")

    def test_custom_values_survive_parsing(self):
        for field, value in zip(importer.WEAPON_FIELDS, [120, 0.25, 90, 12, 240]):
            with self.subTest(field=field):
                payload = self.parse(field, value)
                self.assertTrue(payload["ok"], payload["errors"])
                weapon = next(row for row in payload["modules"] if row["module_type"] == "WEAPON")
                self.assertEqual(weapon[field], value)

    def test_all_fields_required(self):
        for field in importer.WEAPON_FIELDS:
            with self.subTest(field=field):
                self.assertFalse(self.parse(field, missing_header=True)["ok"])
                payload = self.parse(field, "")
                self.assertFalse(payload["ok"])
                self.assertTrue(any(field in error and "不能为空" in error for error in payload["errors"]))

    def test_invalid_numbers_rejected(self):
        for field in importer.WEAPON_FIELDS:
            for value in [-1, "invalid", "nan", "inf"]:
                with self.subTest(field=field, value=value):
                    payload = self.parse(field, value)
                    self.assertFalse(payload["ok"])
                    self.assertTrue(any(field in error for error in payload["errors"]))

    def test_positive_fields_reject_zero(self):
        for field in ["attack_range", "fire_interval", "projectile_speed"]:
            with self.subTest(field=field):
                self.assertFalse(self.parse(field, 0)["ok"])

    def test_turret_and_tolerance_boundaries(self):
        self.assertTrue(self.parse("turn_speed_degrees", 0)["ok"])
        self.assertTrue(self.parse("fire_angle_tolerance_degrees", 0)["ok"])
        self.assertTrue(self.parse("fire_angle_tolerance_degrees", 180)["ok"])
        self.assertFalse(self.parse("fire_angle_tolerance_degrees", 180.1)["ok"])


if __name__ == "__main__":
    unittest.main()

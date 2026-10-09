"""Author-facing dimension and anchor parsing regressions."""
import unittest
from pathlib import Path
from unittest.mock import patch

from import_excel import parse_size, parse_point, parse_sheet, read_sheet_rows


class AuthoringFieldsTest(unittest.TestCase):
    def test_width_first_sizes(self):
        for text in ("2x1", "2X1", " 2 × 1 "):
            errors = []
            self.assertEqual(parse_size(text, "宽x高", "Weapon", 2, errors), (2, 1))
            self.assertEqual(errors, [])

    def test_legacy_height_first_sizes(self):
        errors = []
        self.assertEqual(parse_size('2x1', '高X宽', 'Weapon', 2, errors, True), (1, 2))
        self.assertEqual(errors, [])

    def test_invalid_sizes(self):
        for text in ("", "0x1", "-1x2", "1.5x2", "1x2x3", "nanx1"):
            errors = []
            parse_size(text, "宽x高", "Weapon", 2, errors)
            self.assertTrue(errors, text)
            self.assertIn("Weapon!第 2 行", errors[0])

    def test_points(self):
        for text in ("0.5,0.98", " 0.5 ， 0.98 "):
            errors = []
            self.assertEqual(parse_point(text, "炮口", "Weapon", 2, errors), [0.5, 0.98])
            self.assertEqual(errors, [])
        self.assertEqual(parse_point("0,1", "炮口", "Weapon", 2, []), [0, 1])

    def test_invalid_points(self):
        for text in ("", "0.5", "0.5,0.5,0.5", "-0.1,0.5", "0.5,1.1", "nan,0", "0,inf"):
            errors = []
            parse_point(text, "炮口", "Weapon", 2, errors)
            self.assertTrue(errors, text)

    def test_row_pipeline_and_errors(self):
        source = Path(__file__).resolve().parents[1] / "data_source/module_data.xlsx"
        rows = read_sheet_rows(source, "Weapon")
        errors = []
        modules = parse_sheet(source, "Weapon", "WEAPON", "firepower", set(), errors, [])
        self.assertEqual(errors, [])
        self.assertEqual((modules[0]["width"], modules[0]["height"]), (1, 1))
        self.assertEqual(modules[0]["turret_size_cells"], [1, 2])
        self.assertEqual(modules[0]["turret_pivot"], [0.5, 0.25])
        self.assertEqual(modules[0]["turret_muzzle"], [0.5, 0.98])
        for field, invalid in (("高X宽", "0x1"), ("炮塔高X宽", "2.5x1"), ("炮塔轴点", "nan,0"), ("炮口", "0.5,2"), ("炮塔素材转角（度）", 45)):
            modified = [row[:] for row in rows]
            modified[1][modified[0].index(field)] = invalid
            errors = []
            with patch("import_excel.read_sheet_rows", return_value=modified):
                parse_sheet(source, "Weapon", "WEAPON", "firepower", set(), errors, [])
            self.assertTrue(errors, field)


if __name__ == "__main__":
    unittest.main()

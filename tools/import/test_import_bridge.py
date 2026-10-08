"""Bridge authoring Excel regression coverage."""
import unittest
from pathlib import Path
from import_bridge import parse
from import_excel import parse_sheet

SOURCE = Path(__file__).resolve().parents[1] / "data_source"

class BridgeImportTests(unittest.TestCase):
    def test_bridge_sheet_effects(self):
        data = parse(SOURCE / "bridge_data.xlsx")
        self.assertTrue(data["ok"], data["errors"])
        self.assertEqual(len(data["chips"]), 2)
        self.assertEqual(len(data["crew"]), 2)
        self.assertEqual(data["chips"][0]["effects"][0]["operation"], "PERCENT_ADD")
        for item in data["chips"] + data["crew"]:
            for effect in item["effects"]:
                self.assertEqual(set(effect), {"stat", "operation", "value", "target_filter"})

    def test_core_capacity_from_module_excel(self):
        errors = []
        modules = parse_sheet(SOURCE / "module_data.xlsx", "Core", "CORE", None, set(), errors, [])
        self.assertEqual(errors, [])
        self.assertEqual(modules[0]["crew_slots"], 4)
        self.assertEqual(modules[0]["chip_slots"], 4)

if __name__ == "__main__":
    unittest.main()

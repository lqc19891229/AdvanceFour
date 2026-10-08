"""Excel encounter parser validation independent from external workbooks."""
import unittest
from unittest.mock import patch
from import_battles import parse

class BattleSheetTests(unittest.TestCase):
    def setUp(self):
        self.battles = [
            {"_row":2, "battle_id":"normal_test","display_name":"侦察战","encounter_type":"NORMAL","difficulty_tier":1,"sector_id":"sector_01","loot_table_path":""}
        ]
        self.waves = [
            {"_row":2, "battle_id":"normal_test","wave_index":1,"enemy_path":"res://data/enemies/scout.tres","count":2,"wave_spawn_interval_seconds":1.2},
            {"_row":3, "battle_id":"normal_test","wave_index":2,"enemy_path":"res://data/enemies/gunship.tres","count":1,"wave_spawn_interval_seconds":0.9}
        ]

    def parsed(self):
        with patch("import_battles.records", side_effect=[self.battles, self.waves]):
            return parse(None)

    def test_valid(self):
        result = self.parsed()
        self.assertTrue(result["ok"], result["errors"])
        self.assertEqual(len(result["battles"][0]["waves"]), 2)
        self.assertEqual(result["battles"][0]["reward_parts"], 0)

    def test_missing_wave(self):
        self.waves = self.waves[1:]
        self.assertFalse(self.parsed()["ok"])

    def test_bad_enemy_path(self):
        self.waves[0]["enemy_path"] = "../../secret.tres"
        self.assertFalse(self.parsed()["ok"])

    def test_unknown_battle(self):
        self.waves[0]["battle_id"] = "not_found"
        self.assertFalse(self.parsed()["ok"])

    def test_duplicate_id(self):
        self.battles.append(dict(self.battles[0]))
        self.assertFalse(self.parsed()["ok"])

if __name__ == "__main__":
    unittest.main()

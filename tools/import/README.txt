《前进四》tools/import 目录说明

职责：
保存内容生产与转换脚本。

当前：
- import_excel.py：读取 tools/data_source/game_data.xlsx，校验六类模块 Sheet 并生成 tools/cache/modules.json。

数据链：
tools/data_source/game_data.xlsx
→ tools/import/import_excel.py
→ tools/cache/modules.json
→ Godot Data Importer
→ data/modules/

路径规则：
Excel 中的 texture_path / turret_texture_path 必须直接填写 Runtime 正式路径 res://data/assets/...。
导入器不应依赖旧 game 目录素材路径作为真源。

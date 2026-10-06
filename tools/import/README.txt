《前进四》tools/import 目录说明

职责：
保存内容生产与转换脚本。

当前：
- import_excel.py：读取 tools/data_source/game_data.xlsx，校验六类模块表并生成 JSON 数据。

数据链：
tools/data_source/game_data.xlsx
→ tools/import/import_excel.py
→ tools/cache/modules.json
→ Godot Data Importer
→ data/modules/

兼容：
当前 importer 会把历史 Excel 中 res://game/ship/art/modules/ 路径规范化为 res://data/assets/modules/。
新数据应直接使用 data/assets 正式路径。

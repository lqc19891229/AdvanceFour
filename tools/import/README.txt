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

尺寸使用“高X宽”单列，导入时转换为 Runtime width / height。
Weapon 另读“炮塔高X宽”“炮塔轴点”“炮口”；轴点和炮口为左下角起算的 X,Y。
可选“炮塔素材转角（度）”仅用于旧素材转向，默认 0，必须是 90 的整数倍。
test_import_excel.py 验证高宽顺序、坐标范围及错误输入；verify_project.py 会执行这些测试。

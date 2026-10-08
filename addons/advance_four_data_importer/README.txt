《前进四》Advance Four Data Importer

职责：
把 tools 中的策划源数据转换为 data 中 Godot Runtime 可直接加载的 Resource。

输入：
- res://tools/data_source/module_data.xlsx
- res://tools/cache/modules.json

输出：
- res://data/modules/<type>/*.tres
- res://data/modules/module_database.tres

数据结构：
- res://data/definitions/module/

正式素材：
- res://data/assets/modules/

规则：
导入失败时恢复导入前模块资源，避免留下半更新数据。

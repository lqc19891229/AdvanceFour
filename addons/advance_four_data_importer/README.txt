《前进四》数据导入插件说明

文件：
- plugin.cfg：Godot EditorPlugin 注册信息。
- plugin.gd：编辑器插件主体。

功能：
- “前进四：验证模块数据”：调用 Python 解析六个 Excel Sheet 并检查错误。
- “前进四：导入模块数据”：验证通过后生成六类 .tres，并重建 module_database.tres。

输入：res://data_source/game_data.xlsx
缓存：res://data/import_cache/modules.json
输出：res://data/generated/modules/ 与 module_database.tres

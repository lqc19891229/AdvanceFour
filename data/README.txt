《前进四》data 目录说明

用途：Godot 运行/导入产生的数据，不是策划直接编辑的源数据。

子目录：
- import_cache/：Excel 转换后的中间 JSON。
- generated/：由导入工具自动生成的 .tres 和数据库。

重要：
- 策划数据只修改 tools/data_import/source/game_data.xlsx。
- data/generated 下的文件原则上禁止手工修改。

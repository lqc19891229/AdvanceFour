《前进四》自动生成模块目录说明

本目录对应：Function 功能模块
来源：tools/data_source/game_data.xlsx 中对应 Sheet。
内容：由导入流程生成的 .tres Resource。
正式素材：data/assets/modules/。
数据类型定义：data/definitions/module/。

通常禁止手工修改本目录中的模块 .tres；请修改数据源后重新执行“前进四：导入模块数据”。

v0.38.0：function_cargo_hold 为内建系统模块，由 tools/import/import_excel.py 的 BUILTIN_MODULES 注入缓存并由 Godot 导入器稳定重建，不依赖 Excel Function Sheet。

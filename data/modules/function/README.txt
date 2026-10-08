【当前代码说明｜2026-10】
Godot 4.6.1；入口为 route_map_screen.tscn，默认固定测试航线，随机地图 RouteMapGenerator.generate() 尚非默认。
现行货币：能量结晶用于商店；零件用于 Hull 维修、空间站制造。胜利自动统一结算，失败清空 Run。
以下历史版本记录仅供追溯。

《前进四》自动生成模块目录说明

本目录对应：Function 功能模块
来源：tools/data_source/module_data.xlsx 中对应 Sheet。
内容：由导入流程生成的 .tres Resource。
正式素材：data/assets/modules/。
数据类型定义：data/definitions/module/。

通常禁止手工修改本目录中的模块 .tres；请修改数据源后重新执行“前进四：导入模块数据”。

v0.39.0：
- Function Sheet 正式增加“仓储容量 / storage_capacity”字段。
- function_cargo_hold 已写入 tools/data_source/module_data.xlsx，不再由代码内建注入。
- 仓库模块贴图使用 data/assets/modules/function_cargo_hold.png。
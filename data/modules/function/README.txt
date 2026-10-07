《前进四》自动生成模块目录说明

本目录对应：Function 功能模块
来源：tools/data_source/game_data.xlsx 中对应 Sheet。
内容：由导入流程生成的 .tres Resource。
正式素材：data/assets/modules/。
数据类型定义：data/definitions/module/。

通常禁止手工修改本目录中的模块 .tres；请修改数据源后重新执行“前进四：导入模块数据”。

v0.39.0：
- Function Sheet 正式增加“仓储容量 / storage_capacity”字段。
- function_cargo_hold 已写入 tools/data_source/game_data.xlsx，不再由代码内建注入。
- 仓库模块贴图使用 data/assets/modules/function_cargo_hold.png。
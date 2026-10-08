【当前代码说明｜2026-10】
Godot 4.6.1；项目默认启动 fixed_test_sector 测试星图，动态星图由 RouteMapGenerator.generate() 实现。
能量结晶用于商店，零件用于维修和空间站制造；战斗胜利直接统一结算，失败重置 Run。
历史版本内容不等于当前规则。

《前进四》自动生成模块目录说明

本目录对应：Propulsion 动力模块
来源：tools/data_source/module_data.xlsx 中对应 Sheet。
内容：由导入流程生成的 .tres Resource。
正式素材：data/assets/modules/。
数据类型定义：data/definitions/module/。

禁止手工修改本目录中的模块 .tres；请修改 Excel 后重新执行“前进四：导入模块数据”。

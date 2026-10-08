舰桥 V1.0 数据源结构

tools/data_source/bridge_data.xlsx 仅有 Chips、Crew 两个工作表。
每行通过 effects 列保存 JSON 数组，可包含多条效果；不再建立独立 Effects 工作表。
Chip 和 Crew 都可拥有任意属性方向的修正，不绑定固定岗位。
舰桥机组槽和芯片槽的容量在 tools/data_source/module_data.xlsx 的 Core 工作表（crew_slots、chip_slots）定义，导入 CoreModuleDefinition。
没有单独 BridgeConfig 资源/工作表。bridge_database.tres 持有芯片和机组定义。
此阶段暂未实现桥面管理 UI 与战斗数值计算。

V1.0 效果格式仅包含 stat、operation、value、target_filter 四个字段；不需要 effect_id、owner_id 或 condition_id。

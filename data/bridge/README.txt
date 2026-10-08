《前进四》data/bridge 目录说明（舰桥 V1.0）
更新：2026-10

一、目录定位
本目录存放由 Excel 数据源导入生成的 Godot Resource（.tres），供运行时代码读取。
这不是策划数据的编辑入口。应当优先修改 tools/data_source/bridge_data.xlsx，再通过导入工具更新本目录资源。

二、文件结构
data/bridge/
  bridge_database.tres     汇总芯片和机组定义的 BridgeDatabase
  chips/
    <chip_id>.tres         每种芯片对应一个 BridgeChipDefinition
  crew/
    <crew_id>.tres         每名预设机组对应一个 BridgeCrewDefinition

示例：
- chips/chip_fire_01.tres：火控强化 I。
- chips/chip_energy_01.tres：反应堆优化。
- crew/crew_human_01.tres：莱恩。
- crew/crew_machine_01.tres：AX-07。

三、资源类型与字段
BridgeChipDefinition（data/definitions/bridge/bridge_chip_definition.gd）
- chip_id、display_name、description、rarity、icon、modifiers。

BridgeCrewDefinition（data/definitions/bridge/bridge_crew_definition.gd）
- crew_id、display_name、description、race、rarity、portrait、modifiers。

BridgeModifierDefinition（data/definitions/bridge/bridge_modifier_definition.gd）
- stat：被修改的属性。
- operation：FLAT / PERCENT_ADD / MULTIPLIER。
- value：数值。
- target_filter：效果目标范围。
- 不再包含 effect_id、owner_id、condition_id。

BridgeDatabase（data/definitions/bridge/bridge_database.gd）
- chips：芯片定义集合。
- crew：机组定义集合。
- 提供 find_chip(id)、find_crew(id) 查找接口。

注意：芯片和机组通过 modifiers 保存多条效果，不绑定固定职业或岗位。
各个独立 .tres 与 bridge_database.tres 都由导入器生成；数据库中可能内嵌同一批定义，不要依赖二者始终共享同一个 Resource 实例。

四、数据来源与导入流程
唯一的舰桥策划数据源：tools/data_source/bridge_data.xlsx。
- Chips 工作表：每行对应一种芯片。
- Crew 工作表：每行对应一名机组。
- effects 列直接使用 JSON 数组表示多个修正，不存在独立的 Effects 工作表。
- 详情参考 tools/data_source/bridge_data_README.txt。

在项目根目录先执行：
  python tools/import/import_bridge.py tools/data_source/bridge_data.xlsx tools/cache/bridge.json
然后在 Godot 编辑器「项目 → 工具」菜单执行：
  前进四：验证舰桥数据
  前进四：导入舰桥数据

Godot 插件 addons/advance_four_data_importer/bridge_importer.gd
负责读取校验后的 bridge.json，生成 chips/、crew/ 和 bridge_database.tres。
更新数据时，需要一并核对 Excel、JSON 缓存和生成的 .tres。

五、与 Core 舰桥容量的关系
机组槽位与芯片槽位不是 BridgeDatabase 属性。
crew_slots、chip_slots 定义于 tools/data_source/module_data.xlsx 的 Core 工作表。
导入后存储在 CoreModuleDefinition，属于飞船核心模块的数据。
不要在这里增设 BridgeConfig.tres 或固定岗位定义。

六、当前开发边界
当前 V1.0 已有配置数据、解析与 Resource 导入。
尚未实现完整舰桥管理场景、Run 内机组与芯片装配操作及战斗属性结算。
本目录内的修正属性目前属于数据声明，不代表已经在战斗中生效。

七、维护注意
- 不要将这里的 .tres 当成策划唯一来源直接维护；重新导入可能覆盖手工修改。
- 新增、删除、重命名芯片或机组时，检查数据库条目与旧 .tres 文件；当前导入器按新数据保存资源，不保证自动清理所有不再引用的旧文件。
- 资源图片路径在源 Excel 配置，填写时应使用真实存在的 res://data/assets/ 下 PNG。
- 数据源规则、字段限制和常见填写错误请参见 tools/data_source/bridge_data_README.txt。

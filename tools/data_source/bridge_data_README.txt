《前进四》bridge_data.xlsx 使用说明（V1.0）
更新：2026-10

一、定位和工作表
bridge_data.xlsx 用来配置芯片与机组人员，包含：
- Chips：芯片定义。
- Crew：机组定义。
两者都是开放式插槽构筑资源，不绑定舰长/工程官/驾驶员等固定岗位，允许多个同类加成同时进入构筑（实际装备、叠加和实例规则由后续游戏逻辑实现）。
没有独立 Effects、BridgeConfig Sheet。舰桥槽位在 module_data.xlsx 的 Core 表填写 crew_slots、chip_slots。

二、Chips 列
chip_id       唯一 ID；以小写英文字母开头，只能使用小写字母、数字、下划线；不可与 crew_id 重复。
display_name  显示名称，必填。
rarity        COMMON、UNCOMMON、RARE、EPIC、LEGENDARY。
description   描述，可留空。
icon_path     图片路径，可留空；非空时必须是 res://data/assets/ 下的 .png。
effects       JSON 数组，可包含多条效果；留空等价于 []。

三、Crew 列
crew_id       唯一 ID，与 chip_id 相同的命名规则。
display_name  显示姓名，必填。
race          种族，例如 HUMAN、MACHINE、CRYSTAL；当前只检查标识格式，不设固定种族名单。
rarity        品质，同 Chips。
description   描述，可留空。
portrait_path 人物图片路径，可留空；非空时必须是 res://data/assets/ 下的 .png。
effects       JSON 数组，可包含多条效果；留空等价于 []。

四、effects 单元格格式
一个单元格填写一整个 JSON 数组，例如武器伤害 +15%：
[{"stat":"weapon_damage","operation":"PERCENT_ADD","value":0.15,"target_filter":"ALL"}]

同时提高武器伤害 +15% 和射程 +10%：
[{"stat":"weapon_damage","operation":"PERCENT_ADD","value":0.15,"target_filter":"ALL"},{"stat":"weapon_range","operation":"PERCENT_ADD","value":0.10,"target_filter":"ALL"}]

每条效果只有四个字段：
- stat：属性类型。
- operation：运算方式。
- value：有限数值。
- target_filter：作用对象过滤，可填 ALL 或留空。

不可再写 effect_id、owner_id、condition_id；导入器会将这些旧字段判为错误。
使用英文双引号、英文冒号与逗号；整个单元格必须为合法 JSON 数组，不能使用 Python 风格的单引号。
不含效果的行可填 [] 或留空。

五、stat 可选值
weapon_damage        武器伤害
weapon_range         武器射程
weapon_fire_interval 武器射击间隔（间隔越大，射速越慢）
thrust               推力
turn_speed           转向速度
energy_output        能源输出
protection           防护
repair_cost          维修消耗

六、operation 可选值
FLAT          固定增减。
PERCENT_ADD   百分比增减：0.15 表示 +15%，-0.10 表示 -10%。
MULTIPLIER    乘算系数：1.20 表示乘以 1.20；该值必须大于 0。
value 必须是有限数值，且绝对值不能超过 100000。

七、target_filter 可选值
空字符串、ALL、WEAPON、CANNON、PROPULSION、ENERGY、DEFENSE。
目前只是被导入和校验；精确作用范围与优先级需由未来的战斗属性结算系统落实。

八、编辑与导入步骤
1. 编辑 tools/data_source/bridge_data.xlsx 的 Chips 或 Crew 表，保持原有列名。
2. 在项目根目录执行：
   python tools/import/import_bridge.py tools/data_source/bridge_data.xlsx tools/cache/bridge.json
   Windows 可使用 py -3 替代 python。
3. 确认无 ERROR；Godot 编辑器的「项目 → 工具」菜单可运行：
   - 前进四：验证舰桥数据
   - 前进四：导入舰桥数据
4. 导入后检查 data/bridge/chips/*.tres、data/bridge/crew/*.tres、data/bridge/bridge_database.tres。
5. 提交时同步提交 Excel、tools/cache/bridge.json 和生成资源；完整验收可用：
   python tools/verify_project.py --godot <Godot可执行文件路径>

九、常见问题
- effects 解析失败：检查 JSON 引号、方括号、花括号、逗号和数字写法。
- ID 重复：chip_id 与 crew_id 之间也不可重复。
- stat / operation 不支持：使用本说明第五、六节中的英文值。
- 贴图导入失败：检查 res://data/assets/ PNG 路径是否真实存在。
- Excel 报文件损坏：用标准电子表格工具重新另存为 .xlsx 后验证。
- Excel 修改未生效：需要重新生成缓存并通过 Godot 导入资源；仅修改 Excel 不会改变已生成的 .tres。

当前功能边界：V1.0 提供策划数据、解析校验、Resource 导入。尚未实现舰桥管理界面、Run 中的装配操作和战斗效果结算。
详细的其它数据源流程见同目录 README.txt。

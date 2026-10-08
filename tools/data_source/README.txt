《前进四》策划数据源目录说明
更新：2026-10｜Godot 4.6.1

一、目录职责

本目录存放策划可编辑的 Excel 源表。各表是相应系统的数据源，修改后须重新校验并生成 JSON 缓存及 Godot Resource；不要只修改 tools/cache/ 或 .tres。

目前的数据文件：
- module_data.xlsx：飞船模块数值、尺寸、贴图、武器炮塔配置及 Core 舰桥容量。
- battle_data.xlsx：战斗关卡与敌人波次配置。
- bridge_data.xlsx：芯片（Chips）与机组人员（Crew）定义、能量结晶购买价格（price）及各自内嵌的 effects 数组。
- bridge_data_README.txt：舰桥表字段、效果写法及排错说明。
- README.txt：本文件，介绍目录职责和通用工作流。

二、Excel 工作表分工

module_data.xlsx：
- Energy、Propulsion、Weapon、Defense、Function、Core 六个 Sheet。
- Core 的 crew_slots / chip_slots 决定舰桥可容纳的机组与芯片槽位数，不能在 bridge_data.xlsx 中重复定义。
- 模块数据导入后生成 tools/cache/modules.json，并写入 data/modules/ 对应 .tres 与 module_database.tres。

battle_data.xlsx：
- Battles：战斗关卡、类型、难度、奖励和相关参数。
- Waves：关联关卡 ID 的敌人配置与波次。
- 通过 tools/import/import_battles.py 校验并生成 tools/cache/battles.json；Godot 插件将关卡数据导入 data/battles/。

bridge_data.xlsx：
- Chips、Crew 两个 Sheet，无独立 Effects、BridgeConfig Sheet。
- 每条芯片或机组的 effects 单元格直接填写 JSON 数组；每项仅有 stat、operation、value、target_filter 四个字段。
- 不再使用 effect_id、owner_id、condition_id；效果当前只是数据定义，尚未接入战斗属性结算。
- 详细的可填值及示例，请阅读同目录 bridge_data_README.txt。
- 校验生成 tools/cache/bridge.json；Godot 插件导入 data/bridge/chips/、data/bridge/crew/ 和 bridge_database.tres。

三、通用导入流程（从项目根目录执行）

1. 在 Excel 中编辑数据，保存为标准 .xlsx，确认相关工作表表头未被修改。
2. 用 Python 3 解析并校验本次改动的数据源，刷新对应 JSON 缓存：
   模块：
   python tools/import/import_excel.py tools/data_source/module_data.xlsx tools/cache/modules.json

   战斗关卡：
   python tools/import/import_battles.py tools/data_source/battle_data.xlsx tools/cache/battles.json

   舰桥：
   python tools/import/import_bridge.py tools/data_source/bridge_data.xlsx tools/cache/bridge.json

   Windows 可用 py -3 代替 python。
3. 若解析输出 ERROR 或非零退出码，先修复 Excel 再继续。
4. 打开 Godot 编辑器，在「项目 / Project → 工具 / Tools」中执行对应菜单：
   - 前进四：验证模块数据 / 导入模块数据
   - 前进四：验证战斗关卡 Excel / 导入战斗关卡 Excel
   - 前进四：验证舰桥数据 / 导入舰桥数据
5. 核对生成的 .tres、数据库文件和资源路径，必要时等待 Godot 文件系统刷新。
6. 提交 Excel 时一并提交对应 JSON 缓存和有变化的 .tres。运行完整项目验证：
   python tools/verify_project.py --godot <Godot可执行文件路径>
   该脚本还会运行 Python 单元测试、Godot Headless 导入及船体/战斗/Run 回归；应使用 Godot 4.6.1。

四、module_data.xlsx 尺寸、炮塔美术填写

- 六个模块 Sheet 统一使用「高X宽」，例如 2x1 表示高 2 格、宽 1 格；1x1 表示一格。
- Weapon 的「炮塔高X宽」独立于武器底座：长炮管可填 2x1，底座仍可填 1x1。
- 「炮塔轴点」「炮口」填写 X,Y，如 0.5,0.25 和 0.5,0.98。
- 位置以朝上后的完整图片（包含透明留白）为准：左下角 (0,0)，右上角 (1,1)；X 向右，Y 向上。
- 如 128×256 图片，从左上角数轴点像素 (64,192)，填写 64/128,1-192/256，即 0.5,0.25。
- 炮口像素点 (64,5.12) 对应 0.5,0.98；实际值根据图片素材调整。
- 新素材默认朝上；「炮塔素材转角（度）」可留空或填 0，现有朝右机炮填 -90。
- 尺寸支持 x、X、×，必须为正整数；轴点坐标需为 0～1 的有限数字，支持英文或中文逗号。
- 更改武器贴图后，可运行 tools/generate_weapon_icon.gd 重建武器图标，再让 Godot 导入图片。

五、排错与维护原则

- 修改 Excel 后看到数值没有变化：确认 Python 缓存和 Godot .tres 都已重新生成；仅保存 Excel 不会自动更新运行资源。
- Excel 提示工作簿损坏：检查 .xlsx 是否由规范工具保存，重新另存后再次运行解析器。
- 导入失败：先看 Python 输出中的工作表、行号和字段；舰桥 effects 格式见 bridge_data_README.txt。
- 避免手改 tools/cache/*.json 和自动生成的 .tres，防止与 Excel 不一致。
- 本目录的 README 只维护数据表规则，不重复记录星图、经济、Run 流程等其他系统历史说明；以当前脚本和 Resource 为准。

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


V1.3 价格规则：Chips 和 Crew 两个 Sheet 均需添加 price 正整数列。芯片商店售价与酒馆招募价格直接读取 BridgeDefinition.price，不得在商店/酒馆资源里重复设置。

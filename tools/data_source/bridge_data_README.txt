《前进四》舰桥 Excel 数据表使用说明（V1.0）

一、文件与职责
- 本文档说明同目录的 bridge_data.xlsx，供策划编辑芯片（Chips）与机组人员（Crew）。
- bridge_data.xlsx 仅包含 Chips、Crew 两张工作表；没有单独的 Effects 或 BridgeConfig 表。
- 芯片与机组使用开放插槽，不与舰长、驾驶员、工程官等岗位绑定，可重复堆叠同类属性（具体装备实例限制在后续玩法阶段实现）。
- 舰桥容量来自 module_data.xlsx 的 Core 表（crew_slots、chip_slots），不是 bridge_data.xlsx。

二、Chips 工作表字段
chip_id       芯片唯一 ID，英文小写字母开头，只允许 a-z、0-9、下划线；不可与 crew_id 重复。
display_name  玩家看到的名称；必填。
rarity        品质：COMMON / UNCOMMON / RARE / EPIC / LEGENDARY。
description   芯片文字描述；可以留空。
icon_path     图标资源路径；可以留空。填写时使用 res://data/assets/ 下的 .png 文件。
effects       JSON 数组；每条效果直接属于当前芯片，格式见第五节。

三、Crew 工作表字段
crew_id       人员唯一 ID；命名规范与 chip_id 相同且不可重复。
display_name  人员名字；必填。
race          种族标识，例如 HUMAN、MACHINE、CRYSTAL（导入器目前只检查命名格式，不限制种族名单）。
rarity        品质取值与 Chips 一致。
description   人物特性说明；可以留空。
portrait_path 人物立绘路径；可留空。填写时使用 res://data/assets/ 下的 .png 文件。
effects       JSON 数组；效果直接属于当前人员。

四、effects 的四个字段
stat          被修正的属性标识。
operation     运算方式。
value         有限数字。
target_filter 目标筛选，可填 ALL 或留空，也支持下述类型。

当前可填 stat：
  weapon_damage          武器伤害
  weapon_range           武器射程
  weapon_fire_interval   武器射击间隔（数值增加意味着间隔变长、射速下降）
  thrust                 推力
  turn_speed             转向速度
  energy_output          能量输出
  protection             防护
  repair_cost            维修消耗

operation：
  FLAT          固定增减数值
  PERCENT_ADD   百分比加成，例如 0.15 表示 +15%，-0.10 表示 -10%
  MULTIPLIER    乘算系数，例如 1.20 表示乘以 1.20；必须大于 0

target_filter：
  ALL、WEAPON、CANNON、PROPULSION、ENERGY、DEFENSE 或留空。
  留空及 ALL 具体应用范围会由后续属性结算系统确定；当前阶段只负责解析验证。

五、Excel 单元格填写示例
1. 一条效果（武器伤害 +15%）：
[{"stat":"weapon_damage","operation":"PERCENT_ADD","value":0.15,"target_filter":"ALL"}]

2. 两条效果（武器伤害 +15%、射程 +10%），同一个 effects 单元格：
[{"stat":"weapon_damage","operation":"PERCENT_ADD","value":0.15,"target_filter":"ALL"},{"stat":"weapon_range","operation":"PERCENT_ADD","value":0.10,"target_filter":"ALL"}]

3. 没有效果时填写 []，也可留空。

注意：
- 使用英文双引号 "、冒号 :、逗号 ,；整个单元格必须是合法 JSON 数组。
- 不需要填写 effect_id、owner_id；V1.0 也不支持 condition_id。
- 一个 Excel 行表示一枚芯片定义或一个机组定义；每行的 effects 数组可以有多条效果。
- 每条效果只写 stat、operation、value、target_filter；不要在单元格内嵌套额外的人员或芯片信息。
- 这些效果目前只是数据配置，尚未接入实际战斗属性计算。

六、从 Excel 到 Godot 的导入流程
1. 备份并修改 tools/data_source/bridge_data.xlsx。
2. 在项目根目录运行验证/生成缓存：
   python tools/import/import_bridge.py tools/data_source/bridge_data.xlsx tools/cache/bridge.json
   Windows 也可以使用 py -3 代替 python。
3. 确认输出无 ERROR，再打开 Godot 编辑器，在 Project -> Tools 菜单中选择：
   “前进四：验证舰桥数据” 或 “前进四：导入舰桥数据”。
4. 导入成功后由插件生成 data/bridge/chips/*.tres、data/bridge/crew/*.tres 和 data/bridge/bridge_database.tres。
5. 提交 Excel 时同时提交 tools/cache/bridge.json 及生成的正式 Resource，并运行自动检查：
   python tools/verify_project.py --godot <Godot 可执行文件路径>

七、常见错误
- Excel 报文件损坏：优先用 Microsoft Excel 或 LibreOffice 重新另存为标准 .xlsx，再检查两张工作表及字段。
- JSON 无法解析：检查单元格英文引号、逗号、括号，以及是否错用了单引号。
- ID 重复：chip_id 与 crew_id 在整个文件中必须唯一。
- 不支持的 stat / operation：按第四节选择，不要直接写中文字段名。
- 数值无效：value 必须为有限数字，MULTIPLIER 必须大于 0。
- 贴图无法加载：检查 res://data/assets/ 路径下的 PNG 是否真实存在。

相关源文件：
- tools/import/import_bridge.py：Excel 解析与校验
- addons/advance_four_data_importer/bridge_importer.gd：Godot Resource 导入
- data/definitions/bridge/：芯片、机组与效果的数据类型
- tools/data_source/module_data.xlsx：Core 模块及舰桥容量

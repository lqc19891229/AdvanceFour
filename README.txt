《前进四 / ADVANCE FOUR》Godot 飞船编辑器 Prototype v0.8

本版本重点：
1. 初步整理项目目录结构。
2. Excel 作为模块唯一源数据。
3. 一键验证/导入 Excel。
4. 自动生成六类模块 .tres。
5. 自动生成 ModuleDatabase.tres。
6. 增加 DataManager 作为运行时数据入口。

==================================================
一、模块数据工作流
==================================================

唯一源数据：
res://tools/data_import/source/game_data.xlsx

数据流：
Excel
→ tools/data_import/import_excel.py
→ tools/data_import/cache/modules.json
→ Godot EditorPlugin
→ data/generated/modules/*.tres
→ data/generated/module_database.tres
→ 游戏系统读取

原则：
不要手工编辑 data/generated/ 中的文件。
需要修改模块参数时，只修改 game_data.xlsx，然后重新导入。

==================================================
二、第一次使用
==================================================

1. 使用 Godot 4.x 打开 project.godot。
2. 插件已配置为启用；如未启用：
   项目 → 项目设置 → 插件 → Advance Four Data Importer → 启用。
3. 确保电脑安装 Python 3，且以下任一命令可使用：
   python
   python3
   py
4. 修改 res://tools/data_import/source/game_data.xlsx。
5. 在 Godot 顶部菜单选择：
   项目 → 工具 → 前进四：验证模块数据
6. 验证通过后选择：
   项目 → 工具 → 前进四：导入模块数据
7. 插件自动生成 .tres 与 ModuleDatabase.tres。

说明：
Python 导入脚本只使用 Python 标准库，不依赖 openpyxl。

==================================================
三、Excel Modules 表字段
==================================================

基础字段：
id
display_name
module_type
description
width
height
mass
energy_cost

类型专属字段：
ENERGY      → energy_output
PROPULSION  → thrust
WEAPON      → firepower
DEFENSE     → protection
FUNCTION    → 暂无
CORE        → 暂无

合法 module_type：
ENERGY
PROPULSION
WEAPON
DEFENSE
FUNCTION
CORE

==================================================
四、当前目录职责
==================================================

core/
项目级公共系统、Autoload。

game/ship/definitions/
模块定义 Resource 类。

game/ship/data/
ShipData、ModuleInstance、ModuleDatabase 等数据结构。

game/ship/editor/
飞船编辑器场景与逻辑。

tools/data_import/source/
策划源数据。Excel 放这里。

data/generated/
自动生成的运行时 Resource。禁止手改。

tools/data_import/cache/
Excel 转换后的中间 JSON。

tools/data_import/
Excel 解析和数据校验脚本。

addons/advance_four_data_importer/
Godot EditorPlugin，一键执行验证和导入。

==================================================
五、当前模块规则
==================================================

模块类型：
1. 能量模块：energy_output
2. 动力模块：thrust
3. 武器模块：firepower
4. 防护模块：protection
5. 功能模块：暂无额外参数
6. 核心模块：暂无额外参数

共同基础参数：
id
display_name
module_type
description
size
mass
energy_cost

编辑器规则：
- 模块不能重叠。
- 模块之间不要求连接。
- 编辑阶段允许临时能量不足。
- 出航设计必须至少有核心模块。
- 出航设计总耗能必须 <= 总供能。

V0.9：
- game_data.xlsx 的 Modules 拆分为 Energy / Propulsion / Weapon / Defense / Function / Core 六个 Sheet。
- module_type 由 Sheet 自动决定，不再由每行填写。
- 导入器支持六 Sheet 统一校验和跨 Sheet ID 重复检查。
- 主要项目目录新增 README.txt，说明内部文件、场景、脚本的功能和用法。

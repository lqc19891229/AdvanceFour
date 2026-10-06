《前进四》game/ship/definitions 目录说明

用途：定义六种模块 Resource 数据结构。

文件：
- module_definition.gd：所有模块共同基础字段：id、display_name、module_type、description、size、mass、energy_cost、hp。
- energy_module_definition.gd：能量模块，额外参数 energy_output。
- propulsion_module_definition.gd：动力模块，额外参数 thrust。
- weapon_module_definition.gd：武器模块，额外参数 firepower。
- defense_module_definition.gd：防护模块，额外参数 protection。
- function_module_definition.gd：功能模块，当前无额外参数。
- core_module_definition.gd：核心模块，当前无额外参数。

用法：
- 不在这里写具体模块数值。
- 具体模块数值来自 game_data.xlsx，并由导入工具生成 .tres。
- hp 是模块最大生命值，所有模块统一使用该基础字段；当前示例数据暂时都为 20。

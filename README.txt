《前进四》Godot 飞船编辑器 Prototype v0.7

本版本确认模块 Resource 采用“两部分”结构：

一、所有模块统一基础信息
- id
- display_name
- module_type
- description
- size
- mass
- energy_cost

二、类型专属参数
1. 能量模块：energy_output
2. 动力模块：thrust
3. 武器模块：firepower
4. 防护模块：protection
5. 功能模块：暂无额外参数
6. 核心模块：暂无额外参数

Resource 类结构：
ShipModuleDefinition
├─ EnergyModuleDefinition -> energy_output
├─ PropulsionModuleDefinition -> thrust
├─ WeaponModuleDefinition -> firepower
├─ DefenseModuleDefinition -> protection
├─ FunctionModuleDefinition -> 无额外字段
└─ CoreModuleDefinition -> 无额外字段

当前测试模块：
- 小型反应堆
- 主引擎
- 机炮
- 装甲
- 雷达
- 舰桥

编辑规则：
- 左键放置
- 右键删除
- R 旋转
- 中键拖动画布
- 模块不可重叠
- 模块之间不要求连接
- 编辑阶段允许临时能量不足
- 出航时总耗能必须 <= 总供能
- 当前原型只允许 1 个核心模块
- 核心模块被击毁作为未来沉没判定入口

v0.7 变更：
- 删除 FunctionModuleDefinition 的 special_function
- 删除 FunctionModuleDefinition 的 special_value
- radar.tres 不再包含任何类型专属字段
- 核心模块仍无额外参数
- 编辑器 Tooltip 同步更新

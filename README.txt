《前进四》飞船编辑器 Prototype v0.5

本版本重点：模块数据 Resource 化。

数据结构：
ModuleDefinition.gd
    ↓
六个具体模块 .tres
    ↓
ModuleDatabase.tres
    ↓
ShipEditor 自动读取数据库并生成模块按钮

一、六种模块
1. 能量模块：small_reactor.tres
2. 动力模块：main_engine.tres
3. 武器模块：cannon.tres
4. 防护模块：armor.tres
5. 功能模块：radar.tres
6. 核心模块：bridge.tres

二、ModuleDefinition 当前字段

基础信息：
- id
- display_name
- module_type
- description
- size
- mass
- energy_cost

类型专属参数：
- energy_output
- thrust
- firepower
- protection
- special_function
- special_value

核心模块暂时不需要额外专属字段，直接通过 module_type == CORE 判断。

三、当前规则
- 模块不能重叠。
- 模块之间不需要相邻或连通。
- 当前原型每艘船只允许一个核心模块。
- 编辑阶段允许能量暂时不足。
- 出航合法性要求：至少一个核心模块，且总耗能 <= 总供能。
- 核心模块被击毁时，未来战斗系统判定飞船沉没。

四、如何新增模块
1. 复制同类型目录下的 .tres。
2. 修改 id、名称、描述、尺寸、质量、耗能和类型专属参数。
3. 在 data/module_database.tres 的 modules 数组中加入该资源。
4. 编辑器启动后会自动生成模块按钮，无需修改 ShipEditor 的按钮代码。

操作：
- 左键：放置模块
- 右键：删除模块
- R：旋转模块
- 中键拖动：移动编辑视图

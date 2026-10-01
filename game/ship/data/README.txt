《前进四》game/ship/data 目录说明

文件：
- module_database.gd：模块数据库 Resource，保存所有 ModuleDefinition 列表；每个定义都包含基础 hp。
- module_instance.gd：飞船上已安装模块的实例数据，例如位置、旋转等。
- ship_data.gd：一艘飞船的数据模型，负责模块占用、能量、质量、推力、火力、防护等统计。
- ship_serializer.gd：ShipData 与 JSON 存档之间的序列化/反序列化工具。

用法：
- 编辑器与未来战斗系统应共享 ShipData。
- ShipSerializer 只保存稳定的 module_id、网格位置和旋转，不保存 Resource 路径或运行时 uid。
- 加载时通过 ModuleDatabase 将 module_id 还原为 ModuleDefinition。
- 不要让 UI 节点本身成为飞船真实数据来源。
- 模块 hp 属于 ModuleDefinition 静态数据，不写入 ShipData 设计存档；加载设计时通过 module_id 恢复。

飞船结构规则：
- 模块可以分开放置。
- 模块不要求相邻或连通。
- 网格不要求全部填满。
- 模块占用格不能互相重叠。

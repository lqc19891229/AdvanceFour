《前进四》game/ship/data 目录说明

文件：
- module_database.gd：模块数据库 Resource，保存所有 ModuleDefinition 列表。
- module_instance.gd：飞船上已安装模块的实例数据，例如位置、旋转等。
- ship_data.gd：一艘飞船的数据模型，负责模块占用、能量、质量、推力、火力、防护等统计。

用法：
- 编辑器与未来战斗系统应共享 ShipData。
- 不要让 UI 节点本身成为飞船真实数据来源。

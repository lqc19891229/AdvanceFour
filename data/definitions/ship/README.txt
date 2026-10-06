《前进四》data/definitions/ship 目录说明

职责：
保存飞船纯数据结构与序列化定义，不包含 Runtime Node、控制器或战斗表现。

主要内容：
- ship_data.gd：Hull Layout + Equipment 的飞船数据聚合。
- hull_cell.gd：独立 Hull Cell 数据。
- module_instance.gd：已安装 Equipment 实例数据。
- ship_serializer.gd：飞船设计与战损字段序列化。

依赖：
模块类型来自 data/definitions/module/。
具体模块内容来自 data/modules/。

对应运行逻辑位于 game/ship/runtime、controller、weapon、projectile 等目录。

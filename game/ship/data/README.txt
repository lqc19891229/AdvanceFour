《前进四》game/ship/data 目录说明

当前飞船数据模型：
ShipData
├─ Hull Layout
│  └─ ShipHullCell
└─ Equipment
   └─ ShipModuleInstance

文件：
- hull_cell.gd：单个 Hull Cell 数据；保存 grid_position、hull_type、max_hp、current_hp、mass。
- module_database.gd：Equipment Definition 数据库。
- module_instance.gd：某艘船上已安装 Equipment 的实例数据，例如位置、旋转与 uid。
- ship_data.gd：飞船结构数据；同时管理 hull_cells、Equipment 占格、合法性与整船属性统计。
- ship_serializer.gd：ShipData 与 JSON 存档之间的序列化 / 反序列化工具。

Hull Layout 规则：
- 每个 ShipHullCell 独立拥有 HP。
- 第一版 basic_hull 默认 max_hp = 20、mass = 2。
- Hull Cell 可以存在空格或分离区域；当前不要求相邻或连通。
- Hull Cell 是战斗碰撞与局部耐久的来源。
- Hull Cell 上存在 Equipment 时，不能直接拆除该 Hull Cell。

Equipment 规则：
- Equipment 必须完整安装在已有 Hull Cell 上。
- Equipment 之间不能占用同一个 Hull Cell。
- Equipment 本身不再拥有运行时 HP。
- Equipment 的运行时效率由它覆盖的 Hull Cell 健康度决定。
- 多格 Equipment 的 efficiency = 所覆盖 Hull Cell health ratio 的平均值。
- 核心 Equipment 仍限制每艘飞船最多一个。

属性统计：
- Hull HP：由 ShipHullCell 独立保存，不合并为单一可受击血条。
- 总质量 = Hull mass + Equipment mass。
- Power / Thrust / Damage / Protection 等基础数值继续来自 Equipment Definition。
- 战斗运行时会结合 Hull damage 计算 Equipment 的实际有效输出。

存档：
- 当前 ShipSerializer FORMAT_VERSION = 2。
- v2 同时保存 hull_cells 与 modules。
- hull_cells 保存位置、hull_type、max_hp、current_hp、mass。
- modules 保存稳定的 module_id、位置和 rotation，不保存 Resource 路径或运行时 uid。
- 旧 v1 存档仍可读取：加载时会按旧模块占格自动补齐 basic_hull，再恢复 Equipment。

兼容说明：
- 当前 Excel / ModuleDefinition 仍暂时保留 hp 字段以兼容既有数据链。
- ModuleDefinition.hp 已不参与当前战斗耐久计算；实际战斗 HP 只来自 Hull Layout。

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
- module_instance.gd：已安装 Equipment 的实例数据，例如位置、旋转与 uid。
- ship_data.gd：管理 hull_cells、Equipment 占格、区域 HP、合法性与功能统计。
- ship_serializer.gd：ShipData 与 JSON 存档之间的序列化 / 反序列化工具。

Hull Layout：
- 每个 ShipHullCell 独立保存 max_hp / current_hp。
- 第一版 basic_hull 默认 max_hp = 20、mass = 2。
- Hull Cell 可以存在空格或分离区域；当前不要求相邻或连通。
- Hull Cell 是战斗碰撞与局部战损状态的基础。
- Hull Cell 上存在 Equipment 时，不能直接拆除该 Hull Cell。
- ShipHullCell.mass 目前仅作为预留结构数据，不参与移动。

Equipment：
- Equipment 必须完整安装在已有 Hull Cell 上。
- Equipment 之间不能占用同一个 Hull Cell。
- Energy / Propulsion / Weapon / Function / Core 没有 hp，也没有 mass。
- DefenseModuleDefinition 单独拥有 hp，并继续拥有 protection。
- Equipment 的运行时效率由覆盖 Hull Cell 的健康度决定。
- 多格 Equipment 的 efficiency = 覆盖 Hull Cell health ratio 的平均值。
- Core Equipment 当前仍限制每艘飞船最多一个。

区域 HP：
- 区域最大 HP = ShipHullCell.max_hp + 覆盖该格的 Defense hp bonus。
- 单格 Defense：完整 Defense.hp 加到所在 Hull Cell。
- 多格 Defense：Defense.hp / 覆盖格数，平均添加到每个区域。
- 区域当前 HP = 区域最大 HP × ShipHullCell health ratio。
- 因此区域只有一套 current_hp 状态来源，Defense 不另外维护第二条运行时血条。

属性统计：
- Power / Thrust / Damage / Protection 等基础功能数值来自 Equipment Definition。
- 当前移动不计算 Hull 或 Equipment 质量。
- 设计移动能力只取 Propulsion 提供的 thrust。

存档：
- ShipSerializer FORMAT_VERSION = 2。
- v2 同时保存 hull_cells 与 modules。
- hull_cells 保存位置、hull_type、max_hp、current_hp、mass。
- modules 保存 module_id、位置和 rotation，不保存 Resource 路径或运行时 uid。
- 旧 v1 存档仍可读取：加载时按旧模块占格自动补齐 basic_hull，再恢复 Equipment。

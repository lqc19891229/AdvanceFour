《前进四》game/ship 目录说明

用途：
所有“飞船”相关的核心代码。

子目录：
- art/：Equipment 贴图、武器底座 / 炮塔资源与统一加载规则。
- appearance/：战斗专用 Appearance Layer，根据 Hull Layout 生成最终舰体外观并决定哪些 Equipment 外露。
- definitions/：Equipment Definition Resource 类。
- data/：ShipHullCell、ShipData、ShipModuleInstance、ModuleDatabase、ShipSerializer。
- editor/：Hull Layout + Equipment 编辑器。
- runtime/：Hull / Equipment 在战斗世界中的运行实体。
- controller/：Player / AI 控制来源。
- weapon/：Weapon Equipment 的炮塔、瞄准与开火逻辑。
- projectile/：独立弹丸运行时。
- damage/：通用伤害组件；当前飞船主耐久已迁移到 ShipHullCell。
- dev/：飞船系统开发 / 回归测试。

当前飞船结构：

ShipData
├─ Hull Layout
│  └─ ShipHullCell
│     ├─ grid_position
│     ├─ hull_type
│     ├─ max_hp / current_hp
│     └─ mass
│
└─ Equipment
   └─ ShipModuleInstance
      ├─ ModuleDefinition
      ├─ grid_position
      └─ rotation_quarters

职责：
- Hull Layout 决定飞船实际结构、可命中区域、局部 HP 与 Equipment 可安装区域。
- Equipment 决定 Power、Damage、Thrust、Defense 与其他功能；除 Defense.hp 外不再提供独立耐久。
- Appearance 只负责战斗外观，不进入数据与存档。
- Equipment efficiency 由覆盖 Hull Cell 的健康度决定。

当前 Hull 规则：
- 第一版 basic_hull：max_hp = 20、mass = 2。
- 每个 Hull Cell 独立承伤。
- Hull Cell 可以分离，不要求相邻或连通。
- Hull HP = 0 后该格碰撞失效，可被弹丸穿透。
- 后续计划在 Hull 层扩展轻型 / 重型 / 装甲 / 特殊船体类型。

当前 Equipment 规则：
- Equipment 必须完整安装在 Hull Layout 上。
- Equipment 之间不能重叠。
- 多格 Equipment efficiency = 覆盖 Hull Cell health ratio 的平均值。
- Energy 输出、Propulsion 推力、Defense protection、Weapon 性能会随 efficiency 下降。
- Core Equipment 覆盖 Hull 全毁时整船沉没。

武器：
- Weapon base 由 ShipModuleRuntime 绘制。
- turret 由 WeaponRuntime 绘制并独立旋转。
- WeaponRuntime 自动寻找射程内最近的存活 Hull Cell。
- Projectile 使用 swept ray 命中 HullCellRuntime。
- overkill 会从被击穿的 Hull Cell 继续向后传播。
- 已发射 Projectile 不依赖发射者继续存活。

移动：
- RuntimeShip 仍以 Core Equipment 几何中心作为局部原点。
- 当前速度、加速度与减速度只取决于有效 Propulsion thrust，不读取 Hull / Equipment 质量。
- Propulsion 所在 Hull 受损会降低推力，因此同步降低机动性能。

供电：
- Power Output 与 Power Cost 继续来自 Equipment Definition。
- Energy Equipment 的有效输出按 Hull efficiency 缩放。
- 当前供电优先级：Core > Energy > Propulsion > Defense > Function > Weapon。
- 未供电 Equipment 不提供需要供电的功能。

战斗外观：
- ShipAppearanceRenderer 根据 Hull 邻接关系生成连续舰体 shell。
- Core / Weapon / Propulsion 外露。
- Energy / Defense / Function 在战斗中隐藏，被 shell 包覆。
- 编辑器仍完整显示 Hull + Equipment，不使用 Appearance shell。

存档：
- ShipSerializer 当前格式为 v2，同时保存 Hull Layout 与 Equipment。
- 旧 v1 模块式存档加载时会按原模块占格自动生成 basic_hull。

验证：
- tools/verify_project.py 会运行 Ship / Combat 回归。
- 回归覆盖 Hull 独立 HP、Equipment efficiency、武器 / 动力战损、核心沉没、碰撞过滤、编辑器与存档流程。

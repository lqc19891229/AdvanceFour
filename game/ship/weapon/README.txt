《前进四》game/ship/weapon 目录说明

用途：
- 存放飞船武器进入实际游戏世界后的运行时逻辑。
- WeaponRuntime 是 ShipData 中武器模块的运行时执行对象。
- 当前版本实现可旋转炮塔、自动选敌、自动瞄准和自动触发 fired；Projectile 由 RuntimeShip 根据 fired 事件生成。

当前文件：
- weapon_runtime.gd：单个武器模块的运行时炮塔节点。
- weapon_runtime.tscn：WeaponRuntime 场景。

运行时关系：
ShipData
  ↓
ShipModuleInstance（WeaponModuleDefinition）
  ↓
WeaponRuntime
  ↓
自动搜索目标 / 炮塔转向 / 自动开火
  ↓
fired 信号

目标规则：
- 每个 WeaponRuntime 独立选择目标。
- 默认目标组为 enemy_targets。
- RuntimeShip.weapon_target_group 可以在 setup 前配置，因此玩家飞船、敌方飞船以后可以使用不同敌对目标组。
- 当前目标无效、离开攻击范围或退出场景后，WeaponRuntime 会重新搜索。
- 搜索规则为：攻击范围内距离该炮塔最近的目标。
- attack_range 同时决定弹丸最大飞行距离；RuntimeShip 在开火时将该值传给 ProjectileRuntime，每颗弹丸独立记录，不跟随发射者后续移动。
- 如果目标实现 get_aim_point()，WeaponRuntime 会瞄准其返回的存活模块位置，而不是固定瞄准 RuntimeShip 原点。
- RuntimeShip 当前返回距离该炮塔最近的未 destroyed 模块中心。
- 目标飞船没有任何存活模块时，会视为无效目标，并在重新搜索阶段直接跳过，避免反复重新选中已完全摧毁目标。
- 同一艘飞船上的不同武器允许选择不同目标。

炮塔瞄准：
- module.rotation_quarters 只作为炮塔进入战斗时的初始朝向。
- 战斗中炮塔可以独立于 RuntimeShip 持续旋转。
- desired direction = 目标世界坐标 - 炮塔世界坐标。
- 炮塔使用 turn_speed_degrees 逐步转向目标，不瞬间锁定。
- 当炮口方向与目标方向误差小于 fire_angle_tolerance_degrees 时，视为瞄准完成。

自动开火：
- WeaponRuntime 在物理帧更新。
- 有有效目标、已经瞄准且冷却结束时自动触发 fired。
- fire_interval 控制两次射击的间隔，单位秒；每秒射击次数 = 1 / fire_interval。
- fired 信号包含：
  - ShipModuleInstance
  - firepower
  - 世界坐标发射点
  - 世界坐标发射方向
- RuntimeShip 继续通过 weapon_fired 向上转发事件。

数据参数（当前机炮）：
- firepower = 5：每发初始伤害。
- attack_range = 500 px：选敌范围，同时限制弹丸最大飞行距离。
- fire_interval = 0.5 秒：射击间隔，相当于 2 发/秒。
- turn_speed_degrees = 180°/秒：炮塔转速。
- fire_angle_tolerance_degrees = 6°：允许开火的瞄准方向误差。
- projectile_speed = 700 px/s：弹丸速度。

六项参数均来自 game_data.xlsx 的 Weapon Sheet，经 Python → JSON → Godot 插件生成 WeaponModuleDefinition。
WeaponRuntime.setup() 从该模块定义初始化运行参数；场景不再单独配置同名默认值。
修改 Excel 后执行“前进四：验证模块数据”和“前进四：导入模块数据”，再重新运行战斗。
attack_range / fire_interval / projectile_speed 必须 > 0，炮塔转速 >= 0，瞄准容差在 0~180°；五个新增字段都必填且必须为有限数字。
max_impacts_per_step 是碰撞查询实现上限，继续保留在弹丸脚本，不作为武器策划属性。

手动发射：
- RuntimeShip.request_fire() / WeaponRuntime.fire_once() 暂时保留为调试接口。
- PlayerShipController 已不再读取 Space 开火；正式玩家控制目前只负责飞船移动。
- 正式武器行为是自动选敌、自动瞄准、自动开火。

职责边界：
- WeaponRuntime 不读取玩家输入。
- WeaponRuntime 不负责玩家移动。
- WeaponRuntime 本身不直接创建 Projectile；它只发出 fired，RuntimeShip 负责生成 ProjectileRuntime。
- WeaponRuntime 不计算命中或伤害。
- WeaponRuntime 将“结构存活”与“模块供电”分开：operational 表示武器模块是否已 destroyed，powered 表示该具体武器模块当前是否被 RuntimeShip 能源分配系统供电。
- 对应武器模块 destroyed 后，RuntimeShip 会调用 set_operational(false)，该状态不会因能源恢复而复活。
- 能源不足时不再统一关闭全部武器；RuntimeShip 按模块供电优先级逐个分配，只有未获供电的武器 set_powered(false)。
- 后续供能变化导致该模块重新获得电力时，只要 operational 仍为 true，就可以重新搜索、瞄准和开火。
- is_active() = operational and powered。
- 六项武器参数统一来自 WeaponModuleDefinition；运行时参数变化不写回共享定义或 Excel。
- ShipData.grid_position / rotation_quarters 不因炮塔运行时旋转而改变。

飞船结构原则：
- 武器模块可以与其他模块分开放置。
- 武器模块不要求与核心或其他模块相邻或连通。
- 空格不会影响炮塔坐标、选敌或瞄准。

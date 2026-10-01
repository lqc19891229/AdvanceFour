《前进四》game/ship/projectile 目录说明

用途：
- 存放飞船武器发射后进入世界空间独立飞行的 Projectile 运行时逻辑。
- ProjectileRuntime 当前负责生成后的世界空间飞行、生命周期、连续射线式命中检测、命中事件，以及把伤害交给命中对象。
- 对 ShipModuleRuntime，Projectile 会优先调用 apply_projectile_damage()；任意飞船模块如果被本次伤害摧毁且仍有 overkill，都会把剩余伤害返回给 Projectile 继续沿原弹道向内穿透。其他仅支持 apply_damage() 的对象仍按单次命中处理。
- 当前不处理正式伤害类型、爆炸或模块功能失效。

当前文件：
- projectile_runtime.gd：基础弹丸运行时节点。
- projectile_runtime.tscn：ProjectileRuntime 场景，根节点为 Area2D，并带基础 CircleShape2D。

生成流程：
WeaponRuntime
  ↓ fired
RuntimeShip
  ↓
实例化 ProjectileRuntime
  ↓
以 fired 提供的 world_position / world_direction / firepower 初始化
  ↓
作为 RuntimeShip 的同级节点加入世界

碰撞 / 命中：
- ProjectileRuntime 仍是 Area2D 世界节点，但运行时不再依赖 area_entered / body_entered 的离散触发顺序。
- 每个物理帧从当前位置到本帧终点执行 PhysicsRayQueryParameters2D / intersect_ray()，按弹道最近顺序处理碰撞，减少高速弹丸跨越装甲的 tunneling 风险。
- Projectile collision_mask = 1；当前 ShipModuleRuntime 位于 collision_layer = 1。
- 命中 ShipModuleRuntime 时调用 apply_projectile_damage(remaining_damage)。
- 如果该次命中没有摧毁模块，或模块刚好吸收全部伤害，则 Projectile 结束。
- 如果该次命中摧毁任意 ShipModuleRuntime 且返回 leftover > 0，则 Projectile 在同一弹道上继续向前查询，携带 leftover 继续命中后方模块。
- 每次实际命中都会发出：
  hit(target: Node2D, firepower: float)
  其中 firepower 表示该次碰撞前 Projectile 当前携带的伤害。
- RuntimeShip 仍会把 ProjectileRuntime.hit 转发为 projectile_hit 信号，但该转发现在只用于观察 / 调试，不再是伤害生效的必要链路。
- Projectile 保存 source_owner，并忽略 source_owner 自身及其子节点，避免基础自伤碰撞。

为什么不作为 RuntimeShip 子节点：
- Projectile 发射后应继续独立存在。
- Projectile 不应继续继承飞船后续平移或旋转。
- RuntimeShip 被移除后，已经发射的 Projectile 仍可按自身生命周期继续存在。

当前参数：
- speed = 700
- lifetime = 2.0 秒

这些参数当前属于 ProjectileRuntime Prototype 参数，尚未进入 WeaponModuleDefinition / Excel 数据真源。

当前数据：
- direction：世界空间飞行方向。
- firepower：发射时的初始伤害。
- remaining_damage：当前剩余伤害；命中 Defense 模块时先应用该模块 protection 百分比减伤，再按模块实际吸收的 HP 继续扣减。
- lifetime_remaining：剩余生命周期。
- source_owner：发射该 Projectile 的 RuntimeShip，用于基础自伤过滤。

当前行为：
- setup() 时设置世界坐标、方向、firepower、source_owner 和剩余生命周期。
- _physics_process() 中计算 direction * speed * delta 对应的本帧路径，并沿整段路径做连续射线查询。
- 生命周期结束或 remaining_damage <= 0 后 queue_free()。
- 命中 Defense 模块时，先应用 protection 百分比减伤；减伤后的伤害再进入模块 HP。只要模块被本次伤害摧毁且仍有剩余伤害，就继续向内穿透；模块未被摧毁、protection 完全抵消伤害或刚好耗尽伤害时 Projectile 结束。
- 当前用简单白色图形显示弹丸，后续可替换正式视觉。

当前范围：
- 生成。
- 世界空间直线飞行。
- 生命周期自动销毁。
- 基于物理空间 ray query 的连续弹道命中。
- hit 事件。
- 基础发射者过滤。

暂不包含：
- 正式伤害解析层、护甲 / 伤害类型公式。
- 更复杂的模块失效联动。
- 正式阵营过滤。
- 更精确的有限半径 shape cast；当前连续检测按弹丸中心线 ray 处理。
- 弹丸继承飞船速度。
- 跟踪弹。
- 独立的穿甲系数 / 穿深 / 材质抗性；当前 protection 仅作为 Defense 模块百分比减伤值，之后按模块剩余 HP 吸收伤害并让 overkill 继续传播。
- 爆炸。

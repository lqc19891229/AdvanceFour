《前进四》game/ship/projectile 目录说明

用途：
- 存放飞船武器发射后进入世界空间独立飞行的 Projectile 运行时逻辑。
- ProjectileRuntime 当前负责生成后的世界空间飞行、生命周期、基础碰撞、命中事件，以及把 firepower 直接交给支持 apply_damage() 的命中对象。
- 当前不处理护甲公式、穿透、爆炸或模块功能失效。

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
- ProjectileRuntime 使用 Area2D。
- Projectile collision_layer = 2，collision_mask = 1。
- 当前测试目标位于 collision_layer = 1。
- Projectile 同时监听 area_entered 与 body_entered。
- 首次有效碰撞时，如果目标提供 apply_damage()，ProjectileRuntime 先调用 apply_damage(firepower)。
- 随后发出：
  hit(target: Node2D, firepower: float)
- 命中后立即 queue_free()，当前不穿透。
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
- firepower：从 WeaponRuntime fired 事件带入；命中支持 apply_damage() 的对象时，ProjectileRuntime 直接以该数值作为当前 Prototype 伤害，同时仍随 hit 信号继续传递。
- lifetime_remaining：剩余生命周期。
- source_owner：发射该 Projectile 的 RuntimeShip，用于基础自伤过滤。

当前行为：
- setup() 时设置世界坐标、方向、firepower、source_owner 和剩余生命周期。
- _physics_process() 中按 direction * speed * delta 移动。
- 生命周期结束后 queue_free()。
- 命中有效碰撞目标后，先尝试 apply_damage(firepower)，再发出 hit 并 queue_free()。
- 当前用简单白色图形显示弹丸，后续可替换正式视觉。

当前范围：
- 生成。
- 世界空间直线飞行。
- 生命周期自动销毁。
- Area2D 基础碰撞。
- hit 事件。
- 基础发射者过滤。

暂不包含：
- 正式伤害解析层、护甲 / 伤害类型公式。
- 更复杂的模块失效联动。
- 正式阵营过滤。
- 连续碰撞 / swept collision。
- 弹丸继承飞船速度。
- 跟踪弹。
- 穿透。
- 爆炸。

《前进四》game/ship/projectile 目录说明

用途：
- 存放飞船武器发射后进入世界空间独立飞行的 Projectile 运行时逻辑。
- ProjectileRuntime 当前只负责生成后的世界空间飞行与生命周期。
- 当前不处理碰撞、命中、伤害、穿透或爆炸。

当前文件：
- projectile_runtime.gd：基础弹丸运行时节点。
- projectile_runtime.tscn：ProjectileRuntime 场景。

生成流程：
WeaponRuntime
  ↓ fired
RuntimeShip
  ↓
实例化 ProjectileRuntime
  ↓
以 fired 提供的 world_position / world_direction 初始化
  ↓
作为 RuntimeShip 的同级节点加入世界

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
- firepower：从 WeaponRuntime fired 事件带入，暂时只保存，供后续伤害系统使用。
- lifetime_remaining：剩余生命周期。

当前行为：
- setup() 时设置世界坐标、方向、firepower 和剩余生命周期。
- _physics_process() 中按 direction * speed * delta 移动。
- 生命周期结束后 queue_free()。
- 当前用简单白色图形显示弹丸，后续可替换正式视觉。

当前范围：
- 生成。
- 世界空间直线飞行。
- 生命周期自动销毁。

暂不包含：
- 碰撞。
- 命中检测。
- 伤害。
- 阵营过滤。
- 弹丸继承飞船速度。
- 跟踪弹。
- 穿透。
- 爆炸。

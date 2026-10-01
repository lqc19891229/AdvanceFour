《前进四》game/ship/weapon 目录说明

用途：
- 存放飞船武器进入实际游戏世界后的运行时逻辑。
- WeaponRuntime 是 ShipData 中 WeaponModuleInstance 的运行时执行对象。
- 当前版本只建立武器运行时节点、发射请求和事件，不生成弹丸，也不处理命中与伤害。

当前文件：
- weapon_runtime.gd：单个武器模块的运行时节点。
- weapon_runtime.tscn：WeaponRuntime 场景。

运行时关系：
ShipData
  ↓
ShipModuleInstance（WeaponModuleDefinition）
  ↓
WeaponRuntime
  ↓
fired 信号

当前行为：
- ShipRuntime.setup(ship_data) 时为每个武器模块创建一个 WeaponRuntime。
- WeaponRuntime 的局部位置使用武器模块几何中心，并减去 RuntimeShip 的核心原点偏移。
- WeaponRuntime 的局部旋转使用 module.rotation_quarters。
- fire_once() 触发 fired 信号。
- fired 信号包含：
  - 对应 WeaponRuntime
  - ShipModuleInstance
  - firepower
  - 世界坐标发射点
  - 世界坐标发射方向

发射方向：
- 模块 rotation_quarters = 0 时，武器本地前方为 Vector2.UP。
- 每旋转 1 quarter，发射方向旋转 90°。
- RuntimeShip 自身 rotation 会继续叠加到最终世界方向。

当前输入：
- PlayerShipController 使用 Space 作为测试开火键。
- 当前为“按下一次触发一次齐射”，尚未加入自动连射、射速或冷却参数。
- 一次 request_fire() 会让当前 RuntimeShip 中所有 WeaponRuntime 各触发一次 fired。

职责边界：
- WeaponRuntime 不读取玩家输入。
- WeaponRuntime 不创建 Projectile。
- WeaponRuntime 不计算命中、伤害或模块失效。
- firepower 继续来自 WeaponModuleDefinition，不在运行时复制另一套武器静态数据。
- ShipData.grid_position 不因武器运行时创建而改变。

飞船结构原则：
- 武器模块可以与其他模块分开放置。
- 武器模块不要求与核心或其他模块相邻或连通。
- 空格不会影响武器运行时节点的坐标换算。

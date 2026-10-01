《前进四》ShipModuleRuntime 说明

定位：
- ShipModuleRuntime 是 ShipData 中单个 ShipModuleInstance 进入战斗后的运行时受击对象。
- 它不复制模块静态数据，只引用已有 ShipModuleInstance。
- 每个已安装模块都拥有自己的碰撞区域与 DamageReceiver。

为什么使用“每模块独立碰撞体”：
- 飞船模块允许分开放置，不要求相邻或连通。
- 不能假设飞船是连续舰体，也不能用整块包围盒代表真实可命中区域。
- 每个模块独立 Area2D 可以直接把 Projectile 命中对象解析为对应 ShipModuleInstance。
- 空格天然不会产生碰撞体，因此弹丸可以从模块之间的空隙穿过。

当前运行链：
ProjectileRuntime
  ↓ collision
ShipModuleRuntime
  ↓ apply_damage(firepower)
DamageReceiver
  ↓
module_damaged / module_destroyed

当前 Prototype HP：
- 每个模块暂时使用 RuntimeShip.prototype_module_hp。
- 当前默认值为 10。
- 该数值尚未进入 ModuleDefinition / Excel 数据真源。
- 后续正式模块耐久字段确定后，再把 HP 从 Prototype 参数迁移到静态模块数据。

当前范围：
- 每模块独立碰撞体。
- 每模块独立 HP。
- Projectile 命中时可直接知道具体 ShipModuleInstance。
- 模块 HP 归零后禁用该模块碰撞体，并发出 destroyed。
- RuntimeShip 会转发 module_damaged / module_destroyed。

暂不包含：
- 模块摧毁后从 ShipData 删除。
- 动力模块失效后降低推力。
- 武器模块失效后停止射击。
- 能量模块失效后的供能变化。
- 防护模块失效。
- 核心模块击毁后整船沉没。
- 模块爆炸、残骸或视觉破坏效果。

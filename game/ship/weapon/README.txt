《前进四》game/ship/weapon 目录说明

职责：
保存 Weapon Equipment 的 Runtime 炮塔、自动选敌、瞄准和开火逻辑。

主要文件：
- weapon_runtime.gd / .tscn：单个武器的 Runtime 执行对象。

数据来源：
WeaponModuleDefinition 位于 data/definitions/module/。
具体武器数据由 tools/data_source/game_data.xlsx 生成到 data/modules/weapon/。
正式贴图位于 data/assets/modules/。

目标规则：
- 每个 WeaponRuntime 独立在 target_group 中寻找目标。
- 如果目标实现 get_aim_point()，武器使用其返回点。
- ShipRuntime.get_aim_point() 当前从仍存活的 HullCellRuntime 中选择距离炮塔最近的 Hull Cell。
- 目标无有效 Hull、离开射程或离开射界后重新选敌。
- attack_range 同时决定选敌距离和 Projectile 最大飞行距离。

射界与炮塔：
- 武器贴图与无贴图回退炮口均以向右为 0°；与舰船移动的向上前方分别定义。
- rotation_quarters：0 右、1 下、2 左、3 上；编辑器安装方向与战斗射界中心一致。
- module.rotation_quarters 是安装方向与射界中心。
- 世界射界中心 = 船体 global_rotation + 安装角度，不随当前炮塔转角漂移。
- firing_arc_degrees 限制搜索、旋转与开火。
- 有限射界在安装方向 ± 半射界内逐步转动，整个转动路径不得穿过禁止区域；360° 炮塔使用最短转向路径。
- turn_speed_degrees × efficiency 决定炮塔转速。
- fire_angle_tolerance_degrees 决定允许开火的角误差。
- 自动与手动开火共用冷却、供电及当前炮口射界检查；弹丸方向来自当前炮口世界方向。
- Weapon base 由 ShipModuleRuntime 显示，turret 由 WeaponRuntime 独立旋转。

效率与供电：
- Weapon 没有独立 HP。
- efficiency 来自其覆盖 Hull Cell health ratio 平均值。
- firepower = definition.firepower × efficiency。
- 冷却间隔 = definition.fire_interval / efficiency。
- efficiency <= 0 时结构失效。
- powered 由 ShipRuntime 能源分配决定。
- is_active() = operational && powered && efficiency > 0。
- operational 是 Runtime 生命周期开关；整船退出战斗时会被关闭，不代表“武器模块拥有独立 destroyed HP”。

开火：
WeaponRuntime fired
→ ShipRuntime
→ ProjectileRuntime

ProjectileRuntime 负责移动、连续 ray 命中和 overkill；WeaponRuntime 不负责实际伤害结算。

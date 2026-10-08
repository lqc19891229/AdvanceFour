【当前实现说明｜2026-10】
Godot 4.6.1；项目默认从星图主场景进入 fixed_test_sector 测试航线；生成式星图由 RouteMapGenerator.generate() 实现。
双资源：能量结晶用于商店，零件用于维修及空间站制造。胜利自动统一结算、失败清空 Run。
历史版本说明仅供追溯；当前执行流程以脚本及 .tres 为准。

《前进四》game/ship/weapon 目录说明

职责：
保存 Weapon Equipment 的 Runtime 炮塔、自动选敌、瞄准和开火逻辑。

主要文件：
- weapon_runtime.gd / .tscn：单个武器的 Runtime 执行对象。

数据来源：
WeaponModuleDefinition 位于 data/definitions/module/。
具体武器数据由 tools/data_source/module_data.xlsx 生成到 data/modules/weapon/。
正式贴图位于 data/assets/modules/。

目标规则：
- 每个 WeaponRuntime 独立在 target_group 中寻找目标。
- 如果目标实现 get_aim_point()，武器使用其返回点。
- ShipRuntime.get_aim_point() 当前从仍存活的 HullCellRuntime 中选择距离炮塔最近的 Hull Cell。
- 目标无有效 Hull、离开射程或离开射界后重新选敌。
- attack_range 同时决定选敌距离和 Projectile 最大飞行距离。

射界与炮塔：
- 武器贴图与无贴图回退炮口均以向上为 0°，与舰船前方一致。
- rotation_quarters：0 上、1 右、2 下、3 左；编辑器安装方向与战斗射界中心一致。
- module.rotation_quarters 是安装方向与射界中心。
- 世界射界中心 = 船体 global_rotation + 安装角度，不随当前炮塔转角漂移。
- firing_arc_degrees 限制搜索、旋转与开火。
- 有限射界在安装方向 ± 半射界内逐步转动，整个转动路径不得穿过禁止区域；360° 炮塔使用最短转向路径。
- turn_speed_degrees × efficiency 决定炮塔转速。
- fire_angle_tolerance_degrees 决定允许开火的角误差。
- 自动与手动开火共用冷却、供电及当前炮口射界检查；弹丸方向来自当前炮口世界方向。
- Weapon base 由 ShipModuleRuntime 显示，turret 由 WeaponRuntime 独立旋转。
- turret_size_cells 独立于底座 size；长炮管超出的图像不影响安装、仓储或船体受伤占格。
- turret_pivot / turret_muzzle 是朝上图片的归一化 X,Y（左下角起算，含透明区域）。绘制前统一转换到 Godot 的左上角坐标。
- 按比例缩放炮塔；图片轴点对准底座中心，真实炮口世界位置作为弹丸出生点。
- 编辑器、放置预览、战斗、损伤快照与图标共用 ModuleArtLibrary 几何计算。
- 旧机炮源图由 turret_art_rotation_degrees = -90 转为朝上显示，新素材默认 0。

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

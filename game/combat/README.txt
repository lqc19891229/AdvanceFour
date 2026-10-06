《前进四》game/combat 目录说明

用途：
负责正式关卡战斗的通用运行容器，包括玩家与敌舰生成、波次调度、胜负判定、HUD、结算与退出。
飞船运动、AI、武器、弹丸、局部战损继续复用 game/ship；combat 不复制模块静态数值。
以后普通关卡、Boss 战等都复用 battle.tscn，通过 BattleDefinition 提供不同战斗配置，不为每一关复制战斗场景。

主要文件：
- battle.gd / battle.tscn：正式战斗场景与状态机。battle.tscn 是所有关卡复用的唯一战斗容器。
- battle_definition.gd：BattleDefinition Resource，保存关卡战斗配置。
- definitions/stage_001.tres：第一份正式战斗配置。
- battle_backdrop.gd：世界坐标固定的程序化星点与淡网格。
- dev/combat_regression_test.gd：战斗流程、碰撞、关卡配置与编辑器往返回归。

BattleDefinition 当前字段：
- battle_id：稳定战斗 ID。
- display_name：HUD / 结算显示名称。
- wave_enemy_counts：每波敌舰数量。
- preparation_seconds：开战前准备时间。
- intermission_seconds：波间时间。
- spawn_interval_seconds：同波敌舰生成间隔。
- spawn_radius：围绕玩家生成敌舰的距离。
- return_scene_path：退出战斗后进入的场景。
- restore_saved_ship_on_return：返回场景时是否要求恢复已保存玩家设计。

正式关卡入口：
1. 上层系统先保存或准备玩家 ShipData。
2. 上层系统将 BattleDefinition 资源路径写入 SceneTree meta：battle_definition_path。
3. 切换到 res://game/combat/battle.tscn。
4. Battle 启动时读取该 BattleDefinition，并立即清除 meta，随后按配置运行。
5. 若没有提供 meta，battle.tscn 使用场景中绑定的默认 stage_001.tres。
6. “重新挑战”会保留当前 BattleDefinition；因此从关卡选择进入第二关后，重试仍然是第二关。

当前编辑器入口：
- 飞船编辑器仍可作为现阶段的出航入口，但它不再定义战斗规则。
- 点击“出航战斗”时只负责验证 / 保存玩家飞船，选择 stage_001.tres，然后进入正式 battle.tscn。
- AI 测试仍进入 game/ship/dev/ship_ai_test.tscn，与正式战斗分离。

状态流程：
PREPARING（出航准备）
→ FIGHTING（本波交战）
→ INTERMISSION（波间）
→ 下一波 FIGHTING
→ 最后一波清除后 RESOLVING（等待已发射弹丸结束）
→ VICTORY。
任何未结算阶段玩家核心承载 Hull 全部损毁都立即进入 DEFEAT；同一帧双方都被击毁时失败优先。
VICTORY / DEFEAT 只结算一次，并冻结 World 子树。

玩家飞船：
- 当前正式入口仍使用 user://ships/test_ship.json 作为玩家设计来源。
- F6 单独运行 battle.tscn 且没有玩家存档时，可使用调试示例设计；这是开发便利，不属于未来关卡存档方案。
- 下一阶段战损持久化时，应把“玩家设计 / 当前战损状态”提升为正式 Run / Session 数据，不继续依赖编辑器测试存档语义。

敌舰：
- 当前敌舰仍使用 Battle.build_starter_design() 的固定 Prototype 蓝图。
- BattleDefinition 已把波次与场景流程从 battle.gd 中拆出，但敌舰蓝图、敌舰组合与 Boss 定义尚未数据化。
- 下一步关卡系统扩展时，应优先把“每波生成什么敌舰”加入关卡数据，而不是在 battle.gd 中继续增加 if / match。

碰撞分组：
- 玩家 Hull 使用 collision_layer = 4，敌舰 Hull 使用 collision_layer = 8。
- 玩家 Projectile 只查询敌舰层，敌舰 Projectile 只查询玩家层；Projectile 自身 collision_layer = 0。
- 这是当前战斗场景的最小阵营隔离，尚不是正式 faction / friendly-fire 数据系统。

HUD：
- 镜头跟随玩家；世界星点与网格保持世界坐标固定。
- 显示关卡名称、飞船来源、波次、场上敌舰、Hull HP、核心效率、可用设备、可用武器、供能 / 需求、有效推力、速度与世界坐标。
- W / S 前进 / 倒车，A / D 转向；方向键同理。

当前边界：
- 同一场战斗内战损跨波次保留。
- 退出或重试时目前仍从保存的设计重新建立 RuntimeShip，因此战损尚未写回长期状态。
- 尚无资源奖励、维修、连续关卡 Run、正式敌舰蓝图、Boss 配置。

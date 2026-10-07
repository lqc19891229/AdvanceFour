《前进四》game/run 目录说明

职责：
负责一轮 Run 中跨战斗的战果展示、维修/整备入口与开发回归。

主要内容：
- battle_result/：战斗胜利后的结果页，统一显示资源收益、战利品带走/放弃、仓库容量与可点击维修的飞船战损快照。
- shop/：补给商店，使用能量结晶购买模块 / Hull 并写入 Run Inventory。
- route/：星图与路线节点选择。
- dev/run_regression_test.gd：验证战损持久化、Retry 战前恢复、跨关卡继承、奖励与维修。

状态来源：
- core/autoload/run_state.gd

当前流程：
Ship Editor
→ start_run
→ Battle
→ Victory
→ BattleResult
→ Result Screen
→ Loot / Optional Repair
→ Route Map
→ Shop / Refit
→ Route Map
→ Battle / End

边界：
- game/run 不定义具体关卡内容。
- BattleDefinition 与 BattleResult 数据结构属于 data。
- 当前 Run 状态属于 core/autoload/RunState。
- 永久设计模板仍由 ShipSerializer 写入 user://ships/test_ship.json。


v0.32.1：
- 有 next_battle_path 时显示“下一战”。
- 当前最终战没有 next_battle_path 时显示“结束 Run 并返回设计器”。
- 结束 Run 会清空 RunState，并恢复永久设计模板进入 Ship Editor。
- 同一个 battle_id 的 Victory 不能重复 commit，防止重复领取 Credits。


v0.33.0：
- 战果页只列出受损 Hull Cell，并显示损伤等级、坐标、HP、覆盖 Equipment 与单格维修费用。
- 选中 Hull 后显示对应 Equipment 当前效率，以及修复该格后的预计效率。
- 支持“维修此格”和“全部维修”两种方式。
- 单格维修只修改选中 ShipHullCell；其他 Hull 战损保持不变。
- 当前费用为 1 缺失 Hull HP = 1 Credit；Credits 不足时操作原子失败。
- Equipment 继续没有独立 HP，维修 Hull 即恢复其覆盖模块效率。


v0.34.0：
- RunState 新增 module_inventory 与 hull_stock。
- 胜利结算除 Credits 外可发放固定模块与 Hull 奖励。
- stage_001：轻型装甲×1、Hull×1；stage_002：机炮×1。
- 战果页显示完整奖励明细。
- Run Refit 中安装模块/Hull 消耗库存，拆除返还，移动/旋转免费。
- Run Refit 禁止一键清空，结构修改会立即同步 current_ship。


v0.35.0：
- 战果页新增成长奖励多选一。
- Credits 先自动结算；成长奖励候选领取 1 项后才允许进入整备 / 下一战 / 结束 Run。
- RunState 负责 pending reward choice 与单次领取约束。
- 当前 stage_001：轻型装甲×1 / 机炮×1 / Hull×2 三选一。


v0.36.0：
- 新增独立补给商店场景。
- 商店从 data/shops/basic_shop.tres 读取数据化商品与价格。
- 购买模块 / Hull 会直接进入 Run Inventory。
- Credits 不足时购买原子失败。
- 有未处理战利品时商店入口锁定。
- 只有仍有下一战的战果页显示商店，当前最终关不开放商店。


v0.37.0：
- 正式 Run 改为数据化 RunRouteDefinition。
- Prototype 航线为：第一战 → [补给商店 / 整备站] → 第二战 → 航线终点。
- 星图只允许选择当前节点连接的下一节点，已离开的分支不可返回。
- Battle 节点胜利后先进入战果页，再返回星图。
- Shop / Refit 节点完成后回星图。
- 旧线性 Run API 保留给诊断入口。


v0.43.0：
- RunState 使用能量结晶 + 零件双资源。
- 能量结晶只用于商店交易。
- 零件当前只用于 Hull 维修；1 缺失 Hull HP = 1 零件。
- 战斗可同时奖励两种资源。
- 空间站制造模块留待 v0.44。


v0.45.0：
- 战利品与胜利结算合为 battle_result_screen；删除独立 Loot Screen。
- 移除成长奖励三选一、对应配置和领取状态；模块收益统一经过战利品系统。
- 右侧 ship_damage_snapshot 显示真实 Hull 与模块布局，复用正式船体 Tile、模块底座/炮塔素材。
- 黄/红/暗红分别显示轻伤、重伤和摧毁；摧毁格保留轮廓。点击选格查看 HP、模块效率与费用。
- 维修选中格和全部维修后立即刷新快照、详情和零件余额。维修可跳过。
- 快照自动居中适配完整飞船；滚轮缩放、中键拖动、双击居中。
- 宽屏左右分栏；窄屏纵向排列，整页可滚动。
- 只有未处理战利品阻止继续；带走仍检查仓库容量，已放弃物品明确标注。

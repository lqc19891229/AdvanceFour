《前进四》game/ship/editor 目录说明

场景：
- ship_editor.tscn：飞船设计器主场景。

脚本：
- ship_editor.gd：编辑器 UI、Hull / Equipment 选择、属性显示、保存 / 加载等控制逻辑。
- ship_grid_view.gd：网格绘制、Hull 放置、Equipment 安装 / 删除 / 移动 / 旋转及贴图预览。

当前结构：
- Hull Layout：决定船体形状、可安装范围与局部基础 HP。
- Equipment：安装在 Hull 上，负责 Power / Damage / Thrust / Defense / Function 等功能。

当前操作：
- 左侧“船体｜基础船体格”：进入 Hull 放置模式。
- 左键空格（Hull 模式）：添加 basic_hull。
- 左键空格（Equipment 模式）：安装当前设备；设备必须完整落在 Hull Layout 内。
- 左键已安装 Equipment：选中设备，并在右侧显示详情。
- “移动已选模块”：移动当前 Equipment；目标位置仍需完整覆盖 Hull 且不能与其他 Equipment 重叠。
- R / “旋转模块”：旋转待安装或已安装 Equipment。
- 右键 Equipment：拆除 Equipment。
- 右键空 Hull：拆除 Hull Cell。
- 已有 Equipment 覆盖的 Hull Cell 不能直接拆除，需先拆设备。
- 中键拖动：平移编辑区。
- 保存 / 加载：使用 ShipSerializer v3，同时保存 hull_cells 与 modules；读取 v1/v2 时自动迁移旧武器安装方向。
- 出航战斗：普通设计模式下先保存设计模板并创建 Run，然后进入 stage_001。
- 敌舰 AI 测试：使用相同 Hull / Equipment 设计进入测试场景。

预览：
- Equipment 待放置 / 移动预览继续使用绿色 / 红色表示合法性。
- 绿色：目标 Hull 完整、无 Equipment 重叠、核心规则合法。
- 红色：超出 Hull、与 Equipment 重叠或违反核心规则。
- 预览同时绘制真实 Equipment 贴图；Weapon 显示 base + turret。
- 武器安装角度以贴图向上为 0°，四个方向为 0 上 / 1 右 / 2 下 / 3 左；战斗射界以同一安装方向为中心。
- 先绘制全部底座，再绘制全部炮塔；长炮管允许伸出底座，但选中、移动和安装只按底座占格。
- Hull 放置模式同样使用红 / 绿预览。

属性面板：
- 显示 Hull 格数量。
- 显示区域有效当前 HP / 最大 HP 汇总。
- Equipment 不再显示质量。
- 只有 Defense Equipment 显示“装甲 HP”；其他 Equipment 没有 hp 字段。
- 预计最高速度只由设计有效引擎推力决定，不再受 Hull 或 Equipment 质量影响。

设计规则：
- Hull Layout 当前允许空格、分离区域，不要求相邻或连通。
- Equipment 只能安装在已有 Hull Cell 上。
- Equipment 之间不能重叠。
- Core Equipment 当前仍限制每艘飞船一个。
- 编辑阶段允许临时供能不足；出航时要求总耗能不高于设计供能。
- 第一版 basic_hull 固定 max_hp = 20；其 mass 数据暂保留，但不参与移动。
- 区域最大 HP = ShipHullCell.max_hp + 覆盖 Defense.hp。


v0.32 Run 整备模式：
- 战果页选择“进入整备”后，以 RunState.current_ship 的副本打开编辑器。
- 保存 / 加载按钮在整备模式下只读写 RunState.current_ship，不覆盖永久设计模板。
- “继续下一战”保存本次改装后，使用 BattleResult.next_battle_path 进入下一场。
- 当前版本没有库存/购买成本系统，因此整备仍允许自由改装；经济约束仅应用于 Hull 全部维修。


v0.34 Run Inventory：
- 普通 DESIGN_MODE 仍可自由设计，不使用 Run 库存。
- RUN_REFIT_MODE 启用库存约束：
  - Equipment 安装消耗对应 module_inventory。
  - Equipment 拆除返还库存。
  - Hull 新增消耗 hull_stock，拆除空 Hull 返还库存。
  - 已安装模块移动 / 旋转免费。
  - 禁止一键清空飞船。
- 左侧模块按钮显示库存数量；右侧属性区显示当前 Run 库存汇总。
- 每次结构变化立即同步 RunState.current_ship，避免 Load 导致库存与船体状态脱节。

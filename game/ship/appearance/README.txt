《前进四》Appearance Layer 第一版

定位：
- Appearance 是 Hull Layout 与 Equipment 之上的纯战斗表现层。
- 不写入 ShipData，不修改 Excel，不进入 ShipSerializer。
- 编辑器继续显示完整 Hull + Equipment；战斗中由 Appearance 生成最终外壳。

第一版战斗显示：
- Hull Layout -> ShipAppearanceRenderer 自动绘制连续舰体壳。
- Core -> 显示。
- Weapon -> base 与 turret 显示。
- Propulsion -> 第一版继续显示完整设备贴图，作为外露推进设备。
- Energy / Defense / Function -> 战斗中隐藏，视为被舰体外壳包覆。

外壳生成：
- 每个 Hull Cell 查询上 / 右 / 下 / 左四方向邻接，形成 4-bit mask。
- 相邻侧只画轻微内部接缝。
- 没有邻居的侧绘制较粗外壳边缘。
- 外角增加小型圆角盖板，弱化纯方格轮廓。
- Hull health ratio 会让对应外壳逐步变暗、偏向破损色。
- Hull = 0 第一版仍保留破损壳体显示，不删除视觉格，避免 Equipment 看起来悬空。

层级：
- Appearance Shell：z = 0
- Core / Propulsion Equipment：z = 10
- Weapon Base：z = 20
- Weapon Turret：z = 30

职责边界：
- HullCellRuntime 继续只负责碰撞和局部 HP。
- ShipModuleRuntime 只创建允许外露的 Equipment 视觉。
- WeaponRuntime 继续负责独立炮塔。
- Appearance 不影响命中、HP、供电、推力、火力或存档。

后续：
- 可在不改 ShipData 的前提下替换程序绘制为 Hull atlas / tile art。
- 可继续加入舰首、舰尾、装甲蒙皮、引擎开孔、不同舰体风格。

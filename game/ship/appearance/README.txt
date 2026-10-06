《前进四》Appearance Layer：Hull Tile 第一版

定位：
- Appearance 是 Hull Layout 与 Equipment 之上的纯战斗表现层。
- 不写入 ShipData，不修改 Excel，不进入 ShipSerializer。
- 编辑器继续显示完整 Hull + Equipment；战斗中由 Appearance 生成最终外壳。

当前 Hull 外观：
- 默认外观资源：res://data/appearances/hull/human_basic.tres
- 数据定义：res://data/definitions/appearance/hull_appearance_definition.gd
- Runtime 贴图：res://data/assets/ship/hull/human_basic/
- 源素材：tools/art_source/ship/hull/human_basic/
- 共 16 张 64×64 Hull Tile，占位美术用于建立正式拼接流程。

邻接规则：
每个 Hull Cell 查询上 / 右 / 下 / 左四方向邻接，形成 4-bit mask：
- UP = 1
- RIGHT = 2
- DOWN = 4
- LEFT = 8

mask 直接作为 HullAppearanceDefinition.tiles[mask] 的索引：
0000 → tiles[0]
0001 → tiles[1]
...
1111 → tiles[15]

渲染流程：
ShipData.hull_cells
→ ShipAppearanceRenderer
→ get_neighbor_mask()
→ HullAppearanceDefinition.get_tile(mask)
→ 创建对应 Sprite2D
→ 按 cell_size 缩放并定位

战损：
- Hull health ratio 继续驱动 Tile 亮度。
- Hull = 0 第一版仍保留暗化壳体，不删除视觉格。

Fallback：
- 当前默认 human_basic.tres 会由 ShipAppearanceRenderer 预加载；项目内默认资源必须存在且可加载。
- 在已成功加载 HullAppearanceDefinition 的前提下，若某个 mask 对应 Texture2D 为空或索引不可用，该 Hull Cell 自动回退到原程序绘制外壳。
- fallback 用于局部 Tile 配置异常，不替代默认外观资源本身的完整性要求。

Equipment 显示规则保持不变：
- Core：显示。
- Weapon：base + turret 显示。
- Propulsion：显示。
- Energy / Defense / Function：战斗中隐藏。

层级：
- Hull Tile / Fallback Shell：z = 0
- Core / Propulsion：z = 10
- Weapon Base：z = 20
- Weapon Turret：z = 30

第一版边界：
- human_basic 是全项目默认 Hull 外观。
- appearance_id 暂不写入 ShipData / ShipSerializer。
- 暂不做舰首 / 舰尾、Opening、颜色换皮、Damage Overlay、多风格选择。
- 后续扩展多外观时，再把 Appearance 配置正式纳入飞船数据。

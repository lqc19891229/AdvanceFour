game/run/shop

职责：
- 当前 Run 的补给商店玩法场景。
- 根据当前 SHOP 路线节点加载 ShopDefinition。
- 展示 4 张商品卡、能量结晶 / 零件余额、Run Inventory 与 SOLD 状态。

流程：
Route Map → SHOP Node → shop_screen.tscn → 购买 / 离开 → Route Map。

规则（v0.37.1）：
- UI 不自行随机商品；四槽结果由 RunState.get_shop_slots() 生成并保存。
- 每槽显示商品名称、类型、内容、价格和模块贴图（Hull 暂无独立商品图）。
- 已购买槽显示 SOLD 且不可再次购买。
- 能量结晶不足时购买按钮禁用。
- 离开路线商店时完成当前 SHOP 节点。

依赖：
- data/shops/ShopDefinition 配置。
- RunState 的四槽状态与购买接口。

- 商店只消耗能量结晶；零件不作为商店货币。

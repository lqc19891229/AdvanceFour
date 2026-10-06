《前进四》game/run/shop 目录说明

职责：
负责 Run 内补给商店 UI 与购买交互。

当前：
- shop_screen.tscn / shop_screen.gd
- 读取 data/shops/basic_shop.tres。
- 显示当前 Credits、商品列表与 Run Inventory。
- 购买成功后刷新 Credits / Inventory。
- 返回战果页时保留当前 RunState。

边界：
- 商品与价格定义属于 data。
- Credits / Inventory 状态属于 RunState。
- 商店场景不直接生成或修改 ShipData。

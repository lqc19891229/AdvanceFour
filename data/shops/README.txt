《前进四》data/shops 目录说明

职责：
保存具体 ShopDefinition 商店实例。

当前：
- basic_shop.tres：Prototype 补给商店。

当前商品：
- 轻型装甲 ×1：45 Credits
- 机炮 ×1：70 Credits
- 小型引擎 ×1：55 Credits
- 小型反应堆 ×1：60 Credits
- 雷达 ×1：50 Credits
- Hull ×1：25 Credits

规则：
- 商店实例只描述商品与价格，不直接修改 RunState。
- 购买执行由 core/autoload/run_state.gd 负责。
- 当前第一版无限库存，不做出售、随机刷新、限购。

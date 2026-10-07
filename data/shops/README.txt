data/shops

职责：
- 保存 Runtime 正式商店配置实例。
- 商店配置使用 ShopDefinition / ShopItemDefinition。

当前规则（v0.37.1）：
- basic_shop.tres 提供 6 个候选商品。
- 每个商店节点固定 4 个商品槽。
- 四槽规则依次为 combat / systems / utility / any。
- 每次进入一个新的商店节点时，从商品池按槽规则无重复生成 4 件商品。
- 生成结果由 RunState 按路线节点保存；刷新或重新进入同一节点不会重新抽取。
- 每槽只能购买一次，购买后为 SOLD，不补货。
- 商品只提供模块或 Hull 中的一种，购买结果直接进入 Run Inventory。

边界：
- 当前没有稀有度、权重、刷新、出售和库存数量系统。
- 具体购买执行属于 core/autoload/run_state.gd，UI 属于 game/run/shop。

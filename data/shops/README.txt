【当前代码说明｜2026-10】
Godot 4.6.1；项目默认启动 fixed_test_sector 测试星图，动态星图由 RouteMapGenerator.generate() 实现。
能量结晶用于商店，零件用于维修和空间站制造；战斗胜利直接统一结算，失败重置 Run。
历史版本内容不等于当前规则。

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

资源规则（v0.43.0）：
- ShopItemDefinition 使用 price_energy_crystals 定价。
- 商店只接受能量结晶，不接受零件。

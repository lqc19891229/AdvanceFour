《前进四》data — 正式资源和定义（2026-10-09）

definitions/{module,ship,combat,run,bridge,appearance}/：Resource 数据结构及序列化。
modules/：ModuleDatabase 与各类型模块 .tres；assets/：正式贴图、船壳 Tile 与 UI 素材；appearances/：船壳外观资源。
enemies/：EnemyShipDefinition 身份/AI 距离，不保存 Hull Layout。
ships/templates/：ShipSerializer v3 JSON 船体和设备模板，现有侦察舰和炮舰模板。
battles/：关卡配置和掉落表；routes/：路线资源；shops/、stations/、taverns/：节点内容；bridge/：船员/芯片数据。
设计模板与 user://ships/test_ship.json 玩家本地设计分离。tools/ 是数据生产链，game/ 执行这些数据，core/ 管理跨场景状态。

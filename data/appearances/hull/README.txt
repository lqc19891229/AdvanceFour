Hull Appearance 具体配置实例。

当前：
- human_basic.tres：第一版默认 Hull Tile 外观，包含 16 个四方向邻接贴图。

第一版不写入 ShipData / ShipSerializer，ShipAppearanceRenderer 默认加载 human_basic。
后续需要多外观风格时，再把 appearance_id 正式纳入飞船配置。

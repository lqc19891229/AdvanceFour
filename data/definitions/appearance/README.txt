《前进四》data/definitions/appearance 目录说明

职责：
定义外观表现层使用的数据结构，不执行实际绘制。

当前：
- hull_appearance_definition.gd：定义 Hull 外观 ID 与 16 个四方向邻接 Tile。

邻接位：
- bit 0 / 1：UP
- bit 1 / 2：RIGHT
- bit 2 / 4：DOWN
- bit 3 / 8：LEFT

具体外观实例位于 data/appearances/。
正式 Runtime 素材位于 data/assets/ship/。
实际拼装逻辑位于 game/ship/appearance/。

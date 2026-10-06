《前进四》data/assets 目录说明

职责：
保存 Godot Runtime 正式加载的素材。

当前：
- modules/：Equipment Runtime PNG，包括 Weapon base / turret。
- ship/hull/human_basic/：第一版 16 个 Hull 邻接 Tile。

规则：
- 制作源位于 tools/art_source。
- game 不直接保存正式素材。
- data Resource / game Runtime 只引用 data/assets 下的正式素材。

《前进四》data/assets 目录说明

职责：
保存项目唯一一份游戏素材文件，也是 Godot Runtime 正式加载位置。

当前：
- modules/：Equipment PNG，包括 Weapon base / turret。
- Weapon turret PNG 的默认炮口方向为向右，编辑器与 Runtime 共用这一美术方向约定。
- <module_id>_icon.png：可选 UI 图标，导入器自动挂载；武器组合图标可用 tools/generate_weapon_icon.gd 从正式 base / turret 重建。
- ship/hull/human_basic/：第一版 16 个 Hull 邻接 Tile。

规则：
1. PNG、音频等游戏素材统一只保存在 data/assets。
2. tools 不再保存同一素材的 source/runtime 双份副本。
3. game 不直接保存正式素材。
4. data Resource / game Runtime 统一引用 data/assets 下的路径。
5. 如果未来出现 PSD、Aseprite、Blender 等真正的制作工程文件，再单独设计源码素材管理方案；当前不提前建立双份 PNG 体系。

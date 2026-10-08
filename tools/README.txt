《前进四》tools 目录说明

职责：
tools 只保存内容生产工具、策划源数据和验证工具，不保存游戏美术素材副本。

当前：
- data_source/：策划源数据，例如 module_data.xlsx。
- cache/：导入流程中间缓存。
- import/：数据导入与校验脚本。
- verify_project.py：项目统一验证入口。
- generate_weapon_icon.gd：用已有底座和炮塔重建单个武器的组合 UI 图标。

重建武器图标：
godot --headless --path . --script tools/generate_weapon_icon.gd -- weapon_cannon
在项目根目录执行，末尾替换为缓存中存在的武器 ID。
命令覆盖 data/assets/modules/<module_id>_icon.png；每格 128 像素，按独立炮塔尺寸及轴点组合，自动扩展画布容纳长炮管，保留透明背景和向上炮口。
完成后让 Godot 导入新 PNG，再运行 Data Importer 挂载图标。

规则：
1. PNG、音频等游戏素材只保存在 data/assets。
2. tools 不再维护 art_source 或任何 Runtime 素材副本。
3. game 不直接引用 tools。
4. tools 负责“怎么生产/验证数据”，不负责“游戏里有哪些正式资源”。

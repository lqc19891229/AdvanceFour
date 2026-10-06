《前进四》tools 目录说明

职责：
tools 只保存内容生产工具、策划源数据和验证工具，不保存游戏美术素材副本。

当前：
- data_source/：策划源数据，例如 game_data.xlsx。
- cache/：导入流程中间缓存。
- import/：数据导入与校验脚本。
- verify_project.py：项目统一验证入口。

规则：
1. PNG、音频等游戏素材只保存在 data/assets。
2. tools 不再维护 art_source 或任何 Runtime 素材副本。
3. game 不直接引用 tools。
4. tools 负责“怎么生产/验证数据”，不负责“游戏里有哪些正式资源”。

【当前代码索引（2026-10）】
工程版本：Godot 4.6.1；启动：res://game/run/route/route_map_screen.tscn。
默认星图为 fixed_test_sector 功能测试航线；随机星图使用 RouteMapGenerator.generate()，目前不是默认启动流程。
能量结晶用于商店，零件用于 Hull 维修和空间站制造；胜利进入统一结算，失败重置当前 Run。
本文件后续的历史版本描述应按版本阅读，当前行为以对应脚本及配置为准。
RunState 负责局内飞船、路线、经济、仓储、掉落与节点流转，需通过受验证的流程接口更新。

《前进四》core 目录说明

用途：存放全项目共享的底层系统，不属于某一个具体玩法模块。

子目录：
- autoload/：Godot AutoLoad 单例脚本。

使用原则：
- 只有跨场景、跨系统都需要访问的功能才放到 core。
- 不要把飞船、战斗、地图等具体玩法逻辑直接塞进 core。

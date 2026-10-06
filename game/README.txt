《前进四》game 目录说明

职责：
game 保存“游戏如何运行”的代码与场景：Gameplay、Runtime、Controller、Renderer、UI、编辑器与测试场景。

当前子目录：
- ship/：飞船 Runtime、控制、武器、弹丸、伤害、外观、编辑器与开发测试。
- combat/：正式 battle 场景、战斗状态机、HUD 与战斗流程测试。

不放入 game：
- 策划源表与美术源素材：放 tools。
- 纯数据结构定义：放 data/definitions。
- 具体模块/敌舰/关卡配置：放 data/modules、data/enemies、data/battles。
- Runtime 正式 PNG / 音频等素材：放 data/assets。
- 全项目基础设施：放 core。

判断：
“这个东西是什么” → data。
“这个东西怎么在游戏里运行” → game。

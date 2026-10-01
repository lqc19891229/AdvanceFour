《前进四》tools 目录说明

用途：开发期工具，不属于游戏运行玩法。

子目录：
- data_import/：Excel 数据解析和导入辅助脚本。

当前工具：
- verify_project.py：检查 Excel ZIP 完整性、六类模块源数据 / 缓存一致性，再执行 Godot 导入及飞船物理回归；使用临时用户目录，失败时返回非零退出码。

使用：
python3 tools/verify_project.py --godot /path/to/godot

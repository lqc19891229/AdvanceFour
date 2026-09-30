《前进四》tools/data_import 目录说明

文件：
- import_excel.py
  功能：读取 game_data.xlsx 的六个模块 Sheet，校验字段和 ID，并输出 data/import_cache/modules.json。
  依赖：仅使用 Python 标准库，不依赖 openpyxl。

六 Sheet 映射：
Energy -> ENERGY
Propulsion -> PROPULSION
Weapon -> WEAPON
Defense -> DEFENSE
Function -> FUNCTION
Core -> CORE

一般不需要手动运行，由 Godot EditorPlugin 调用。

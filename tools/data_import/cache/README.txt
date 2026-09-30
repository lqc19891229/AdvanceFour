数据导入缓存目录

文件：
- modules.json：由 import_excel.py 自动生成的模块中间数据。

用途：
把 Excel 解析与 Godot Resource 生成解耦。

规则：
- 本目录内容可以自动重建。
- 不要手动修改 JSON cache。

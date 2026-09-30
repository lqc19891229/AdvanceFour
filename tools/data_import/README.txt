《前进四》数据导入系统

目录职责：
集中管理所有“策划数据 -> Godot 运行数据”的导入内容。

目录结构：
- source/game_data.xlsx
  策划数据唯一真源。模块数据维护在六个 Sheet：
  Energy / Propulsion / Weapon / Defense / Function / Core。

- import_excel.py
  读取 Excel、校验字段、根据 Sheet 判断模块类型，并生成 JSON cache。

- cache/modules.json
  Excel 解析后的中间数据，仅用于导入流程。
  可以删除，重新导入时会再次生成。

使用流程：
1. 修改 source/game_data.xlsx。
2. 在 Godot 顶部菜单执行“前进四：验证模块数据”。
3. 验证通过后执行“前进四：导入模块数据”。
4. 插件读取 cache/modules.json；验证通过后清理 res://data/generated/modules/ 六类目录中的旧 .tres，再生成当前 Excel 对应的 .tres。

规则：
- 不要手动修改 cache/modules.json。
- 不要把运行时 .tres 放在本目录。
- 重新导入时，Excel 中已经删除或改名的模块，其旧 .tres 会自动清理；README.txt 等非 .tres 文件不会被删除。
- 新的数据导入脚本、源表和缓存文件统一放在这里管理。

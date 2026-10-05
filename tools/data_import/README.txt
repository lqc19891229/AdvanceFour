《前进四》数据导入系统

目录职责：
集中管理所有“策划数据 -> Godot 运行数据”的导入内容。

目录结构：
- source/game_data.xlsx
  策划数据唯一真源。模块数据维护在六个 Sheet：
  Energy / Propulsion / Weapon / Defense / Function / Core。
  六类模块共同包含 texture_path；Weapon 额外包含 turret_texture_path。
  路径使用 Godot res:// 格式。

- import_excel.py
  读取 Excel、校验字段、根据 Sheet 判断模块类型，并生成 JSON cache。
  所有模块基础字段包含 hp、texture_path；Weapon 额外要求 turret_texture_path。

- cache/modules.json
  Excel 解析后的中间数据，包含贴图路径，仅用于导入流程。

使用流程：
1. 修改 source/game_data.xlsx，包括模块数值和 PNG 的 res:// 路径。
2. 在 Godot 顶部菜单执行“前进四：验证模块数据”。
3. 验证通过后执行“前进四：导入模块数据”。
4. 插件加载 texture_path / turret_texture_path 指向的 Texture2D。
5. 重新生成带 Texture2D 引用的 .tres。
6. 导入器先在内存中构建并验证全部模块；只有全部通过后才替换 generated 资源。写入失败时会恢复导入前的模块 .tres 与 ModuleDatabase。

规则：
- PNG 路径由 Excel 决定，不再依赖 module_id 自动拼接。
- 每次解析 Excel 前会先删除旧 cache/modules.json；本次 Python 解析必须生成新的缓存文件，避免失败时误读旧缓存。
- generated 资源采用“全部准备成功后再替换 + 失败回滚”流程，避免半导入状态。
- 不要手动修改 cache/modules.json 或 generated 目录中的 .tres。

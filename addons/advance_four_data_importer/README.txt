Advance Four Data Importer - Godot 插件入口

文件：
- plugin.cfg：EditorPlugin 注册配置。
- plugin.gd：Godot 编辑器菜单入口，负责调用 tools/data_import 中的导入流程；数据验证通过后先清理旧的自动生成模块 .tres，再重新生成当前 Excel 对应的 .tres。

职责边界：
- addons 只负责 Godot EditorPlugin 接入。
- Excel、Python 和 JSON cache 不放在 addons。
- 真正的数据导入资源统一位于 res://tools/data_import/。
- 最终运行数据输出到 res://data/generated/。

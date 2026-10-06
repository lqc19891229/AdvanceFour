《前进四》tools/data_source 目录说明

职责：
保存策划可直接编辑的数据源。

当前：
- game_data.xlsx：模块策划数值唯一真源。

工作流：
修改 Excel
→ 运行导入/验证
→ 更新 tools/cache/modules.json
→ 生成 data/modules 下的正式 Runtime Resource。

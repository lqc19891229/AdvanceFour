舰桥 V1.0 数据模型

机组与芯片均为开放式插槽：无岗位、无类型绑定。一个芯片/机组可以包含多个 BridgeModifierDefinition 效果。
bridge_data.xlsx 是唯一策划来源，JSON 为 Python 解析缓存，data/bridge/ 中 .tres 为 Runtime 正式资源。
此阶段仅实现数据与导入，尚不接入 RunState、战斗属性、奖励和管理界面。

class_name RunRouteNodeDefinition
extends Resource

enum NodeType {
	BATTLE,
	SHOP,
	REFIT,
	END
}

@export var node_id: StringName = &""
@export var display_name := ""
@export var node_type := NodeType.BATTLE
@export_file var target_path := ""
@export var next_node_ids: Array[StringName] = []
@export var map_position := Vector2.ZERO

func is_valid() -> bool:
	if node_id == &"" or display_name.strip_edges().is_empty():
		return false
	if node_type in [NodeType.BATTLE, NodeType.SHOP, NodeType.REFIT] and target_path.is_empty():
		return false
	if node_type == NodeType.END and not target_path.is_empty():
		return false
	if not target_path.is_empty() and not ResourceLoader.exists(target_path):
		return false
	return true

func get_invalid_reason() -> String:
	if node_id == &"":
		return "节点 ID 不能为空。"
	if display_name.strip_edges().is_empty():
		return "节点名称不能为空。"
	if node_type in [NodeType.BATTLE, NodeType.SHOP, NodeType.REFIT] and target_path.is_empty():
		return "战斗 / 商店 / 空间站节点必须配置 target_path。"
	if node_type == NodeType.END and not target_path.is_empty():
		return "终点节点不能配置 target_path。"
	if not target_path.is_empty() and not ResourceLoader.exists(target_path):
		return "节点目标资源不存在：%s" % target_path
	return ""

func get_type_label() -> String:
	match node_type:
		NodeType.BATTLE:
			return "战斗"
		NodeType.SHOP:
			return "商店"
		NodeType.REFIT:
			return "空间站"
		NodeType.END:
			return "终点"
	return "未知"

class_name RunRouteDefinition
extends Resource

@export var route_id: StringName = &""
@export var display_name := ""
@export var start_node_id: StringName = &""
@export var nodes: Array[Resource] = []

func get_node(node_id: StringName) -> RunRouteNodeDefinition:
	for raw_node in nodes:
		var node := raw_node as RunRouteNodeDefinition
		if node != null and node.node_id == node_id:
			return node
	return null

func is_valid() -> bool:
	if route_id == &"" or display_name.strip_edges().is_empty() or start_node_id == &"" or nodes.is_empty():
		return false
	var ids: Dictionary = {}
	for raw_node in nodes:
		if not (raw_node is RunRouteNodeDefinition):
			return false
		var node := raw_node as RunRouteNodeDefinition
		if not node.is_valid() or ids.has(node.node_id):
			return false
		ids[node.node_id] = true
	if not ids.has(start_node_id):
		return false
	for raw_node in nodes:
		var node := raw_node as RunRouteNodeDefinition
		for next_id in node.next_node_ids:
			if not ids.has(next_id) or next_id == node.node_id:
				return false
	return true

func get_invalid_reason() -> String:
	if route_id == &"":
		return "路线 ID 不能为空。"
	if display_name.strip_edges().is_empty():
		return "路线名称不能为空。"
	if start_node_id == &"":
		return "路线起点不能为空。"
	if nodes.is_empty():
		return "路线至少需要一个节点。"
	var ids: Dictionary = {}
	for index in range(nodes.size()):
		var raw_node := nodes[index]
		if not (raw_node is RunRouteNodeDefinition):
			return "第 %d 个路线节点类型无效。" % (index + 1)
		var node := raw_node as RunRouteNodeDefinition
		if not node.is_valid():
			return "第 %d 个节点：%s" % [index + 1, node.get_invalid_reason()]
		if ids.has(node.node_id):
			return "路线节点 ID 重复：%s" % String(node.node_id)
		ids[node.node_id] = true
	if not ids.has(start_node_id):
		return "路线起点不存在：%s" % String(start_node_id)
	for raw_node in nodes:
		var node := raw_node as RunRouteNodeDefinition
		for next_id in node.next_node_ids:
			if not ids.has(next_id):
				return "节点 %s 指向不存在的节点 %s。" % [String(node.node_id), String(next_id)]
			if next_id == node.node_id:
				return "节点不能指向自身：%s" % String(node.node_id)
	return ""

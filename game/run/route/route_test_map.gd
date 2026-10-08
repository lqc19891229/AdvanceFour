class_name RouteTestMap
extends RefCounted

# First-playable fixed test route. No RNG or procedural topology.
static func build() -> RunRouteDefinition:
	var route := RunRouteDefinition.new()
	route.route_id = &"fixed_test_sector"
	route.display_name = "星区 01 · 功能测试航线"
	var data := [
		[&"shop", "贸易空间站", RunRouteNodeDefinition.NodeType.SHOP, "res://data/shops/basic_shop.tres"],
		[&"station", "维修改装站", RunRouteNodeDefinition.NodeType.REFIT, "res://data/stations/basic_station.tres"],
		[&"battle_1", "测试普通战", RunRouteNodeDefinition.NodeType.BATTLE, "res://data/battles/test_normal/battle.tres"],
		[&"battle_2", "测试精英战", RunRouteNodeDefinition.NodeType.BATTLE, "res://data/battles/test_elite/battle.tres"],
		[&"end", "航线终点", RunRouteNodeDefinition.NodeType.END, ""]
	]
	for i in range(data.size()):
		var item: Array = data[i]
		var node := RunRouteNodeDefinition.new()
		node.node_id = item[0]
		node.display_name = item[1]
		node.node_type = item[2]
		node.target_path = item[3]
		node.map_position = Vector2(85 + i * 245, 235)
		if i < data.size() - 1:
			node.next_node_ids.append(data[i + 1][0])
		route.nodes.append(node)
	# Optional tavern branch in the test map; existing shop → station → battle flow remains valid.
	var tavern := RunRouteNodeDefinition.new()
	tavern.node_id = &"tavern"
	tavern.display_name = "星际酒馆"
	tavern.node_type = RunRouteNodeDefinition.NodeType.TAVERN
	tavern.target_path = "res://data/taverns/basic_tavern.tres"
	tavern.map_position = Vector2(330, 385)
	tavern.next_node_ids.append(&"battle_1")
	(route.get_node(&"station") as RunRouteNodeDefinition).next_node_ids.append(&"tavern")
	route.nodes.append(tavern)
	route.start_node_id = &"shop"
	return route

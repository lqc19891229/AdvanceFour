class_name RouteMapGenerator
extends RefCounted

const STAGE_ONE := "res://data/battles/stage_001/battle.tres"
const STAGE_TWO := "res://data/battles/stage_002/battle.tres"
const ELITE := "res://data/battles/elite_001/battle.tres"
const SHOP := "res://data/shops/basic_shop.tres"
const STATION := "res://data/stations/basic_station.tres"

# A deterministic graph for a given seed; new runs use a fresh seed.
static func generate(seed_value: int = -1) -> RunRouteDefinition:
	var rng := RandomNumberGenerator.new()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var route := RunRouteDefinition.new()
	route.route_id = &"generated_sector"
	route.display_name = "星区 01 · 全息航线"
	var layers: Array = []
	for depth in range(10):
		var layer: Array = []
		var count := 1 if depth == 0 or depth == 9 else rng.randi_range(2, 3)
		for lane in range(count):
			var node := RunRouteNodeDefinition.new()
			node.node_id = StringName("sector_%02d_%02d" % [depth, lane])
			node.map_position = Vector2(80 + depth * 205, 100 + (lane + 1) * (480.0 / (count + 1)) - 35 + rng.randf_range(-14.0, 14.0))
			if depth == 0:
				node.display_name = "星区入口"
				node.node_type = RunRouteNodeDefinition.NodeType.BATTLE
				node.target_path = STAGE_ONE
			elif depth == 9:
				node.display_name = "星区终点"
				node.node_type = RunRouteNodeDefinition.NodeType.END
			else:
				var roll := rng.randf()
				if depth == 8:
					roll = 0.0
				if roll < 0.53:
					node.node_type = RunRouteNodeDefinition.NodeType.BATTLE
					node.display_name = "敌对舰队"
					node.target_path = STAGE_TWO
				elif roll < 0.7:
					node.node_type = RunRouteNodeDefinition.NodeType.BATTLE
					node.display_name = "精英舰队"
					node.target_path = ELITE
				elif roll < 0.85:
					node.node_type = RunRouteNodeDefinition.NodeType.SHOP
					node.display_name = "贸易空间站"
					node.target_path = SHOP
				else:
					node.node_type = RunRouteNodeDefinition.NodeType.REFIT
					node.display_name = "维修改装站"
					node.target_path = STATION
			layer.append(node)
			route.nodes.append(node)
		layers.append(layer)
	route.start_node_id = (layers[0][0] as RunRouteNodeDefinition).node_id
	for depth in range(layers.size() - 1):
		var left: Array = layers[depth]
		var right: Array = layers[depth + 1]
		# Each source has an outgoing edge, each destination has an incoming edge.
		for i in range(left.size()):
			var src := left[i] as RunRouteNodeDefinition
			var dst := right[mini(int(round(float(i) * (right.size() - 1) / maxi(left.size() - 1, 1))), right.size() - 1)] as RunRouteNodeDefinition
			src.next_node_ids.append(dst.node_id)
		for j in range(right.size()):
			var src := left[mini(int(round(float(j) * (left.size() - 1) / maxi(right.size() - 1, 1))), left.size() - 1)] as RunRouteNodeDefinition
			var dst := right[j] as RunRouteNodeDefinition
			if not src.next_node_ids.has(dst.node_id):
				src.next_node_ids.append(dst.node_id)
		# Extra adjacent-lane branches, avoiding long crossing edges.
		for i in range(left.size()):
			var src := left[i] as RunRouteNodeDefinition
			for j in range(right.size()):
				if absf(float(i + 0.5) / left.size() - float(j + 0.5) / right.size()) < 0.35 and rng.randf() < 0.33:
					var dst := right[j] as RunRouteNodeDefinition
					if not src.next_node_ids.has(dst.node_id):
						src.next_node_ids.append(dst.node_id)
	return route

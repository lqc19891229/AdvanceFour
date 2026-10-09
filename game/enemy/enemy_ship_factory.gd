class_name EnemyShipFactory
extends RefCounted

const DATABASE: ModuleDatabase = preload("res://data/modules/module_database.tres")

static func create_design(definition: EnemyShipDefinition) -> ShipData:
	if definition == null or not definition.is_valid() or definition.ship_template_path.is_empty():
		push_error("敌舰未配置合法的飞船模板")
		return null
	var loaded := ShipSerializer.load_from_file(definition.ship_template_path, DATABASE)
	if not loaded["ok"]:
		push_error("敌舰模板加载失败：" + String(loaded["error"]))
		return null
	var ship := loaded["ship"] as ShipData
	if ship == null or not ship.is_design_valid():
		push_error("敌舰模板不符合出航要求：" + definition.ship_template_path)
		return null
	return ship

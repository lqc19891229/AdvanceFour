class_name BattleWaveDefinition
extends Resource

@export var enemies: Array[Resource] = []
@export var counts: Array[int] = []
@export var spawn_interval_seconds := -1.0

func is_valid() -> bool:
	if enemies.is_empty() or enemies.size() != counts.size():
		return false
	for index in range(enemies.size()):
		if not (enemies[index] is EnemyShipDefinition) or not (enemies[index] as EnemyShipDefinition).is_valid() or counts[index] <= 0:
			return false
	return spawn_interval_seconds >= -1.0

func get_invalid_reason() -> String:
	if enemies.is_empty():
		return "波次至少需要一种敌舰。"
	if enemies.size() != counts.size():
		return "波次敌舰与数量数组长度必须一致。"
	for index in range(enemies.size()):
		if not (enemies[index] is EnemyShipDefinition):
			return "波次包含无效敌舰配置。"
		if not (enemies[index] as EnemyShipDefinition).is_valid():
			return (enemies[index] as EnemyShipDefinition).get_invalid_reason()
		if counts[index] <= 0:
			return "波次内每种敌舰数量必须大于零。"
	if spawn_interval_seconds < -1.0:
		return "波次生成间隔必须为 -1 或非负数。"
	return ""

func get_total_enemy_count() -> int:
	var total := 0
	for count in counts:
		total += count
	return total

func get_enemy_for_spawn_index(spawn_index: int) -> EnemyShipDefinition:
	var cursor := spawn_index
	for index in range(enemies.size()):
		if cursor < counts[index]:
			return enemies[index] as EnemyShipDefinition
		cursor -= counts[index]
	return null

extends Node

signal upgrade_purchased(upgrade_id: String)

const BASE_COSTS = {
	"fire_rate":   50.0,
	"damage":      75.0,
	"spawn_count": 40.0,
	"dot_value":   60.0,
}

const COST_SCALE = 1.35

var levels: Dictionary = {
	"fire_rate":   0,
	"damage":      0,
	"spawn_count": 0,
	"dot_value":   0,
}


func get_cost(upgrade_id: String) -> float:
	var level = levels[upgrade_id]
	return BASE_COSTS[upgrade_id] * pow(COST_SCALE, level)


func can_afford(upgrade_id: String, currency: float) -> bool:
	return currency >= get_cost(upgrade_id)


func purchase(upgrade_id: String) -> void:
	levels[upgrade_id] += 1
	upgrade_purchased.emit(upgrade_id)


func get_fire_rate() -> float:
	return 1.5 + levels["fire_rate"] * 0.25


func get_damage() -> float:
	return 1.0 + levels["damage"] * 0.5


func get_dot_count() -> int:
	return 10 + levels["spawn_count"] * 2


func get_dot_value() -> float:
	return 1.0 + levels["dot_value"] * 0.25


func format_currency(value: float) -> String:
	if value >= 1_000_000_000:
		return "$%.2fB" % (value / 1_000_000_000.0)
	elif value >= 1_000_000:
		return "$%.2fM" % (value / 1_000_000.0)
	elif value >= 1_000:
		return "$%.2fK" % (value / 1_000.0)
	else:
		return "$%.0f" % value

extends Node

signal upgrade_purchased(upgrade_id: String)

const BASE_COSTS: Dictionary = {
	"fire_rate":      30.0,
	"damage":         45.0,
	"spawn_count":    25.0,
	"dot_value":      35.0,
	"drone_speed":    80.0,
	"drone_damage":   90.0,
	"drone_agility": 100.0,
	"drone_size":     70.0,
	"drone_cooldown": 60.0,
}

const COST_SCALE := 1.45

var levels: Dictionary = {
	"fire_rate":      0,
	"damage":         0,
	"spawn_count":    0,
	"dot_value":      0,
	"drone_speed":    0,
	"drone_damage":   0,
	"drone_agility":  0,
	"drone_size":     0,
	"drone_cooldown": 0,
}


func get_cost(upgrade_id: String) -> float:
	var level: int = levels[upgrade_id]
	return BASE_COSTS[upgrade_id] * pow(COST_SCALE, level)


func can_afford(upgrade_id: String, currency: float) -> bool:
	return currency >= get_cost(upgrade_id)


func purchase(upgrade_id: String) -> void:
	levels[upgrade_id] += 1
	upgrade_purchased.emit(upgrade_id)


# --- Turret stats ---

func get_fire_rate() -> float:
	return 1.5 * pow(1.20, levels["fire_rate"])


func get_damage() -> float:
	return 1.0 * pow(1.35, levels["damage"])


func get_dot_count() -> int:
	return 10 + levels["spawn_count"] * 3


func get_dot_value() -> float:
	return 1.0 * pow(1.30, levels["dot_value"])


# --- Drone stats ---

func get_drone_speed() -> float:
	# Base 160 px/s, +15% per level
	return 160.0 * pow(1.15, levels["drone_speed"])


func get_drone_damage() -> float:
	return 1.0 * pow(1.35, levels["drone_damage"])


func get_drone_agility() -> float:
	# Orbit speed multiplier
	return 1.0 * pow(1.10, levels["drone_agility"])


func get_drone_size() -> float:
	# Visual and collision size multiplier
	return 1.0 * pow(1.08, levels["drone_size"])


func get_drone_orbit_radius() -> float:
	# Reserved for a future upgrade — always 1.0 for now
	return 1.0


func get_drone_ram_cooldown() -> float:
	# Seconds between rams, floored at 0.4s
	return maxf(0.4, 2.0 - levels["drone_cooldown"] * 0.2)


func format_currency(value: float) -> String:
	if value >= 1_000_000_000:
		return "$%.2fB" % (value / 1_000_000_000.0)
	elif value >= 1_000_000:
		return "$%.2fM" % (value / 1_000_000.0)
	elif value >= 1_000:
		return "$%.2fK" % (value / 1_000.0)
	else:
		return "$%.0f" % value


func restore_levels(saved_levels: Dictionary) -> void:
	for key in levels.keys():
		if saved_levels.has(key):
			levels[key] = int(saved_levels[key])

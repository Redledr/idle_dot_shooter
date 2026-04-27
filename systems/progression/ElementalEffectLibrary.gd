extends RefCounted

const STATUS_RULES := {
	"fire": {
		"damage_property": "dot_fire_damage",
		"duration_property": "dot_fire_duration",
		"default_duration": 2.0,
		"spread_property": "fire_spread_count",
		"permanent_property": "dot_fire_permanent",
		"bonus_property": "fire_bonus_full_hp_multiplier",
		"bonus_key": "bonus_vs_full_hp",
	},
	"poison": {
		"damage_property": "dot_poison_damage",
		"duration_property": "dot_poison_duration",
		"default_duration": 3.0,
		"spread_property": "dot_poison_spread_count",
	},
	"acid": {
		"damage_property": "dot_acid_damage",
		"duration_property": "dot_acid_duration",
		"default_duration": 4.0,
		"spread_property": "acid_spread_count",
		"stack_property": "acid_stack_limit",
	},
	"bleed": {
		"damage_property": "dot_bleed_damage",
		"duration_property": "dot_bleed_duration",
		"default_duration": 5.0,
		"stack_property": "bleed_stack_limit",
		"bonus_property": "bleed_orb_multiplier",
		"bonus_key": "orb_multiplier",
	},
}


static func build_projectile_payload(main, count_for_shot_triggers: bool) -> Dictionary:
	var payload := {
		"statuses": {},
		"impact": {},
		"void_pen_percent": main.void_pen_percent,
	}

	for status_name in STATUS_RULES.keys():
		var status_payload := build_status_payload(main, status_name)
		if not status_payload.is_empty():
			payload["statuses"][status_name] = status_payload

	if count_for_shot_triggers:
		main._shots_fired += 1
		if main.solar_flare_every_shots > 0 and main._shots_fired % main.solar_flare_every_shots == 0:
			payload["impact"]["detonation_radius"] = 140.0
			payload["impact"]["detonation_damage"] = UpgradeManager.get_damage() * 1.5
		if main.cluster_every_shots > 0 and main._shots_fired % main.cluster_every_shots == 0:
			payload["impact"]["cluster_targets"] = main.cluster_targets

	return payload


static func build_status_payload(main, status_name: String) -> Dictionary:
	var rule: Dictionary = STATUS_RULES.get(status_name, {})
	if rule.is_empty():
		return {}

	var damage_property: String = String(rule.get("damage_property", ""))
	var dps: float = float(main.get(damage_property))
	if dps <= 0.0:
		return {}

	var payload := {
		"dps": dps,
		"duration": float(main.get(String(rule.get("duration_property", "")))),
		"source": status_name,
	}

	var spread_property: String = String(rule.get("spread_property", ""))
	if not spread_property.is_empty():
		var spread_count: int = int(main.get(spread_property))
		if spread_count > 0:
			payload["spread_count"] = spread_count

	var stack_property: String = String(rule.get("stack_property", ""))
	if not stack_property.is_empty():
		var max_stacks: int = int(main.get(stack_property))
		if max_stacks > 1:
			payload["max_stacks"] = max_stacks

	var permanent_property: String = String(rule.get("permanent_property", ""))
	if not permanent_property.is_empty() and bool(main.get(permanent_property)):
		payload["permanent"] = true

	var bonus_property: String = String(rule.get("bonus_property", ""))
	if not bonus_property.is_empty():
		var bonus_value: float = float(main.get(bonus_property))
		if bonus_value > 0.0:
			payload[String(rule.get("bonus_key", "bonus"))] = bonus_value

	return payload


static func apply_status_damage(main, status_name: String, damage_per_second: float, minimum_duration: float = -1.0) -> bool:
	var rule: Dictionary = STATUS_RULES.get(status_name, {})
	if rule.is_empty():
		return false

	var damage_property: String = String(rule.get("damage_property", ""))
	main.set(damage_property, maxf(float(main.get(damage_property)), damage_per_second))

	if minimum_duration < 0.0:
		minimum_duration = float(rule.get("default_duration", 0.0))
	if minimum_duration > 0.0:
		apply_status_duration(main, status_name, minimum_duration)

	return true


static func apply_status_duration(main, status_name: String, duration: float) -> bool:
	var rule: Dictionary = STATUS_RULES.get(status_name, {})
	if rule.is_empty():
		return false

	var duration_property: String = String(rule.get("duration_property", ""))
	if duration_property.is_empty():
		return false

	main.set(duration_property, maxf(float(main.get(duration_property)), duration))
	return true


static func apply_status_spread(main, status_name: String, count: int) -> bool:
	var rule: Dictionary = STATUS_RULES.get(status_name, {})
	if rule.is_empty():
		return false

	var spread_property: String = String(rule.get("spread_property", ""))
	if spread_property.is_empty():
		return false

	main.set(spread_property, max(int(main.get(spread_property)), count))
	return true


static func apply_status_stack_limit(main, status_name: String, limit: int) -> bool:
	var rule: Dictionary = STATUS_RULES.get(status_name, {})
	if rule.is_empty():
		return false

	var stack_property: String = String(rule.get("stack_property", ""))
	if stack_property.is_empty():
		return false

	main.set(stack_property, max(int(main.get(stack_property)), limit))
	return true


static func apply_status_permanent(main, status_name: String) -> bool:
	var rule: Dictionary = STATUS_RULES.get(status_name, {})
	if rule.is_empty():
		return false

	var permanent_property: String = String(rule.get("permanent_property", ""))
	if permanent_property.is_empty():
		return false

	main.set(permanent_property, true)
	return true


static func apply_status_bonus(main, status_name: String, value: float) -> bool:
	var rule: Dictionary = STATUS_RULES.get(status_name, {})
	if rule.is_empty():
		return false

	var bonus_property: String = String(rule.get("bonus_property", ""))
	if bonus_property.is_empty():
		return false

	main.set(bonus_property, maxf(float(main.get(bonus_property)), value))
	return true

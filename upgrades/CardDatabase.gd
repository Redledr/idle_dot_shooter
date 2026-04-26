extends Node

const CARDS_JSON_PATH := "res://data/cards.json"

const WEIGHTS := {
	"common":    60,
	"rare":      30,
	"epic":      15,
	"legendary": 5,
}

var _cards: Array = []
var codex: Array[String] = []
var active_cards: Array[String] = []
var bonus_draws: int = 0


func _ready() -> void:
	_load_cards()


func _load_cards() -> void:
	if not FileAccess.file_exists(CARDS_JSON_PATH):
		push_warning("CardDatabase: cards.json not found — using fallback")
		_cards = _get_fallback_cards()
		return
	var file := FileAccess.open(CARDS_JSON_PATH, FileAccess.READ)
	if file == null:
		_cards = _get_fallback_cards()
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.has("cards"):
		_cards = _get_fallback_cards()
		return
	_cards = parsed["cards"]
	print("CardDatabase: loaded %d cards" % _cards.size())


func draw_hand(count: int) -> Array:
	var hand := []
	var attempts := 0
	while hand.size() < count and attempts < 200:
		attempts += 1
		var card := _weighted_random()
		if not card.is_empty() and card not in hand:
			hand.append(card)
	return hand


func apply_card(card_id: String, main: Node) -> void:
	active_cards.append(card_id)
	_add_to_codex(card_id)

	var card := get_card(card_id)
	if card.is_empty():
		return

	var effect_key: String = card.get("effect_key", "")
	var n: float = float(card.get("effect_value", 0))
	var ni: int = int(n)

	match effect_key:
		# Turret
		"fire_rate_levels":      UpgradeManager.levels["fire_rate"] += ni; _apply_fire_rate(main)
		"damage_levels":         UpgradeManager.levels["damage"] += ni
		"balanced_boost":        UpgradeManager.levels["fire_rate"] += ni; UpgradeManager.levels["damage"] += ni; _apply_fire_rate(main)
		"damage_and_rate":       UpgradeManager.levels["damage"] += 15; UpgradeManager.levels["fire_rate"] += 8; _apply_fire_rate(main)
		"bullets_pierce":        main.set("bullets_pierce", true)
		# Drone
		"drone_speed_levels":    UpgradeManager.levels["drone_speed"] += ni
		"drone_damage_levels":   UpgradeManager.levels["drone_damage"] += ni
		"drone_agility_levels":  UpgradeManager.levels["drone_agility"] += ni
		"drone_size_levels":     UpgradeManager.levels["drone_size"] += ni
		"drone_cooldown_levels": UpgradeManager.levels["drone_cooldown"] += ni
		"spawn_drone":
			for i in ni:
				main.call("spawn_extra_drone")
		"drone_combo":
			UpgradeManager.levels["drone_speed"] += ni
			UpgradeManager.levels["drone_damage"] += ni
		"drone_all":
			for key in ["drone_speed","drone_damage","drone_agility","drone_size","drone_cooldown"]:
				UpgradeManager.levels[key] += ni
		# Economy
		"orbs_per_kill":         main.set("orbs_per_kill", main.get("orbs_per_kill") + ni)
		"pickup_radius_mul":     main.orb_pickup_radius *= n; main.cursor.radius = main.orb_pickup_radius
		"chain_pickup":          main.set("chain_pickup", true)
		"dot_value_levels":      UpgradeManager.levels["dot_value"] += ni
		"spawn_count_levels":    UpgradeManager.levels["spawn_count"] += ni
		"orb_lifetime_add":      main.set("orb_lifetime", main.get("orb_lifetime") + n)
		"orb_gravity":           main.set("orb_gravity", true)
		"orb_nova":              main.set("orb_nova", true)
		"orb_speed_mul":         main.set("orb_speed_mul", main.get("orb_speed_mul") * n)
		"orb_time_bonus":        main.set("orb_time_bonus", main.get("orb_time_bonus") + n)
		"economy_combo":
			UpgradeManager.levels["dot_value"] += 6
			main.set("orbs_per_kill", main.get("orbs_per_kill") + 1)
		# Wildcard
		"run_duration_add":      main.run_duration += n
		"all_stats":
			for key in UpgradeManager.levels.keys():
				UpgradeManager.levels[key] += ni
			_apply_fire_rate(main)
		"turret_all":
			for key in ["fire_rate","damage"]:
				UpgradeManager.levels[key] += ni
			_apply_fire_rate(main)
		"speed_combo":
			UpgradeManager.levels["fire_rate"] += ni; _apply_fire_rate(main)
			UpgradeManager.levels["drone_speed"] += ni
		"rate_and_value":
			UpgradeManager.levels["fire_rate"] += ni; _apply_fire_rate(main)
			UpgradeManager.levels["dot_value"] += ni
		"time_and_dots":
			main.run_duration += 45
			UpgradeManager.levels["spawn_count"] += 8
		"density_boost":
			UpgradeManager.levels["spawn_count"] += 8
			UpgradeManager.levels["dot_value"] += 4
		"efficient_trade":
			UpgradeManager.levels["spawn_count"] = max(0, UpgradeManager.levels["spawn_count"] - 3)
			UpgradeManager.levels["dot_value"] += 8
		"random_stat":
			var keys := UpgradeManager.levels.keys()
			var key: String = keys[randi() % keys.size()]
			UpgradeManager.levels[key] += ni
			if key == "fire_rate": _apply_fire_rate(main)
		"random_three":
			var keys := UpgradeManager.levels.keys().duplicate()
			keys.shuffle()
			for i in min(3, keys.size()):
				UpgradeManager.levels[keys[i]] += ni
			_apply_fire_rate(main)
		# Elemental / DoT / Nuke / Chain — flagged for future systems
		_:
			main.set("card_flags", _merge_flag(main.get("card_flags"), effect_key, n))
			push_warning("CardDatabase: effect '%s' flagged — implement in main.gd" % effect_key)


func _merge_flag(existing, key: String, value: float) -> Dictionary:
	var d: Dictionary = existing if existing is Dictionary else {}
	d[key] = d.get(key, 0.0) + value
	return d


func get_card(card_id: String) -> Dictionary:
	for card in _cards:
		if (card as Dictionary).get("id", "") == card_id:
			return card as Dictionary
	return {}


func get_all_cards() -> Array:
	return _cards


func reset_run() -> void:
	active_cards.clear()


func _weighted_random() -> Dictionary:
	var weighted := []
	for card in _cards:
		var w: int = WEIGHTS.get((card as Dictionary).get("rarity", "common"), 10)
		for i in w:
			weighted.append(card)
	if weighted.is_empty():
		return {}
	return weighted[randi() % weighted.size()] as Dictionary


func _add_to_codex(card_id: String) -> void:
	if card_id not in codex:
		codex.append(card_id)


func _apply_fire_rate(main: Node) -> void:
	var turret := main.get_node_or_null("Turret")
	if turret:
		turret.get_node("ShooterComponent").fire_rate = UpgradeManager.get_fire_rate()


func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color(0.961, 0.969, 0.969, 1.0)
		"rare":      return Color(0.204, 0.439, 0.831, 1.0)
		"epic":      return Color(0.71,  0.192, 0.863, 1.0)
		"legendary": return Color(0.984, 0.58,  0.039, 1.0)
		_:           return Color.WHITE


func get_category_symbol(category: String) -> String:
	match category:
		"turret":    return "⬡"
		"drone":     return "◈"
		"economy":   return "◎"
		"wildcard":  return "✦"
		"elemental": return "◉"
		"chain":     return "⬢"
		"dot":       return "◆"
		"nuke":      return "☢"
		_:           return "?"


func _get_fallback_cards() -> Array:
	return [
		{"id":"rapid_fire","name":"Rapid Fire","description":"Fire rate +1 level","rarity":"common","category":"turret","effect_key":"fire_rate_levels","effect_value":1},
		{"id":"heavy_rounds","name":"Heavy Rounds","description":"Bullet damage +3 levels","rarity":"common","category":"turret","effect_key":"damage_levels","effect_value":3},
		{"id":"twin_drone","name":"Twin Protocol","description":"Spawns a second drone","rarity":"legendary","category":"drone","effect_key":"spawn_drone","effect_value":1},
		{"id":"bonus_orbs","name":"Windfall","description":"Dots drop 2 orbs on death","rarity":"common","category":"economy","effect_key":"orbs_per_kill","effect_value":1},
		{"id":"time_warp","name":"Time Warp","description":"+30 seconds","rarity":"legendary","category":"wildcard","effect_key":"run_duration_add","effect_value":30},
	]

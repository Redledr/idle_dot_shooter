extends RefCounted

const ElementalEffectLibrary = preload("res://systems/progression/ElementalEffectLibrary.gd")


static func apply_effect(effect_key: String, n: float, ni: int, main) -> void:
	if _apply_turret_effect(effect_key, n, ni, main):
		return
	if _apply_drone_effect(effect_key, ni, main):
		return
	if _apply_economy_effect(effect_key, n, ni, main):
		return
	if _apply_wildcard_effect(effect_key, n, ni, main):
		return
	if _apply_combat_effect(effect_key, n, ni, main):
		return

	main.card_flags = _merge_flag(main.card_flags, effect_key, n)
	push_warning("CardDatabase: effect '%s' not implemented" % effect_key)


static func apply_effect_data(effect_data: Dictionary, main) -> void:
	if _apply_resource_effect(effect_data, main):
		return

	var effect_key: String = String(effect_data.get("effect_type", ""))
	var value: float = float(effect_data.get("value", 0.0))
	apply_effect(effect_key, value, int(value), main)


static func _apply_resource_effect(effect_data: Dictionary, main) -> bool:
	var effect_type: String = String(effect_data.get("effect_type", ""))
	var element: String = String(effect_data.get("element", ""))
	var value: float = float(effect_data.get("value", 0.0))
	var duration: float = float(effect_data.get("duration", 0.0))
	var metadata: Dictionary = effect_data.get("metadata", {}) as Dictionary
	var operation: String = String(effect_data.get("operation", ""))
	var property_name: String = String(effect_data.get("property_name", ""))
	var upgrade_id: String = String(effect_data.get("upgrade_id", ""))

	match effect_type:
		"status_damage":
			var minimum_duration := duration if duration > 0.0 else -1.0
			return ElementalEffectLibrary.apply_status_damage(main, element, value, minimum_duration)
		"status_duration":
			return ElementalEffectLibrary.apply_status_duration(main, element, value)
		"status_spread":
			return ElementalEffectLibrary.apply_status_spread(main, element, int(value))
		"status_stack_limit":
			return ElementalEffectLibrary.apply_status_stack_limit(main, element, int(value))
		"status_permanent":
			return ElementalEffectLibrary.apply_status_permanent(main, element)
		"status_bonus":
			return ElementalEffectLibrary.apply_status_bonus(main, element, value)
		"upgrade_level":
			if upgrade_id.is_empty():
				upgrade_id = String(metadata.get("upgrade_id", ""))
			return _apply_upgrade_level(upgrade_id, int(value), main)
		"runtime_flag":
			if property_name.is_empty():
				property_name = String(metadata.get("property_name", ""))
			if operation.is_empty():
				operation = String(metadata.get("operation", "add"))
			return _apply_runtime_flag(main, property_name, operation, value)
		_:
			return false


static func _apply_turret_effect(effect_key: String, n: float, ni: int, main) -> bool:
	match effect_key:
		"fire_rate_levels":
			UpgradeManager.levels["fire_rate"] += ni
			_apply_fire_rate(main)
		"damage_levels":
			UpgradeManager.levels["damage"] += ni
		"balanced_boost":
			UpgradeManager.levels["fire_rate"] += ni
			UpgradeManager.levels["damage"] += ni
			_apply_fire_rate(main)
		"damage_and_rate":
			UpgradeManager.levels["damage"] += 15
			UpgradeManager.levels["fire_rate"] += 8
			_apply_fire_rate(main)
		"bullets_pierce":
			main.bullets_pierce = true
		"fire_and_pierce":
			main.bullets_pierce = true
			ElementalEffectLibrary.apply_status_damage(main, "fire", n if n > 0.0 else 1.0, 2.0)
		_:
			return false
	return true


static func _apply_drone_effect(effect_key: String, ni: int, main) -> bool:
	match effect_key:
		"drone_speed_levels":
			UpgradeManager.levels["drone_speed"] += ni
		"drone_damage_levels":
			UpgradeManager.levels["drone_damage"] += ni
		"drone_agility_levels":
			UpgradeManager.levels["drone_agility"] += ni
		"drone_size_levels":
			UpgradeManager.levels["drone_size"] += ni
		"drone_cooldown_levels":
			UpgradeManager.levels["drone_cooldown"] += ni
		"spawn_drone":
			for i in ni:
				main.spawn_extra_drone()
		"drone_combo":
			UpgradeManager.levels["drone_speed"] += ni
			UpgradeManager.levels["drone_damage"] += ni
		"drone_all":
			for key in ["drone_speed", "drone_damage", "drone_agility", "drone_size", "drone_cooldown"]:
				UpgradeManager.levels[key] += ni
		_:
			return false
	return true


static func _apply_economy_effect(effect_key: String, n: float, ni: int, main) -> bool:
	match effect_key:
		"orbs_per_kill":
			main.orbs_per_kill += ni
		"pickup_radius_mul":
			main.orb_pickup_radius *= n
			main.refresh_pickup_radius()
		"chain_pickup":
			main.chain_pickup = true
		"dot_value_levels":
			UpgradeManager.levels["dot_value"] += ni
		"spawn_count_levels":
			UpgradeManager.levels["spawn_count"] += ni
		"orb_lifetime_add":
			main.orb_lifetime_bonus += n
		"orb_gravity":
			main.orb_gravity = true
		"orb_nova":
			main.orb_nova = true
		"orb_speed_mul":
			main.orb_speed_mul *= n
		"orb_time_bonus":
			main.orb_time_bonus += n
		"auto_collect_radius":
			main.auto_collect_radius = maxf(main.auto_collect_radius, n)
		"economy_combo":
			UpgradeManager.levels["dot_value"] += 6
			main.orbs_per_kill += 1
		_:
			return false
	return true


static func _apply_wildcard_effect(effect_key: String, n: float, ni: int, main) -> bool:
	match effect_key:
		"run_duration_add":
			main.run_duration += n
		"all_stats":
			for key in UpgradeManager.levels.keys():
				UpgradeManager.levels[key] += ni
			_apply_fire_rate(main)
		"turret_all":
			UpgradeManager.levels["fire_rate"] += ni
			UpgradeManager.levels["damage"] += ni
			_apply_fire_rate(main)
		"speed_combo":
			UpgradeManager.levels["fire_rate"] += ni
			UpgradeManager.levels["drone_speed"] += ni
			_apply_fire_rate(main)
		"rate_and_value":
			UpgradeManager.levels["fire_rate"] += ni
			UpgradeManager.levels["dot_value"] += ni
			_apply_fire_rate(main)
		"time_and_dots":
			main.run_duration += 45.0
			UpgradeManager.levels["spawn_count"] += 8
		"density_boost":
			UpgradeManager.levels["spawn_count"] += 8
			UpgradeManager.levels["dot_value"] += 4
		"efficient_trade":
			UpgradeManager.levels["spawn_count"] = max(0, UpgradeManager.levels["spawn_count"] - 3)
			UpgradeManager.levels["dot_value"] += 8
		"random_stat":
			var keys: Array = UpgradeManager.levels.keys()
			var key: String = keys[randi() % keys.size()]
			UpgradeManager.levels[key] += ni
			if key == "fire_rate":
				_apply_fire_rate(main)
		"random_three":
			var keys: Array = UpgradeManager.levels.keys().duplicate()
			keys.shuffle()
			for i in min(3, keys.size()):
				UpgradeManager.levels[keys[i]] += ni
			_apply_fire_rate(main)
		"compound_bonus":
			main.compound_bonus_percent = maxf(main.compound_bonus_percent, n)
			UpgradeManager.global_level_effect_bonus_percent = maxf(UpgradeManager.global_level_effect_bonus_percent, n)
		_:
			return false
	return true


static func _apply_combat_effect(effect_key: String, n: float, ni: int, main) -> bool:
	match effect_key:
		"bullet_bounce":
			main.bullet_bounces = max(main.bullet_bounces, ni)
		"bullet_wrap":
			main.bullet_wrap = true
		"mirror_bullet":
			main.mirror_bullets = true
		"dot_fire":
			ElementalEffectLibrary.apply_status_damage(main, "fire", n, 2.0)
		"dot_fire_duration":
			ElementalEffectLibrary.apply_status_duration(main, "fire", n)
		"dot_fire_permanent":
			ElementalEffectLibrary.apply_status_permanent(main, "fire")
		"fire_spread":
			ElementalEffectLibrary.apply_status_spread(main, "fire", ni)
		"fire_bonus_full_hp":
			ElementalEffectLibrary.apply_status_bonus(main, "fire", n)
		"dot_poison":
			ElementalEffectLibrary.apply_status_damage(main, "poison", n * 0.5, 3.0)
		"dot_duration":
			ElementalEffectLibrary.apply_status_duration(main, "poison", n)
		"dot_spread":
			ElementalEffectLibrary.apply_status_spread(main, "poison", ni)
		"dot_acid":
			ElementalEffectLibrary.apply_status_damage(main, "acid", n * 0.5, 4.0)
		"acid_stack":
			ElementalEffectLibrary.apply_status_stack_limit(main, "acid", ni)
		"acid_aoe":
			main.acid_aoe_damage = maxf(main.acid_aoe_damage, n)
		"acid_spread":
			ElementalEffectLibrary.apply_status_spread(main, "acid", ni)
			ElementalEffectLibrary.apply_status_stack_limit(main, "acid", 999)
		"dot_bleed":
			ElementalEffectLibrary.apply_status_damage(main, "bleed", n * 0.25, 5.0)
		"bleed_stack":
			ElementalEffectLibrary.apply_status_stack_limit(main, "bleed", ni)
		"bleed_orb_bonus":
			ElementalEffectLibrary.apply_status_bonus(main, "bleed", ni)
		"frost_slow":
			main.dot_respawn_delay = maxf(main.dot_respawn_delay, n)
		"frost_aoe":
			main.frost_aoe_damage = maxf(main.frost_aoe_damage, n)
		"frost_debuff":
			main.frost_debuff_multiplier = maxf(main.frost_debuff_multiplier, n)
		"chain_lightning":
			main.chain_lightning_hits = max(main.chain_lightning_hits, ni)
			if ni >= 6:
				main.chain_lightning_damage_multiplier = maxf(main.chain_lightning_damage_multiplier, 2.0)
		"chain_kill":
			main.chain_bonus_bullets = max(main.chain_bonus_bullets, ni)
		"shockwave":
			main.shockwave_damage = maxf(main.shockwave_damage, n)
		"kill_stack":
			main.kill_stack_percent = maxf(main.kill_stack_percent, n)
		"kill_stack_cap":
			main.kill_stack_cap_percent = maxf(main.kill_stack_cap_percent, n)
		"execute_bonus":
			main.execute_bonus_bullets = max(main.execute_bonus_bullets, ni)
		"volley_every":
			main.volley_every_kills = max(main.volley_every_kills, ni)
		"frenzy_stack":
			main.frenzy_stack_percent = maxf(main.frenzy_stack_percent, n)
		"chain_orb_bonus":
			main.chain_orb_bonus = max(main.chain_orb_bonus, ni)
		"orb_combo":
			main.orb_combo_threshold = max(main.orb_combo_threshold, ni)
		"orb_frenzy":
			main.orb_frenzy_threshold = max(main.orb_frenzy_threshold, ni)
		"solar_flare":
			main.solar_flare_every_shots = max(main.solar_flare_every_shots, ni)
		"void_pen":
			main.void_pen_percent = maxf(main.void_pen_percent, n)
		"cluster_every":
			main.cluster_every_shots = max(main.cluster_every_shots, ni)
			main.cluster_targets = max(main.cluster_targets, 6 if ni <= 10 else 3)
		"nuke_every":
			main.nuke_every_kills = max(main.nuke_every_kills, ni)
		"nuke_power":
			main.nuke_power_multiplier = maxf(main.nuke_power_multiplier, n)
		"screen_nuke":
			main.screen_nuke_damage = maxf(main.screen_nuke_damage, n)
		"emp_every":
			main.emp_every_kills = max(main.emp_every_kills, ni)
		"orbital_every":
			main.orbital_every_orbs = max(main.orbital_every_orbs, ni)
		"extinction":
			main.extinction_damage = maxf(main.extinction_damage, n)
			main.extinction_available = true
			main.trigger_extinction_event()
		"gravity_nuke":
			main.gravity_nuke = true
		"black_hole_every":
			main.black_hole_every_kills = max(main.black_hole_every_kills, ni)
		"hp_halve":
			main.dot_hp_scale = minf(main.dot_hp_scale, 0.5)
			for dot in main.get_tree().get_nodes_in_group("dots"):
				if dot.has_method("configure_runtime_modifiers"):
					dot.configure_runtime_modifiers(0.5)
		"per_draw_bonus":
			main.per_draw_bonus_levels += ni
		_:
			return false
	return true


static func _merge_flag(existing, key: String, value: float) -> Dictionary:
	var dictionary: Dictionary = existing if existing is Dictionary else {}
	dictionary[key] = dictionary.get(key, 0.0) + value
	return dictionary


static func _apply_fire_rate(main) -> void:
	var turret: Node = main.get_node_or_null("Turret")
	if turret:
		turret.get_node("ShooterComponent").fire_rate = UpgradeManager.get_fire_rate()


static func _apply_upgrade_level(upgrade_id: String, amount: int, main) -> bool:
	if upgrade_id.is_empty() or not UpgradeManager.levels.has(upgrade_id):
		return false
	UpgradeManager.levels[upgrade_id] += amount
	if upgrade_id == "fire_rate":
		_apply_fire_rate(main)
	return true


static func _apply_runtime_flag(main, property_name: String, operation: String, value: float) -> bool:
	if property_name.is_empty() or main.get(property_name) == null:
		return false

	match operation:
		"add":
			main.set(property_name, float(main.get(property_name)) + value)
		"mul":
			main.set(property_name, float(main.get(property_name)) * value)
		"max":
			main.set(property_name, maxf(float(main.get(property_name)), value))
		"bool":
			main.set(property_name, value > 0.0)
		_:
			return false
	return true

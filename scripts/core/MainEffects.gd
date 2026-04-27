extends RefCounted


static func apply_frost_aoe(main, origin: Vector2, damage_amount: float, kill_context: Dictionary = {}) -> void:
	var chain_depth: int = int(kill_context.get("chain_depth", 0)) + 1
	for dot in main.get_tree().get_nodes_in_group("dots"):
		if dot.global_position.distance_to(origin) <= 140.0:
			if dot.has_method("take_bullet_damage_with_context"):
				dot.take_bullet_damage_with_context(
					damage_amount,
					{
						"source": "frost_aoe",
						"chain_depth": chain_depth,
						"no_chain": true
					}
				)
			else:
				var health: HealthComponent = dot.get_node_or_null("HealthComponent")
				if health:
					health.take_damage(damage_amount)


static func handle_kill_triggers(main, pos: Vector2, kill_context: Dictionary) -> void:
	if kill_context.get("no_chain", false):
		return

	var now: float = main.run_timer
	var chain_depth: int = int(kill_context.get("chain_depth", 0))

	_handle_status_kill_effects(main, pos, kill_context)

	if main.chain_lightning_hits > 0:
		_fire_chain_lightning(main, pos, kill_context)

	if main.chain_bonus_bullets > 0:
		_fire_bonus_bullets(main, pos, main.chain_bonus_bullets, chain_depth + 1)

	if main.shockwave_damage > 0.0:
		_apply_shockwave(main, pos, main.shockwave_damage)

	if main.kill_stack_percent > 0.0:
		main._kill_stack_count += 1

	if main.execute_bonus_bullets > 0 and bool(kill_context.get("was_execute", false)):
		_fire_bonus_bullets(main, pos, main.execute_bonus_bullets, chain_depth + 1)

	if main.volley_every_kills > 0 and RunManager.dots_destroyed % main.volley_every_kills == 0:
		_fire_turret_volley(main)

	if main.nuke_every_kills > 0 and RunManager.dots_destroyed % main.nuke_every_kills == 0:
		_trigger_nuke(main, pos)

	if main.black_hole_every_kills > 0 and RunManager.dots_destroyed % main.black_hole_every_kills == 0:
		_trigger_black_hole(main, pos)

	if main.emp_every_kills > 0 and RunManager.dots_destroyed % main.emp_every_kills == 0:
		_trigger_emp(main)

	if main.frenzy_stack_percent > 0.0:
		if now - main._last_kill_time <= 2.0:
			main._frenzy_stacks += 1
		else:
			main._frenzy_stacks = 1
		main._last_kill_time = now
		main._frenzy_buff_until = now + 3.0
		main._refresh_fire_rate()


static func update_orb_combo_state(main) -> void:
	if main.orb_combo_threshold > 0:
		if main.run_timer > main._orb_combo_window_until:
			main._orb_combo_count = 0
		main._orb_combo_count += 1
		main._orb_combo_window_until = main.run_timer + 3.0
		if main._orb_combo_count >= main.orb_combo_threshold:
			main._orb_combo_count = 0
			_fire_mega_bullet(main)

	if main.orb_frenzy_threshold > 0:
		if main.run_timer > main._orb_frenzy_window_until:
			main._orb_frenzy_count = 0
		main._orb_frenzy_count += 1
		main._orb_frenzy_window_until = main.run_timer + 5.0
		if main._orb_frenzy_count >= main.orb_frenzy_threshold:
			main._orb_frenzy_count = 0
			main._orb_frenzy_until = main.run_timer + 5.0
			main.refresh_pickup_radius()


static func update_temporary_effects(main) -> void:
	if main._frenzy_stacks > 0 and main.run_timer > main._frenzy_buff_until:
		main._frenzy_stacks = 0
		main._refresh_fire_rate()

	if main._orb_frenzy_until > 0.0 and main.run_timer > main._orb_frenzy_until:
		main._orb_frenzy_until = 0.0
		main.refresh_pickup_radius()


static func consume_kill_stack_bonus(main) -> float:
	if main.kill_stack_percent <= 0.0 or main._kill_stack_count <= 0:
		return 1.0

	var bonus_percent := minf(main._kill_stack_count * main.kill_stack_percent, main.kill_stack_cap_percent)
	main._kill_stack_count = 0
	return 1.0 + bonus_percent / 100.0


static func get_frenzy_multiplier(main) -> float:
	if main.frenzy_stack_percent <= 0.0 or main._frenzy_stacks <= 0 or main.run_timer > main._frenzy_buff_until:
		return 1.0
	return 1.0 + (main._frenzy_stacks * main.frenzy_stack_percent) / 100.0


static func get_nearest_dot_from(main, origin: Vector2, excluded: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for dot in main.get_tree().get_nodes_in_group("dots"):
		if dot in excluded:
			continue
		var dist := origin.distance_to(dot.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = dot
	return nearest


static func _fire_chain_lightning(main, origin: Vector2, kill_context: Dictionary) -> void:
	var remaining: int = main.chain_lightning_hits
	var visited: Array = []
	var current_origin := origin
	var damage_amount: float = UpgradeManager.get_damage() * main.chain_lightning_damage_multiplier
	var base_depth := int(kill_context.get("chain_depth", 0))

	while remaining > 0:
		var next_dot := get_nearest_dot_from(main, current_origin, visited)
		if next_dot == null:
			return

		var health: HealthComponent = next_dot.get_node_or_null("HealthComponent")
		if health:
			if next_dot.has_method("take_bullet_damage_with_context"):
				next_dot.take_bullet_damage_with_context(
					damage_amount,
					{
						"source": "chain_lightning",
						"chain_depth": base_depth + 1,
						"damage_multiplier": main.chain_lightning_damage_multiplier,
						"no_chain": true
					}
				)
			else:
				health.take_damage(damage_amount)

		visited.append(next_dot)
		current_origin = next_dot.global_position
		remaining -= 1


static func _fire_bonus_bullets(main, origin: Vector2, count: int, chain_depth: int) -> void:
	for i in count:
		var target := get_nearest_dot_from(main, origin, [])
		if target == null:
			return
		var spread := float(i - (count - 1) * 0.5) * 0.08
		var direction := (target.global_position - origin).normalized().rotated(spread)
		main.spawn_runtime_bullet(main.turret.bullet_scene, origin, direction, true, 1.0, chain_depth, false, true)


static func _apply_shockwave(main, origin: Vector2, damage_amount: float) -> void:
	_apply_area_damage(main, origin, 150.0, damage_amount, {"source": "shockwave", "no_chain": true})


static func _fire_turret_volley(main) -> void:
	for i in 8:
		var angle := (TAU * float(i)) / 8.0
		main.spawn_runtime_bullet(main.turret.bullet_scene, main.turret.global_position, Vector2.RIGHT.rotated(angle), true, 1.0, 0, false, true)


static func _fire_mega_bullet(main) -> void:
	var target := get_nearest_dot_from(main, main.turret.global_position, [])
	if target == null:
		return
	var direction: Vector2 = (target.global_position - main.turret.global_position).normalized()
	main.spawn_runtime_bullet(main.turret.bullet_scene, main.turret.global_position, direction, true, 5.0, 0, false, true)


static func handle_projectile_impact(main, impact_position: Vector2, target: Area2D, effect_payload: Dictionary, chain_depth: int) -> void:
	var detonation_radius: float = float(effect_payload.get("detonation_radius", 0.0))
	var detonation_damage: float = float(effect_payload.get("detonation_damage", 0.0))
	if detonation_radius > 0.0 and detonation_damage > 0.0:
		_apply_area_damage(
			main,
			target.global_position if target else impact_position,
			detonation_radius,
			detonation_damage,
			{"source": "solar_flare", "chain_depth": chain_depth + 1, "no_chain": true}
		)

	var cluster_targets: int = int(effect_payload.get("cluster_targets", 0))
	if cluster_targets > 0:
		_spawn_cluster_shots(main, impact_position, cluster_targets, chain_depth + 1)


static func fire_orb_nova(main, origin: Vector2) -> void:
	for i in 8:
		var angle := (TAU * float(i)) / 8.0
		main.spawn_runtime_bullet(main.turret.bullet_scene, origin, Vector2.RIGHT.rotated(angle), true, 1.0, 1, false, true)


static func apply_orbital_strike(main, origin: Vector2) -> void:
	_trigger_nuke(main, origin, 1.25, 1.0)


static func trigger_extinction_event(main) -> void:
	var damage := maxf(main.extinction_damage, main.screen_nuke_damage)
	if damage > 0.0:
		_apply_area_damage(main, main.turret.global_position, 99999.0, damage, {"source": "extinction", "no_chain": true})


static func _handle_status_kill_effects(main, origin: Vector2, kill_context: Dictionary) -> void:
	var status_effects: Dictionary = kill_context.get("status_effects", {})
	if status_effects.is_empty():
		return

	for status_name in status_effects.keys():
		var effect: Dictionary = status_effects[status_name] as Dictionary
		var spread_count: int = int(effect.get("spread_count", 0))
		if spread_count > 0:
			_spread_status(main, origin, status_name, effect, spread_count)

	if str(kill_context.get("source", "")) == "acid" and main.acid_aoe_damage > 0.0:
		_apply_area_damage(main, origin, 130.0, main.acid_aoe_damage, {"source": "acid_aoe", "no_chain": true})


static func _spread_status(main, origin: Vector2, status_name: String, effect: Dictionary, count: int) -> void:
	var visited: Array = []
	var current_origin := origin
	for i in count:
		var next_dot := get_nearest_dot_from(main, current_origin, visited)
		if next_dot == null:
			return
		if next_dot.has_method("apply_status_effect"):
			next_dot.apply_status_effect(status_name, effect)
		visited.append(next_dot)
		current_origin = next_dot.global_position


static func _spawn_cluster_shots(main, origin: Vector2, count: int, chain_depth: int) -> void:
	for i in count:
		var target := get_nearest_dot_from(main, origin, [])
		if target == null:
			return
		var spread := float(i - (count - 1) * 0.5) * 0.16
		var direction := (target.global_position - origin).normalized().rotated(spread)
		main.spawn_runtime_bullet(main.turret.bullet_scene, origin, direction, true, 1.0, chain_depth, false, true)


static func _trigger_nuke(main, origin: Vector2, damage_multiplier: float = 1.0, radius_multiplier: float = 1.0) -> void:
	var damage := maxf(UpgradeManager.get_damage() * 2.0 * main.nuke_power_multiplier * damage_multiplier, 1.0)
	var radius := 180.0 * maxf(1.0, main.nuke_power_multiplier) * radius_multiplier
	if main.gravity_nuke:
		for dot in main.get_tree().get_nodes_in_group("dots"):
			dot.global_position = dot.global_position.lerp(origin, 0.45)

	if main.screen_nuke_damage > 0.0:
		_apply_area_damage(main, origin, 99999.0, maxf(main.screen_nuke_damage, damage), {"source": "screen_nuke", "no_chain": true})
	else:
		_apply_area_damage(main, origin, radius, damage, {"source": "nuke", "no_chain": true})


static func _trigger_black_hole(main, origin: Vector2) -> void:
	var visited: Array = []
	var current_origin := origin
	for i in 3:
		var target := get_nearest_dot_from(main, current_origin, visited)
		if target == null:
			return
		if target.has_method("take_bullet_damage_with_context"):
			target.take_bullet_damage_with_context(999999.0, {"source": "black_hole", "no_chain": true})
		visited.append(target)
		current_origin = target.global_position


static func _trigger_emp(main) -> void:
	for dot in main.get_tree().get_nodes_in_group("dots"):
		if dot.has_method("apply_emp_stun"):
			dot.apply_emp_stun(1.0)


static func _apply_area_damage(main, origin: Vector2, radius: float, damage_amount: float, context: Dictionary) -> void:
	for dot in main.get_tree().get_nodes_in_group("dots"):
		if dot.global_position.distance_to(origin) <= radius:
			if dot.has_method("take_bullet_damage_with_context"):
				dot.take_bullet_damage_with_context(damage_amount, context)
			else:
				var health: HealthComponent = dot.get_node_or_null("HealthComponent")
				if health:
					health.take_damage(damage_amount)

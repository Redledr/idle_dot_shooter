extends Node2D

@export var dot_scene: PackedScene
@export var drone_scene: PackedScene
@export var orb_scene: PackedScene
@export var spawn_margin: float = 60.0

@export var run_duration: float = 300.0
@export var card_draw_interval: int = 10
@export var orb_pickup_radius: float = 32.0

# Runtime flags — set by cards
var bullets_pierce: bool = false
var orbs_per_kill: int = 1
var chain_pickup: bool = false
var auto_collect_radius: float = 0.0
var bullet_bounces: int = 0
var mirror_bullets: bool = false
var bullet_wrap: bool = false
var dot_fire_damage: float = 0.0
var dot_respawn_delay: float = 0.0
var frost_debuff_multiplier: float = 1.0
var frost_aoe_damage: float = 0.0
var chain_lightning_hits: int = 0
var chain_lightning_damage_multiplier: float = 1.0
var chain_bonus_bullets: int = 0
var shockwave_damage: float = 0.0
var kill_stack_percent: float = 0.0
var kill_stack_cap_percent: float = 100.0
var execute_bonus_bullets: int = 0
var volley_every_kills: int = 0
var frenzy_stack_percent: float = 0.0
var chain_orb_bonus: int = 0
var orb_combo_threshold: int = 0
var orb_frenzy_threshold: int = 0
var per_draw_bonus_levels: int = 0
var dot_hp_scale: float = 1.0
var card_flags: Dictionary = {}

const DRONE_UNLOCK_THRESHOLD := 100
const END_OF_RUN_SCENE := "res://ui/EndOfRunScreen.tscn"
const CARD_DRAW_SCENE := "res://ui/CardDrawScreen.tscn"

var currency: float = 0.0
var run_timer: float = 0.0
var run_active: bool = false

var _screen_size: Vector2
var _base_orb_pickup_radius: float = 32.0
var _drone_unlocked: bool = false
var _next_card_draw: int = 0
var _card_draw_open: bool = false
var _dot_respawn_queue: Array[float] = []
var _kill_stack_count: int = 0
var _last_kill_time: float = -100.0
var _frenzy_stacks: int = 0
var _frenzy_buff_until: float = 0.0
var _orb_combo_count: int = 0
var _orb_combo_window_until: float = 0.0
var _orb_frenzy_count: int = 0
var _orb_frenzy_window_until: float = 0.0
var _orb_frenzy_until: float = 0.0

@onready var hud = $HUD
@onready var turret = $Turret
@onready var cursor = $Cursor


func _ready() -> void:
	add_to_group("main")
	_screen_size = get_viewport_rect().size
	_base_orb_pickup_radius = orb_pickup_radius
	refresh_pickup_radius()
	# Keep HUD and cursor alive during card draw pause
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	cursor.process_mode = Node.PROCESS_MODE_ALWAYS
	RunManager.start_run()
	_start_run()


func _start_run() -> void:
	currency = 0.0
	run_timer = 0.0
	_next_card_draw = card_draw_interval
	run_active = true
	bullets_pierce = false
	orbs_per_kill = 1
	chain_pickup = false
	orb_pickup_radius = _base_orb_pickup_radius
	auto_collect_radius = 0.0
	bullet_bounces = 0
	mirror_bullets = false
	bullet_wrap = false
	dot_fire_damage = 0.0
	dot_respawn_delay = 0.0
	frost_debuff_multiplier = 1.0
	frost_aoe_damage = 0.0
	chain_lightning_hits = 0
	chain_lightning_damage_multiplier = 1.0
	chain_bonus_bullets = 0
	shockwave_damage = 0.0
	kill_stack_percent = 0.0
	kill_stack_cap_percent = 100.0
	execute_bonus_bullets = 0
	volley_every_kills = 0
	frenzy_stack_percent = 0.0
	chain_orb_bonus = 0
	orb_combo_threshold = 0
	orb_frenzy_threshold = 0
	per_draw_bonus_levels = 0
	dot_hp_scale = 1.0
	card_flags.clear()
	_dot_respawn_queue.clear()
	_kill_stack_count = 0
	_last_kill_time = -100.0
	_frenzy_stacks = 0
	_frenzy_buff_until = 0.0
	_orb_combo_count = 0
	_orb_combo_window_until = 0.0
	_orb_frenzy_count = 0
	_orb_frenzy_window_until = 0.0
	_orb_frenzy_until = 0.0
	refresh_pickup_radius()
	_refresh_fire_rate()
	_fill_dots()
	hud.update_display(currency, RunManager.dots_destroyed, run_duration)


func _process(delta: float) -> void:
	if not run_active or _card_draw_open:
		return

	run_timer += delta
	if run_timer >= run_duration:
		_end_run()
		return

	_update_temporary_effects()
	_process_dot_respawns()

	var current := get_tree().get_nodes_in_group("dots").size()
	if current + _dot_respawn_queue.size() < UpgradeManager.get_dot_count():
		_spawn_dot()

	hud.update_timer(run_duration - run_timer)


func _end_run() -> void:
	run_active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(END_OF_RUN_SCENE)


func spawn_orb(pos: Vector2, value: float, kill_context: Dictionary = {}) -> void:
	RunManager.dots_destroyed += 1
	if not _drone_unlocked and RunManager.dots_destroyed >= DRONE_UNLOCK_THRESHOLD:
		_unlock_drone()

	if orb_scene == null:
		return

	var orb_count := orbs_per_kill + max(0, int(kill_context.get("chain_depth", 0))) * chain_orb_bonus
	for i in orb_count:
		var orb := orb_scene.instantiate()
		add_child(orb)
		var scatter := Vector2(randf_range(-20, 20), randf_range(-20, 20)) * i
		orb.init(pos + scatter, value * UpgradeManager.get_dot_value())
		RunManager.register_orb_spawn(orb.get_instance_id())

	if auto_collect_radius > 0.0:
		_auto_collect_nearby_orbs(pos)

	if dot_respawn_delay > 0.0:
		_schedule_dot_respawn(dot_respawn_delay)

	if frost_aoe_damage > 0.0:
		_apply_frost_aoe(pos, frost_aoe_damage)

	_handle_kill_triggers(pos, kill_context)


func on_orb_collected(orb_id: int, value: float) -> void:
	currency += value
	RunManager.currency_earned += value
	RunManager.register_orb_collected(orb_id)
	hud.update_display(currency, RunManager.dots_destroyed, run_duration - run_timer)

	_update_orb_combo_state()

	# Chain pickup — pull nearby orbs
	if chain_pickup:
		_pull_nearby_orbs(get_global_mouse_position())

	# Card draw check
	if RunManager.orbs_collected >= _next_card_draw:
		_next_card_draw += card_draw_interval
		_open_card_draw()


func _pull_nearby_orbs(origin: Vector2) -> void:
	for orb in get_tree().get_nodes_in_group("orbs"):
		if orb.global_position.distance_to(origin) < get_effective_pickup_radius() * 3.0:
			orb.pull_to(origin)


func _open_card_draw() -> void:
	if per_draw_bonus_levels > 0:
		_apply_global_upgrade_bonus(per_draw_bonus_levels)
	_card_draw_open = true
	get_tree().paused = true
	cursor.set_gameplay_mode(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var scene: PackedScene = load(CARD_DRAW_SCENE) as PackedScene
	var card_draw: Node = scene.instantiate()
	card_draw.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(card_draw)
	card_draw.connect("card_chosen", _on_card_chosen.bind(card_draw))


func _on_card_chosen(card_id: String, card_draw_node: Node) -> void:
	CardDatabase.apply_card(card_id, self)
	card_draw_node.queue_free()
	_card_draw_open = false
	get_tree().paused = false
	cursor.set_gameplay_mode(true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	hud.show_notification(CardDatabase.get_card(card_id).get("name", "") + " applied!")


func spawn_extra_drone() -> void:
	_spawn_drone()


func _unlock_drone() -> void:
	if _drone_unlocked:
		return
	_drone_unlocked = true
	_spawn_drone()
	hud.show_notification("Drone unlocked!")


func _spawn_drone() -> void:
	if drone_scene == null:
		return
	var drone := drone_scene.instantiate()
	add_child(drone)
	drone.init(turret.global_position)
	var upgrade_panel := get_node_or_null("CanvasLayer")
	if upgrade_panel and upgrade_panel.has_method("notify_drone_spawned"):
		upgrade_panel.notify_drone_spawned()


func _fill_dots() -> void:
	for i in UpgradeManager.get_dot_count():
		_spawn_dot()


func _spawn_dot() -> void:
	if dot_scene == null:
		return
	var dot := dot_scene.instantiate()
	add_child(dot)
	dot.position = _random_play_area_position()
	if dot.has_method("configure_runtime_modifiers"):
		dot.configure_runtime_modifiers(dot_hp_scale)


func spawn_runtime_bullet(
	projectile_scene: PackedScene,
	origin: Vector2,
	direction: Vector2,
	allow_mirror: bool = true,
	damage_multiplier: float = 1.0,
	chain_depth: int = 0,
	consume_kill_stack: bool = true
) -> void:
	if projectile_scene == null:
		return

	var bullet := projectile_scene.instantiate()
	add_child(bullet)
	bullet.global_position = origin
	if bullet.has_method("set_direction"):
		bullet.set_direction(direction)
	var applied_damage_multiplier := damage_multiplier
	if consume_kill_stack:
		applied_damage_multiplier *= _consume_kill_stack_bonus()
	if bullet.has_method("configure_runtime_effects"):
		bullet.configure_runtime_effects(
			bullet_bounces,
			dot_fire_damage,
			bullet_wrap,
			frost_debuff_multiplier,
			applied_damage_multiplier,
			chain_depth
		)

	if mirror_bullets and allow_mirror:
		var perpendicular := Vector2(-direction.y, direction.x) * 14.0
		spawn_runtime_bullet(projectile_scene, origin - perpendicular, direction, false, applied_damage_multiplier, chain_depth, false)


func _auto_collect_nearby_orbs(origin: Vector2) -> void:
	for orb in get_tree().get_nodes_in_group("orbs"):
		if orb.global_position.distance_to(origin) <= auto_collect_radius:
			if orb.has_method("collect_now"):
				orb.collect_now()


func _schedule_dot_respawn(delay: float) -> void:
	_dot_respawn_queue.append(run_timer + delay)
	_dot_respawn_queue.sort()


func _process_dot_respawns() -> void:
	while not _dot_respawn_queue.is_empty() and _dot_respawn_queue[0] <= run_timer:
		if get_tree().get_nodes_in_group("dots").size() < UpgradeManager.get_dot_count():
			_spawn_dot()
		_dot_respawn_queue.pop_front()


func _apply_frost_aoe(origin: Vector2, damage_amount: float) -> void:
	for dot in get_tree().get_nodes_in_group("dots"):
		if dot.global_position.distance_to(origin) <= 140.0:
			var health: HealthComponent = dot.get_node_or_null("HealthComponent")
			if health:
				health.take_damage(damage_amount)


func _apply_global_upgrade_bonus(levels_to_add: int) -> void:
	for key in UpgradeManager.levels.keys():
		UpgradeManager.levels[key] += levels_to_add
	_refresh_fire_rate()


func _handle_kill_triggers(pos: Vector2, kill_context: Dictionary) -> void:
	var now := run_timer
	var chain_depth := int(kill_context.get("chain_depth", 0))

	if chain_lightning_hits > 0:
		_fire_chain_lightning(pos)

	if chain_bonus_bullets > 0:
		_fire_bonus_bullets(pos, chain_bonus_bullets, chain_depth + 1)

	if shockwave_damage > 0.0:
		_apply_shockwave(pos, shockwave_damage)

	if kill_stack_percent > 0.0:
		_kill_stack_count += 1

	if execute_bonus_bullets > 0 and bool(kill_context.get("was_execute", false)):
		_fire_bonus_bullets(pos, execute_bonus_bullets, chain_depth + 1)

	if volley_every_kills > 0 and RunManager.dots_destroyed % volley_every_kills == 0:
		_fire_turret_volley()

	if frenzy_stack_percent > 0.0:
		if now - _last_kill_time <= 2.0:
			_frenzy_stacks += 1
		else:
			_frenzy_stacks = 1
		_last_kill_time = now
		_frenzy_buff_until = now + 3.0
		_refresh_fire_rate()


func _fire_chain_lightning(origin: Vector2) -> void:
	var remaining := chain_lightning_hits
	var visited: Array = []
	var current_origin := origin
	var damage_amount := UpgradeManager.get_damage() * chain_lightning_damage_multiplier

	while remaining > 0:
		var next_dot := _get_nearest_dot_from(current_origin, visited)
		if next_dot == null:
			return
		var health: HealthComponent = next_dot.get_node_or_null("HealthComponent")
		if health:
			if next_dot.has_method("take_bullet_damage_with_context"):
				next_dot.take_bullet_damage_with_context(
					damage_amount,
					{"source": "chain_lightning", "chain_depth": 0, "damage_multiplier": chain_lightning_damage_multiplier}
				)
			else:
				health.take_damage(damage_amount)
		visited.append(next_dot)
		current_origin = next_dot.global_position
		remaining -= 1


func _fire_bonus_bullets(origin: Vector2, count: int, chain_depth: int) -> void:
	for i in count:
		var target := _get_nearest_dot_from(origin, [])
		if target == null:
			return
		var spread := float(i - (count - 1) * 0.5) * 0.08
		var direction := (target.global_position - origin).normalized().rotated(spread)
		spawn_runtime_bullet(turret.bullet_scene, origin, direction, true, 1.0, chain_depth, false)


func _apply_shockwave(origin: Vector2, damage_amount: float) -> void:
	for dot in get_tree().get_nodes_in_group("dots"):
		if dot.global_position.distance_to(origin) <= 150.0:
			var health: HealthComponent = dot.get_node_or_null("HealthComponent")
			if health:
				health.take_damage(damage_amount)


func _fire_turret_volley() -> void:
	for i in 8:
		var angle := (TAU * float(i)) / 8.0
		spawn_runtime_bullet(turret.bullet_scene, turret.global_position, Vector2.RIGHT.rotated(angle), true, 1.0, 0, false)


func _update_orb_combo_state() -> void:
	if orb_combo_threshold > 0:
		if run_timer > _orb_combo_window_until:
			_orb_combo_count = 0
		_orb_combo_count += 1
		_orb_combo_window_until = run_timer + 3.0
		if _orb_combo_count >= orb_combo_threshold:
			_orb_combo_count = 0
			_fire_mega_bullet()

	if orb_frenzy_threshold > 0:
		if run_timer > _orb_frenzy_window_until:
			_orb_frenzy_count = 0
		_orb_frenzy_count += 1
		_orb_frenzy_window_until = run_timer + 5.0
		if _orb_frenzy_count >= orb_frenzy_threshold:
			_orb_frenzy_count = 0
			_orb_frenzy_until = run_timer + 5.0
			_refresh_pickup_radius()


func _fire_mega_bullet() -> void:
	var target := _get_nearest_dot_from(turret.global_position, [])
	if target == null:
		return
	var direction := (target.global_position - turret.global_position).normalized()
	spawn_runtime_bullet(turret.bullet_scene, turret.global_position, direction, true, 5.0, 0, false)


func _update_temporary_effects() -> void:
	if _frenzy_stacks > 0 and run_timer > _frenzy_buff_until:
		_frenzy_stacks = 0
		_refresh_fire_rate()

	if _orb_frenzy_until > 0.0 and run_timer > _orb_frenzy_until:
		_orb_frenzy_until = 0.0
		_refresh_pickup_radius()


func _consume_kill_stack_bonus() -> float:
	if kill_stack_percent <= 0.0 or _kill_stack_count <= 0:
		return 1.0

	var bonus_percent := minf(_kill_stack_count * kill_stack_percent, kill_stack_cap_percent)
	_kill_stack_count = 0
	return 1.0 + bonus_percent / 100.0


func _get_nearest_dot_from(origin: Vector2, excluded: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for dot in get_tree().get_nodes_in_group("dots"):
		if dot in excluded:
			continue
		var dist := origin.distance_to(dot.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = dot
	return nearest


func _refresh_fire_rate() -> void:
	var shooter := turret.get_node_or_null("ShooterComponent")
	if shooter:
		shooter.fire_rate = UpgradeManager.get_fire_rate() * _get_frenzy_multiplier()


func _get_frenzy_multiplier() -> float:
	if frenzy_stack_percent <= 0.0 or _frenzy_stacks <= 0 or run_timer > _frenzy_buff_until:
		return 1.0
	return 1.0 + (_frenzy_stacks * frenzy_stack_percent) / 100.0


func refresh_pickup_radius() -> void:
	cursor.radius = get_effective_pickup_radius()


func get_effective_pickup_radius() -> float:
	if _orb_frenzy_until > run_timer:
		return orb_pickup_radius * 2.0
	return orb_pickup_radius


func _random_play_area_position() -> Vector2:
	return Vector2(
		randf_range(spawn_margin, _screen_size.x - spawn_margin),
		randf_range(spawn_margin, _screen_size.y * 0.70)
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _screen_size), Color(0.04, 0.04, 0.04))
	for y in range(0, int(_screen_size.y), 4):
		draw_line(Vector2(0, y), Vector2(_screen_size.x, y), Color(1, 1, 1, 0.025), 1.0)
	var cx := _screen_size.x / 2.0
	for i in 5:
		var x := cx - 340.0 + i * 170.0
		draw_line(Vector2(x, 0), Vector2(x, _screen_size.y), Color(1, 1, 1, 0.04), 1.0)

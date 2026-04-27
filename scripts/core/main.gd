extends Node2D

const MainEffects = preload("res://scripts/core/MainEffects.gd")
const ElementalEffectLibrary = preload("res://systems/progression/ElementalEffectLibrary.gd")

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
var orb_lifetime_bonus: float = 0.0
var orb_gravity: bool = false
var orb_nova: bool = false
var orb_speed_mul: float = 1.0
var orb_time_bonus: float = 0.0
var dot_fire_duration: float = 2.0
var dot_fire_permanent: bool = false
var fire_spread_count: int = 0
var fire_bonus_full_hp_multiplier: float = 1.0
var dot_poison_damage: float = 0.0
var dot_poison_duration: float = 3.0
var dot_poison_spread_count: int = 0
var dot_acid_damage: float = 0.0
var dot_acid_duration: float = 4.0
var acid_stack_limit: int = 1
var acid_aoe_damage: float = 0.0
var acid_spread_count: int = 0
var dot_bleed_damage: float = 0.0
var dot_bleed_duration: float = 5.0
var bleed_stack_limit: int = 1
var bleed_orb_multiplier: int = 1
var solar_flare_every_shots: int = 0
var void_pen_percent: float = 0.0
var cluster_every_shots: int = 0
var cluster_targets: int = 0
var nuke_every_kills: int = 0
var nuke_power_multiplier: float = 1.0
var screen_nuke_damage: float = 0.0
var emp_every_kills: int = 0
var orbital_every_orbs: int = 0
var extinction_damage: float = 0.0
var extinction_available: bool = false
var gravity_nuke: bool = false
var black_hole_every_kills: int = 0
var compound_bonus_percent: float = 0.0

const DRONE_UNLOCK_THRESHOLD := 100
const END_OF_RUN_SCENE := "res://ui/screens/EndOfRunScreen.tscn"
const CARD_DRAW_SCENE := "res://ui/screens/CardDrawScreen.tscn"
const MAX_ACTIVE_ORBS := 1200
const MAX_ORBS_PER_SPAWN := 24
const MAX_ACTIVE_BULLETS := 320
const MAX_ACTIVE_PROC_BULLETS := 96
const MAX_PROC_BULLETS_PER_FRAME := 48

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
var _shots_fired: int = 0
var _active_orb_count: int = 0
var _active_bullet_count: int = 0
var _active_proc_bullet_count: int = 0
var _proc_bullets_spawned_this_frame: int = 0
var _proc_bullet_frame_id: int = -1

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
	UpgradeManager.reset_runtime_modifiers()
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
	orb_lifetime_bonus = 0.0
	orb_gravity = false
	orb_nova = false
	orb_speed_mul = 1.0
	orb_time_bonus = 0.0
	dot_fire_duration = 2.0
	dot_fire_permanent = false
	fire_spread_count = 0
	fire_bonus_full_hp_multiplier = 1.0
	dot_poison_damage = 0.0
	dot_poison_duration = 3.0
	dot_poison_spread_count = 0
	dot_acid_damage = 0.0
	dot_acid_duration = 4.0
	acid_stack_limit = 1
	acid_aoe_damage = 0.0
	acid_spread_count = 0
	dot_bleed_damage = 0.0
	dot_bleed_duration = 5.0
	bleed_stack_limit = 1
	bleed_orb_multiplier = 1
	solar_flare_every_shots = 0
	void_pen_percent = 0.0
	cluster_every_shots = 0
	cluster_targets = 0
	nuke_every_kills = 0
	nuke_power_multiplier = 1.0
	screen_nuke_damage = 0.0
	emp_every_kills = 0
	orbital_every_orbs = 0
	extinction_damage = 0.0
	extinction_available = false
	gravity_nuke = false
	black_hole_every_kills = 0
	compound_bonus_percent = 0.0
	_shots_fired = 0
	_active_orb_count = 0
	_active_bullet_count = 0
	_active_proc_bullet_count = 0
	_proc_bullets_spawned_this_frame = 0
	_proc_bullet_frame_id = -1


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

	var orb_multiplier: int = max(1, int(kill_context.get("orb_multiplier", 1)))
	var raw_orb_count: int = max(1, (orbs_per_kill + max(0, int(kill_context.get("chain_depth", 0))) * chain_orb_bonus) * orb_multiplier)
	var value_per_orb: float = value * UpgradeManager.get_dot_value()
	var total_orb_value: float = value_per_orb * raw_orb_count
	var remaining_slots: int = max(0, MAX_ACTIVE_ORBS - _active_orb_count)
	var spawn_count: int = min(raw_orb_count, MAX_ORBS_PER_SPAWN)
	spawn_count = min(spawn_count, remaining_slots)

	if spawn_count <= 0:
		_merge_orb_value_into_existing(pos, total_orb_value)
	else:
		var packed_value: float = total_orb_value / float(spawn_count)
		for i in spawn_count:
			var orb := orb_scene.instantiate()
			add_child(orb)
			var scatter: Vector2 = Vector2(randf_range(-20, 20), randf_range(-20, 20)) * i
			orb.init(pos + scatter, packed_value)
			_active_orb_count += 1
			RunManager.register_orb_spawn(orb.get_instance_id())

		var overflow_value: float = total_orb_value - packed_value * spawn_count
		if overflow_value > 0.0:
			_merge_orb_value_into_existing(pos, overflow_value)

	if auto_collect_radius > 0.0:
		_auto_collect_nearby_orbs(pos)

	if dot_respawn_delay > 0.0:
		_schedule_dot_respawn(dot_respawn_delay)

	if frost_aoe_damage > 0.0 and not bool(kill_context.get("no_chain", false)):
		MainEffects.apply_frost_aoe(self, pos, frost_aoe_damage, kill_context)

	MainEffects.handle_kill_triggers(self, pos, kill_context)


func on_orb_collected(orb_id: int, value: float, orb_position: Vector2 = Vector2.ZERO) -> void:
	currency += value
	RunManager.currency_earned += value
	RunManager.register_orb_collected(orb_id)

	if orb_time_bonus > 0.0:
		run_timer = maxf(0.0, run_timer - orb_time_bonus)

	hud.update_display(currency, RunManager.dots_destroyed, run_duration - run_timer)

	_update_orb_combo_state()

	if orb_nova:
		MainEffects.fire_orb_nova(self, orb_position)

	if orbital_every_orbs > 0 and RunManager.orbs_collected % orbital_every_orbs == 0:
		MainEffects.apply_orbital_strike(self, orb_position)

	# Chain pickup — pull nearby orbs
	if chain_pickup:
		_pull_nearby_orbs(get_global_mouse_position())

	# Card draw check
	if not _card_draw_open and RunManager.orbs_collected >= _next_card_draw:
		_next_card_draw += card_draw_interval
		_open_card_draw()


func _pull_nearby_orbs(origin: Vector2) -> void:
	for orb in get_tree().get_nodes_in_group("orbs"):
		if orb.global_position.distance_to(origin) < get_effective_pickup_radius() * 3.0:
			orb.pull_to(origin)


func _open_card_draw() -> void:
	if _card_draw_open:
		return
	if per_draw_bonus_levels > 0:
		_apply_global_upgrade_bonus(per_draw_bonus_levels)
	_card_draw_open = true
	visible = false
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
	_next_card_draw = RunManager.orbs_collected + card_draw_interval
	visible = true
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
	consume_kill_stack: bool = true,
	is_proc_bullet: bool = false
) -> void:
	call_deferred(
		"_spawn_runtime_bullet_deferred",
		projectile_scene,
		origin,
		direction,
		allow_mirror,
		damage_multiplier,
		chain_depth,
		consume_kill_stack,
		is_proc_bullet
	)

func _spawn_runtime_bullet_deferred(
	projectile_scene: PackedScene,
	origin: Vector2,
	direction: Vector2,
	allow_mirror: bool,
	damage_multiplier: float,
	chain_depth: int,
	consume_kill_stack: bool,
	is_proc_bullet: bool
) -> void:
	if projectile_scene == null:
		return
	if is_proc_bullet and not _can_spawn_proc_bullet():
		return
	if _active_bullet_count >= MAX_ACTIVE_BULLETS:
		return
	if get_tree().get_nodes_in_group("dots").is_empty():
		return

	var bullet := projectile_scene.instantiate()
	add_child(bullet)
	bullet.global_position = origin
	_active_bullet_count += 1
	if is_proc_bullet:
		_active_proc_bullet_count += 1

	if bullet.has_method("set_direction"):
		bullet.set_direction(direction)

	var applied_damage_multiplier := damage_multiplier
	if consume_kill_stack:
		applied_damage_multiplier *= MainEffects.consume_kill_stack_bonus(self)

	var count_for_shot_triggers := chain_depth == 0 and allow_mirror
	var projectile_effect_payload := _build_projectile_effect_payload(count_for_shot_triggers)

	if bullet.has_method("configure_runtime_effects"):
		bullet.configure_runtime_effects(
			bullet_bounces,
			dot_fire_damage,
			bullet_wrap,
			frost_debuff_multiplier,
			applied_damage_multiplier,
			chain_depth,
			projectile_effect_payload,
			is_proc_bullet
		)

	if mirror_bullets and allow_mirror:
		var perpendicular := Vector2(-direction.y, direction.x) * 14.0
		spawn_runtime_bullet(
			projectile_scene,
			origin - perpendicular,
			direction,
			false,
			applied_damage_multiplier,
			chain_depth,
			false,
			is_proc_bullet
		)


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


func _apply_global_upgrade_bonus(levels_to_add: int) -> void:
	for key in UpgradeManager.levels.keys():
		UpgradeManager.levels[key] += levels_to_add
	_refresh_fire_rate()


func _update_orb_combo_state() -> void:
	MainEffects.update_orb_combo_state(self)


func _update_temporary_effects() -> void:
	MainEffects.update_temporary_effects(self)


func _refresh_fire_rate() -> void:
	var shooter := turret.get_node_or_null("ShooterComponent")
	if shooter:
		shooter.fire_rate = UpgradeManager.get_fire_rate() * MainEffects.get_frenzy_multiplier(self)


func _build_projectile_effect_payload(count_for_shot_triggers: bool) -> Dictionary:
	return ElementalEffectLibrary.build_projectile_payload(self, count_for_shot_triggers)


func handle_projectile_impact(impact_position: Vector2, target: Area2D, effect_payload: Dictionary, chain_depth: int) -> void:
	MainEffects.handle_projectile_impact(self, impact_position, target, effect_payload, chain_depth)


func trigger_extinction_event() -> void:
	if extinction_available and extinction_damage > 0.0:
		extinction_available = false
		MainEffects.trigger_extinction_event(self)


func refresh_pickup_radius() -> void:
	cursor.radius = get_effective_pickup_radius()


func get_effective_pickup_radius() -> float:
	if _orb_frenzy_until > run_timer:
		return orb_pickup_radius * 2.0
	return orb_pickup_radius


func on_orb_removed() -> void:
	_active_orb_count = max(0, _active_orb_count - 1)


func get_active_orb_count() -> int:
	return _active_orb_count


func on_bullet_removed(is_proc_bullet: bool = false) -> void:
	_active_bullet_count = max(0, _active_bullet_count - 1)
	if is_proc_bullet:
		_active_proc_bullet_count = max(0, _active_proc_bullet_count - 1)


func get_active_bullet_count() -> int:
	return _active_bullet_count


func get_active_proc_bullet_count() -> int:
	return _active_proc_bullet_count


func _can_spawn_proc_bullet() -> bool:
	var frame_id: int = Engine.get_process_frames()
	if frame_id != _proc_bullet_frame_id:
		_proc_bullet_frame_id = frame_id
		_proc_bullets_spawned_this_frame = 0
	if _active_proc_bullet_count >= MAX_ACTIVE_PROC_BULLETS:
		return false
	if _proc_bullets_spawned_this_frame >= MAX_PROC_BULLETS_PER_FRAME:
		return false
	_proc_bullets_spawned_this_frame += 1
	return true


func _random_play_area_position() -> Vector2:
	return Vector2(
		randf_range(spawn_margin, _screen_size.x - spawn_margin),
		randf_range(spawn_margin, _screen_size.y * 0.70)
	)


func _merge_orb_value_into_existing(origin: Vector2, total_orb_value: float) -> void:
	if total_orb_value <= 0.0:
		return

	var nearest_orb: Node2D = null
	var nearest_distance: float = INF
	for orb in get_tree().get_nodes_in_group("orbs"):
		var distance: float = (orb as Node2D).global_position.distance_to(origin)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_orb = orb as Node2D

	if nearest_orb and nearest_orb.has_method("absorb_value"):
		nearest_orb.absorb_value(total_orb_value)
		return

	if orb_scene == null:
		currency += total_orb_value
		RunManager.currency_earned += total_orb_value
		hud.update_display(currency, RunManager.dots_destroyed, run_duration - run_timer)
		return

	var orb := orb_scene.instantiate()
	add_child(orb)
	orb.init(origin, total_orb_value)
	_active_orb_count += 1
	RunManager.register_orb_spawn(orb.get_instance_id())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _screen_size), Color(0.04, 0.04, 0.04))
	for y in range(0, int(_screen_size.y), 4):
		draw_line(Vector2(0, y), Vector2(_screen_size.x, y), Color(1, 1, 1, 0.025), 1.0)
	var cx := _screen_size.x / 2.0
	for i in 5:
		var x := cx - 340.0 + i * 170.0
		draw_line(Vector2(x, 0), Vector2(x, _screen_size.y), Color(1, 1, 1, 0.04), 1.0)

extends Area2D

@export var speed: float = 600.0

@onready var damage_component: DamageComponent = $DamageComponent

var _direction: Vector2 = Vector2.RIGHT
var _screen_size: Vector2
var _remaining_bounces: int = 0
var _burn_damage: float = 0.0
var _burn_duration: float = 2.0
var _wrap_edges: bool = false
var _frost_debuff_multiplier: float = 1.0
var _damage_multiplier: float = 1.0
var _chain_depth: int = 0
var _status_effect_payloads: Dictionary = {}
var _impact_effect_payload: Dictionary = {}
var _void_pen_percent: float = 0.0
var _is_proc_bullet: bool = false


func _ready() -> void:
	add_to_group("bullets")
	_screen_size = get_viewport_rect().size
	area_entered.connect(_on_area_entered)
	tree_exiting.connect(_on_tree_exiting)
	# Override damage component with current upgrade value
	$DamageComponent.damage = UpgradeManager.get_damage()


func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized()


func configure_runtime_effects(
	bounces: int,
	burn_damage: float,
	wrap_edges: bool,
	frost_debuff_multiplier: float,
	damage_multiplier: float = 1.0,
	chain_depth: int = 0,
	effect_payload: Dictionary = {},
	is_proc_bullet: bool = false
) -> void:
	_remaining_bounces = max(0, bounces)
	_burn_damage = maxf(0.0, burn_damage)
	_wrap_edges = wrap_edges
	_frost_debuff_multiplier = maxf(1.0, frost_debuff_multiplier)
	_damage_multiplier = maxf(0.1, damage_multiplier)
	_chain_depth = max(0, chain_depth)
	_status_effect_payloads = effect_payload.get("statuses", {}).duplicate(true)
	_impact_effect_payload = effect_payload.get("impact", {}).duplicate(true)
	_void_pen_percent = float(effect_payload.get("void_pen_percent", 0.0))
	_is_proc_bullet = is_proc_bullet


func _process(delta: float) -> void:
	position += _direction * speed * delta
	if _wrap_edges:
		_wrap_position()
	if _is_offscreen():
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("dots"):
		return
	var health: HealthComponent = area.get_node_or_null("HealthComponent")
	var was_execute := false
	var was_full_hp := false
	if health and health.max_hp > 0.0:
		was_execute = (health.current_hp / health.max_hp) <= 0.25
		was_full_hp = is_equal_approx(health.current_hp, health.max_hp)
	var dealt_damage := damage_component.get_damage() * _damage_multiplier
	if health and _void_pen_percent > 0.0:
		dealt_damage += health.max_hp * (_void_pen_percent / 100.0)
	if health:
		if area.has_method("take_bullet_damage_with_context"):
			area.take_bullet_damage_with_context(
				dealt_damage,
				{
					"source": "bullet",
					"chain_depth": _chain_depth,
					"damage_multiplier": dealt_damage,
					"was_execute": was_execute,
				}
			)
		elif area.has_method("take_bullet_damage"):
			area.take_bullet_damage(dealt_damage)
		else:
			health.take_damage(dealt_damage)
	if _burn_damage > 0.0 and area.has_method("apply_burn"):
		area.apply_burn(_burn_damage, _burn_duration)
	if _frost_debuff_multiplier > 1.0 and area.has_method("apply_frost_debuff"):
		area.apply_frost_debuff(_frost_debuff_multiplier, 5.0)
	if area.has_method("apply_status_effect"):
		for status_name in _status_effect_payloads.keys():
			var status_payload: Dictionary = (_status_effect_payloads[status_name] as Dictionary).duplicate(true)
			if status_name == "fire" and was_full_hp:
				status_payload["dps"] = float(status_payload.get("dps", 0.0)) * float(status_payload.get("bonus_vs_full_hp", 1.0))
			area.apply_status_effect(status_name, status_payload)
	AudioManager.play_hit()
	var main = get_tree().get_first_node_in_group("main")
	if main and not _impact_effect_payload.is_empty():
		main.handle_projectile_impact(global_position, area, _impact_effect_payload, _chain_depth)
		_impact_effect_payload.clear()
	if _remaining_bounces > 0 and _bounce_to_next_dot(area):
		_remaining_bounces -= 1
		return
	queue_free()


func _is_offscreen() -> bool:
	return (
		position.x < -60 or position.x > _screen_size.x + 60
		or position.y < -60 or position.y > _screen_size.y + 60
	)


func _bounce_to_next_dot(hit_dot: Area2D) -> bool:
	var next_target := _get_nearest_other_dot(hit_dot)
	if next_target == null:
		return false

	_direction = (next_target.global_position - global_position).normalized()
	global_position += _direction * 10.0
	return true


func _get_nearest_other_dot(excluded_dot: Area2D) -> Area2D:
	var nearest: Area2D = null
	var nearest_dist := INF

	for dot in get_tree().get_nodes_in_group("dots"):
		if dot == excluded_dot:
			continue
		var distance := global_position.distance_to(dot.global_position)
		if distance < nearest_dist:
			nearest_dist = distance
			nearest = dot

	return nearest


func _wrap_position() -> void:
	if position.x < -10.0:
		position.x = _screen_size.x + 10.0
	elif position.x > _screen_size.x + 10.0:
		position.x = -10.0

	if position.y < -10.0:
		position.y = _screen_size.y + 10.0
	elif position.y > _screen_size.y + 10.0:
		position.y = -10.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color.WHITE)


func _on_tree_exiting() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_bullet_removed"):
		main.on_bullet_removed(_is_proc_bullet)

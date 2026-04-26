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


func _ready() -> void:
	_screen_size = get_viewport_rect().size
	area_entered.connect(_on_area_entered)
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
	chain_depth: int = 0
) -> void:
	_remaining_bounces = max(0, bounces)
	_burn_damage = maxf(0.0, burn_damage)
	_wrap_edges = wrap_edges
	_frost_debuff_multiplier = maxf(1.0, frost_debuff_multiplier)
	_damage_multiplier = maxf(0.1, damage_multiplier)
	_chain_depth = max(0, chain_depth)


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
	if health and health.max_hp > 0.0:
		was_execute = (health.current_hp / health.max_hp) <= 0.25
	if health:
		if area.has_method("take_bullet_damage_with_context"):
			area.take_bullet_damage_with_context(
				damage_component.get_damage() * _damage_multiplier,
				{
					"source": "bullet",
					"chain_depth": _chain_depth,
					"damage_multiplier": _damage_multiplier,
					"was_execute": was_execute,
				}
			)
		elif area.has_method("take_bullet_damage"):
			area.take_bullet_damage(damage_component.get_damage() * _damage_multiplier)
		else:
			health.take_damage(damage_component.get_damage() * _damage_multiplier)
	if _burn_damage > 0.0 and area.has_method("apply_burn"):
		area.apply_burn(_burn_damage, _burn_duration)
	if _frost_debuff_multiplier > 1.0 and area.has_method("apply_frost_debuff"):
		area.apply_frost_debuff(_frost_debuff_multiplier, 5.0)
	AudioManager.play_hit()
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

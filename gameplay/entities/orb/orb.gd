extends Node2D

@export var lifetime: float = 8.0
@export var bob_speed: float = 2.0
@export var bob_height: float = 4.0

var value: float = 1.0
var pickup_radius: float = 32.0

var _timer: float = 0.0
var _origin: Vector2
var _collected: bool = false
var _color: Color
var _pull_target: Vector2 = Vector2.ZERO
var _being_pulled: bool = false
var _gravity_enabled: bool = false
var _speed_multiplier: float = 1.0
var _redraw_accumulator: float = 0.0


func _ready() -> void:
	add_to_group("orbs")
	_origin = global_position
	_color = Color(randf_range(0.8, 1.0), randf_range(0.7, 1.0), randf_range(0.1, 0.4))
	tree_exiting.connect(_on_tree_exiting)


func init(pos: Vector2, orb_value: float) -> void:
	global_position = pos
	_origin = pos
	value = orb_value
	var main := get_tree().get_first_node_in_group("main")
	if main:
		if main.has_method("get_effective_pickup_radius"):
			pickup_radius = main.get_effective_pickup_radius()
		else:
			pickup_radius = main.orb_pickup_radius
		lifetime += main.orb_lifetime_bonus
		_gravity_enabled = main.orb_gravity
		_speed_multiplier = main.orb_speed_mul


func pull_to(target: Vector2) -> void:
	_pull_target = target
	_being_pulled = true


func collect_now() -> void:
	_collect()


func absorb_value(extra_value: float) -> void:
	value += maxf(0.0, extra_value)
	_timer = minf(_timer, lifetime * 0.5)
	queue_redraw()


func _process(delta: float) -> void:
	_timer += delta
	_redraw_accumulator += delta

	if _being_pulled:
		global_position = global_position.move_toward(_pull_target, 400.0 * _speed_multiplier * delta)
		if global_position.distance_to(_pull_target) < 8.0:
			_collect()
		_maybe_queue_redraw(1.0 / 24.0)
		return

	if _timer >= lifetime:
		queue_free()
		return

	if _gravity_enabled:
		var gravity_target := get_global_mouse_position()
		global_position = global_position.move_toward(gravity_target, 120.0 * _speed_multiplier * delta)

	var mouse := get_global_mouse_position()
	if global_position.distance_to(mouse) <= pickup_radius and not _collected:
		_collect()

	_maybe_queue_redraw(1.0 / 12.0)


func _collect() -> void:
	if _collected:
		return
	_collected = true
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.on_orb_collected(get_instance_id(), value, global_position)
	queue_free()


func _on_tree_exiting() -> void:
	RunManager.unregister_orb(get_instance_id())
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_orb_removed"):
		main.on_orb_removed()


func _maybe_queue_redraw(interval: float) -> void:
	if _redraw_accumulator < interval:
		return
	_redraw_accumulator = 0.0
	queue_redraw()


func _draw() -> void:
	var life_ratio: float = 1.0 - (_timer / lifetime)
	var alpha: float = life_ratio if life_ratio < 0.3 else 1.0
	var value_scale: float = clampf(log(value + 1.0), 0.0, 6.0)
	var radius: float = 6.0 + value_scale * 1.2 + sin(_timer * 3.0) * 1.5
	draw_circle(Vector2(0, sin(_timer * bob_speed) * bob_height), radius + 3.0,
		Color(_color.r, _color.g, _color.b, alpha * 0.25))
	draw_circle(Vector2(0, sin(_timer * bob_speed) * bob_height), radius,
		Color(_color.r, _color.g, _color.b, alpha))
	draw_circle(Vector2(-1.5, sin(_timer * bob_speed) * bob_height - 2.0), radius * 0.3,
		Color(1, 1, 1, alpha * 0.6))

extends Area2D

enum State { ORBITING, HUNTING, RETURNING }

const ORBIT_RADIUS := 80.0
const ORBIT_SPEED := 2.0  # radians per second at base

var _state: State = State.ORBITING
var _orbit_angle: float = 0.0
var _target: Node2D = null
var _home: Vector2 = Vector2.ZERO
var _ram_cooldown: float = 0.0

@onready var damage_component: DamageComponent = $DamageComponent


func _ready() -> void:
	add_to_group("drones")
	area_entered.connect(_on_area_entered)


func init(home_position: Vector2) -> void:
	_home = home_position
	global_position = _home + Vector2(ORBIT_RADIUS, 0.0)


func _process(delta: float) -> void:
	_ram_cooldown = maxf(_ram_cooldown - delta, 0.0)

	match _state:
		State.ORBITING:
			_process_orbit(delta)
			if _ram_cooldown <= 0.0:
				_try_acquire_target()
		State.HUNTING:
			_process_hunt(delta)
		State.RETURNING:
			_process_return(delta)

	queue_redraw()


func _process_orbit(delta: float) -> void:
	var orbit_speed := ORBIT_SPEED * UpgradeManager.get_drone_agility()
	_orbit_angle += orbit_speed * delta
	global_position = _home + Vector2(
		cos(_orbit_angle),
		sin(_orbit_angle)
	) * ORBIT_RADIUS * UpgradeManager.get_drone_orbit_radius()


func _process_hunt(delta: float) -> void:
	if not is_instance_valid(_target):
		_enter_return()
		return

	var speed := UpgradeManager.get_drone_speed()
	var dir := (_target.global_position - global_position).normalized()
	global_position += dir * speed * delta


func _process_return(delta: float) -> void:
	var speed := UpgradeManager.get_drone_speed()
	var dir := (_home - global_position).normalized()
	global_position += dir * speed * delta

	if global_position.distance_to(_home) < ORBIT_RADIUS + 4.0:
		_enter_orbit()


func _try_acquire_target() -> void:
	var dots := get_tree().get_nodes_in_group("dots")
	var nearest: Node2D = null
	var nearest_dist := INF

	for dot in dots:
		var d := global_position.distance_to(dot.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = dot

	if nearest != null:
		_target = nearest
		_state = State.HUNTING


func _on_area_entered(area: Area2D) -> void:
	if _state != State.HUNTING:
		return
	if not area.is_in_group("dots"):
		return

	var health: HealthComponent = area.get_node_or_null("HealthComponent")
	if health:
		health.take_damage(damage_component.get_damage())
	AudioManager.play_hit()

	_target = null
	_ram_cooldown = UpgradeManager.get_drone_ram_cooldown()
	_enter_return()


func _enter_orbit() -> void:
	_state = State.ORBITING
	# Sync angle to current position so orbit doesn't snap
	_orbit_angle = (global_position - _home).angle()


func _enter_return() -> void:
	_state = State.RETURNING
	_target = null


func _draw() -> void:
	var size := 7.0 * UpgradeManager.get_drone_size()
	var color := Color(0.3, 1.0, 0.6) if _state == State.HUNTING else Color(0.2, 0.7, 0.4)
	draw_circle(Vector2.ZERO, size, color)
	draw_arc(Vector2.ZERO, size + 2.0, 0.0, TAU, 24, Color(1, 1, 1, 0.3), 1.5)

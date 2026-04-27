extends Node2D

enum State { ORBITING, HUNTING }

const ORBIT_RADIUS := 80.0
const ORBIT_SPEED := 2.0

@export var projectile_scene: PackedScene

var _state: State = State.ORBITING
var _orbit_angle: float = 0.0
var _target: Node2D = null
var _home: Vector2 = Vector2.ZERO
var _fire_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("drones")


func init(home_position: Vector2) -> void:
	_home = home_position
	global_position = _home + Vector2(ORBIT_RADIUS, 0.0)


func _process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)

	match _state:
		State.ORBITING:
			_process_orbit(delta)
			_try_acquire_target()
		State.HUNTING:
			_process_hunt(delta)

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
		_try_acquire_target()
		return

	# Move toward target
	var speed := UpgradeManager.get_drone_speed()
	var dir := (_target.global_position - global_position).normalized()
	global_position += dir * speed * delta

	# Fire when close enough
	var dist := global_position.distance_to(_target.global_position)
	if dist <= 120.0 and _fire_cooldown <= 0.0:
		_fire_at_target()


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
	else:
		_state = State.ORBITING


func _fire_at_target() -> void:
	if projectile_scene == null or not is_instance_valid(_target):
		return

	var dir := (_target.global_position - global_position).normalized()
	var main := get_tree().get_first_node_in_group("main")
	if main:
		var turret_damage := maxf(0.1, UpgradeManager.get_damage())
		var drone_damage_multiplier := UpgradeManager.get_drone_damage() / turret_damage
		main.spawn_runtime_bullet(projectile_scene, global_position, dir, true, drone_damage_multiplier)

	_fire_cooldown = UpgradeManager.get_drone_ram_cooldown()
	AudioManager.play_shoot()


func _draw() -> void:
	var size := 7.0 * UpgradeManager.get_drone_size()
	var color := Color(0.3, 1.0, 0.6) if _state == State.HUNTING else Color(0.2, 0.7, 0.4)
	draw_circle(Vector2.ZERO, size, color)
	draw_arc(Vector2.ZERO, size + 2.0, 0.0, TAU, 24, Color(1, 1, 1, 0.3), 1.5)

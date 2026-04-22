extends Node2D

@export var bullet_scene: PackedScene

@onready var shooter: ShooterComponent = $ShooterComponent


func _ready() -> void:
	shooter.fire_requested.connect(_on_fire_requested)


func _on_fire_requested() -> void:
	var target = _get_nearest_dot()
	if target == null:
		return

	var direction = (target.global_position - global_position).normalized()
	rotation = direction.angle()

	_spawn_bullet(direction)
	AudioManager.play_shoot()


func _spawn_bullet(direction: Vector2) -> void:
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.set_direction(direction)


func _get_nearest_dot() -> Node2D:
	var dots = get_tree().get_nodes_in_group("dots")
	var nearest: Node2D = null
	var nearest_dist: float = INF

	for dot in dots:
		var d = global_position.distance_to(dot.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = dot

	return nearest


func _draw() -> void:
	var points = PackedVector2Array([
		Vector2(20, 0),
		Vector2(-12, 10),
		Vector2(-12, -10)
	])
	draw_colored_polygon(points, Color(0.4, 0.8, 1.0))
	draw_circle(Vector2.ZERO, 8.0, Color(0.2, 0.5, 0.8))

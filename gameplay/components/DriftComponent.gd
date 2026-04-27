extends Node
class_name DriftComponent

@export var speed: float = 60.0

var direction: Vector2 = Vector2.RIGHT


func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()


func get_velocity() -> Vector2:
	return direction * speed

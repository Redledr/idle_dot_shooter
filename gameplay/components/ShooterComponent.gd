extends Node
class_name ShooterComponent

signal fire_requested

@export var fire_rate: float = 1.5

var _timer: float = 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= (1.0 / fire_rate):
		_timer = 0.0
		fire_requested.emit()

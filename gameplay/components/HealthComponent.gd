extends Node
class_name HealthComponent

signal died
signal damaged(amount: float)

@export var max_hp: float = 3.0

var current_hp: float


func _ready() -> void:
	current_hp = max_hp


func take_damage(amount: float) -> void:
	current_hp -= amount
	damaged.emit(amount)
	if current_hp <= 0.0:
		died.emit()


func is_alive() -> bool:
	return current_hp > 0.0

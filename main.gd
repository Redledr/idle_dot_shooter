extends Node2D

@export var dot_scene: PackedScene
@export var target_dot_count: int = 10
@export var spawn_margin: float = 40.0

var currency: float = 0.0
var dots_destroyed: int = 0

var _screen_size: Vector2

@onready var hud = $HUD


func _ready() -> void:
	add_to_group("main")
	_screen_size = get_viewport_rect().size
	_fill_dots()


func _process(_delta: float) -> void:
	var current_count = get_tree().get_nodes_in_group("dots").size()
	if current_count < target_dot_count:
		_spawn_dot()


func on_dot_destroyed(value: float) -> void:
	currency += value
	dots_destroyed += 1
	hud.update_display(currency, dots_destroyed)


func _fill_dots() -> void:
	for i in target_dot_count:
		_spawn_dot()


func _spawn_dot() -> void:
	if dot_scene == null:
		return

	var dot = dot_scene.instantiate()
	add_child(dot)
	dot.position = _random_play_area_position()


func _random_play_area_position() -> Vector2:
	return Vector2(
		randf_range(spawn_margin, _screen_size.x - spawn_margin),
		randf_range(spawn_margin, _screen_size.y - spawn_margin)
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _screen_size), Color(0.05, 0.05, 0.1))

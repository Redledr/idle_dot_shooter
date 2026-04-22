extends Area2D

@export var currency_value: float = 1.0

@onready var health: HealthComponent = $HealthComponent

var _dot_color: Color = Color.WHITE
var _screen_size: Vector2


func _ready() -> void:
	add_to_group("dots")
	_screen_size = get_viewport_rect().size
	_dot_color = Color(randf(), randf_range(0.5, 1.0), randf_range(0.5, 1.0))

	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)


func _process(delta: float) -> void:
	if _is_offscreen():
		queue_free()


func _on_died() -> void:
	AudioManager.play_pop()
	var main = get_tree().get_first_node_in_group("main")
	if main:
		main.on_dot_destroyed(currency_value)
	queue_free()


func _on_damaged(_amount: float) -> void:
	_dot_color = _dot_color.lightened(0.3)
	queue_redraw()


func _is_offscreen() -> bool:
	var margin: float = 120.0
	return (
		position.x < -margin or position.x > _screen_size.x + margin
		or position.y < -margin or position.y > _screen_size.y + margin
	)


func _draw() -> void:
	var hp_ratio: float = health.current_hp / health.max_hp
	var radius: float = lerp(10.0, 18.0, hp_ratio)
	draw_circle(Vector2.ZERO, radius, _dot_color)
	draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 1.5)

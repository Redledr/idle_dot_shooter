extends Area2D

@export var speed: float = 600.0

@onready var damage_component: DamageComponent = $DamageComponent

var _direction: Vector2 = Vector2.RIGHT
var _screen_size: Vector2


func _ready() -> void:
	_screen_size = get_viewport_rect().size
	area_entered.connect(_on_area_entered)


func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized()


func _process(delta: float) -> void:
	position += _direction * speed * delta
	if _is_offscreen():
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("dots"):
		return
	var health: HealthComponent = area.get_node_or_null("HealthComponent")
	if health:
		health.take_damage(damage_component.get_damage())
	AudioManager.play_hit()
	queue_free()


func _is_offscreen() -> bool:
	return (
		position.x < -60 or position.x > _screen_size.x + 60
		or position.y < -60 or position.y > _screen_size.y + 60
	)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color.WHITE)

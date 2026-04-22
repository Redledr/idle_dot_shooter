extends Node2D

@export var dot_scene: PackedScene
@export var spawn_margin: float = 60.0

var currency: float = 0.0
var dots_destroyed: int = 0

var _screen_size: Vector2

@onready var hud = $HUD
@onready var turret = $Turret


func _ready() -> void:
	add_to_group("main")
	_screen_size = get_viewport_rect().size
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	_fill_dots()


func _process(_delta: float) -> void:
	var current = get_tree().get_nodes_in_group("dots").size()
	if current < UpgradeManager.get_dot_count():
		_spawn_dot()


func on_dot_destroyed(value: float) -> void:
	currency += value * UpgradeManager.get_dot_value()
	dots_destroyed += 1
	hud.update_display(currency, dots_destroyed)


func _on_upgrade_purchased(upgrade_id: String) -> void:
	match upgrade_id:
		"fire_rate":
			turret.get_node("ShooterComponent").fire_rate = UpgradeManager.get_fire_rate()
		"damage":
			turret.get_node("Bullet").get_node("DamageComponent") # bullets are instanced so damage applies on spawn
			pass


func _fill_dots() -> void:
	for i in UpgradeManager.get_dot_count():
		_spawn_dot()


func _spawn_dot() -> void:
	if dot_scene == null:
		return
	var dot = dot_scene.instantiate()
	add_child(dot)
	dot.position = _random_play_area_position()


func _random_play_area_position() -> Vector2:
	# Keep dots in the upper 70% so they don't overlap the upgrade panel
	return Vector2(
		randf_range(spawn_margin, _screen_size.x - spawn_margin),
		randf_range(spawn_margin, _screen_size.y * 0.70)
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _screen_size), Color(0.05, 0.05, 0.1))

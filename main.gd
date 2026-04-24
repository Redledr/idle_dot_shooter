extends Node2D

@export var dot_scene: PackedScene
@export var drone_scene: PackedScene
@export var spawn_margin: float = 60.0

var currency: float = 0.0
var dots_destroyed: int = 0

var _screen_size: Vector2
var _save_timer: float = 0.0
var _drone_unlocked: bool = false

const DRONE_UNLOCK_THRESHOLD := 100
const SAVE_INTERVAL := 30.0

@onready var hud = $HUD
@onready var turret = $Turret


func _ready() -> void:
	add_to_group("main")
	_screen_size = get_viewport_rect().size
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)

	_load_game()
	_fill_dots()


func _process(delta: float) -> void:
	# Maintain dot count
	var current := get_tree().get_nodes_in_group("dots").size()
	if current < UpgradeManager.get_dot_count():
		_spawn_dot()

	# Autosave
	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		SaveManager.save_game(currency, dots_destroyed)


func on_dot_destroyed(value: float) -> void:
	currency += value * UpgradeManager.get_dot_value()
	dots_destroyed += 1
	hud.update_display(currency, dots_destroyed)
	if not _drone_unlocked and dots_destroyed >= DRONE_UNLOCK_THRESHOLD:
		_unlock_drone()


func _on_upgrade_purchased(upgrade_id: String) -> void:
	match upgrade_id:
		"fire_rate":
			turret.get_node("ShooterComponent").fire_rate = UpgradeManager.get_fire_rate()
	# damage applies per bullet at spawn — no action needed here
	# dot_value applies per kill via get_dot_value() — no action needed here
	# spawn_count is read each frame in _process — no action needed here


# --- Dot spawning ---

func _fill_dots() -> void:
	for i in UpgradeManager.get_dot_count():
		_spawn_dot()


func _spawn_dot() -> void:
	if dot_scene == null:
		return
	var dot := dot_scene.instantiate()
	add_child(dot)
	dot.position = _random_play_area_position()


func _unlock_drone() -> void:
	if _drone_unlocked:
		return
	_drone_unlocked = true
	_spawn_drone()
	var upgrade_panel = get_node_or_null("CanvasLayer")
	if upgrade_panel and upgrade_panel.has_method("notify_drone_spawned"):
		upgrade_panel.notify_drone_spawned()


func _spawn_drone() -> void:
	if drone_scene == null:
		return
	var drone := drone_scene.instantiate()
	add_child(drone)
	drone.init(turret.global_position)


func _random_play_area_position() -> Vector2:
	return Vector2(
		randf_range(spawn_margin, _screen_size.x - spawn_margin),
		randf_range(spawn_margin, _screen_size.y * 0.70)
	)


# --- Save / Load ---

func _load_game() -> void:
	var data := SaveManager.load_game()
	if data.is_empty():
		hud.update_display(currency, dots_destroyed)
		return

	# Restore upgrade levels first so stat getters are correct
	if data.has("upgrade_levels"):
		UpgradeManager.restore_levels(data["upgrade_levels"])

	# Restore progress
	currency = float(data.get("currency", 0.0))
	dots_destroyed = int(data.get("dots_destroyed", 0))

	# Apply saved fire rate to turret
	turret.get_node("ShooterComponent").fire_rate = UpgradeManager.get_fire_rate()

	# Calculate offline earnings
	if data.has("timestamp"):
		var offline := SaveManager.calculate_offline_progress(float(data["timestamp"]))
		if offline["currency"] > 0.0:
			currency += offline["currency"]
			hud.show_offline_summary(offline)

	hud.update_display(currency, dots_destroyed)

	# Restore drone if already unlocked in this save
	if dots_destroyed >= DRONE_UNLOCK_THRESHOLD:
		_unlock_drone()


func _notification(what: int) -> void:
	# Save on quit and on focus loss (covers Alt+F4, browser tab close, etc.)
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		SaveManager.save_game(currency, dots_destroyed)


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, _screen_size), Color(0.04, 0.04, 0.04))

	# Scanlines
	for y in range(0, int(_screen_size.y), 4):
		draw_line(Vector2(0, y), Vector2(_screen_size.x, y), Color(1, 1, 1, 0.025), 1.0)

	# Vertical stripes
	var cx := _screen_size.x / 2.0
	for i in 5:
		var x := cx - 340.0 + i * 170.0
		draw_line(Vector2(x, 0), Vector2(x, _screen_size.y), Color(1, 1, 1, 0.04), 1.0)

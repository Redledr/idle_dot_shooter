extends Node2D

@export var dot_scene: PackedScene
@export var drone_scene: PackedScene
@export var orb_scene: PackedScene
@export var spawn_margin: float = 60.0

@export var run_duration: float = 300.0
@export var card_draw_interval: int = 10
@export var orb_pickup_radius: float = 32.0

# Runtime flags — set by cards
var bullets_pierce: bool = false
var orbs_per_kill: int = 1
var chain_pickup: bool = false

const DRONE_UNLOCK_THRESHOLD := 100
const END_OF_RUN_SCENE := "res://ui/EndOfRunScreen.tscn"
const CARD_DRAW_SCENE := "res://ui/CardDrawScreen.tscn"

var currency: float = 0.0
var run_timer: float = 0.0
var run_active: bool = false

var _screen_size: Vector2
var _drone_unlocked: bool = false
var _next_card_draw: int = 0
var _card_draw_open: bool = false

@onready var hud = $HUD
@onready var turret = $Turret
@onready var cursor = $Cursor


func _ready() -> void:
	add_to_group("main")
	_screen_size = get_viewport_rect().size
	cursor.radius = orb_pickup_radius
	# Keep HUD and cursor alive during card draw pause
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	cursor.process_mode = Node.PROCESS_MODE_ALWAYS
	RunManager.start_run()
	_start_run()


func _start_run() -> void:
	currency = 0.0
	run_timer = 0.0
	_next_card_draw = card_draw_interval
	run_active = true
	_fill_dots()
	hud.update_display(currency, RunManager.dots_destroyed, run_duration)


func _process(delta: float) -> void:
	if not run_active or _card_draw_open:
		return

	run_timer += delta
	if run_timer >= run_duration:
		_end_run()
		return

	var current := get_tree().get_nodes_in_group("dots").size()
	if current < UpgradeManager.get_dot_count():
		_spawn_dot()

	hud.update_timer(run_duration - run_timer)


func _end_run() -> void:
	run_active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(END_OF_RUN_SCENE)


func spawn_orb(pos: Vector2, value: float) -> void:
	RunManager.dots_destroyed += 1
	if not _drone_unlocked and RunManager.dots_destroyed >= DRONE_UNLOCK_THRESHOLD:
		_unlock_drone()

	if orb_scene == null:
		return

	for i in orbs_per_kill:
		var orb := orb_scene.instantiate()
		add_child(orb)
		var scatter := Vector2(randf_range(-20, 20), randf_range(-20, 20)) * i
		orb.init(pos + scatter, value * UpgradeManager.get_dot_value())
		RunManager.register_orb_spawn(orb.get_instance_id())


func on_orb_collected(orb_id: int, value: float) -> void:
	currency += value
	RunManager.currency_earned += value
	RunManager.register_orb_collected(orb_id)
	hud.update_display(currency, RunManager.dots_destroyed, run_duration - run_timer)

	# Chain pickup — pull nearby orbs
	if chain_pickup:
		_pull_nearby_orbs(get_global_mouse_position())

	# Card draw check
	if RunManager.orbs_collected >= _next_card_draw:
		_next_card_draw += card_draw_interval
		_open_card_draw()


func _pull_nearby_orbs(origin: Vector2) -> void:
	for orb in get_tree().get_nodes_in_group("orbs"):
		if orb.global_position.distance_to(origin) < orb_pickup_radius * 3.0:
			orb.pull_to(origin)


func _open_card_draw() -> void:
	_card_draw_open = true
	get_tree().paused = true
	cursor.set_gameplay_mode(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var scene: PackedScene = load(CARD_DRAW_SCENE) as PackedScene
	var card_draw: Node = scene.instantiate()
	card_draw.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(card_draw)
	card_draw.connect("card_chosen", _on_card_chosen.bind(card_draw))


func _on_card_chosen(card_id: String, card_draw_node: Node) -> void:
	CardDatabase.apply_card(card_id, self)
	card_draw_node.queue_free()
	_card_draw_open = false
	get_tree().paused = false
	cursor.set_gameplay_mode(true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	hud.show_notification(CardDatabase.get_card(card_id).get("name", "") + " applied!")


func spawn_extra_drone() -> void:
	_spawn_drone()


func _unlock_drone() -> void:
	if _drone_unlocked:
		return
	_drone_unlocked = true
	_spawn_drone()
	hud.show_notification("Drone unlocked!")


func _spawn_drone() -> void:
	if drone_scene == null:
		return
	var drone := drone_scene.instantiate()
	add_child(drone)
	drone.init(turret.global_position)


func _fill_dots() -> void:
	for i in UpgradeManager.get_dot_count():
		_spawn_dot()


func _spawn_dot() -> void:
	if dot_scene == null:
		return
	var dot := dot_scene.instantiate()
	add_child(dot)
	dot.position = _random_play_area_position()


func _random_play_area_position() -> Vector2:
	return Vector2(
		randf_range(spawn_margin, _screen_size.x - spawn_margin),
		randf_range(spawn_margin, _screen_size.y * 0.70)
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _screen_size), Color(0.04, 0.04, 0.04))
	for y in range(0, int(_screen_size.y), 4):
		draw_line(Vector2(0, y), Vector2(_screen_size.x, y), Color(1, 1, 1, 0.025), 1.0)
	var cx := _screen_size.x / 2.0
	for i in 5:
		var x := cx - 340.0 + i * 170.0
		draw_line(Vector2(x, 0), Vector2(x, _screen_size.y), Color(1, 1, 1, 0.04), 1.0)

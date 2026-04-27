extends Node2D

const MAIN_SCENE := "res://scenes/game/main.tscn"
const SETTINGS_SCENE := "res://ui/screens/SettingsScreen.tscn"
const GameSettings = preload("res://systems/config/GameSettings.gd")

var _time: float = 0.0
var _particles: Array = []
var _screen_size: Vector2
var _title_scale: float = 1.0
var _title_scale_dir: float = 1.0
var _hovered: String = ""
var _transitioning: bool = false
var _has_save: bool = false

class Particle:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var radius: float
	var life: float
	var max_life: float

var _buttons := []  # populated in _ready based on save state


func _ready() -> void:
	_screen_size = get_viewport_rect().size
	_has_save = FileAccess.file_exists("user://save.json")
	_build_buttons()
	_apply_saved_settings()
	_burst_particles(_screen_size / 2, 40)


func _build_buttons() -> void:
	_buttons.clear()
	if _has_save:
		_buttons.append({ "id": "continue", "label": "CONTINUE" })
		_buttons.append({ "id": "new_game", "label": "NEW GAME" })
	else:
		_buttons.append({ "id": "new_game", "label": "START" })
	_buttons.append({ "id": "settings", "label": "SETTINGS" })
	_buttons.append({ "id": "quit",     "label": "QUIT" })


func _process(delta: float) -> void:
	_time += delta

	_title_scale += _title_scale_dir * delta * 0.4
	if _title_scale > 1.08:
		_title_scale_dir = -1.0
	elif _title_scale < 0.95:
		_title_scale_dir = 1.0

	for p in _particles:
		p.pos += p.vel * delta
		p.vel *= 0.94
		p.life -= delta
	_particles = _particles.filter(func(p: Particle) -> bool: return p.life > 0.0)

	if randf() < delta * 3.0:
		_burst_particles(_random_edge_position(), 5)

	queue_redraw()


func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)
	if event is InputEventMouseMotion:
		_handle_hover(event.position)


func _handle_hover(mouse: Vector2) -> void:
	_hovered = ""
	for i in _buttons.size():
		if _get_button_rect(i).has_point(mouse):
			_hovered = _buttons[i]["id"]
			break


func _handle_click(mouse: Vector2) -> void:
	for i in _buttons.size():
		if not _get_button_rect(i).has_point(mouse):
			continue
		var id: String = _buttons[i]["id"]
		_burst_particles(mouse, 30)
		match id:
			"continue":
				_transition_to(MAIN_SCENE, false)
			"new_game":
				SaveManager.delete_save()
				_transition_to(MAIN_SCENE, false)
			"settings":
				_open_settings()
			"quit":
				_burst_particles(mouse, 40)
				await get_tree().create_timer(0.3).timeout
				get_tree().quit()
		break


func _get_button_rect(index: int) -> Rect2:
	var cx := _screen_size.x / 2.0
	var start_y := _screen_size.y / 2.0 + 60.0
	var btn_w := 220.0
	var btn_h := 44.0
	var spacing := 60.0
	return Rect2(cx - btn_w / 2.0, start_y + index * spacing, btn_w, btn_h)


func _transition_to(scene: String, _wipe: bool) -> void:
	_transitioning = true
	_burst_particles(_screen_size / 2, 80)
	await get_tree().create_timer(0.35).timeout
	get_tree().change_scene_to_file(scene)


func _open_settings() -> void:
	_transitioning = true
	var settings_scene: PackedScene = load(SETTINGS_SCENE) as PackedScene
	var settings: Node = settings_scene.instantiate()
	get_tree().root.add_child(settings)
	settings.connect("back_pressed", _on_settings_back.bind(settings))
	# Hide self
	visible = false
	set_process(false)
	set_process_input(false)


func _on_settings_back(settings_node: Node) -> void:
	settings_node.queue_free()
	visible = true
	set_process(true)
	set_process_input(true)
	_transitioning = false
	_has_save = FileAccess.file_exists("user://save.json")
	_build_buttons()
	queue_redraw()


func _draw() -> void:
	var cx := _screen_size.x / 2.0
	var cy := _screen_size.y / 2.0

	draw_rect(Rect2(Vector2.ZERO, _screen_size), Color(0.04, 0.04, 0.04))

	for y in range(0, int(_screen_size.y), 4):
		draw_line(Vector2(0, y), Vector2(_screen_size.x, y), Color(1, 1, 1, 0.025), 1.0)

	for i in 5:
		var x := cx - 340.0 + i * 170.0
		draw_line(Vector2(x, 0), Vector2(x, _screen_size.y), Color(1, 1, 1, 0.04), 1.0)

	for p in _particles:
		var alpha: float = p.life / p.max_life
		draw_circle(p.pos, p.radius * alpha, Color(p.color.r, p.color.g, p.color.b, alpha * 0.85))

	var title_y := cy - 160.0
	_draw_title(cx, title_y)

	var tag_alpha := 0.55 + sin(_time * 1.2) * 0.15
	draw_string(ThemeDB.fallback_font, Vector2(cx - 210, title_y + 110),
		"EVERYTHING BECOMES A NUMBER.",
		HORIZONTAL_ALIGNMENT_CENTER, 420, 22, Color(1, 1, 1, tag_alpha))

	draw_line(Vector2(cx - 180, title_y + 130), Vector2(cx + 180, title_y + 130),
		Color(1, 1, 1, 0.18), 1.0)

	_draw_buttons(cx)

	draw_string(ThemeDB.fallback_font, Vector2(cx - 200, _screen_size.y - 30),
		"v0.1  —  idle dot shooter",
		HORIZONTAL_ALIGNMENT_CENTER, 400, 13, Color(1, 1, 1, 0.2))

	_draw_corner_brackets(cx, cy)


func _draw_buttons(_cx: float) -> void:
	var font := ThemeDB.fallback_font
	for i in _buttons.size():
		var btn: Dictionary = _buttons[i]
		var rect := _get_button_rect(i)
		var hovered: bool = _hovered == btn["id"]

		# Button bg
		var bg_alpha := 0.10 if hovered else 0.0
		if bg_alpha > 0.0:
			draw_rect(rect, Color(1, 1, 1, bg_alpha))

		# Border
		var border_alpha := 0.5 if hovered else 0.18
		draw_rect(rect, Color(1, 1, 1, border_alpha), false, 1.0)

		# Accent line on hover
		if hovered:
			var accent := Color(1.0, 0.3, 0.3) if btn["id"] == "quit" else Color(0.3, 1.0, 0.5)
			draw_line(
				Vector2(rect.position.x, rect.position.y + rect.size.y),
				Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
				Color(accent.r, accent.g, accent.b, 0.8), 2.0
			)

		# Label
		var text_color := Color.WHITE if hovered else Color(1, 1, 1, 0.6)
		draw_string(font,
			Vector2(rect.position.x, rect.position.y + 28),
			btn["label"], HORIZONTAL_ALIGNMENT_CENTER,
			int(rect.size.x), 16, text_color)


func _draw_title(cx: float, y: float) -> void:
	var font := ThemeDB.fallback_font
	var s := _title_scale

	draw_string(font, Vector2(cx - 242 + 3, y + 3), "IDLE DOT",
		HORIZONTAL_ALIGNMENT_CENTER, 484, int(78 * s), Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(cx - 242 + 3, y + 78 + 3), "SHOOTER",
		HORIZONTAL_ALIGNMENT_CENTER, 484, int(78 * s), Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(cx - 242, y), "IDLE DOT",
		HORIZONTAL_ALIGNMENT_CENTER, 484, int(78 * s), Color.WHITE)
	draw_string(font, Vector2(cx - 242 + 2, y + 78 + 2), "SHOOTER",
		HORIZONTAL_ALIGNMENT_CENTER, 484, int(78 * s), Color(0.3, 1.0, 0.5, 0.5))
	draw_string(font, Vector2(cx - 242, y + 78), "SHOOTER",
		HORIZONTAL_ALIGNMENT_CENTER, 484, int(78 * s), Color.WHITE)


func _draw_corner_brackets(cx: float, cy: float) -> void:
	var w := 520.0
	var h := 400.0
	var x := cx - w / 2.0
	var y := cy - h / 2.0
	var arm := 28.0
	var c := Color(1, 1, 1, 0.25)
	var t := 1.5
	draw_line(Vector2(x, y + arm), Vector2(x, y), c, t)
	draw_line(Vector2(x, y), Vector2(x + arm, y), c, t)
	draw_line(Vector2(x + w - arm, y), Vector2(x + w, y), c, t)
	draw_line(Vector2(x + w, y), Vector2(x + w, y + arm), c, t)
	draw_line(Vector2(x, y + h - arm), Vector2(x, y + h), c, t)
	draw_line(Vector2(x, y + h), Vector2(x + arm, y + h), c, t)
	draw_line(Vector2(x + w - arm, y + h), Vector2(x + w, y + h), c, t)
	draw_line(Vector2(x + w, y + h), Vector2(x + w, y + h - arm), c, t)


func _burst_particles(origin: Vector2, count: int) -> void:
	var colors := [
		Color(1.0, 0.2, 0.3), Color(0.2, 0.8, 1.0), Color(0.1, 1.0, 0.5),
		Color(1.0, 0.85, 0.1), Color(0.9, 0.2, 1.0), Color(1.0, 0.5, 0.1),
	]
	for i in count:
		var p := Particle.new()
		p.pos = origin + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		var angle := randf() * TAU
		var speed := randf_range(60.0, 320.0)
		p.vel = Vector2(cos(angle), sin(angle)) * speed
		p.color = colors[randi() % colors.size()]
		p.radius = randf_range(3.0, 9.0)
		p.max_life = randf_range(0.5, 1.4)
		p.life = p.max_life
		_particles.append(p)


func _random_edge_position() -> Vector2:
	match randi() % 4:
		0: return Vector2(randf_range(0, _screen_size.x), 0)
		1: return Vector2(randf_range(0, _screen_size.x), _screen_size.y)
		2: return Vector2(0, randf_range(0, _screen_size.y))
		_: return Vector2(_screen_size.x, randf_range(0, _screen_size.y))


func _apply_saved_settings() -> void:
	GameSettings.apply_display_and_audio(GameSettings.load_settings())

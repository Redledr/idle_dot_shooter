extends Node2D

signal back_pressed

const GameSettings = preload("res://systems/config/GameSettings.gd")

var _time: float = 0.0
var _particles: Array = []
var _screen_size: Vector2
var _hovered: String = ""
var _confirm_reset: bool = false
var _confirm_timer: float = 0.0
var _flash: Dictionary = {}

# Settings state
var _master_volume: float = 1.0
var _fullscreen: bool = false
var _particles_enabled: bool = true
var _resolution_index: int = 0

const RESOLUTIONS := [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1280, 720),
	Vector2i(2560, 1440),
]
const RESOLUTION_LABELS := ["1920 x 1080", "1600 x 900", "1280 x 720", "2560 x 1440"]

class Particle:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var radius: float
	var life: float
	var max_life: float

# UI rows — each entry: { id, label, type: "slider"|"toggle"|"cycle"|"action" }
var _rows := [
	{ "id": "volume",     "label": "MASTER VOLUME",    "type": "slider" },
	{ "id": "fullscreen", "label": "FULLSCREEN",        "type": "toggle" },
	{ "id": "resolution", "label": "RESOLUTION",        "type": "cycle"  },
	{ "id": "particles",  "label": "PARTICLE EFFECTS",  "type": "toggle" },
	{ "id": "fps",        "label": "SHOW FPS",          "type": "toggle" },
	{ "id": "cpu",        "label": "SHOW CPU / MEMORY", "type": "toggle" },
	{ "id": "reset",      "label": "RESET SAVE",        "type": "action" },
]

# Telemetry state
var _show_fps: bool = false
var _show_cpu: bool = false


func _ready() -> void:
	_screen_size = get_viewport_rect().size
	_load_settings()
	_burst_particles(_screen_size / 2, 25)


func _process(delta: float) -> void:
	_time += delta

	if _confirm_reset:
		_confirm_timer -= delta
		if _confirm_timer <= 0.0:
			_confirm_reset = false

	for p in _particles:
		p.pos += p.vel * delta
		p.vel *= 0.94
		p.life -= delta
	_particles = _particles.filter(func(p: Particle) -> bool: return p.life > 0.0)

	if randf() < delta * 1.5:
		_burst_particles(_random_edge_position(), 3)

	# Tick flashes
	for key in _flash.keys():
		_flash[key] -= delta
		if _flash[key] <= 0.0:
			_flash.erase(key)

	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_save_settings()
			emit_signal("back_pressed")

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

	if event is InputEventMouseMotion:
		_handle_hover(event.position)


func _handle_hover(mouse: Vector2) -> void:
	_hovered = ""
	var rows_start_y := _get_rows_start_y()
	for i in _rows.size():
		var row_y := rows_start_y + i * 72.0
		var row_rect := Rect2(_screen_size.x / 2.0 - 260, row_y - 22, 520, 52)
		if row_rect.has_point(mouse):
			_hovered = _rows[i]["id"]
			break
	# Back button
	if _get_back_rect().has_point(mouse):
		_hovered = "back"


func _handle_click(mouse: Vector2) -> void:
	var cx := _screen_size.x / 2.0
	var rows_start_y := _get_rows_start_y()

	for i in _rows.size():
		var row: Dictionary = _rows[i] as Dictionary
		var row_y := rows_start_y + i * 72.0
		var row_rect := Rect2(cx - 260, row_y - 22, 520, 52)
		if not row_rect.has_point(mouse):
			continue

		match row["type"]:
			"toggle":
				_toggle(row["id"])
			"cycle":
				_cycle(row["id"], mouse, cx)
			"slider":
				_slider_click(row["id"], mouse, cx, row_y)
			"action":
				_action(row["id"])
		_flash[row["id"]] = 0.3
		_burst_particles(Vector2(mouse.x, row_y), 8)
		break

	if _get_back_rect().has_point(mouse):
		_save_settings()
		_burst_particles(mouse, 15)
		await get_tree().create_timer(0.2).timeout
		emit_signal("back_pressed")


func _toggle(id: String) -> void:
	match id:
		"fullscreen":
			_fullscreen = not _fullscreen
			if _fullscreen:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"particles":
			_particles_enabled = not _particles_enabled
		"fps":
			_show_fps = not _show_fps
			Engine.max_fps = 0
			if TelemetryOverlay:
				TelemetryOverlay.set_show_fps(_show_fps)
		"cpu":
			_show_cpu = not _show_cpu
			if TelemetryOverlay:
				TelemetryOverlay.set_show_cpu(_show_cpu)


func _cycle(id: String, _mouse: Vector2, _cx: float) -> void:
	match id:
		"resolution":
			_resolution_index = (_resolution_index + 1) % RESOLUTIONS.size()
			var res: Vector2i = RESOLUTIONS[_resolution_index] as Vector2i
			DisplayServer.window_set_size(res)


func _slider_click(id: String, mouse: Vector2, cx: float, _row_y: float) -> void:
	var track_x := cx - 100.0
	var track_w := 200.0
	var t := clampf((mouse.x - track_x) / track_w, 0.0, 1.0)
	match id:
		"volume":
			_master_volume = t
			AudioServer.set_bus_volume_db(0, linear_to_db(_master_volume))


func _action(id: String) -> void:
	match id:
		"reset":
			if _confirm_reset:
				SaveManager.delete_save()
				_confirm_reset = false
				_flash["reset_done"] = 1.5
			else:
				_confirm_reset = true
				_confirm_timer = 3.0


func _get_rows_start_y() -> float:
	return _screen_size.y / 2.0 - (_rows.size() * 72.0) / 2.0 + 30.0


func _get_back_rect() -> Rect2:
	return Rect2(40, _screen_size.y - 70, 120, 36)


func _draw() -> void:
	var cx := _screen_size.x / 2.0
	var cy := _screen_size.y / 2.0

	# Background
	draw_rect(Rect2(Vector2.ZERO, _screen_size), Color(0.04, 0.04, 0.04))

	# Scanlines
	for y in range(0, int(_screen_size.y), 4):
		draw_line(Vector2(0, y), Vector2(_screen_size.x, y), Color(1, 1, 1, 0.025), 1.0)

	# Vertical stripes
	for i in 5:
		var x := cx - 340.0 + i * 170.0
		draw_line(Vector2(x, 0), Vector2(x, _screen_size.y), Color(1, 1, 1, 0.04), 1.0)

	# Particles
	for p in _particles:
		var alpha: float = p.life / p.max_life
		draw_circle(p.pos, p.radius * alpha, Color(p.color.r, p.color.g, p.color.b, alpha * 0.85))

	# Header
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(cx - 160, 80), "SETTINGS",
		HORIZONTAL_ALIGNMENT_CENTER, 320, 52, Color.WHITE)
	draw_line(Vector2(cx - 180, 95), Vector2(cx + 180, 95), Color(1, 1, 1, 0.15), 1.0)

	# Rows
	var rows_start_y := _get_rows_start_y()
	for i in _rows.size():
		var row: Dictionary = _rows[i] as Dictionary
		var row_y := rows_start_y + i * 72.0
		_draw_row(row, row_y, cx, font)

	# Back button
	_draw_back_button(font)

	# Corner brackets
	_draw_corner_brackets(cx, cy)


func _draw_row(row: Dictionary, row_y: float, cx: float, font: Font) -> void:
	var id: String = row["id"]
	var is_hovered := _hovered == id
	var is_flashing := _flash.has(id)

	# Row highlight
	if is_hovered:
		draw_rect(
			Rect2(cx - 260, row_y - 22, 520, 52),
			Color(1, 1, 1, 0.04)
		)

	# Label
	var label_alpha := 1.0 if is_hovered else 0.65
	if is_flashing:
		label_alpha = 1.0
	draw_string(font, Vector2(cx - 240, row_y + 8),
		row["label"], HORIZONTAL_ALIGNMENT_LEFT, 200, 16,
		Color(1, 1, 1, label_alpha))

	# Value / control
	match row["type"]:
		"slider":
			_draw_slider(id, row_y, cx, font, is_hovered)
		"toggle":
			_draw_toggle(id, row_y, cx, font)
		"cycle":
			_draw_cycle(id, row_y, cx, font, is_hovered)
		"action":
			_draw_action(id, row_y, cx, font, is_hovered)

	# Separator
	draw_line(
		Vector2(cx - 260, row_y + 28),
		Vector2(cx + 260, row_y + 28),
		Color(1, 1, 1, 0.08), 1.0
	)


func _draw_slider(id: String, row_y: float, cx: float, font: Font, hovered: bool) -> void:
	var value := 0.0
	match id:
		"volume": value = _master_volume

	var track_x := cx - 100.0
	var track_w := 200.0
	var track_y := row_y + 6.0

	# Track bg
	draw_line(Vector2(track_x, track_y), Vector2(track_x + track_w, track_y),
		Color(1, 1, 1, 0.15), 2.0)
	# Track fill
	var fill_color := Color(0.3, 1.0, 0.5) if hovered else Color(1, 1, 1, 0.6)
	draw_line(Vector2(track_x, track_y), Vector2(track_x + track_w * value, track_y),
		fill_color, 2.0)
	# Handle
	draw_circle(Vector2(track_x + track_w * value, track_y), 6.0, fill_color)

	# Percentage
	draw_string(font, Vector2(cx + 115, row_y + 12),
		"%d%%" % int(value * 100),
		HORIZONTAL_ALIGNMENT_LEFT, 60, 14, Color(1, 1, 1, 0.55))


func _draw_toggle(id: String, row_y: float, cx: float, _font: Font) -> void:
	var on := false
	match id:
		"fullscreen": on = _fullscreen
		"particles":  on = _particles_enabled
		"fps":        on = _show_fps
		"cpu":        on = _show_cpu

	var tx := cx + 140.0
	var ty := row_y + 6.0
	var w := 44.0
	var h := 22.0

	# Track
	var track_color := Color(0.3, 1.0, 0.5, 0.9) if on else Color(1, 1, 1, 0.15)
	draw_rect(Rect2(tx, ty - h / 2.0, w, h), track_color, true, -1.0)
	draw_rect(Rect2(tx, ty - h / 2.0, w, h), Color(1, 1, 1, 0.2), false, 1.0)

	# Knob
	var knob_x := tx + w - h / 2.0 - 2.0 if on else tx + h / 2.0 + 2.0
	draw_circle(Vector2(knob_x, ty), h / 2.0 - 3.0, Color.WHITE)


func _draw_cycle(id: String, row_y: float, cx: float, font: Font, hovered: bool) -> void:
	var label := ""
	match id:
		"resolution": label = RESOLUTION_LABELS[_resolution_index]

	var arrow_color := Color(0.3, 1.0, 0.5) if hovered else Color(1, 1, 1, 0.5)
	# Left arrow
	draw_string(font, Vector2(cx + 60, row_y + 12), "<",
		HORIZONTAL_ALIGNMENT_LEFT, 20, 16, arrow_color)
	# Value
	draw_string(font, Vector2(cx + 75, row_y + 12), label,
		HORIZONTAL_ALIGNMENT_LEFT, 150, 14, Color(1, 1, 1, 0.85))
	# Right arrow
	draw_string(font, Vector2(cx + 230, row_y + 12), ">",
		HORIZONTAL_ALIGNMENT_LEFT, 20, 16, arrow_color)


func _draw_action(id: String, row_y: float, cx: float, font: Font, hovered: bool) -> void:
	match id:
		"reset":
			if _flash.has("reset_done"):
				draw_string(font, Vector2(cx + 60, row_y + 12),
					"SAVE DELETED", HORIZONTAL_ALIGNMENT_LEFT, 200, 14,
					Color(0.3, 1.0, 0.5))
			elif _confirm_reset:
				draw_string(font, Vector2(cx + 60, row_y + 12),
					"CLICK AGAIN TO CONFIRM", HORIZONTAL_ALIGNMENT_LEFT, 240, 14,
					Color(1.0, 0.3, 0.3))
			else:
				var c := Color(1.0, 0.3, 0.3, 0.9) if hovered else Color(1, 1, 1, 0.4)
				draw_string(font, Vector2(cx + 60, row_y + 12),
					"CLICK TO RESET", HORIZONTAL_ALIGNMENT_LEFT, 200, 14, c)


func _draw_back_button(font: Font) -> void:
	var rect := _get_back_rect()
	var hovered := _hovered == "back"
	if hovered:
		draw_rect(rect, Color(1, 1, 1, 0.06))
	draw_rect(rect, Color(1, 1, 1, 0.12), false, 1.0)
	var c := Color.WHITE if hovered else Color(1, 1, 1, 0.6)
	draw_string(font, Vector2(rect.position.x + 12, rect.position.y + 24),
		"< BACK", HORIZONTAL_ALIGNMENT_LEFT, 100, 15, c)


func _draw_corner_brackets(cx: float, cy: float) -> void:
	var w := 580.0
	var h := 420.0
	var x := cx - w / 2.0
	var y := cy - h / 2.0
	var arm := 28.0
	var c := Color(1, 1, 1, 0.2)
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
		var speed := randf_range(40.0, 220.0)
		p.vel = Vector2(cos(angle), sin(angle)) * speed
		p.color = colors[randi() % colors.size()]
		p.radius = randf_range(2.0, 7.0)
		p.max_life = randf_range(0.4, 1.2)
		p.life = p.max_life
		_particles.append(p)


func _random_edge_position() -> Vector2:
	match randi() % 4:
		0: return Vector2(randf_range(0, _screen_size.x), 0)
		1: return Vector2(randf_range(0, _screen_size.x), _screen_size.y)
		2: return Vector2(0, randf_range(0, _screen_size.y))
		_: return Vector2(_screen_size.x, randf_range(0, _screen_size.y))


func _save_settings() -> void:
	GameSettings.save_settings({
		"master_volume": _master_volume,
		"fullscreen": _fullscreen,
		"particles_enabled": _particles_enabled,
		"resolution_index": _resolution_index,
		"show_fps": _show_fps,
		"show_cpu": _show_cpu,
	})


func _load_settings() -> void:
	var settings := GameSettings.load_settings()
	_master_volume = float(settings.get("master_volume", 1.0))
	_fullscreen = bool(settings.get("fullscreen", false))
	_particles_enabled = bool(settings.get("particles_enabled", true))
	_resolution_index = int(settings.get("resolution_index", 0))
	_show_fps = bool(settings.get("show_fps", false))
	_show_cpu = bool(settings.get("show_cpu", false))
	GameSettings.apply_display_and_audio(settings)


## Called by start screen to apply settings on boot without opening the menu
static func apply_saved_settings() -> void:
	GameSettings.apply_display_and_audio(GameSettings.load_settings())

extends Node2D

const START_SCENE := "res://ui/screens/StartScreen.tscn"
const MAIN_SCENE := "res://scenes/game/main.tscn"

var _summary: Dictionary = {}
var _time: float = 0.0
var _particles: Array = []
var _screen_size: Vector2
var _hovered: String = ""
var _reveal_timer: float = 0.0
var _lines_revealed: int = 0

class Particle:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var radius: float
	var life: float
	var max_life: float


func _ready() -> void:
	_screen_size = get_viewport_rect().size
	_summary = RunManager.get_run_summary()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_burst_particles(_screen_size / 2, 60)


func _process(delta: float) -> void:
	_time += delta
	_reveal_timer += delta

	# Reveal stat lines one by one
	if _reveal_timer > 0.18:
		_reveal_timer = 0.0
		_lines_revealed = min(_lines_revealed + 1, _get_stat_lines().size())

	for p in _particles:
		p.pos += p.vel * delta
		p.vel *= 0.93
		p.life -= delta
	_particles = _particles.filter(func(p: Particle) -> bool: return p.life > 0.0)

	if randf() < delta * 2.0:
		_burst_particles(_random_edge_position(), 4)

	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_hover(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)


func _handle_hover(mouse: Vector2) -> void:
	_hovered = ""
	if _get_button_rect("play_again").has_point(mouse):
		_hovered = "play_again"
	elif _get_button_rect("main_menu").has_point(mouse):
		_hovered = "main_menu"


func _handle_click(mouse: Vector2) -> void:
	if _get_button_rect("play_again").has_point(mouse):
		_burst_particles(mouse, 30)
		await get_tree().create_timer(0.25).timeout
		get_tree().change_scene_to_file(MAIN_SCENE)
	elif _get_button_rect("main_menu").has_point(mouse):
		_burst_particles(mouse, 30)
		await get_tree().create_timer(0.25).timeout
		get_tree().change_scene_to_file(START_SCENE)


func _get_button_rect(id: String) -> Rect2:
	var cx := _screen_size.x / 2.0
	var cy := _screen_size.y / 2.0
	var base_y: float = cy + 230.0
	match id:
		"play_again": return Rect2(cx - 240, base_y, 220, 44)
		"main_menu":  return Rect2(cx + 20,  base_y, 220, 44)
		_:            return Rect2()


func _get_stat_lines() -> Array:
	var r := _summary
	var avg_rt: float = r.get("avg_reaction_time", 0.0)
	var idle: float = r.get("idle_time", 0.0)
	return [
		["DOTS DESTROYED",   "%d" % r.get("dots_destroyed", 0)],
		["ORBS COLLECTED",   "%d" % r.get("orbs_collected", 0)],
		["ORBS / SEC",       "%.2f" % r.get("orbs_per_second", 0.0)],
		["CURRENCY EARNED",  UpgradeManager.format_currency(r.get("currency_earned", 0.0))],
		["AVG REACTION",     "%.2fs" % avg_rt if avg_rt > 0.0 else "—"],
		["IDLE TIME",        "%ds" % int(idle)],
		["CARDS PLAYED",     "%d" % r.get("cards_played", 0)],
		["SHARDS EARNED",    "+%d ◆" % r.get("shards_earned", 0)],
	]


func _draw() -> void:
	var cx := _screen_size.x / 2.0
	var cy := _screen_size.y / 2.0
	var font := ThemeDB.fallback_font

	# Background
	draw_rect(Rect2(Vector2.ZERO, _screen_size), Color(0.04, 0.04, 0.04))
	for y in range(0, int(_screen_size.y), 4):
		draw_line(Vector2(0, y), Vector2(_screen_size.x, y), Color(1, 1, 1, 0.025), 1.0)
	for i in 5:
		var x := cx - 340.0 + i * 170.0
		draw_line(Vector2(x, 0), Vector2(x, _screen_size.y), Color(1, 1, 1, 0.04), 1.0)

	# Particles
	for p in _particles:
		var alpha: float = p.life / p.max_life
		draw_circle(p.pos, p.radius * alpha, Color(p.color.r, p.color.g, p.color.b, alpha * 0.85))

	# Header — use full width so text doesn't clip
	draw_string(font, Vector2(cx - 300, cy - 290), "RUN COMPLETE",
		HORIZONTAL_ALIGNMENT_CENTER, 600, 52, Color.WHITE)
	draw_string(font, Vector2(cx - 300, cy - 250), "— — —",
		HORIZONTAL_ALIGNMENT_CENTER, 600, 16, Color(1, 1, 1, 0.3))

	# Shards callout
	var shards: int = _summary.get("shards_earned", 0)
	draw_string(font, Vector2(cx - 300, cy - 220),
		"+%d SHARDS EARNED" % shards,
		HORIZONTAL_ALIGNMENT_CENTER, 600, 18, Color(1.0, 0.85, 0.2))

	# Stats — anchored from center
	var stats := _get_stat_lines()
	var row_h := 44.0
	var total_h: float = stats.size() * row_h
	var stat_start_y: float = cy - total_h / 2.0 - 10.0

	for i in min(_lines_revealed, stats.size()):
		var label: String = stats[i][0]
		var value: String = stats[i][1]
		var row_y: float = stat_start_y + i * row_h

		var slide: float = 1.0 if i < _lines_revealed - 1 else clampf((_time - i * 0.18) * 8.0, 0.0, 1.0)
		var x_offset: float = (1.0 - slide) * 40.0

		draw_string(font, Vector2(cx - 260 + x_offset, row_y),
			label, HORIZONTAL_ALIGNMENT_LEFT, 220, 14, Color(1, 1, 1, 0.5))
		draw_string(font, Vector2(cx + 40 + x_offset, row_y),
			value, HORIZONTAL_ALIGNMENT_RIGHT, 220, 14, Color.WHITE)
		draw_line(
			Vector2(cx - 260, row_y + 8),
			Vector2(cx + 260, row_y + 8),
			Color(1, 1, 1, 0.07), 1.0
		)

	# Buttons
	_draw_button("play_again", "PLAY AGAIN", font)
	_draw_button("main_menu", "MAIN MENU", font)

	# Corner brackets — frame the whole content block
	_draw_corner_brackets(cx, cy)


func _draw_button(id: String, label: String, font: Font) -> void:
	var rect := _get_button_rect(id)
	var hovered: bool = _hovered == id
	if hovered:
		draw_rect(rect, Color(1, 1, 1, 0.08))
	draw_rect(rect, Color(1, 1, 1, 0.18 if hovered else 0.1), false, 1.0)
	if hovered:
		var accent := Color(0.3, 1.0, 0.5) if id == "play_again" else Color(1, 1, 1, 0.4)
		draw_line(
			Vector2(rect.position.x, rect.end.y),
			Vector2(rect.end.x, rect.end.y),
			accent, 2.0
		)
	draw_string(font, Vector2(rect.position.x, rect.position.y + 28),
		label, HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), 15,
		Color.WHITE if hovered else Color(1, 1, 1, 0.6))


func _draw_corner_brackets(cx: float, cy: float) -> void:
	var w := 580.0
	var h := 580.0
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
		p.vel = Vector2(cos(angle), sin(angle)) * randf_range(60.0, 300.0)
		p.color = colors[randi() % colors.size()]
		p.radius = randf_range(3.0, 8.0)
		p.max_life = randf_range(0.5, 1.4)
		p.life = p.max_life
		_particles.append(p)


func _random_edge_position() -> Vector2:
	match randi() % 4:
		0: return Vector2(randf_range(0, _screen_size.x), 0)
		1: return Vector2(randf_range(0, _screen_size.x), _screen_size.y)
		2: return Vector2(0, randf_range(0, _screen_size.y))
		_: return Vector2(_screen_size.x, randf_range(0, _screen_size.y))

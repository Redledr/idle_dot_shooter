extends Node2D

const SETTINGS_PATH := "user://settings.json"
const UPDATE_INTERVAL := 0.5

var _show_fps: bool = false
var _show_cpu: bool = false
var _timer: float = 0.0
var _fps: int = 0
var _memory_mb: float = 0.0
var _process_mb: float = 0.0


func _ready() -> void:
	z_index = 128  # Always on top
	_load_telemetry_settings()


func _load_telemetry_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	_show_fps = bool(parsed.get("show_fps", false))
	_show_cpu = bool(parsed.get("show_cpu", false))


func set_show_fps(value: bool) -> void:
	_show_fps = value
	queue_redraw()


func set_show_cpu(value: bool) -> void:
	_show_cpu = value
	queue_redraw()


func _process(delta: float) -> void:
	if not _show_fps and not _show_cpu:
		return

	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		_timer = 0.0
		_fps = Engine.get_frames_per_second()
		_memory_mb = float(OS.get_static_memory_usage()) / 1_048_576.0
		_process_mb = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1_048_576.0
		queue_redraw()


func _draw() -> void:
	if not _show_fps and not _show_cpu:
		return

	var font := ThemeDB.fallback_font
	var x := 12.0
	var y := 12.0
	var line_h := 18.0
	var bg_w := 160.0
	var lines := []

	if _show_fps:
		var fps_color := _fps_color(_fps)
		lines.append(["FPS  %d" % _fps, fps_color])

	if _show_cpu:
		lines.append(["MEM  %.1f MB" % _memory_mb, Color(0.6, 1.0, 0.8)])
		lines.append(["PROC %.1f MB" % _process_mb, Color(0.6, 0.8, 1.0)])

	# Background
	draw_rect(
		Rect2(x - 4, y - 4, bg_w, lines.size() * line_h + 8),
		Color(0, 0, 0, 0.55)
	)

	for i in lines.size():
		var text: String = lines[i][0]
		var color: Color = lines[i][1]
		draw_string(font, Vector2(x, y + i * line_h + line_h - 4),
			text, HORIZONTAL_ALIGNMENT_LEFT, int(bg_w), 13, color)


func _fps_color(fps: int) -> Color:
	if fps >= 55:
		return Color(0.3, 1.0, 0.5)   # green — good
	elif fps >= 30:
		return Color(1.0, 0.85, 0.1)  # yellow — acceptable
	else:
		return Color(1.0, 0.3, 0.3)   # red — bad

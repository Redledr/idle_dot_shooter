extends CanvasItem

const SETTINGS_PATH := "user://settings.json"
const UPDATE_INTERVAL := 0.5

var _show_fps: bool = false
var _show_cpu: bool = false
var _timer: float = 0.0
var _fps: int = 0
var _memory_mb: float = 0.0
var _process_mb: float = 0.0

var _panel: PanelContainer
var _content: VBoxContainer
var _fps_label: Label
var _mem_label: Label
var _proc_label: Label


func _ready() -> void:
	layer = 128
	_build_ui()
	_load_telemetry_settings()
	_refresh_display()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(12.0, 12.0)
	add_child(_panel)

	_content = VBoxContainer.new()
	_panel.add_child(_content)

	_fps_label = Label.new()
	_mem_label = Label.new()
	_proc_label = Label.new()

	_content.add_child(_fps_label)
	_content.add_child(_mem_label)
	_content.add_child(_proc_label)


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
	_refresh_display()


func set_show_cpu(value: bool) -> void:
	_show_cpu = value
	_refresh_display()


func _process(delta: float) -> void:
	if not _show_fps and not _show_cpu:
		if _panel.visible:
			_panel.visible = false
		return

	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		_timer = 0.0
		_fps = Engine.get_frames_per_second()
		_memory_mb = float(OS.get_static_memory_usage()) / 1_048_576.0
		_process_mb = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1_048_576.0
		_refresh_display()


func _refresh_display() -> void:
	if _panel == null:
		return

	_panel.visible = _show_fps or _show_cpu
	if not _panel.visible:
		return

	_fps_label.visible = _show_fps
	_mem_label.visible = _show_cpu
	_proc_label.visible = _show_cpu

	if _show_fps:
		_fps_label.text = "FPS  %d" % _fps
		_fps_label.modulate = _fps_color(_fps)

	if _show_cpu:
		_mem_label.text = "MEM  %.1f MB" % _memory_mb
		_mem_label.modulate = Color(0.6, 1.0, 0.8)
		_proc_label.text = "PROC %.1f MB" % _process_mb
		_proc_label.modulate = Color(0.6, 0.8, 1.0)


func _fps_color(fps: int) -> Color:
	if fps >= 55:
		return Color(0.3, 1.0, 0.5)
	elif fps >= 30:
		return Color(1.0, 0.85, 0.1)
	else:
		return Color(1.0, 0.3, 0.3)

extends CanvasLayer

@export var notification_duration: float = 3.0

@onready var currency_label: Label = $TopCenter/CurrencyLabel
@onready var dots_label: Label = $TopCenter/DotsLabel
@onready var timer_label: Label = $TopCenter/TimerLabel
@onready var offline_label: Label = $OfflineLabel
@onready var perf_label: Label = $PerfLabel

var _perf_update_timer: float = 0.0



func _ready() -> void:
	offline_label.visible = false
	perf_label.visible = OS.is_debug_build()
	update_display(0.0, 0, 0.0)


func _process(delta: float) -> void:
	if not perf_label.visible:
		return

	_perf_update_timer += delta
	if _perf_update_timer < 0.25:
		return
	_perf_update_timer = 0.0
	_update_perf_label()


func update_display(currency: float, dots: int, time_remaining: float) -> void:
	currency_label.text = UpgradeManager.format_currency(currency)
	dots_label.text = "Dots: %d" % dots
	update_timer(time_remaining)


func update_timer(time_remaining: float) -> void:
	var mins: int = int(time_remaining) / 60
	var secs: int = int(time_remaining) % 60
	timer_label.text = "%d:%02d" % [mins, secs]
	# Flash red in last 30 seconds
	timer_label.modulate = Color(1.0, 0.3, 0.3) if time_remaining <= 30.0 else Color.WHITE


func show_notification(message: String) -> void:
	offline_label.text = message
	offline_label.visible = true
	offline_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(notification_duration - 1.0)
	tween.tween_property(offline_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): offline_label.visible = false; offline_label.modulate.a = 1.0)


func show_offline_summary(offline: Dictionary) -> void:
	var elapsed := int(offline["elapsed_seconds"])
	var hours := elapsed / 3600
	var minutes := (elapsed % 3600) / 60
	var time_str := "%dh %dm" % [hours, minutes] if hours > 0 else "%dm" % minutes
	show_notification("Welcome back! Away for %s\n+%s while offline" % [
		time_str, UpgradeManager.format_currency(offline["currency"])
	])


func _update_perf_label() -> void:
	var tree := get_tree()
	if tree == null:
		return

	var main := tree.get_first_node_in_group("main")
	var active_orbs: int = tree.get_nodes_in_group("orbs").size()
	var active_dots: int = tree.get_nodes_in_group("dots").size()
	var active_bullets: int = tree.get_nodes_in_group("bullets").size()
	var packed_orbs: int = -1
	var orb_cap: int = 0
	var packed_bullets: int = -1
	var bullet_cap: int = 0
	var packed_proc_bullets: int = -1
	var proc_bullet_cap: int = 0
	if main and main.has_method("get_active_orb_count"):
		packed_orbs = main.get_active_orb_count()
		orb_cap = int(main.MAX_ACTIVE_ORBS)
	if main and main.has_method("get_active_bullet_count"):
		packed_bullets = main.get_active_bullet_count()
		bullet_cap = int(main.MAX_ACTIVE_BULLETS)
	if main and main.has_method("get_active_proc_bullet_count"):
		packed_proc_bullets = main.get_active_proc_bullet_count()
		proc_bullet_cap = int(main.MAX_ACTIVE_PROC_BULLETS)

	if packed_orbs >= 0 and packed_bullets >= 0 and packed_proc_bullets >= 0:
		perf_label.text = "Perf O:%d/%d D:%d B:%d/%d P:%d/%d" % [packed_orbs, orb_cap, active_dots, packed_bullets, bullet_cap, packed_proc_bullets, proc_bullet_cap]
	elif packed_orbs >= 0:
		perf_label.text = "Perf O:%d/%d D:%d B:%d" % [packed_orbs, orb_cap, active_dots, active_bullets]
	else:
		perf_label.text = "Perf O:%d D:%d B:%d" % [active_orbs, active_dots, active_bullets]

extends CanvasLayer

@export var notification_duration: float = 3.0

@onready var currency_label: Label = $TopCenter/CurrencyLabel
@onready var dots_label: Label = $TopCenter/DotsLabel
@onready var timer_label: Label = $TopCenter/TimerLabel
@onready var offline_label: Label = $OfflineLabel



func _ready() -> void:
	offline_label.visible = false
	update_display(0.0, 0, 0.0)


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

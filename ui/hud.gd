extends CanvasLayer

@onready var currency_label: Label = $TopCenter/CurrencyLabel
@onready var dots_label: Label = $TopCenter/DotsLabel
@onready var offline_label: Label = $OfflineLabel


func _ready() -> void:
	offline_label.visible = false
	update_display(0.0, 0)


func update_display(currency: float, dots: int) -> void:
	currency_label.text = UpgradeManager.format_currency(currency)
	dots_label.text = "Dots: %d" % dots


## Shows a brief offline earnings summary then fades it out.
func show_offline_summary(offline: Dictionary) -> void:
	var elapsed := int(offline["elapsed_seconds"])
	var hours := elapsed / 3600
	var minutes := (elapsed % 3600) / 60

	var time_str: String
	if hours > 0:
		time_str = "%dh %dm" % [hours, minutes]
	else:
		time_str = "%dm" % minutes

	offline_label.text = "Welcome back! Away for %s\n+%s while offline" % [
		time_str,
		UpgradeManager.format_currency(offline["currency"])
	]
	offline_label.visible = true

	# Fade out after 4 seconds
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(offline_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): offline_label.visible = false; offline_label.modulate.a = 1.0)

extends CanvasLayer

@onready var currency_label: Label = $TopCenter/CurrencyLabel
@onready var dots_label: Label = $TopCenter/DotsLabel


func _ready() -> void:
	update_display(0.0, 0)


func update_display(currency: float, dots: int) -> void:
	currency_label.text = UpgradeManager.format_currency(currency)
	dots_label.text = "Dots: %d" % dots

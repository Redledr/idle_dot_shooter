extends CanvasLayer

@onready var currency_label: Label = $VBoxContainer/CurrencyLabel
@onready var dots_label: Label = $VBoxContainer/DotsLabel


func _ready() -> void:
	update_display(0.0, 0)


func update_display(currency: float, dots: int) -> void:
	currency_label.text = "$%.0f" % currency
	dots_label.text = "Dots: %d" % dots

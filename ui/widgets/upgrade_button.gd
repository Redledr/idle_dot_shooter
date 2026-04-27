extends PanelContainer

@export var upgrade_id: String = ""
@export var display_name: String = ""

@onready var name_label: Label = $HBox/NameLabel
@onready var level_label: Label = $HBox/LevelLabel
@onready var cost_label: Label = $HBox/CostLabel
@onready var buy_button: Button = $HBox/BuyButton


func _ready() -> void:
	name_label.text = display_name
	buy_button.pressed.connect(_on_buy_pressed)
	refresh()


func refresh() -> void:
	var level = UpgradeManager.levels[upgrade_id]
	var cost = UpgradeManager.get_cost(upgrade_id)
	level_label.text = "Lv %d" % level
	cost_label.text = UpgradeManager.format_currency(cost)


func _on_buy_pressed() -> void:
	var main = get_tree().get_first_node_in_group("main")
	if main == null:
		return
	if not UpgradeManager.can_afford(upgrade_id, main.currency):
		return
	main.currency -= UpgradeManager.get_cost(upgrade_id)
	UpgradeManager.purchase(upgrade_id)
	main.hud.update_display(main.currency, main.dots_destroyed)

extends CanvasLayer

var _active_tab: String = ""
var _panel_open: bool = false

@onready var panel_container: PanelContainer = $CenterContainer/VBoxContainer/PanelContainer
@onready var tab_bar: HBoxContainer = $CenterContainer/VBoxContainer/TabBar
@onready var defense_content: VBoxContainer = $CenterContainer/VBoxContainer/PanelContainer/Content/Defense
@onready var economy_content: VBoxContainer = $CenterContainer/VBoxContainer/PanelContainer/Content/Economy


func _ready() -> void:
	panel_container.visible = false
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	$CenterContainer/VBoxContainer/TabBar/DefenseTab.pressed.connect(_on_tab_pressed.bind("defense"))
	$CenterContainer/VBoxContainer/TabBar/EconomyTab.pressed.connect(_on_tab_pressed.bind("economy"))


func _on_tab_pressed(tab_name: String) -> void:
	if _active_tab == tab_name and _panel_open:
		_close_panel()
		return
	_active_tab = tab_name
	_open_panel(tab_name)


func _open_panel(tab_name: String) -> void:
	_panel_open = true
	panel_container.visible = true
	defense_content.visible = tab_name == "defense"
	economy_content.visible = tab_name == "economy"
	_refresh_buttons()


func _close_panel() -> void:
	_panel_open = false
	_active_tab = ""
	panel_container.visible = false


func _refresh_buttons() -> void:
	var content = defense_content if _active_tab == "defense" else economy_content
	for button in content.get_children():
		if button.has_method("refresh"):
			button.refresh()


func _on_upgrade_purchased(_id: String) -> void:
	_refresh_buttons()

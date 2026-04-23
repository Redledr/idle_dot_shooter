extends CanvasLayer

var _active_tab: String = ""
var _panel_open: bool = false

@onready var panel_container: PanelContainer = $CenterContainer/VBoxContainer/PanelContainer
@onready var tab_bar: HBoxContainer = $CenterContainer/VBoxContainer/TabBar
@onready var defense_content: VBoxContainer = $CenterContainer/VBoxContainer/PanelContainer/Content/Defense
@onready var economy_content: VBoxContainer = $CenterContainer/VBoxContainer/PanelContainer/Content/Economy
@onready var drone_content: VBoxContainer = $CenterContainer/VBoxContainer/PanelContainer/Content/Drone
@onready var drone_tab: Button = $CenterContainer/VBoxContainer/TabBar/DroneTab


func _ready() -> void:
	panel_container.visible = false
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	$CenterContainer/VBoxContainer/TabBar/DefenseTab.pressed.connect(_on_tab_pressed.bind("defense"))
	$CenterContainer/VBoxContainer/TabBar/EconomyTab.pressed.connect(_on_tab_pressed.bind("economy"))
	drone_tab.pressed.connect(_on_tab_pressed.bind("drone"))

	# Drone tab unlocks when drone is spawned
	_refresh_drone_tab_lock()


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
	drone_content.visible = tab_name == "drone"
	_refresh_buttons()


func _close_panel() -> void:
	_panel_open = false
	_active_tab = ""
	panel_container.visible = false


func _refresh_buttons() -> void:
	var content: VBoxContainer
	match _active_tab:
		"defense": content = defense_content
		"economy": content = economy_content
		"drone":   content = drone_content
		_: return

	for button in content.get_children():
		if button.has_method("refresh"):
			button.refresh()


func _refresh_drone_tab_lock() -> void:
	var drones := get_tree().get_nodes_in_group("drones")
	drone_tab.disabled = drones.is_empty()
	drone_tab.text = "Drone" if not drone_tab.disabled else "Drone 🔒"


func _on_upgrade_purchased(_id: String) -> void:
	_refresh_buttons()


## Called by main.gd after the drone is spawned so the tab unlocks immediately.
func notify_drone_spawned() -> void:
	_refresh_drone_tab_lock()

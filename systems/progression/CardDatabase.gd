extends Node

const CARDS_JSON_PATH := "res://data/runtime/cards.json"
const CARDS_RESOURCE_DIR := "res://data/cards"
const CardEffectApplier = preload("res://systems/progression/CardEffectApplier.gd")
const CardResource = preload("res://data/cards/CardResource.gd")
const CardResourceFactory = preload("res://systems/progression/CardResourceFactory.gd")

const WEIGHTS := {
	"common": 60,
	"rare": 30,
	"epic": 15,
	"legendary": 5,
}

var _cards: Array = []
var _card_resources_by_id: Dictionary = {}
var _card_views_by_id: Dictionary = {}
var codex: Array[String] = []
var active_cards: Array[String] = []
var bonus_draws: int = 0


func _ready() -> void:
	_load_cards()


func _load_cards() -> void:
	_cards.clear()
	_card_resources_by_id.clear()
	_card_views_by_id.clear()

	for card in _load_legacy_cards():
		_store_card_resource(CardResourceFactory.from_legacy_card(card as Dictionary))

	for card_resource in _load_card_resources(CARDS_RESOURCE_DIR):
		_store_card_resource(card_resource)

	_cards = _card_views_by_id.values()
	_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("id", "")) < String(b.get("id", "")))

	if _cards.is_empty():
		for fallback_card in _get_fallback_cards():
			_store_card_resource(CardResourceFactory.from_legacy_card(fallback_card))
		_cards = _card_views_by_id.values()
		push_warning("CardDatabase: no cards found, using fallback")
		return

	print("CardDatabase: loaded %d cards" % _cards.size())


func _load_legacy_cards() -> Array:
	if not FileAccess.file_exists(CARDS_JSON_PATH):
		return []

	var file := FileAccess.open(CARDS_JSON_PATH, FileAccess.READ)
	if file == null:
		return []

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.has("cards"):
		return parsed["cards"]
	return []


func _load_card_resources(directory_path: String) -> Array[CardResource]:
	var card_resources: Array[CardResource] = []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory_path)):
		return card_resources

	var dir := DirAccess.open(directory_path)
	if dir == null:
		return card_resources

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				card_resources.append_array(_load_card_resources("%s/%s" % [directory_path, file_name]))
			continue
		if not file_name.ends_with(".tres"):
			continue
		var path := "%s/%s" % [directory_path, file_name]
		var card_resource := load(path) as CardResource
		if card_resource != null and not card_resource.id.is_empty():
			card_resources.append(card_resource)
	dir.list_dir_end()

	return card_resources


func draw_hand(count: int) -> Array:
	var hand := []
	var attempts := 0
	while hand.size() < count and attempts < 200:
		attempts += 1
		var card := _weighted_random()
		if not card.is_empty() and card not in hand:
			hand.append(card)
	return hand


func apply_card(card_id: String, main: Node) -> void:
	active_cards.append(card_id)
	_add_to_codex(card_id)

	var card_resource := get_card_resource(card_id)
	if card_resource == null:
		return

	for effect_resource in card_resource.effects:
		if effect_resource != null:
			CardEffectApplier.apply_effect_data(effect_resource.to_effect_dict(), main)


func get_card(card_id: String) -> Dictionary:
	return (_card_views_by_id.get(card_id, {}) as Dictionary).duplicate(true)


func get_card_resource(card_id: String) -> CardResource:
	return _card_resources_by_id.get(card_id) as CardResource


func get_all_cards() -> Array:
	return _cards


func reset_run() -> void:
	active_cards.clear()


func _weighted_random() -> Dictionary:
	var weighted := []
	for card in _cards:
		var w: int = WEIGHTS.get((card as Dictionary).get("rarity", "common"), 10)
		for i in w:
			weighted.append(card)
	if weighted.is_empty():
		return {}
	return weighted[randi() % weighted.size()] as Dictionary


func _add_to_codex(card_id: String) -> void:
	if card_id not in codex:
		codex.append(card_id)


func _store_card_resource(card_resource: CardResource) -> void:
	if card_resource == null or card_resource.id.is_empty():
		return
	_card_resources_by_id[card_resource.id] = card_resource
	_card_views_by_id[card_resource.id] = card_resource.to_card_dict()


func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common":
			return Color(0.961, 0.969, 0.969, 1.0)
		"rare":
			return Color(0.204, 0.439, 0.831, 1.0)
		"epic":
			return Color(0.71, 0.192, 0.863, 1.0)
		"legendary":
			return Color(0.984, 0.58, 0.039, 1.0)
		_:
			return Color.WHITE


func get_category_symbol(category: String) -> String:
	match category:
		"turret":
			return "[T]"
		"drone":
			return "[D]"
		"economy":
			return "[$]"
		"wildcard":
			return "[*]"
		"elemental":
			return "[E]"
		"chain":
			return "[C]"
		"dot":
			return "[P]"
		"nuke":
			return "[N]"
		_:
			return "[?]"


func _get_fallback_cards() -> Array:
	return [
		{"id": "rapid_fire", "name": "Rapid Fire", "description": "Fire rate +1 level", "rarity": "common", "category": "turret", "effect_key": "fire_rate_levels", "effect_value": 1},
		{"id": "heavy_rounds", "name": "Heavy Rounds", "description": "Bullet damage +3 levels", "rarity": "common", "category": "turret", "effect_key": "damage_levels", "effect_value": 3},
		{"id": "twin_drone", "name": "Twin Protocol", "description": "Spawns a second drone", "rarity": "legendary", "category": "drone", "effect_key": "spawn_drone", "effect_value": 1},
		{"id": "bonus_orbs", "name": "Windfall", "description": "Dots drop 2 orbs on death", "rarity": "common", "category": "economy", "effect_key": "orbs_per_kill", "effect_value": 1},
		{"id": "time_warp", "name": "Time Warp", "description": "+30 seconds", "rarity": "legendary", "category": "wildcard", "effect_key": "run_duration_add", "effect_value": 30},
	]

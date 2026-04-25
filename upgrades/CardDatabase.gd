extends Node

# Adding a new card:
# 1. Add an entry to CARDS with a unique id
# 2. Set rarity: "common", "rare", "legendary"
# 3. Set category: "turret", "drone", "economy", "wildcard"
# 4. Implement the effect in apply_card() below

const CARDS := [
	# --- TURRET ---
	{
		"id": "rapid_fire",
		"name": "Rapid Fire",
		"description": "Fire rate x1.5",
		"rarity": "common",
		"category": "turret",
	},
	{
		"id": "heavy_rounds",
		"name": "Heavy Rounds",
		"description": "Bullet damage x2",
		"rarity": "common",
		"category": "turret",
	},
	{
		"id": "overclocked",
		"name": "Overclocked",
		"description": "Fire rate x3. Bullets are tiny.",
		"rarity": "rare",
		"category": "turret",
	},
	{
		"id": "piercing",
		"name": "Piercing Shot",
		"description": "Bullets pass through all dots",
		"rarity": "epic",
		"category": "turret",
	},

	# --- DRONE ---
	{
		"id": "drone_speed_boost",
		"name": "Afterburner",
		"description": "Drone speed x2",
		"rarity": "common",
		"category": "drone",
	},
	{
		"id": "drone_damage_boost",
		"name": "Warhead",
		"description": "Drone damage x2",
		"rarity": "rare",
		"category": "drone",
	},
	{
		"id": "twin_drone",
		"name": "Twin Protocol",
		"description": "Spawns a second drone",
		"rarity": "epic",
		"category": "drone",
	},
		{
		"id": "twin_drone",
		"name": "Twin Protocol",
		"description": "Spawns a second drone",
		"rarity": "legendary",
		"category": "drone",
	},

	# --- ECONOMY ---
	{
		"id": "bonus_orbs",
		"name": "Windfall",
		"description": "Dots drop 2 orbs on death",
		"rarity": "common",
		"category": "economy",
	},
	{
		"id": "orb_magnet",
		"name": "Magnet",
		"description": "Pickup radius x2",
		"rarity": "rare",
		"category": "economy",
	},
	{
		"id": "chain_collect",
		"name": "Chain Reaction",
		"description": "Collecting an orb pulls nearby orbs in",
		"rarity": "legendary",
		"category": "economy",
	},

	# --- WILDCARD ---
	{
		"id": "dot_frenzy",
		"name": "Dot Frenzy",
		"description": "Double the dots. Double the chaos.",
		"rarity": "rare",
		"category": "wildcard",
	},
	{
		"id": "time_warp",
		"name": "Time Warp",
		"description": "+30 seconds added to the run",
		"rarity": "legendary",
		"category": "wildcard",
	},
]

# Rarity weights for random draw
const WEIGHTS := {
	"common": 50,
	"rare": 30,
	"epic": 15,
	"legendary": 5,
}

# Cards unlocked in the codex (persistent)
var codex: Array[String] = []
# Cards active this run
var active_cards: Array[String] = []
# Bonus draw count from shop upgrades
var bonus_draws: int = 0


func draw_hand(count: int) -> Array:
	var pool := _get_draw_pool()
	var hand := []
	var attempts := 0
	while hand.size() < count and attempts < 100:
		attempts += 1
		var card := _weighted_random(pool)
		if card not in hand:
			hand.append(card)
	return hand


func apply_card(card_id: String, main: Node) -> void:
	active_cards.append(card_id)
	_add_to_codex(card_id)

	match card_id:
		"rapid_fire":
			UpgradeManager.levels["fire_rate"] += 2
			_apply_fire_rate(main)
		"heavy_rounds":
			UpgradeManager.levels["damage"] += 3
		"overclocked":
			UpgradeManager.levels["fire_rate"] += 6
			_apply_fire_rate(main)
		"piercing":
			main.set("bullets_pierce", true)
		"drone_speed_boost":
			UpgradeManager.levels["drone_speed"] += 4
		"drone_damage_boost":
			UpgradeManager.levels["drone_damage"] += 4
		"twin_drone":
			main.call("spawn_extra_drone")
		"bonus_orbs":
			main.set("orbs_per_kill", main.get("orbs_per_kill") + 1)
		"orb_magnet":
			main.orb_pickup_radius *= 2.0
			main.cursor.radius = main.orb_pickup_radius
		"chain_collect":
			main.set("chain_pickup", true)
		"dot_frenzy":
			UpgradeManager.levels["spawn_count"] += 5
		"time_warp":
			main.run_duration += 30.0


func get_card(card_id: String) -> Dictionary:
	for card in CARDS:
		if card["id"] == card_id:
			return card
	return {}


func reset_run() -> void:
	active_cards.clear()


func _get_draw_pool() -> Array:
	# If codex has cards, bias toward unlocked ones
	if codex.is_empty():
		return CARDS
	var pool := []
	for card in CARDS:
		pool.append(card)
	return pool


func _weighted_random(pool: Array) -> Dictionary:
	# Build weighted list
	var weighted := []
	for card in pool:
		var w: int = WEIGHTS.get(card["rarity"], 10)
		for i in w:
			weighted.append(card)
	return weighted[randi() % weighted.size()]


func _add_to_codex(card_id: String) -> void:
	if card_id not in codex:
		codex.append(card_id)


func _apply_fire_rate(main: Node) -> void:
	var turret := main.get_node_or_null("Turret")
	if turret:
		turret.get_node("ShooterComponent").fire_rate = UpgradeManager.get_fire_rate()


func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color(0.961, 0.969, 0.969, 1.0)
		"rare":      return Color(0.204, 0.439, 0.831, 1.0)
		"epic":		 return Color(0.71, 0.192, 0.863, 1.0)
		"legendary": return Color(0.984, 0.58, 0.039, 1.0)
		_:           return Color.WHITE


func get_category_symbol(category: String) -> String:
	match category:
		"turret":   return "⬡"
		"drone":    return "◈"
		"economy":  return "◎"
		"wildcard": return "✦"
		_:          return "?"

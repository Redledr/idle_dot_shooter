extends Node

# All run stats tracked here
var run_start_time: float = 0.0
var dots_destroyed: int = 0
var orbs_collected: int = 0
var orbs_per_second: float = 0.0
var currency_earned: float = 0.0
var shards_earned: int = 0
var idle_time: float = 0.0
var reaction_times: Array[float] = []

# Reaction time tracking
var _orb_spawn_times: Dictionary = {}  # orb instance_id -> spawn time
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _mouse_idle_timer: float = 0.0
const IDLE_THRESHOLD := 5.0  # px movement to count as active


func start_run() -> void:
	run_start_time = Time.get_unix_time_from_system()
	dots_destroyed = 0
	orbs_collected = 0
	orbs_per_second = 0.0
	currency_earned = 0.0
	shards_earned = 0
	idle_time = 0.0
	reaction_times.clear()
	_orb_spawn_times.clear()
	CardDatabase.reset_run()


func _process(delta: float) -> void:
	# Track idle time
	var mouse := get_viewport().get_mouse_position()
	if mouse.distance_to(_last_mouse_pos) < IDLE_THRESHOLD:
		_mouse_idle_timer += delta
		idle_time += delta
	else:
		_mouse_idle_timer = 0.0
	_last_mouse_pos = mouse


func register_orb_spawn(orb_id: int) -> void:
	_orb_spawn_times[orb_id] = Time.get_unix_time_from_system()


func register_orb_collected(orb_id: int) -> void:
	if _orb_spawn_times.has(orb_id):
		var reaction: float = Time.get_unix_time_from_system() - _orb_spawn_times[orb_id]
		reaction_times.append(reaction)
		_orb_spawn_times.erase(orb_id)
	orbs_collected += 1


func get_avg_reaction_time() -> float:
	if reaction_times.is_empty():
		return 0.0
	var total: float = 0.0
	for t in reaction_times:
		total += t
	return total / reaction_times.size()


func get_elapsed_time() -> float:
	return Time.get_unix_time_from_system() - run_start_time


func calculate_shards() -> int:
	# Shards = rough score / 100, minimum 1
	var score := dots_destroyed * 10 + int(currency_earned / 10)
	return max(1, score / 100)


func get_run_summary() -> Dictionary:
	var elapsed := get_elapsed_time()
	shards_earned = calculate_shards()
	return {
		"dots_destroyed": dots_destroyed,
		"orbs_collected": orbs_collected,
		"orbs_per_second": float(orbs_collected) / max(elapsed, 1.0),
		"currency_earned": currency_earned,
		"avg_reaction_time": get_avg_reaction_time(),
		"idle_time": idle_time,
		"elapsed_time": elapsed,
		"shards_earned": shards_earned,
		"cards_played": CardDatabase.active_cards.size(),
	}

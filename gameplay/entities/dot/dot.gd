extends Area2D

@export var currency_value: float = 1.0

@onready var health: HealthComponent = $HealthComponent

var _dot_color: Color = Color.WHITE
var _screen_size: Vector2
var _damage_multiplier: float = 1.0
var _damage_multiplier_time_remaining: float = 0.0
var _last_hit_context: Dictionary = {}
var _status_effects: Dictionary = {}
var _stun_time_remaining: float = 0.0


func _ready() -> void:
	add_to_group("dots")
	_screen_size = get_viewport_rect().size
	_dot_color = Color(randf(), randf_range(0.5, 1.0), randf_range(0.5, 1.0))
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)


func configure_runtime_modifiers(hp_scale: float) -> void:
	if hp_scale >= 1.0:
		return
	health.max_hp = maxf(1.0, health.max_hp * hp_scale)
	health.current_hp = minf(health.current_hp, health.max_hp)


func _process(delta: float) -> void:
	_process_status_effects(delta)
	_process_damage_multiplier(delta)
	if _is_offscreen():
		queue_free()


func _on_died() -> void:
	AudioManager.play_pop()
	var main = get_tree().get_first_node_in_group("main")
	if main:
		var kill_context := _last_hit_context.duplicate(true)
		kill_context["status_effects"] = _status_effects.duplicate(true)
		main.spawn_orb(global_position, currency_value, kill_context)
	queue_free()


func _on_damaged(_amount: float) -> void:
	_dot_color = _dot_color.lightened(0.3)
	queue_redraw()


func apply_burn(damage_per_second: float, duration: float) -> void:
	apply_status_effect("fire", {
		"dps": damage_per_second,
		"duration": duration,
		"source": "fire",
	})


func apply_frost_debuff(multiplier: float, duration: float) -> void:
	var was_default: bool = is_equal_approx(_damage_multiplier, 1.0) and _damage_multiplier_time_remaining <= 0.0
	_damage_multiplier = maxf(_damage_multiplier, multiplier)
	_damage_multiplier_time_remaining = maxf(_damage_multiplier_time_remaining, duration)
	if was_default:
		queue_redraw()


func apply_emp_stun(duration: float) -> void:
	var was_unstunned: bool = _stun_time_remaining <= 0.0
	_stun_time_remaining = maxf(_stun_time_remaining, duration)
	if was_unstunned:
		queue_redraw()


func apply_status_effect(status_name: String, effect_data: Dictionary) -> void:
	var had_status: bool = _status_effects.has(status_name)
	var effect: Dictionary = _status_effects.get(status_name, {}).duplicate(true)
	var incoming_dps: float = float(effect_data.get("dps", 0.0))
	var incoming_duration: float = float(effect_data.get("duration", 0.0))
	var max_stacks: int = max(1, int(effect_data.get("max_stacks", 1)))
	var is_permanent: bool = bool(effect_data.get("permanent", false))
	var incoming_stacks: int = max(1, int(effect_data.get("stacks", 1)))

	effect["dps"] = maxf(float(effect.get("dps", 0.0)), incoming_dps)
	effect["remaining"] = maxf(float(effect.get("remaining", 0.0)), incoming_duration)
	effect["tick_timer"] = float(effect.get("tick_timer", 0.0))
	effect["permanent"] = bool(effect.get("permanent", false)) or is_permanent
	effect["source"] = effect_data.get("source", status_name)
	effect["spread_count"] = max(int(effect.get("spread_count", 0)), int(effect_data.get("spread_count", 0)))
	effect["orb_multiplier"] = max(int(effect.get("orb_multiplier", 1)), int(effect_data.get("orb_multiplier", 1)))
	effect["max_stacks"] = max_stacks

	if max_stacks > 1:
		effect["stacks"] = min(int(effect.get("stacks", 0)) + incoming_stacks, max_stacks)
	else:
		effect["stacks"] = 1

	_status_effects[status_name] = effect
	if not had_status:
		queue_redraw()


func take_bullet_damage(amount: float) -> void:
	take_bullet_damage_with_context(amount, {})


func take_bullet_damage_with_context(amount: float, hit_context: Dictionary) -> void:
	_last_hit_context = hit_context.duplicate()
	health.take_damage(amount * _damage_multiplier)


func _is_offscreen() -> bool:
	var margin: float = 120.0
	return (
		position.x < -margin or position.x > _screen_size.x + margin
		or position.y < -margin or position.y > _screen_size.y + margin
	)


func _process_status_effects(delta: float) -> void:
	if _status_effects.is_empty() or not health.is_alive():
		return

	var visuals_changed: bool = false
	for status_name in _status_effects.keys().duplicate():
		var effect: Dictionary = (_status_effects[status_name] as Dictionary).duplicate(true)
		if not bool(effect.get("permanent", false)):
			effect["remaining"] = maxf(0.0, float(effect.get("remaining", 0.0)) - delta)
		effect["tick_timer"] = float(effect.get("tick_timer", 0.0)) + delta

		while float(effect.get("tick_timer", 0.0)) >= 1.0 and health.is_alive():
			effect["tick_timer"] = float(effect.get("tick_timer", 0.0)) - 1.0
			_last_hit_context = {
				"source": effect.get("source", status_name),
				"orb_multiplier": int(effect.get("orb_multiplier", 1)),
			}
			health.take_damage(float(effect.get("dps", 0.0)) * max(1, int(effect.get("stacks", 1))) * _damage_multiplier)

		if not bool(effect.get("permanent", false)) and float(effect.get("remaining", 0.0)) <= 0.0:
			_status_effects.erase(status_name)
			visuals_changed = true
		else:
			_status_effects[status_name] = effect

	if visuals_changed:
		queue_redraw()


func _process_damage_multiplier(delta: float) -> void:
	if _damage_multiplier_time_remaining <= 0.0:
		_damage_multiplier = 1.0
		return

	_damage_multiplier_time_remaining = maxf(0.0, _damage_multiplier_time_remaining - delta)
	if _damage_multiplier_time_remaining <= 0.0 and not is_equal_approx(_damage_multiplier, 1.0):
		_damage_multiplier = 1.0
		queue_redraw()

	if _stun_time_remaining == 0.0:
		return

	var previous_stun: float = _stun_time_remaining
	_stun_time_remaining = maxf(0.0, _stun_time_remaining - delta)
	if previous_stun > 0.0 and _stun_time_remaining == 0.0:
		queue_redraw()


func _draw() -> void:
	var hp_ratio: float = health.current_hp / health.max_hp
	var radius: float = lerp(10.0, 18.0, hp_ratio)
	var display_color := _dot_color
	if _status_effects.has("fire"):
		display_color = display_color.lerp(Color(1.0, 0.35, 0.15), 0.45)
	elif _status_effects.has("poison"):
		display_color = display_color.lerp(Color(0.45, 1.0, 0.35), 0.4)
	elif _status_effects.has("acid"):
		display_color = display_color.lerp(Color(0.75, 1.0, 0.2), 0.45)
	elif _status_effects.has("bleed"):
		display_color = display_color.lerp(Color(1.0, 0.25, 0.35), 0.35)
	if _stun_time_remaining > 0.0:
		display_color = display_color.lerp(Color(0.75, 0.9, 1.0), 0.45)
	draw_circle(Vector2.ZERO, radius, display_color)
	draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 1.5)

extends Area2D

@export var currency_value: float = 1.0

@onready var health: HealthComponent = $HealthComponent

var _dot_color: Color = Color.WHITE
var _screen_size: Vector2
var _burn_damage: float = 0.0
var _burn_time_remaining: float = 0.0
var _burn_tick_timer: float = 0.0
var _damage_multiplier: float = 1.0
var _damage_multiplier_time_remaining: float = 0.0
var _last_hit_context: Dictionary = {}


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
	_process_burn(delta)
	_process_damage_multiplier(delta)
	if _is_offscreen():
		queue_free()


func _on_died() -> void:
	AudioManager.play_pop()
	var main = get_tree().get_first_node_in_group("main")
	if main:
		main.spawn_orb(global_position, currency_value, _last_hit_context)
	queue_free()


func _on_damaged(_amount: float) -> void:
	_dot_color = _dot_color.lightened(0.3)
	queue_redraw()


func apply_burn(damage_per_second: float, duration: float) -> void:
	_burn_damage = maxf(_burn_damage, damage_per_second)
	_burn_time_remaining = maxf(_burn_time_remaining, duration)
	_burn_tick_timer = 0.0
	queue_redraw()


func apply_frost_debuff(multiplier: float, duration: float) -> void:
	_damage_multiplier = maxf(_damage_multiplier, multiplier)
	_damage_multiplier_time_remaining = maxf(_damage_multiplier_time_remaining, duration)
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


func _process_burn(delta: float) -> void:
	if _burn_time_remaining <= 0.0 or not health.is_alive():
		return

	_burn_time_remaining = maxf(0.0, _burn_time_remaining - delta)
	_burn_tick_timer += delta
	if _burn_tick_timer >= 1.0:
		_burn_tick_timer -= 1.0
		health.take_damage(_burn_damage * _damage_multiplier)
	queue_redraw()


func _process_damage_multiplier(delta: float) -> void:
	if _damage_multiplier_time_remaining <= 0.0:
		_damage_multiplier = 1.0
		return

	_damage_multiplier_time_remaining = maxf(0.0, _damage_multiplier_time_remaining - delta)


func _draw() -> void:
	var hp_ratio: float = health.current_hp / health.max_hp
	var radius: float = lerp(10.0, 18.0, hp_ratio)
	var display_color := _dot_color
	if _burn_time_remaining > 0.0:
		display_color = display_color.lerp(Color(1.0, 0.35, 0.15), 0.45)
	draw_circle(Vector2.ZERO, radius, display_color)
	draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 1.5)

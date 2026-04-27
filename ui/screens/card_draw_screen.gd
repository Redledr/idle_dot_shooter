extends Node2D

signal card_chosen(card_id: String)

@export var card_count: int = 3
@export var use_parallax_v2: bool = false
@export var parallax_strength: float = 28.0
@export var hover_lift: float = 50.0
@export var parallax_lerp_speed: float = 6.0
@export var lift_lerp_speed: float = 8.0
@export var tilt_strength: float = 6.0
@export var tilt_zone_multiplier: float = 2.0
@export var intro_duration: float = 0.55
@export var intro_stagger: float = 0.08
@export var intro_y_offset: float = 140.0
@export var intro_header_offset: float = 28.0

const CARD_W := 200.0
const CARD_H := 290.0
const ARC_DEPTH := 50.0

var _cards: Array = []
var _time: float = 0.0
var _particles: Array = []
var _screen_size: Vector2
var _hovered_index: int = -1
var _chosen_index: int = -1
var _animating: bool = false
var _intro_timer: float = 0.0

# Per-card smooth state
var _parallax_current: Array = []   # Array of Vector2
var _lift_current: Array = []       # Array of float
var _aura_timer: float = 0.0        # chosen card aura pulse timer

class Particle:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var radius: float
	var life: float
	var max_life: float


func _ready() -> void:
	_screen_size = get_viewport_rect().size
	_cards = CardDatabase.draw_hand(card_count + CardDatabase.bonus_draws)
	_parallax_current.resize(_cards.size())
	_parallax_current.fill(Vector2.ZERO)
	_lift_current.resize(_cards.size())
	_lift_current.fill(0.0)


func _process(delta: float) -> void:
	_time += delta
	_intro_timer += delta

	var mouse := get_global_mouse_position()

	# Smooth parallax and lift per card
	for i in _cards.size():
		var center := _get_card_center(i)
		var is_hovered: bool = i == _hovered_index and not _animating and not _is_intro_active()

		# Target parallax
		var target_parallax := _get_target_parallax(i, mouse, center, is_hovered)

		_parallax_current[i] = (_parallax_current[i] as Vector2).lerp(
			target_parallax, parallax_lerp_speed * delta
		)

		# Target lift
		var target_lift: float = hover_lift if is_hovered else 0.0
		_lift_current[i] = lerpf(_lift_current[i] as float, target_lift, lift_lerp_speed * delta)

		# Ambient hover particles — trickle while hovered
		if is_hovered and not _animating:
			var card_center := _get_card_center(i)
			var rarity: String = (_cards[i] as Dictionary).get("rarity", "common")
			var rarity_color: Color = CardDatabase.get_rarity_color(rarity)
			if randf() < delta * 12.0:
				_spawn_hover_particle(card_center, rarity_color)

	# Aura timer
	if _animating and _chosen_index >= 0:
		_aura_timer += delta
		# Burst particles from card edges during aura
		if int(_aura_timer * 20.0) % 2 == 0:
			var center := _get_card_center(_chosen_index)
			var rarity: String = (_cards[_chosen_index] as Dictionary).get("rarity", "common")
			var rarity_color: Color = CardDatabase.get_rarity_color(rarity)
			_burst_rarity_particles(center, rarity_color, 3)
		# Emit after aura has played for 0.8s
		if _aura_timer > 0.8:
			var chosen_id: String = (_cards[_chosen_index] as Dictionary)["id"]
			card_chosen.emit(chosen_id)

	# Particles
	for p in _particles:
		p.pos += p.vel * delta
		p.vel *= 0.92
		p.life -= delta
	_particles = _particles.filter(func(p: Particle) -> bool: return p.life > 0.0)

	queue_redraw()


func _input(event: InputEvent) -> void:
	if _animating or _is_intro_active():
		return
	if event is InputEventMouseMotion:
		_handle_hover(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)


func _handle_hover(mouse: Vector2) -> void:
	_hovered_index = -1
	for i in _cards.size():
		if _get_card_rect(i).has_point(mouse):
			_hovered_index = i
			break


func _handle_click(mouse: Vector2) -> void:
	for i in _cards.size():
		if _get_card_rect(i).has_point(mouse):
			_choose_card(i)
			break


func _choose_card(index: int) -> void:
	_animating = true
	_chosen_index = index
	_aura_timer = 0.0
	# Initial burst
	var center := _get_card_center(index)
	var rarity: String = (_cards[index] as Dictionary).get("rarity", "common")
	_burst_rarity_particles(center, CardDatabase.get_rarity_color(rarity), 30)


func _get_card_center(index: int) -> Vector2:
	var cx := _screen_size.x / 2.0
	var base_y: float = _screen_size.y - CARD_H / 2.0 - 40.0
	var total := _cards.size()
	var spacing: float = minf(CARD_W + 30.0, (_screen_size.x - 300.0) / float(total))
	var start_x: float = cx - float(total - 1) * spacing / 2.0
	var arc_t: float = float(index) / float(max(total - 1, 1)) - 0.5
	var arc_y: float = arc_t * arc_t * ARC_DEPTH
	var intro_t := _get_intro_progress(index)
	var intro_y := lerpf(intro_y_offset, 0.0, intro_t)
	var intro_x := lerpf(arc_t * 34.0, 0.0, intro_t)
	return Vector2(start_x + float(index) * spacing + intro_x, base_y + arc_y + intro_y)


func _get_card_rect(index: int) -> Rect2:
	var center := _get_card_center(index)
	var lift: float = _lift_current[index] if index < _lift_current.size() else 0.0
	var px: Vector2 = _parallax_current[index] if index < _parallax_current.size() else Vector2.ZERO
	return Rect2(
		center.x - CARD_W / 2.0 + px.x,
		center.y - CARD_H / 2.0 - lift + px.y,
		CARD_W, CARD_H
	)


func _draw() -> void:
	var cx := _screen_size.x / 2.0
	var font := ThemeDB.fallback_font
	var header_t := _get_intro_header_progress()

	# Dim overlay
	draw_rect(Rect2(Vector2.ZERO, _screen_size), Color(0, 0, 0, 0.78 * header_t))

	# Particles
	for p in _particles:
		var alpha: float = p.life / p.max_life
		draw_circle(p.pos, p.radius * alpha, Color(p.color.r, p.color.g, p.color.b, alpha))

	# Header
	draw_string(
		font,
		Vector2(cx - 200, _screen_size.y - CARD_H - 90 + lerpf(intro_header_offset, 0.0, header_t)),
		"CHOOSE A CARD",
		HORIZONTAL_ALIGNMENT_CENTER,
		400,
		22,
		Color(1, 1, 1, 0.8 * header_t)
	)

	# Cards — draw non-hovered first, then hovered on top
	for i in _cards.size():
		if i == _hovered_index or (_animating and i == _chosen_index):
			continue
		_draw_card(i, font)

	# Draw chosen card with aura if animating
	if _animating and _chosen_index >= 0:
		_draw_card_aura(_chosen_index)
		_draw_card(_chosen_index, font)
	elif _hovered_index >= 0:
		_draw_card(_hovered_index, font)


func _draw_card(index: int, font: Font) -> void:
	var card: Dictionary = _cards[index] as Dictionary
	var hovered: bool = index == _hovered_index and not _animating
	var chosen: bool = _animating and index == _chosen_index
	var center := _get_card_center(index)

	var lift: float = _lift_current[index] if index < _lift_current.size() else 0.0
	var px: Vector2 = _parallax_current[index] if index < _parallax_current.size() else Vector2.ZERO
	var card_center := Vector2(center.x + px.x, center.y - lift + px.y)

	var mouse := get_global_mouse_position()
	var tilt := Vector2.ZERO
	if hovered or chosen:
		tilt = (mouse - card_center) / Vector2(CARD_W * tilt_zone_multiplier, CARD_H * tilt_zone_multiplier)
		tilt = tilt.clamp(Vector2(-1, -1), Vector2(1, 1))

	var rarity_color: Color = CardDatabase.get_rarity_color(card.get("rarity", "common"))

	# Build perspective-warped corners.
	# Each corner is pushed in/out based on how much it aligns with the tilt direction.
	# A corner on the same side as the tilt gets pulled back (shrinks toward center).
	# Opposite corner comes forward (pushed out from center).
	var half := Vector2(CARD_W / 2.0, CARD_H / 2.0)


	# Corner directions relative to card center: TL, TR, BR, BL
	var corner_dirs := [
		Vector2(-1, -1), Vector2(1, -1),
		Vector2(1,  1),  Vector2(-1,  1)
	]

	# For each corner, dot product with tilt tells us how much to push it
	var corners: PackedVector2Array = PackedVector2Array()
	for cd in corner_dirs:
		var base: Vector2 = card_center + cd * half
		var dot: float = cd.dot(tilt)
		var warp: Vector2 = cd * (-dot * tilt_strength)
		corners.append(base + warp)

	# Outer edge glow — multiple expanding border passes on hover
	if hovered or chosen:
		var glow_pulse: float = 0.7 + sin(_time * 3.0) * 0.3
		for glow_layer in 4:
			var expand: float = float(glow_layer + 1) * 3.5
			var glow_alpha: float = (0.18 - float(glow_layer) * 0.04) * glow_pulse
			var glow_corners := PackedVector2Array()
			for cd in corner_dirs:
				var base: Vector2 = card_center + cd * (half + Vector2(expand, expand))
				var dot: float = cd.dot(tilt)
				var warp: Vector2 = cd * (-dot * tilt_strength)
				glow_corners.append(base + warp)
			draw_colored_polygon(glow_corners,
				Color(rarity_color.r, rarity_color.g, rarity_color.b, glow_alpha))
			draw_polyline(
				PackedVector2Array([glow_corners[0], glow_corners[1], glow_corners[2], glow_corners[3], glow_corners[0]]),
				Color(rarity_color.r, rarity_color.g, rarity_color.b, glow_alpha * 1.5),
				1.0
			)

	# Shadow
	var shadow_shift := tilt * 10.0 + Vector2(4, 6)
	var shadow_corners := PackedVector2Array()
	for c in corners:
		shadow_corners.append(c + shadow_shift)
	draw_colored_polygon(shadow_corners, Color(0, 0, 0, 0.5))

	# Card body
	draw_colored_polygon(corners, Color(0.07, 0.07, 0.09))

	# Rarity top bar
	var bar_h_ratio: float = 5.0 / CARD_H
	var bar_quad := PackedVector2Array([
		corners[0], corners[1],
		corners[1].lerp(corners[2], bar_h_ratio),
		corners[0].lerp(corners[3], bar_h_ratio),
	])
	draw_colored_polygon(bar_quad,
		Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.95))

	# Border outline
	var border_alpha: float = 1.0 if (hovered or chosen) else 0.45
	draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]),
		Color(rarity_color.r, rarity_color.g, rarity_color.b, border_alpha),
		2.0 if (hovered or chosen) else 1.0)

	# Inner glow on hover — stronger pulse
	if hovered or chosen:
		var inner_pulse: float = 0.08 + sin(_time * 4.0) * 0.04
		draw_colored_polygon(corners,
			Color(rarity_color.r, rarity_color.g, rarity_color.b, inner_pulse))

	# Text layers — use card_center offset by tilt at varying depths
	# Layer 1: symbol + rarity label (shallow)
	var t1 := card_center + tilt * -2.0
	draw_set_transform(t1, 0.0, Vector2.ONE)
	var bp := Vector2(-CARD_W / 2.0, -CARD_H / 2.0)
	draw_string(font, Vector2(bp.x + 10, bp.y + 26),
		CardDatabase.get_category_symbol(card.get("category", "")),
		HORIZONTAL_ALIGNMENT_LEFT, 30, 17,
		Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.75))
	draw_string(font, Vector2(bp.x, bp.y + 26),
		card.get("rarity", "").to_upper(),
		HORIZONTAL_ALIGNMENT_RIGHT, int(CARD_W) - 10, 11,
		Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.65))

	# Layer 2: card name + divider (mid)
	var t2 := card_center + tilt * 2.0
	draw_set_transform(t2, 0.0, Vector2.ONE)
	draw_string(font, Vector2(bp.x + 10, bp.y + 90),
		card.get("name", ""),
		HORIZONTAL_ALIGNMENT_LEFT, int(CARD_W) - 20, 19, Color.WHITE)
	draw_line(Vector2(bp.x + 10, bp.y + 100),
		Vector2(bp.x + CARD_W - 10, bp.y + 100),
		Color(1, 1, 1, 0.12), 1.0)

	# Layer 3: description (closest, floats most)
	var t3 := card_center + tilt * 6.0
	draw_set_transform(t3, 0.0, Vector2.ONE)
	draw_multiline_string(font, Vector2(bp.x + 10, bp.y + 130),
		card.get("description", ""),
		HORIZONTAL_ALIGNMENT_LEFT, int(CARD_W) - 20, 14,
		-1, Color(1, 1, 1, 0.72))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_card_aura(index: int) -> void:
	var center := _get_card_center(index)
	var lift: float = _lift_current[index] if index < _lift_current.size() else 0.0
	var px: Vector2 = _parallax_current[index] if index < _parallax_current.size() else Vector2.ZERO
	var card_center := Vector2(center.x + px.x, center.y - lift + px.y)

	var rarity: String = (_cards[index] as Dictionary).get("rarity", "common")
	var rarity_color: Color = CardDatabase.get_rarity_color(rarity)

	# Pulsing rings
	for ring in 3:
		var ring_t: float = fmod(_aura_timer * 2.0 + float(ring) * 0.33, 1.0)
		var ring_radius: float = (CARD_W * 0.6 + ring_t * CARD_W * 0.8)
		var ring_alpha: float = (1.0 - ring_t) * 0.5
		draw_arc(card_center, ring_radius, 0.0, TAU, 48,
			Color(rarity_color.r, rarity_color.g, rarity_color.b, ring_alpha), 3.0)

	# Inner glow
	var pulse: float = 0.5 + sin(_aura_timer * 12.0) * 0.5
	draw_circle(card_center, CARD_W * 0.55,
		Color(rarity_color.r, rarity_color.g, rarity_color.b, pulse * 0.12))


func _spawn_hover_particle(card_center: Vector2, rarity_color: Color) -> void:
	# Spawn from a random edge of the card, float upward slowly
	var p := Particle.new()
	var side := randi() % 4
	match side:
		0: p.pos = card_center + Vector2(randf_range(-CARD_W / 2.0, CARD_W / 2.0), -CARD_H / 2.0)
		1: p.pos = card_center + Vector2(randf_range(-CARD_W / 2.0, CARD_W / 2.0), CARD_H / 2.0)
		2: p.pos = card_center + Vector2(-CARD_W / 2.0, randf_range(-CARD_H / 2.0, CARD_H / 2.0))
		3: p.pos = card_center + Vector2(CARD_W / 2.0, randf_range(-CARD_H / 2.0, CARD_H / 2.0))
	# Gentle upward drift with slight random spread
	p.vel = Vector2(randf_range(-15.0, 15.0), randf_range(-40.0, -10.0))
	p.color = rarity_color.lerp(Color.WHITE, randf_range(0.2, 0.7))
	p.radius = randf_range(2.0, 5.0)
	p.max_life = randf_range(0.8, 1.8)
	p.life = p.max_life
	_particles.append(p)


func _burst_rarity_particles(origin: Vector2, rarity_color: Color, count: int) -> void:
	for i in count:
		var p := Particle.new()
		var angle := randf() * TAU
		var edge_x: float = (CARD_W / 2.0) * (1.0 if cos(angle) > 0 else -1.0)
		var edge_y: float = (CARD_H / 2.0) * (1.0 if sin(angle) > 0 else -1.0)
		p.pos = origin + Vector2(
			randf_range(-CARD_W / 2.0, CARD_W / 2.0),
			randf_range(-CARD_H / 2.0, CARD_H / 2.0)
		)
		p.vel = Vector2(cos(angle), sin(angle)) * randf_range(60.0, 280.0)
		# Mix rarity color with white
		p.color = rarity_color.lerp(Color.WHITE, randf_range(0.0, 0.5))
		p.radius = randf_range(3.0, 8.0)
		p.max_life = randf_range(0.4, 1.1)
		p.life = p.max_life
		_particles.append(p)
		# Suppress unused warnings
		var _unused := edge_x + edge_y


func _get_target_parallax(index: int, mouse: Vector2, center: Vector2, is_hovered: bool) -> Vector2:
	if _is_intro_active():
		return Vector2.ZERO

	var offset := mouse - center
	var screen_normalized := offset / (_screen_size / 2.0)
	if not use_parallax_v2:
		if is_hovered:
			return screen_normalized * parallax_strength
		return Vector2.ZERO

	var distance := mouse.distance_to(center)
	var radius := CARD_W * 2.25
	var influence := clampf(1.0 - distance / radius, 0.0, 1.0)
	influence = influence * influence * (3.0 - 2.0 * influence)

	var local_normalized := Vector2(
		clampf(offset.x / (CARD_W * 0.9), -1.0, 1.0),
		clampf(offset.y / (CARD_H * 0.9), -1.0, 1.0)
	)
	var fan := float(index) - float(max(_cards.size() - 1, 1)) * 0.5
	var ambient := Vector2(
		sin(_time * 1.5 + float(index) * 0.7),
		cos(_time * 1.2 + float(index) * 0.45)
	) * 2.0 * influence
	var target := screen_normalized * parallax_strength * (0.2 + influence * 0.5)
	target += local_normalized * (parallax_strength * 0.35 * influence)
	target += Vector2(fan * 1.4, -abs(fan) * 0.6) * influence
	target += ambient
	if is_hovered:
		target += screen_normalized * (parallax_strength * 0.55)
	return target


func _is_intro_active() -> bool:
	return _intro_timer < intro_duration + intro_stagger * float(max(_cards.size() - 1, 0))


func _get_intro_progress(index: int) -> float:
	var start_time := intro_stagger * float(index)
	var t := clampf((_intro_timer - start_time) / intro_duration, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _get_intro_header_progress() -> float:
	var t := clampf(_intro_timer / maxf(0.01, intro_duration * 0.75), 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 2.0)

extends Node2D

@export var radius: float = 32.0
@export var rotation_speed: float = 1.5
@export var dash_count: int = 12
@export var dash_gap_ratio: float = 0.4
@export var color: Color = Color(1, 1, 1, 0.7)
@export var thickness: float = 1.5
@export var show_pickup_ring: bool = true

var _angle: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	top_level = true
	z_index = 100


func _process(delta: float) -> void:
	global_position = get_global_mouse_position()
	_angle += rotation_speed * delta
	queue_redraw()


func set_gameplay_mode(enabled: bool) -> void:
	show_pickup_ring = enabled


func _draw() -> void:
	# Crosshair lines — always visible
	var cross_size := 6.0
	var cross_gap := 3.0
	var c := Color(1, 1, 1, 0.9)

	# Horizontal
	draw_line(Vector2(-cross_size - cross_gap, 0), Vector2(-cross_gap, 0), c, 1.5)
	draw_line(Vector2(cross_gap, 0), Vector2(cross_size + cross_gap, 0), c, 1.5)
	# Vertical
	draw_line(Vector2(0, -cross_size - cross_gap), Vector2(0, -cross_gap), c, 1.5)
	draw_line(Vector2(0, cross_gap), Vector2(0, cross_size + cross_gap), c, 1.5)

	# Corner ticks — small L-shapes at 45 degrees for precision feel
	var tick := 4.0
	var tick_dist := 2.5
	for i in 4:
		var angle := PI / 4.0 + i * PI / 2.0
		var dir := Vector2(cos(angle), sin(angle))
		var perp := Vector2(-dir.y, dir.x)
		var origin := dir * (cross_gap + tick_dist)
		draw_line(origin, origin + dir * tick, Color(1, 1, 1, 0.4), 1.0)
		draw_line(origin, origin + perp * tick * 0.6, Color(1, 1, 1, 0.4), 1.0)

	# Pickup ring — only in gameplay
	if show_pickup_ring:
		var arc_per_dash := TAU / dash_count
		var gap := arc_per_dash * dash_gap_ratio
		var filled := arc_per_dash - gap
		for i in dash_count:
			var start_angle := _angle + i * arc_per_dash
			draw_arc(Vector2.ZERO, radius, start_angle, start_angle + filled, 12, color, thickness)

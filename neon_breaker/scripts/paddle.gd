class_name Paddle
extends AnimatableBody2D
## Player controlled paddle. Keyboard, joypad and mouse are all supported and
## switch automatically depending on the last input device used.

const MIN_WIDTH := 90.0
const MAX_WIDTH := 240.0

var width: float = Boot.PADDLE_SIZE.x
var height: float = Boot.PADDLE_SIZE.y

var _velocity: float = 0.0
var _squash: float = 1.0
var _expand_time_left: float = 0.0
var _use_mouse: bool = false
var _collision: CollisionShape2D

func _ready() -> void:
	_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	position = Vector2((Boot.ARENA.position.x + Boot.ARENA.end.x) * 0.5, Boot.PADDLE_Y)
	_rebuild_shape()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_use_mouse = true
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_use_mouse = false

func _physics_process(delta: float) -> void:
	if _expand_time_left > 0.0:
		_expand_time_left -= delta
		if _expand_time_left <= 0.0:
			set_width(Boot.PADDLE_SIZE.x)
			_expand_time_left = 0.0

	var direction := Input.get_axis("move_left", "move_right")
	if _use_mouse:
		var target := get_global_mouse_position().x
		var delta_x := target - global_position.x
		direction = clampf(delta_x / 60.0, -1.0, 1.0)
	_velocity = move_toward(_velocity, direction * Boot.PADDLE_SPEED, Boot.PADDLE_ACCEL * delta)

	var half := width * 0.5
	var new_x := clampf(global_position.x + _velocity * delta, Boot.ARENA.position.x + half, Boot.ARENA.end.x - half)
	global_position = Vector2(new_x, Boot.PADDLE_Y)

	if _squash < 1.0:
		_squash = minf(_squash + delta * 4.0, 1.0)
		queue_redraw()

func set_width(new_width: float) -> void:
	width = clampf(new_width, MIN_WIDTH, MAX_WIDTH)
	_rebuild_shape()
	queue_redraw()

## Temporarily widens the paddle (power-up).
func expand(duration: float = 18.0, factor: float = 1.4) -> void:
	set_width(maxf(width, Boot.PADDLE_SIZE.x) * factor)
	_expand_time_left = duration

func play_hit(offset: float) -> void:
	_squash = 0.72
	queue_redraw()

func _rebuild_shape() -> void:
	if _collision == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	_collision.shape = rect

func _draw() -> void:
	var drawn_height := height * _squash
	var rect := Rect2(-width * 0.5, -drawn_height * 0.5, width, drawn_height)
	var core := Color(0.45, 0.95, 1.0).lerp(Color(1.0, 0.45, 0.9), 1.0 - _squash)

	draw_rect(rect.grow(6.0), Color(0.35, 0.85, 1.0, 0.12))
	draw_rect(rect, Color(0.06, 0.10, 0.18))
	draw_rect(rect.grow(-3.0), core)
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 4.0), Vector2(rect.size.x, 4.0)), core.darkened(0.5))
	# Little thruster strip in the middle.
	var strip := Rect2(Vector2(-width * 0.22, -2.0), Vector2(width * 0.44, 4.0))
	draw_rect(strip, Color(1, 1, 1, 0.75))

class_name Ball
extends CharacterBody2D
## The ball. Uses `move_and_collide` with manual reflection so the bounce off
## the paddle can be aimed precisely.

signal bounced_on_paddle(offset: float)
signal hit_brick(brick: Brick)
signal left_field(ball: Ball)

const TRAIL_POINTS := 16
const MAX_BOUNCE_ANGLE := 62.0

var speed: float = Boot.BALL_START_SPEED
var stuck: bool = true

var _paddle: Paddle = null
var _trail: Line2D
var _trail_positions: Array[Vector2] = []

func _ready() -> void:
	_trail = get_node_or_null("Trail") as Line2D
	if _trail != null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 0.35, 0.85, 0.0))
		gradient.set_color(1, Color(0.55, 0.95, 1.0, 0.85))
		_trail.gradient = gradient
		_trail.points = PackedVector2Array()

## Parks the ball on top of the paddle until `launch()` is called.
func attach_to_paddle(paddle: Paddle) -> void:
	_paddle = paddle
	stuck = true
	velocity = Vector2.ZERO
	_sync_with_paddle()
	_update_trail()

func launch() -> void:
	if not stuck:
		return
	stuck = false
	var angle := deg_to_rad(randf_range(-38.0, 38.0) - 90.0)
	velocity = Vector2(cos(angle), sin(angle)).normalized() * speed
	_trail_positions.clear()

func set_speed(new_speed: float) -> void:
	speed = clampf(new_speed, 160.0, Boot.BALL_MAX_SPEED)
	if not stuck:
		velocity = velocity.normalized() * speed

func _physics_process(delta: float) -> void:
	if stuck:
		if _paddle != null and is_instance_valid(_paddle):
			_sync_with_paddle()
		_update_trail()
		return

	var collision := move_and_collide(velocity * delta)
	if collision != null:
		_resolve_collision(collision)

	if global_position.y > Boot.ARENA.end.y + 48.0:
		left_field.emit(self)
		return
	_update_trail()

func _sync_with_paddle() -> void:
	if _paddle == null or not is_instance_valid(_paddle):
		return
	global_position = _paddle.global_position + Vector2(_paddle.width * 0.16, -Boot.PADDLE_SIZE.y * 0.5 - Boot.BALL_RADIUS - 1.0)

func _resolve_collision(collision: KinematicCollision2D) -> void:
	var normal := collision.get_normal()
	var collider := collision.get_collider()

	if collider is Paddle:
		var paddle := collider as Paddle
		var offset := 0.0
		if paddle.width > 0.0:
			offset = clampf((global_position.x - paddle.global_position.x) / (paddle.width * 0.5), -1.0, 1.0)
		var angle := deg_to_rad(offset * MAX_BOUNCE_ANGLE)
		velocity = Vector2(sin(angle), -cos(angle)).normalized() * speed
		bounced_on_paddle.emit(offset)
	elif collider is Brick:
		hit_brick.emit(collider as Brick)
		velocity = velocity.bounce(normal)
	else:
		velocity = velocity.bounce(normal)

	# Keep the trajectory from becoming (almost) horizontal.
	var min_vertical := speed * 0.28
	if absf(velocity.y) < min_vertical:
		var sign_y := -1.0 if velocity.y <= 0.0 else 1.0
		velocity.y = min_vertical * sign_y
		velocity.x = sqrt(maxf(speed * speed - velocity.y * velocity.y, 1.0)) * signf(velocity.x if velocity.x != 0.0 else 1.0)

	velocity = velocity.normalized() * speed
	# Nudge out of the surface to avoid re-colliding on the next frame.
	global_position += normal * 0.75

func _update_trail() -> void:
	if _trail == null:
		return
	_trail_positions.push_front(global_position)
	while _trail_positions.size() > TRAIL_POINTS:
		_trail_positions.pop_back()
	_trail.points = PackedVector2Array(_trail_positions)

func _draw() -> void:
	# Soft halo + bright core.
	draw_circle(Vector2.ZERO, Boot.BALL_RADIUS * 2.1, Color(0.5, 0.9, 1.0, 0.10))
	draw_circle(Vector2.ZERO, Boot.BALL_RADIUS * 1.45, Color(0.6, 0.95, 1.0, 0.22))
	draw_circle(Vector2.ZERO, Boot.BALL_RADIUS, Color(0.92, 0.98, 1.0))
	draw_circle(Vector2(-2.0, -2.0), Boot.BALL_RADIUS * 0.42, Color(1, 1, 1))

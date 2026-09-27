class_name Game
extends Node2D
## Owns the whole run: bricks, balls, power-ups, score and level flow.

signal score_changed(score: int, combo: int)
signal lives_changed(lives: int)
signal level_changed(level: int)
signal level_cleared(level: int)
signal game_finished(score: int, level: int, won: bool)
signal shake_requested(amount: float)

enum State { IDLE, READY, PLAYING, PAUSED, CLEARED, FINISHED }

const BALL_SCENE := preload("res://scenes/ball.tscn")
const BRICK_SCENE := preload("res://scenes/brick.tscn")
const POWERUP_SCENE := preload("res://scenes/powerup.tscn")

const POWERUP_CHANCE := 0.22
const COMBO_PER_STEP := 4
const MAX_MULTIPLIER := 5

@onready var paddle: Paddle = $Paddle
@onready var bricks_root: Node2D = $Bricks
@onready var balls_root: Node2D = $Balls
@onready var powerups_root: Node2D = $PowerUps
@onready var effects_root: Node2D = $Effects

var state: State = State.IDLE
var score: int = 0
var lives: int = Boot.START_LIVES
var level: int = 1
var combo: int = 0
var bricks_left: int = 0

func _process(_delta: float) -> void:
	if state == State.READY and Input.is_action_just_pressed("launch"):
		launch_balls()

# --------------------------------------------------------------------------- #
# Public API
# --------------------------------------------------------------------------- #
func start_new_game() -> void:
	score = 0
	lives = Boot.START_LIVES
	level = 1
	combo = 0
	start_level()

func start_level() -> void:
	_clear_field()
	_spawn_bricks()
	_spawn_ball()
	state = State.READY
	level_changed.emit(level)
	score_changed.emit(score, combo)
	lives_changed.emit(lives)

func launch_balls() -> void:
	var launched := false
	for ball: Ball in balls():
		if ball.stuck:
			ball.launch()
			launched = true
	if launched:
		state = State.PLAYING
		shake_requested.emit(0.08)

func balls() -> Array[Ball]:
	var result: Array[Ball] = []
	for child in balls_root.get_children():
		if child is Ball:
			result.append(child as Ball)
	return result

func multiplier() -> int:
	return clampi(1 + combo / COMBO_PER_STEP, 1, MAX_MULTIPLIER)

func stop() -> void:
	state = State.IDLE
	for ball: Ball in balls():
		ball.set_physics_process(false)

# --------------------------------------------------------------------------- #
# Level construction
# --------------------------------------------------------------------------- #
func _spawn_bricks() -> void:
	bricks_left = 0
	for entry: Dictionary in LevelGen.build(level):
		var brick: Brick = BRICK_SCENE.instantiate()
		bricks_root.add_child(brick)
		brick.setup(entry["cell"], entry["hp"], entry["hue"], entry["points"])
		brick.destroyed.connect(_on_brick_destroyed)
		brick.damaged.connect(_on_brick_damaged)
		bricks_left += 1

func _spawn_ball() -> void:
	var ball := _make_ball()
	ball.attach_to_paddle(paddle)

func _make_ball() -> Ball:
	var ball: Ball = BALL_SCENE.instantiate()
	balls_root.add_child(ball)
	ball.bounced_on_paddle.connect(_on_ball_bounced_on_paddle)
	ball.hit_brick.connect(_on_ball_hit_brick)
	ball.left_field.connect(_on_ball_left_field)
	ball.speed = Boot.BALL_START_SPEED + float(level - 1) * Boot.BALL_SPEED_PER_LEVEL
	return ball

func _clear_field() -> void:
	for container: Node in [bricks_root, balls_root, powerups_root, effects_root]:
		for child in container.get_children():
			child.queue_free()
	bricks_left = 0
	combo = 0

# --------------------------------------------------------------------------- #
# Ball callbacks
# --------------------------------------------------------------------------- #
func _on_ball_bounced_on_paddle(offset: float) -> void:
	if state == State.CLEARED or state == State.FINISHED:
		return
	paddle.play_hit(offset)
	Sfx.play("paddle", 1.0 + offset * 0.18)
	shake_requested.emit(0.10)
	if combo > 0:
		combo = 0
		score_changed.emit(score, combo)

func _on_ball_hit_brick(brick: Brick) -> void:
	if state != State.PLAYING and state != State.READY:
		return
	if brick.take_hit():
		return
	Sfx.play("brick_hit", randf_range(0.95, 1.05), -4.0)

func _on_ball_left_field(ball: Ball) -> void:
	ball.queue_free()
	if state == State.CLEARED or state == State.FINISHED:
		return
	var still_in_play := 0
	for other: Ball in balls():
		if other != ball:
			still_in_play += 1
	if still_in_play > 0:
		return
	lives -= 1
	lives_changed.emit(lives)
	combo = 0
	score_changed.emit(score, combo)
	shake_requested.emit(0.55)
	if lives <= 0:
		Sfx.play("game_over")
		_finish(false)
	else:
		Sfx.play("life_lost")
		_spawn_ball()
		state = State.READY

# --------------------------------------------------------------------------- #
# Brick callbacks
# --------------------------------------------------------------------------- #
func _on_brick_damaged(brick: Brick) -> void:
	Sfx.play("brick_hit", randf_range(0.9, 1.1), -6.0)
	spawn_burst(brick.global_position, brick.base_color(), 5, 0.35)

func _on_brick_destroyed(brick: Brick, points: int) -> void:
	combo += 1
	var gained := points * multiplier()
	score += gained
	bricks_left = maxi(bricks_left - 1, 0)

	var color := brick.base_color()
	spawn_burst(brick.global_position, color, 16, 0.7)
	spawn_popup("+%d" % gained, brick.global_position, color)
	Sfx.play("brick", randf_range(0.9, 1.15))
	shake_requested.emit(0.14)
	score_changed.emit(score, combo)

	if randf() < POWERUP_CHANCE:
		spawn_powerup(brick.global_position, PowerUp.random_kind())

	brick.queue_free()

	if bricks_left <= 0:
		_complete_level()

func _complete_level() -> void:
	state = State.CLEARED
	Sfx.play("level_up")
	shake_requested.emit(0.35)
	for ball: Ball in balls():
		ball.set_physics_process(false)
	level_cleared.emit(level)

	await get_tree().create_timer(1.5).timeout
	if state != State.CLEARED:
		return
	if level >= Boot.MAX_LEVELS:
		_finish(true)
	else:
		level += 1
		start_level()

func _finish(won: bool) -> void:
	state = State.FINISHED
	for ball: Ball in balls():
		ball.set_physics_process(false)
	if won:
		Sfx.play("level_up")
	game_finished.emit(score, level, won)

# --------------------------------------------------------------------------- #
# Power-ups
# --------------------------------------------------------------------------- #
## Drops a power-up at `at`. Public so tests and gameplay share one code path.
func spawn_powerup(at: Vector2, kind: int) -> void:
	var powerup: PowerUp = POWERUP_SCENE.instantiate()
	powerups_root.add_child(powerup)
	powerup.collected.connect(_on_powerup_collected)
	powerup.setup(kind, at)

func _on_powerup_collected(powerup: PowerUp) -> void:
	var color := PowerUp.kind_color(powerup.kind)
	Sfx.play("powerup")
	shake_requested.emit(0.18)
	spawn_popup(PowerUp.kind_title(powerup.kind), powerup.global_position - Vector2(0.0, 14.0), color)
	match powerup.kind:
		PowerUp.KIND_EXPAND:
			paddle.expand()
		PowerUp.KIND_MULTIBALL:
			spawn_extra_balls(2)
		PowerUp.KIND_SLOW:
			for ball: Ball in balls():
				ball.set_speed(ball.speed * 0.78)
		PowerUp.KIND_EXTRA_LIFE:
			lives += 1
			lives_changed.emit(lives)
	score_changed.emit(score, combo)

## Spawns `count` extra balls from an existing ball (MULTIBALL power-up).
func spawn_extra_balls(count: int) -> void:
	var current := balls()
	if current.is_empty():
		return
	var source := current[0]
	for _i in count:
		var ball := _make_ball()
		ball.stuck = false
		ball.global_position = source.global_position
		ball.set_speed(source.speed)
		var angle := deg_to_rad(randf_range(-125.0, -55.0))
		ball.velocity = Vector2(cos(angle), sin(angle)).normalized() * ball.speed
	if state == State.READY:
		state = State.PLAYING

# --------------------------------------------------------------------------- #
# Juice
# --------------------------------------------------------------------------- #
func spawn_burst(at: Vector2, color: Color, amount: int = 14, lifetime: float = 0.6) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.92
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 420.0)
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 320.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.damping_min = 20.0
	particles.damping_max = 80.0
	particles.color = color
	particles.z_index = 3
	particles.position = at
	effects_root.add_child(particles)
	get_tree().create_timer(lifetime + 0.6).timeout.connect(particles.queue_free)

func spawn_popup(text: String, at: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(220.0, 30.0)
	label.position = at + Vector2(-110.0, -34.0)
	label.z_index = 4
	effects_root.add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 48.0, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)

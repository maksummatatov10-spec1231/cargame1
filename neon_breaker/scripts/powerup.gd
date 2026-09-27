class_name PowerUp
extends Area2D
## Collectible that falls from a destroyed brick.
##
## Kinds are plain ints on purpose: it keeps every call site statically typed
## without any enum <-> int casting noise.

signal collected(powerup: PowerUp)

const KIND_EXPAND := 0
const KIND_MULTIBALL := 1
const KIND_SLOW := 2
const KIND_EXTRA_LIFE := 3
const KIND_COUNT := 4

const FALL_SPEED := 175.0
const RADIUS := 15.0

var kind: int = KIND_EXPAND
var _spin := 0.0
var _collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(new_kind: int, start_position: Vector2) -> void:
	kind = clampi(new_kind, 0, KIND_COUNT - 1)
	global_position = start_position
	queue_redraw()

static func random_kind() -> int:
	return randi() % KIND_COUNT

static func kind_color(powerup_kind: int) -> Color:
	match powerup_kind:
		KIND_EXPAND:
			return Color(0.35, 0.95, 0.75)
		KIND_MULTIBALL:
			return Color(0.45, 0.75, 1.0)
		KIND_SLOW:
			return Color(1.0, 0.85, 0.35)
		_:
			return Color(1.0, 0.4, 0.65)

static func kind_label(powerup_kind: int) -> String:
	match powerup_kind:
		KIND_EXPAND:
			return "W"
		KIND_MULTIBALL:
			return "3"
		KIND_SLOW:
			return "S"
		_:
			return "+"

static func kind_title(powerup_kind: int) -> String:
	match powerup_kind:
		KIND_EXPAND:
			return "Платформа шире!"
		KIND_MULTIBALL:
			return "Три мяча!"
		KIND_SLOW:
			return "Замедление"
		_:
			return "+1 жизнь"

func _physics_process(delta: float) -> void:
	position.y += FALL_SPEED * delta
	_spin += delta * 1.6
	queue_redraw()
	if global_position.y > Boot.ARENA.end.y + 60.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if _collected or not (body is Paddle):
		return
	_collected = true
	# Emitting right inside a physics callback makes the engine complain
	# ("Can't change this state while flushing queries"), so finish a frame later.
	_finish_collection.call_deferred()

func _finish_collection() -> void:
	collected.emit(self)
	queue_free()

func _draw() -> void:
	var color := kind_color(kind)
	var points := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 6:
		var angle := _spin + TAU * float(i) / 6.0
		points.append(Vector2(cos(angle), sin(angle)) * RADIUS)
		inner.append(Vector2(cos(angle), sin(angle)) * (RADIUS - 3.0))

	draw_circle(Vector2.ZERO, RADIUS * 1.85, Color(color.r, color.g, color.b, 0.10))
	draw_colored_polygon(points, Color(0.05, 0.07, 0.13))
	draw_colored_polygon(inner, color)

	var font := ThemeDB.fallback_font
	if font != null:
		var text := kind_label(kind)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(font, Vector2(-text_size.x * 0.5, text_size.y * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.05, 0.07, 0.13))

class_name Brick
extends StaticBody2D
## A single destructible block. Draws itself procedurally, so the game needs
## no imported textures at all.

signal destroyed(brick: Brick, points: int)
signal damaged(brick: Brick)

var hp: int = 1
var max_hp: int = 1
var points: int = 10
var hue: float = 0.55

var _flash: float = 0.0

func setup(cell: Vector2i, new_hp: int, new_hue: float, new_points: int) -> void:
	hp = maxi(new_hp, 1)
	max_hp = hp
	hue = new_hue
	points = new_points
	position = Boot.cell_center(cell.x, cell.y)
	queue_redraw()

func base_color() -> Color:
	var tint := Color.from_hsv(hue, 0.72, 1.0)
	# Heavily damaged bricks get visibly dimmer and colder.
	var wear := float(max_hp - hp) / float(max(1, max_hp))
	return tint.lerp(Color(0.28, 0.30, 0.42), wear * 0.65)

## Applies one hit. Returns `true` when the brick was destroyed.
func take_hit() -> bool:
	hp -= 1
	if hp <= 0:
		destroyed.emit(self, points)
		return true
	damaged.emit(self)
	_flash = 1.0
	var tween := create_tween()
	tween.tween_method(_set_flash, 1.0, 0.0, 0.25)
	queue_redraw()
	return false

func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()

func _draw() -> void:
	var size := Boot.BRICK_SIZE
	var rect := Rect2(-size * 0.5, size)
	var color := base_color().lerp(Color(1, 1, 1), _flash * 0.75)

	# Outer glow-ish frame.
	draw_rect(rect.grow(3.0), Color(color.r, color.g, color.b, 0.16))
	# Body.
	draw_rect(rect, color)
	# Neon top edge + dark bottom edge fake a bit of depth.
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), color.lightened(0.45))
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 4.0), Vector2(rect.size.x, 4.0)), color.darkened(0.45))
	# Core dot marks for multi-hit bricks.
	if max_hp > 1:
		for i in max_hp - 1:
			var x := -size.x * 0.25 + i * (size.x * 0.5 / float(maxi(max_hp - 1, 1)))
			draw_circle(Vector2(x, 0), 3.0, Color(1, 1, 1, 0.55))

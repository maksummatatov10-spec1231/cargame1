class_name LivesDisplay
extends Control
## Draws the remaining lives as little neon hearts.

const HEART_SIZE := 13.0
const SPACING := 34.0
const MAX_DRAWN := 8

var lives: int = 3:
	set(value):
		lives = maxi(value, 0)
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(SPACING * MAX_DRAWN, HEART_SIZE * 2.4)

func _draw() -> void:
	var shown := mini(lives, MAX_DRAWN)
	for i in shown:
		_draw_heart(Vector2(HEART_SIZE + i * SPACING, HEART_SIZE * 1.2), Color(1.0, 0.35, 0.62))
	if lives > MAX_DRAWN:
		var font := ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(HEART_SIZE + shown * SPACING, HEART_SIZE * 1.6), "+%d" % (lives - MAX_DRAWN), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.35, 0.62))

func _draw_heart(center: Vector2, color: Color) -> void:
	var r := HEART_SIZE * 0.55
	var points := PackedVector2Array([
		center + Vector2(-HEART_SIZE, -HEART_SIZE * 0.35),
		center + Vector2(0.0, HEART_SIZE * 1.05),
		center + Vector2(HEART_SIZE, -HEART_SIZE * 0.35),
	])
	draw_circle(center + Vector2(-r * 0.95, -r * 0.85), r, color)
	draw_circle(center + Vector2(r * 0.95, -r * 0.85), r, color)
	draw_colored_polygon(points, color)
	draw_circle(center + Vector2(-r * 1.1, -r * 1.0), r * 0.35, Color(1, 1, 1, 0.55))

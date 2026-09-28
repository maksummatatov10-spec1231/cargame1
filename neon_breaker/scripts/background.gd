extends Node2D
class_name NeonBackground
## Animated neon backdrop: parallax grid, arena frame and a sweeping scanline.

const GRID_STEP := 48.0
const SWEEP_PERIOD := 6.0

var _time := 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var view := get_viewport_rect().size

	# Vertical / horizontal grid with a slow wave.
	var columns := int(view.x / GRID_STEP) + 2
	for i in columns:
		var x := float(i) * GRID_STEP
		var wave := 0.5 + 0.5 * sin(_time * 0.9 + x * 0.012)
		draw_line(Vector2(x, 0.0), Vector2(x, view.y), Color(0.18, 0.45, 0.72, 0.05 + wave * 0.05), 1.0)
	var rows := int(view.y / GRID_STEP) + 2
	for j in rows:
		var y := float(j) * GRID_STEP
		var wave := 0.5 + 0.5 * sin(_time * 0.7 + y * 0.02)
		draw_line(Vector2(0.0, y), Vector2(view.x, y), Color(0.18, 0.45, 0.72, 0.05 + wave * 0.05), 1.0)

	# Sweeping scanline.
	var sweep_progress := fposmod(_time, SWEEP_PERIOD) / SWEEP_PERIOD
	var sweep_y := view.y * sweep_progress
	draw_rect(Rect2(0.0, sweep_y, view.x, 3.0), Color(0.5, 0.85, 1.0, 0.07))
	draw_rect(Rect2(0.0, sweep_y - 26.0, view.x, 26.0), Color(0.4, 0.8, 1.0, 0.02))

	# Arena frame.
	var arena := Boot.ARENA
	var frame := Color(0.35, 0.85, 1.0, 0.35 + 0.12 * sin(_time * 2.0))
	draw_rect(Rect2(arena.position, arena.size), frame, false, 3.0)
	draw_rect(Rect2(arena.position, arena.size).grow(4.0), Color(0.35, 0.85, 1.0, 0.08), false, 8.0)

	# Bottom "danger" line where the ball is lost.
	var danger_y := arena.end.y
	draw_line(Vector2(arena.position.x, danger_y), Vector2(arena.end.x, danger_y), Color(1.0, 0.35, 0.55, 0.45), 3.0)

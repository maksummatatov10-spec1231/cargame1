class_name LevelGen
## Deterministic level layout generator. Every level is a pure function of its
## index, so a given level always looks identical (good for speedrunning and
## for the headless tests).

## Returns an array of dictionaries: `{ cell: Vector2i, hp: int, hue: float, points: int }`.
static func build(level: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("neon-breaker/level/%d" % level)

	var rows := clampi(4 + int(level / 2.0), 4, Boot.GRID_ROWS_MAX)
	var base_hp := 1 + int(level / 4.0)
	var pattern := posmod(level - 1, 6)
	var bricks: Array[Dictionary] = []

	for row in rows:
		for col in Boot.GRID_COLS:
			if not _cell_is_used(pattern, col, row, rows, rng):
				continue
			var hp := base_hp
			if rng.randf() < 0.16:
				hp += 1
			if level >= 6 and rng.randf() < 0.10:
				hp += 1
			bricks.append({
				"cell": Vector2i(col, row),
				"hp": hp,
				"hue": fposmod(0.52 + row * 0.055 + level * 0.017, 1.0),
				"points": 10 * hp,
			})

	# Never hand the player an empty (or nearly empty) board.
	if bricks.size() < 12:
		for row in rows:
			for col in Boot.GRID_COLS:
				if bricks.size() >= 24:
					break
				bricks.append({
					"cell": Vector2i(col, row),
					"hp": base_hp,
					"hue": fposmod(0.52 + row * 0.055, 1.0),
					"points": 10 * base_hp,
				})
	return bricks

static func _cell_is_used(pattern: int, col: int, row: int, rows: int, rng: RandomNumberGenerator) -> bool:
	match pattern:
		0:  # checkerboard
			return (col + row) % 2 == 0
		1:  # pyramid
			return absi(col - (Boot.GRID_COLS - 1) / 2) <= 2 + row
		2:  # vertical stripes with gaps
			return col % 5 != 3
		3:  # diamond
			var cx := float(Boot.GRID_COLS - 1) * 0.5
			var cy := float(rows - 1) * 0.5
			return absf(col - cx) + absf(row - cy) * 1.5 <= maxf(cx, cy) + 1.0
		4:  # zig-zag waves
			return (col + (row % 2) * 3) % 6 != 5
		_:  # organic noise
			return rng.randf() > 0.28

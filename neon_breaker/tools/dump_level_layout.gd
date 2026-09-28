extends Node
## Dumps the brick layout of every generated level as JSON.
##
##     godot --headless --path . res://tools/dump_level_layout.tscn | grep '^{"arena'' > layout.json
##
## Useful for eyeballing the level generator without opening the editor.

func _ready() -> void:
	var levels := []
	for level in range(1, Boot.MAX_LEVELS + 1):
		var bricks := []
		for entry: Dictionary in LevelGen.build(level):
			var cell: Vector2i = entry["cell"]
			bricks.append({
				"col": cell.x,
				"row": cell.y,
				"hp": int(entry["hp"]),
				"hue": float(entry["hue"]),
				"pos": [Boot.cell_center(cell.x, cell.y).x, Boot.cell_center(cell.x, cell.y).y],
			})
		levels.append({"level": level, "bricks": bricks})

	var payload := {
		"arena": [Boot.ARENA.position.x, Boot.ARENA.position.y, Boot.ARENA.size.x, Boot.ARENA.size.y],
		"brick_size": [Boot.BRICK_SIZE.x, Boot.BRICK_SIZE.y],
		"paddle_y": Boot.PADDLE_Y,
		"levels": levels,
	}
	print(JSON.stringify(payload))
	get_tree().quit(0)

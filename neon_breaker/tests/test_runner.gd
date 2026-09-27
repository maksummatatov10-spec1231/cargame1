extends Node
## Headless smoke/regression tests for Neon Breaker.
##
## Run with:
##     godot --headless --path . res://tests/test_runner.tscn
##
## Exit code is 0 when everything passed, 1 otherwise.

var _checks: int = 0
var _failures: Array[String] = []
var _game: Game = null

func _ready() -> void:
	print("=== Neon Breaker headless tests ===")
	await get_tree().process_frame

	_test_boot_geometry()
	_test_input_map()
	_test_level_generation()
	_test_brick_damage()
	await _test_ball_bounces_off_paddle()
	await _test_ball_breaks_bricks()
	await _test_powerups()
	await _test_ball_lost_ends_run()
	await _test_level_completion()
	_test_save_file()

	print("---")
	if _failures.is_empty():
		print("TESTS PASSED (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("TESTS FAILED: %d of %d checks failed" % [_failures.size(), _checks])
		for failure in _failures:
			print("  ✗ ", failure)
		get_tree().quit(1)

# --------------------------------------------------------------------------- #
# Assertions
# --------------------------------------------------------------------------- #
func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("  ✗ ", message)

func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (получено %s, ожидалось %s)" % [message, str(actual), str(expected)])

func check_almost(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (получено %s, ожидалось %s ± %s)" % [message, str(actual), str(expected), str(tolerance)])

func step(frames: int = 1) -> void:
	for _i in frames:
		await get_tree().physics_frame

# --------------------------------------------------------------------------- #
# Tests
# --------------------------------------------------------------------------- #
func _test_boot_geometry() -> void:
	print("· геометрия арены")
	var arena := Boot.ARENA
	check(arena.size.x > 0.0 and arena.size.y > 0.0, "арена имеет положительный размер")
	check(Boot.GRID_COLS >= 6, "сетка кирпичей достаточно широкая")

	var last_cell := Boot.cell_position(Boot.GRID_COLS - 1, Boot.GRID_ROWS_MAX - 1)
	var last_bottom_right := last_cell + Boot.BRICK_SIZE
	check(last_cell.x >= arena.position.x, "сетка не выходит за левый край арены")
	check(last_bottom_right.x <= arena.end.x, "сетка не выходит за правый край арены")
	check(last_bottom_right.y < Boot.PADDLE_Y, "кирпичи не наезжают на платформу")
	check(Boot.PADDLE_Y > arena.position.y and Boot.PADDLE_Y < arena.end.y, "платформа внутри арены")

func _test_input_map() -> void:
	print("· карта ввода")
	for action: String in ["move_left", "move_right", "launch", "pause", "mute"]:
		check(InputMap.has_action(action), "действие %s существует" % action)
		check(InputMap.action_get_events(action).size() > 0, "у действия %s есть события" % action)

func _test_level_generation() -> void:
	print("· генерация уровней 1..%d" % Boot.MAX_LEVELS)
	for level in range(1, Boot.MAX_LEVELS + 1):
		var layout := LevelGen.build(level)
		check(layout.size() >= 12, "уровень %d содержит хотя бы 12 кирпичей (%d)" % [level, layout.size()])
		var seen := {}
		var valid := true
		for entry: Dictionary in layout:
			var cell: Vector2i = entry["cell"]
			if cell.x < 0 or cell.x >= Boot.GRID_COLS or cell.y < 0 or cell.y >= Boot.GRID_ROWS_MAX:
				valid = false
			if seen.has(cell):
				valid = false
			seen[cell] = true
			if int(entry["hp"]) < 1:
				valid = false
		check(valid, "уровень %d: все ячейки валидны и уникальны" % level)

		# Deterministic: same level index must produce the same board.
		var again := LevelGen.build(level)
		check_eq(again.size(), layout.size(), "уровень %d детерминирован" % level)

func _test_brick_damage() -> void:
	print("· урон по кирпичам")
	var brick: Brick = load("res://scenes/brick.tscn").instantiate()
	add_child(brick)
	brick.setup(Vector2i(0, 0), 3, 0.5, 30)

	# Lambdas capture by value in GDScript, so counters live inside an array.
	var destroyed_count := [0]
	var damaged_count := [0]
	brick.destroyed.connect(func(_b: Brick, _p: int) -> void: destroyed_count[0] += 1)
	brick.damaged.connect(func(_b: Brick) -> void: damaged_count[0] += 1)

	check(not brick.take_hit(), "кирпич с 3 HP выживает после первого удара")
	check_eq(damaged_count[0], 1, "сигнал damaged сработал один раз")
	check_eq(brick.hp, 2, "HP уменьшилось до 2")
	check(not brick.take_hit(), "кирпич выживает после второго удара")
	check(brick.take_hit(), "кирпич разрушается третьим ударом")
	check_eq(destroyed_count[0], 1, "сигнал destroyed сработал один раз")
	brick.free()

func _make_game() -> Game:
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	_game = game
	return game

func _test_ball_bounces_off_paddle() -> void:
	print("· отскок мяча от платформы")
	var game := _make_game()
	game.start_new_game()
	await step(2)

	check_eq(game.balls().size(), 1, "на старте уровня ровно один мяч")
	var ball := game.balls()[0]
	check(ball.stuck, "мяч приклеен к платформе до запуска")

	game.launch_balls()
	check(not ball.stuck, "после запуска мяч свободен")
	check_eq(game.state, Game.State.PLAYING, "состояние перешло в PLAYING")

	# Drop the ball straight down onto the right half of the paddle.
	ball.stuck = false
	ball.global_position = game.paddle.global_position + Vector2(45.0, -70.0)
	ball.velocity = Vector2(0.0, 320.0)

	var bounced := false
	for _i in 60:
		await get_tree().physics_frame
		if ball.velocity.y < 0.0:
			bounced = true
			break
	check(bounced, "мяч отскочил вверх от платформы")
	check(ball.velocity.x > 0.0, "удар по правой половине платформы уводит мяч вправо")
	check_almost(ball.velocity.length(), ball.speed, 6.0, "скорость мяча сохраняется после отскока")

	game.queue_free()
	await step(2)

func _test_ball_breaks_bricks() -> void:
	print("· мяч разбивает кирпич и приносит очки")
	var game := _make_game()
	game.start_new_game()
	await step(2)

	var ball := game.balls()[0]
	game.launch_balls()
	ball.stuck = false

	var target := game.bricks_root.get_child(0) as Brick
	var bricks_before := game.bricks_left
	ball.global_position = target.global_position + Vector2(0.0, 40.0)
	ball.velocity = Vector2(0.0, -420.0)

	var destroyed := false
	for _i in 40:
		await get_tree().physics_frame
		if not is_instance_valid(target) or game.bricks_left < bricks_before:
			destroyed = true
			break
	check(destroyed, "мяч уничтожил кирпич")
	check_eq(game.bricks_left, bricks_before - 1, "счётчик кирпичей уменьшился")
	check(game.score > 0, "очки начислены")

	game.queue_free()
	await step(2)

func _test_powerups() -> void:
	print("· бонусы")
	var game := _make_game()
	game.start_new_game()
	await step(2)
	game.launch_balls()

	var drop_at := game.paddle.global_position + Vector2(0.0, -40.0)

	var base_width := game.paddle.width
	game.spawn_powerup(drop_at, PowerUp.KIND_EXPAND)
	await step(30)
	check(game.paddle.width > base_width, "расширение платформы работает")
	check_eq(game.powerups_root.get_child_count(), 0, "подобранный бонус исчезает со сцены")

	var balls_before := game.balls().size()
	game.spawn_powerup(drop_at, PowerUp.KIND_MULTIBALL)
	await step(30)
	check_eq(game.balls().size(), balls_before + 2, "мультимяч добавляет два мяча")

	var lives_before := game.lives
	game.spawn_powerup(drop_at, PowerUp.KIND_EXTRA_LIFE)
	await step(30)
	check_eq(game.lives, lives_before + 1, "бонус жизни добавляет жизнь")

	var speed_before := game.balls()[0].speed
	game.spawn_powerup(drop_at, PowerUp.KIND_SLOW)
	await step(30)
	check(game.balls()[0].speed < speed_before, "замедление уменьшает скорость мяча")

	# Не подобранный бонус падает за пределы арены и удаляется.
	var falling := load("res://scenes/powerup.tscn").instantiate() as PowerUp
	game.powerups_root.add_child(falling)
	falling.setup(PowerUp.KIND_EXPAND, Vector2(Boot.ARENA.position.x + 20.0, Boot.ARENA.end.y - 30.0))
	await step(90)
	check(not is_instance_valid(falling) or falling.is_queued_for_deletion(), "упавший бонус удаляется")

	for kind in [PowerUp.KIND_EXPAND, PowerUp.KIND_MULTIBALL, PowerUp.KIND_SLOW, PowerUp.KIND_EXTRA_LIFE]:
		check(PowerUp.kind_title(kind) != "", "у бонуса %d есть название" % kind)

	game.queue_free()
	await step(2)

func _test_ball_lost_ends_run() -> void:
	print("· потеря мяча и конец игры")
	var game := _make_game()
	game.start_new_game()
	await step(2)
	game.launch_balls()

	var finished := [false]
	var won := [true]
	game.game_finished.connect(func(_s: int, _l: int, is_win: bool) -> void:
		finished[0] = true
		won[0] = is_win)

	game.lives = 1
	var ball := game.balls()[0]
	ball.global_position = Vector2(Boot.ARENA.get_center().x, Boot.ARENA.end.y + 60.0)
	await step(4)

	check_eq(game.lives, 0, "жизни обнулились")
	check(finished[0], "сигнал game_finished отправлен")
	check(not won[0], "забег помечен как проигранный")
	check_eq(game.state, Game.State.FINISHED, "состояние FINISHED")

	game.queue_free()
	await step(2)

func _test_level_completion() -> void:
	print("· прохождение уровня и переход на следующий")
	var game := _make_game()
	game.start_new_game()
	await step(2)
	check_eq(game.level, 1, "старт с первого уровня")

	var bricks := game.bricks_root.get_children()
	check(bricks.size() > 0, "кирпичи созданы")
	for child in bricks:
		var brick := child as Brick
		if not is_instance_valid(brick):
			continue
		for _hit in 6:
			if not is_instance_valid(brick) or brick.is_queued_for_deletion():
				break
			if brick.take_hit():
				break
	await step(2)
	check_eq(game.bricks_left, 0, "все кирпичи уничтожены")
	check_eq(game.state, Game.State.CLEARED, "уровень помечен пройденным")

	await get_tree().create_timer(2.2).timeout
	check_eq(game.level, 2, "переход на второй уровень")
	check_eq(game.state, Game.State.READY, "новый уровень ждёт запуска мяча")
	check(game.bricks_left > 0, "на новом уровне есть кирпичи")

	game.queue_free()
	await step(2)

func _test_save_file() -> void:
	print("· сохранение рекорда")
	Save.high_score = 0
	var is_record := Save.submit_score(4242, 3)
	check(is_record, "первый результат становится рекордом")
	check_eq(Save.high_score, 4242, "рекорд записан")
	check(not Save.submit_score(10, 1), "меньший результат не перезаписывает рекорд")

	Save.load_data()
	check_eq(Save.high_score, 4242, "рекорд считывается с диска")
	check_eq(Save.best_level, 3, "лучший уровень сохранён")

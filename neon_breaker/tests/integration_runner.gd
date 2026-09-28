extends Node
## Integration test: drives the real `main.tscn` through a full session
## (menu -> play -> pause -> resume -> game over -> menu) with synthetic input.
##
##     godot --headless --path . res://tests/integration_runner.tscn

var _checks: int = 0
var _failures: Array[String] = []

var _main: Node = null
var _menu: MainMenu = null
var _hud: Hud = null
var _overlay: GameOverlay = null
var _game: Game = null

func _ready() -> void:
	print("=== Neon Breaker integration test ===")
	Save.sound_enabled = false  # keep the log clean
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame

	_menu = _main.get_node("UI/Menu") as MainMenu
	_hud = _main.get_node("UI/HUD") as Hud
	_overlay = _main.get_node("UI/Overlay") as GameOverlay
	_game = _main.get_node("Game") as Game

	_test_initial_screen()
	await _test_start_run()
	await _test_paddle_moves()
	await _test_pause_cycle()
	await _test_life_lost()
	await _test_game_over()

	print("---")
	if _failures.is_empty():
		print("INTEGRATION PASSED (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		print("INTEGRATION FAILED: %d of %d checks failed" % [_failures.size(), _checks])
		for failure in _failures:
			print("  ✗ ", failure)
		get_tree().quit(1)

func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("  ✗ ", message)

func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (получено %s, ожидалось %s)" % [message, str(actual), str(expected)])

func frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame

func tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame

# --------------------------------------------------------------------------- #
func _test_initial_screen() -> void:
	print("· стартовый экран")
	check(_menu.visible, "меню показано на старте")
	check(not _hud.visible, "HUD скрыт на старте")
	check(not _game.visible, "игра скрыта на старте")
	check(not _overlay.pause_panel.visible, "пауза не показана")
	check_eq(_game.state, Game.State.IDLE, "игра не запущена")

func _test_start_run() -> void:
	print("· запуск игры из меню")
	_main._on_start_pressed()
	await frames(3)
	check(not _menu.visible, "меню скрылось")
	check(_hud.visible, "HUD показан")
	check(_game.visible, "игра показана")
	check_eq(_game.state, Game.State.READY, "уровень ждёт запуска мяча")
	check(_game.bricks_left > 0, "кирпичи расставлены")

func _test_paddle_moves() -> void:
	print("· управление платформой")
	var start_x := _game.paddle.global_position.x
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	await frames(2)
	check(_game.paddle.global_position.x > start_x, "платформа едет вправо")

	Input.action_press("move_left")
	await frames(30)
	Input.action_release("move_left")
	await frames(2)
	check(_game.paddle.global_position.x < Boot.ARENA.end.x, "платформа едет влево")

	# Launch the ball with the real input action.
	var ball := _game.balls()[0]
	await tap("launch")
	await frames(2)
	check(not ball.stuck, "пробел запускает мяч")
	check_eq(_game.state, Game.State.PLAYING, "состояние PLAYING после запуска")

func _test_pause_cycle() -> void:
	print("· пауза")
	await tap("pause")
	await frames(2)
	check(get_tree().paused, "дерево на паузе")
	check(_overlay.pause_panel.visible, "панель паузы показана")
	check_eq(_game.state, Game.State.PAUSED, "состояние PAUSED")

	var ball := _game.balls()[0]
	var paused_position := ball.global_position
	await frames(20)
	check(ball.global_position.is_equal_approx(paused_position), "на паузе мяч не двигается")

	await tap("pause")
	await frames(2)
	check(not get_tree().paused, "пауза снята")
	check(not _overlay.pause_panel.visible, "панель паузы скрыта")

func _test_life_lost() -> void:
	print("· потеря жизни")
	var lives_before := _game.lives
	for ball: Ball in _game.balls():
		ball.global_position = Vector2(Boot.ARENA.get_center().x, Boot.ARENA.end.y + 60.0)
	await frames(6)
	check_eq(_game.lives, lives_before - 1, "жизнь списана")
	check_eq(_game.state, Game.State.READY, "новый мяч ждёт запуска")
	check_eq(_game.balls().size(), 1, "в игре снова один мяч")

func _test_game_over() -> void:
	print("· конец игры и возврат в меню")
	_game.lives = 1
	await tap("launch")  # мяч должен быть запущен, иначе он «приклеен» к платформе
	await frames(2)
	for ball: Ball in _game.balls():
		ball.global_position = Vector2(Boot.ARENA.get_center().x, Boot.ARENA.end.y + 60.0)
	await frames(6)

	check_eq(_game.state, Game.State.FINISHED, "состояние FINISHED")
	check(_overlay.over_panel.visible, "экран конца игры показан")
	check(_overlay.over_result.text.contains("Очки"), "результат содержит очки")

	var over_score := _game.score
	check(Save.high_score >= over_score, "рекорд не ниже результата")

	_main._on_menu_requested()
	await frames(3)
	check(_menu.visible, "вернулись в меню")
	check(not _hud.visible, "HUD снова скрыт")
	check(not get_tree().paused, "игра не на паузе")

	# Start again: the run must reset cleanly.
	_main._on_start_pressed()
	await frames(3)
	check_eq(_game.score, 0, "новый забег начинается с нуля очков")
	check_eq(_game.lives, Boot.START_LIVES, "жизни восстановлены")
	check_eq(_game.level, 1, "уровень сброшен на первый")
	check(not _overlay.over_panel.visible, "экран конца игры скрыт")

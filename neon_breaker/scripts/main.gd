extends Node2D
## Root scene: owns the screen flow (menu <-> game) and wires the UI to the
## `Game` node.

@onready var game: Game = $Game
@onready var camera: ShakeCamera = $Camera2D
@onready var menu: MainMenu = $UI/Menu
@onready var hud: Hud = $UI/HUD
@onready var overlay: GameOverlay = $UI/Overlay

func _ready() -> void:
	game.shake_requested.connect(camera.add_trauma)
	game.level_changed.connect(_on_level_changed)
	game.game_finished.connect(_on_game_finished)
	hud.bind(game)

	menu.start_pressed.connect(_on_start_pressed)
	menu.quit_pressed.connect(_on_quit_pressed)
	overlay.pause_requested.connect(_on_pause_requested)
	overlay.resume_requested.connect(_on_resume_requested)
	overlay.restart_requested.connect(_on_restart_requested)
	overlay.menu_requested.connect(_on_menu_requested)
	overlay.mute_requested.connect(_on_mute_requested)

	_show_menu()

# --------------------------------------------------------------------------- #
# Flow
# --------------------------------------------------------------------------- #
func _show_menu() -> void:
	get_tree().paused = false
	game.stop()
	game.visible = false
	hud.visible = false
	menu.visible = true
	menu.refresh()
	overlay.hide_all()

func _start_run() -> void:
	get_tree().paused = false
	overlay.hide_all()
	overlay.fade_through()
	menu.visible = false
	game.visible = true
	hud.visible = true
	game.start_new_game()
	overlay.show_banner("УРОВЕНЬ 1")

func _on_start_pressed() -> void:
	_start_run()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_pause_requested() -> void:
	if game.state != Game.State.READY and game.state != Game.State.PLAYING:
		return
	game.state = Game.State.PAUSED
	get_tree().paused = true
	overlay.show_pause()

func _on_resume_requested() -> void:
	if game.state != Game.State.PAUSED:
		return
	get_tree().paused = false
	overlay.hide_all()

func _on_restart_requested() -> void:
	get_tree().paused = false
	_start_run()

func _on_menu_requested() -> void:
	_show_menu()

func _on_mute_requested() -> void:
	Sfx.toggle_mute()
	menu.refresh()

# --------------------------------------------------------------------------- #
# Game events
# --------------------------------------------------------------------------- #
func _on_level_changed(level: int) -> void:
	if level > 1:
		overlay.show_banner("УРОВЕНЬ %d" % level)

func _on_game_finished(score: int, level: int, won: bool) -> void:
	get_tree().paused = false
	var is_record := Save.submit_score(score, level)
	overlay.show_game_over(score, level, won, is_record)

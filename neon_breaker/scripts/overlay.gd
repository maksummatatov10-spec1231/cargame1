extends Control
class_name GameOverlay
## Pause menu, game over screen, level banner and screen fade.
##
## Runs with `process_mode = ALWAYS` so it keeps reacting to input while the
## tree is paused.

signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal mute_requested

@onready var fade: ColorRect = $Fade
@onready var banner: Label = $Banner
@onready var pause_panel: CenterContainer = $PausePanel
@onready var over_panel: CenterContainer = $GameOverPanel
@onready var over_title: Label = $GameOverPanel/Panel/Box/Title
@onready var over_result: Label = $GameOverPanel/Panel/Box/Result

func _ready() -> void:
	($PausePanel/Panel/Box/ResumeButton as Button).pressed.connect(_on_resume_pressed)
	($PausePanel/Panel/Box/RestartButton as Button).pressed.connect(_on_restart_pressed)
	($PausePanel/Panel/Box/MenuButton as Button).pressed.connect(_on_menu_pressed)
	($GameOverPanel/Panel/Box/PlayAgainButton as Button).pressed.connect(_on_restart_pressed)
	($GameOverPanel/Panel/Box/MenuButton as Button).pressed.connect(_on_menu_pressed)
	hide_all()
	fade.color = Color(0.02, 0.02, 0.05, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		if pause_panel.visible:
			resume_requested.emit()
		elif not over_panel.visible:
			pause_requested.emit()
	if Input.is_action_just_pressed("mute"):
		mute_requested.emit()

# --------------------------------------------------------------------------- #
# Screens
# --------------------------------------------------------------------------- #
func hide_all() -> void:
	pause_panel.visible = false
	over_panel.visible = false
	banner.modulate.a = 0.0

func show_pause() -> void:
	pause_panel.visible = true
	($PausePanel/Panel/Box/ResumeButton as Button).grab_focus()

func show_game_over(score: int, level: int, won: bool, is_record: bool) -> void:
	over_panel.visible = true
	pause_panel.visible = false
	over_title.text = "ПОБЕДА!" if won else "ИГРА ОКОНЧЕНА"
	over_title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.75) if won else Color(1.0, 0.4, 0.6))
	var lines := "Очки: %d\nУровень: %d из %d" % [score, level, Boot.MAX_LEVELS]
	if is_record:
		lines += "\n\nНОВЫЙ РЕКОРД!"
	over_result.text = lines
	($GameOverPanel/Panel/Box/PlayAgainButton as Button).grab_focus()

func show_banner(text: String) -> void:
	banner.text = text
	var tween := create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.25)
	tween.tween_interval(1.1)
	tween.tween_property(banner, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func() -> void: banner.modulate.a = 0.0)

## Quick black flash used when switching between menu and game.
func fade_through() -> void:
	fade.color = Color(0.02, 0.02, 0.05, 0.85)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.45)

# --------------------------------------------------------------------------- #
# Buttons
# --------------------------------------------------------------------------- #
func _on_resume_pressed() -> void:
	Sfx.play("click")
	resume_requested.emit()

func _on_restart_pressed() -> void:
	Sfx.play("click")
	restart_requested.emit()

func _on_menu_pressed() -> void:
	Sfx.play("click")
	menu_requested.emit()

extends Control
class_name MainMenu
## Title screen.

signal start_pressed
signal quit_pressed

@onready var title: Label = $Center/Box/Title
@onready var high_score_label: Label = $Center/Box/HighScore
@onready var start_button: Button = $Center/Box/StartButton
@onready var mute_button: Button = $Center/Box/MuteButton
@onready var quit_button: Button = $Center/Box/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	mute_button.pressed.connect(_on_mute_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# Quitting is not possible in the web export.
	quit_button.visible = not OS.has_feature("web")
	refresh()

	# Slow neon pulse on the title.
	var tween := create_tween().set_loops()
	tween.tween_property(title, "modulate", Color(0.65, 0.95, 1.0), 1.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(title, "modulate", Color(1.0, 0.45, 0.9), 1.4).set_trans(Tween.TRANS_SINE)
	start_button.grab_focus()

func refresh() -> void:
	high_score_label.text = "РЕКОРД: %d  ·  УРОВЕНЬ %d" % [Save.high_score, Save.best_level]
	mute_button.text = "ЗВУК: %s" % ("ВКЛ" if Save.sound_enabled else "ВЫКЛ")

func _on_start_pressed() -> void:
	Sfx.play("click")
	start_pressed.emit()

func _on_mute_pressed() -> void:
	Sfx.toggle_mute()
	Sfx.play("click")
	refresh()

func _on_quit_pressed() -> void:
	Sfx.play("click")
	quit_pressed.emit()

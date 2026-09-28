extends Control
class_name Hud
## In-game HUD: score, level, lives, combo multiplier and the launch hint.

const HINT_READY := "ПРОБЕЛ / ЛКМ — ЗАПУСТИТЬ МЯЧ"

@onready var score_label: Label = $Score
@onready var level_label: Label = $Level
@onready var combo_label: Label = $Combo
@onready var lives_display: LivesDisplay = $Lives
@onready var hint_label: Label = $Hint

var _game: Game = null

func bind(game: Game) -> void:
	_game = game
	game.score_changed.connect(_on_score_changed)
	game.lives_changed.connect(_on_lives_changed)
	game.level_changed.connect(_on_level_changed)
	game.level_cleared.connect(_on_level_cleared)
	_on_score_changed(game.score, game.combo)
	_on_lives_changed(game.lives)
	_on_level_changed(game.level)
	hint_label.visible = false

func _process(_delta: float) -> void:
	if _game == null or not is_instance_valid(_game):
		return
	var ready := _game.state == Game.State.READY
	hint_label.visible = ready
	if ready:
		hint_label.text = HINT_READY

func _on_score_changed(score: int, combo: int) -> void:
	score_label.text = "ОЧКИ  %d" % score
	var multiplier := clampi(1 + combo / Game.COMBO_PER_STEP, 1, Game.MAX_MULTIPLIER)
	combo_label.visible = multiplier > 1
	combo_label.text = "КОМБО x%d" % multiplier

func _on_lives_changed(lives: int) -> void:
	lives_display.lives = lives

func _on_level_changed(level: int) -> void:
	level_label.text = "УРОВЕНЬ %d / %d" % [level, Boot.MAX_LEVELS]

func _on_level_cleared(level: int) -> void:
	hint_label.visible = true
	hint_label.text = "УРОВЕНЬ %d ПРОЙДЕН!" % level

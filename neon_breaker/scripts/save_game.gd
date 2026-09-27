extends Node
## Autoload `Save`: tiny persistent store for the high score and options.

const PATH := "user://neon_breaker.cfg"

var high_score: int = 0
var best_level: int = 1
var sound_enabled: bool = true

func _ready() -> void:
	load_data()

func load_data() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	high_score = int(config.get_value("progress", "high_score", 0))
	best_level = int(config.get_value("progress", "best_level", 1))
	sound_enabled = bool(config.get_value("options", "sound_enabled", true))

func save_data() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "high_score", high_score)
	config.set_value("progress", "best_level", best_level)
	config.set_value("options", "sound_enabled", sound_enabled)
	config.save(PATH)

## Stores a finished run, returns true when it is a new record.
func submit_score(score: int, level: int) -> bool:
	var is_record := score > high_score
	high_score = maxi(high_score, score)
	best_level = maxi(best_level, level)
	save_data()
	return is_record

extends Node
## Autoload `Boot`: shared constants for the whole game plus a safety net that
## guarantees the input actions exist even if `project.godot` is missing them.

# --- Playfield geometry (designed around a 1152x648 viewport) ------------- #
const ARENA := Rect2(64.0, 96.0, 1024.0, 520.0)
const BRICK_SIZE := Vector2(64.0, 28.0)
const BRICK_GAP := 8.0
const GRID_COLS := 14
const GRID_ROWS_MAX := 8
const BRICK_BOX := Vector2(62.0, 26.0)

const BALL_RADIUS := 9.0
const BALL_START_SPEED := 420.0
const BALL_MAX_SPEED := 900.0
const BALL_SPEED_PER_LEVEL := 14.0

const PADDLE_SIZE := Vector2(140.0, 18.0)
# 36 px above the bottom of the arena (ARENA.end.y - 36).
const PADDLE_Y := 580.0
const PADDLE_SPEED := 900.0
const PADDLE_ACCEL := 5200.0

const MAX_LEVELS := 12
const START_LIVES := 3

const ACTION_KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"launch": [KEY_SPACE, KEY_ENTER],
	"pause": [KEY_ESCAPE, KEY_P],
	"mute": [KEY_M],
}

const ACTION_JOYPAD_BUTTONS := {
	"launch": [JOY_BUTTON_A],
	"pause": [JOY_BUTTON_START],
}

func _enter_tree() -> void:
	_ensure_actions()

## Returns the top-left corner of cell `(col, row)` of the brick grid.
static func cell_position(col: int, row: int) -> Vector2:
	var total_width := GRID_COLS * BRICK_SIZE.x + (GRID_COLS - 1) * BRICK_GAP
	var origin := Vector2(ARENA.position.x + (ARENA.size.x - total_width) * 0.5, ARENA.position.y + 24.0)
	return origin + Vector2(col * (BRICK_SIZE.x + BRICK_GAP), row * (BRICK_SIZE.y + BRICK_GAP))

static func cell_center(col: int, row: int) -> Vector2:
	return cell_position(col, row) + BRICK_SIZE * 0.5

func _ensure_actions() -> void:
	for action: String in ACTION_KEYS:
		_ensure_action(action)
		for keycode: int in ACTION_KEYS[action]:
			if not _has_key(action, keycode):
				_add_key(action, keycode)
	for action: String in ACTION_JOYPAD_BUTTONS:
		for button: int in ACTION_JOYPAD_BUTTONS[action]:
			if not _has_joy_button(action, button):
				_add_joy_button(action, button)
	_ensure_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_axis("move_right", JOY_AXIS_LEFT_X, 1.0)

func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)

func _has_key(action: String, keycode: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false

func _has_joy_button(action: String, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false

func _add_key(action: String, keycode: int) -> void:
	_ensure_action(action)
	var event := InputEventKey.new()
	event.set("physical_keycode", keycode)
	InputMap.action_add_event(action, event)

func _add_joy_button(action: String, button: int) -> void:
	_ensure_action(action)
	var event := InputEventJoypadButton.new()
	event.set("button_index", button)
	InputMap.action_add_event(action, event)

func _ensure_axis(action: String, axis: int, value: float) -> void:
	_ensure_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(motion.axis_value, value):
				return
	var motion := InputEventJoypadMotion.new()
	motion.set("axis", axis)
	motion.axis_value = value
	InputMap.action_add_event(action, motion)

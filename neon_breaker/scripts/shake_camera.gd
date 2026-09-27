extends Camera2D
class_name ShakeCamera
## Trauma based screen shake (Squirrel Eiserloh style): small hits do not
## shake at all, big hits shake a lot.

const DECAY := 2.2
const MAX_OFFSET := 22.0
const MAX_ROLL := 0.05

var _trauma := 0.0
var _noise_time := 0.0
var _noise := FastNoiseLite.new()

func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.8
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	_noise_time += delta * 60.0
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = 0.0
		return
	_trauma = maxf(_trauma - DECAY * delta, 0.0)
	var shake := _trauma * _trauma
	offset = Vector2(
		_noise.get_noise_2d(_noise_time, 0.0) * MAX_OFFSET * shake,
		_noise.get_noise_2d(0.0, _noise_time) * MAX_OFFSET * shake
	)
	rotation = _noise.get_noise_2d(_noise_time, 100.0) * MAX_ROLL * shake

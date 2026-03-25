extends Node3D

# ── Camera that follows the centroid of all alive fighters ────────────────────

@onready var camera : Camera3D = $Camera3D

var targets     : Array  = []
var trauma      : float  = 0.0   # screen shake intensity 0..1

const BASE_OFFSET    := Vector3(0.0, 16.0, 14.0)
const MIN_DIST       := 6.0
const MAX_DIST       := 14.0
const LERP_SPEED     := 3.5
const TRAUMA_DECAY   := 2.2
const MAX_SHAKE_X    := 0.35
const MAX_SHAKE_Y    := 0.2

var _shake_noise : FastNoiseLite
var _noise_t     : float = 0.0

func _ready() -> void:
	_shake_noise = FastNoiseLite.new()
	_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_shake_noise.frequency  = 0.8

	# Position camera initially
	if camera:
		camera.look_at_from_position(BASE_OFFSET, Vector3.ZERO, Vector3.UP)

func set_targets(t: Array) -> void:
	targets = t

func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func _process(delta: float) -> void:
	_update_follow(delta)
	_update_shake(delta)

func _update_follow(delta: float) -> void:
	var alive := targets.filter(func(f) -> bool: return f.alive)
	if alive.is_empty():
		return

	# Compute centroid
	var centroid := Vector3.ZERO
	for f in alive:
		centroid += f.global_position
	centroid /= float(alive.size())
	centroid.y = 0.0

	# Compute spread to adjust zoom
	var max_spread := 0.0
	for f in alive:
		max_spread = maxf(max_spread, centroid.distance_to(f.global_position))

	var zoom_t    := clampf(max_spread / 8.0, 0.0, 1.0)
	var distance  := lerpf(MIN_DIST, MAX_DIST, zoom_t)
	var target_pos := centroid + BASE_OFFSET.normalized() * distance

	global_position = global_position.lerp(target_pos, delta * LERP_SPEED)

	if camera:
		camera.look_at(centroid, Vector3.UP)

func _update_shake(delta: float) -> void:
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * delta)
	if not camera:
		return

	_noise_t += delta * 60.0
	var shake := trauma * trauma
	var ox := _shake_noise.get_noise_2d(_noise_t, 0.0)      * MAX_SHAKE_X * shake
	var oy := _shake_noise.get_noise_2d(0.0, _noise_t)      * MAX_SHAKE_Y * shake
	camera.h_offset = ox
	camera.v_offset = oy

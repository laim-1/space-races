extends CharacterBody3D
class_name Fighter

# ── Signals ───────────────────────────────────────────────────────────────────
signal fighter_died(fighter: Fighter)
signal fighter_attacked(attacker: Fighter, target: Fighter, damage: float, move_name: String)
signal took_damage(fighter: Fighter, amount: float, attacker)

# ── Exported config (set by Main.gd before _ready) ────────────────────────────
@export var fighter_name   : String  = "Fighter"
@export var fighter_color  : Color   = Color.WHITE
@export var max_hp         : float   = 200.0
@export var move_speed     : float   = 4.5
@export var attack_range   : float   = 1.9
@export var attack_damage  : float   = 25.0
@export var attack_cooldown: float   = 2.2
@export var archetype      : String  = "bruiser"

# ── Runtime state ─────────────────────────────────────────────────────────────
var hp              : float  = 200.0
var alive           : bool   = true
var attack_timer    : float  = 0.0   # counts down to 0 before next attack
var freeze_timer    : float  = 0.0   # movement freeze during attack windup
var wander_timer    : float  = 0.0
var wander_target   : Vector3 = Vector3.ZERO
var all_fighters    : Array  = []
var arena_center    : Vector3 = Vector3.ZERO
var arena_radius    : float  = 7.5

# ── Move name shown in HUD ────────────────────────────────────────────────────
const MOVE_NAMES := {
	"bruiser": ["Smash",    "Ground Slam"],
	"beast":   ["Bite",     "Feral Lunge"],
	"sniper":  ["Spike",    "Nova Burst"],
	"tank":    ["Stomp",    "Gravity Slam"],
}

# ── Node refs (set in _ready) ──────────────────────────────────────────────────
var _body_mesh  : MeshInstance3D
var _glow_ring  : MeshInstance3D
var _name_label : Label3D

# ── State machine ─────────────────────────────────────────────────────────────
enum State { IDLE, WANDERING, CHASING, ATTACKING, HIT_STUN, DEAD }
var state: State = State.IDLE

# ── Init ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	hp            = max_hp
	attack_timer  = randf_range(0.3, attack_cooldown)
	wander_timer  = randf_range(0.5, 2.0)
	motion_mode   = CharacterBody3D.MOTION_MODE_FLOATING

	_body_mesh  = $MeshInstance3D
	_glow_ring  = $GlowRing
	_name_label = $NameLabel

	_apply_materials()

	if _name_label:
		_name_label.text = fighter_name

func _apply_materials() -> void:
	# Body material
	if _body_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color  = fighter_color.darkened(0.25)
		mat.roughness     = 0.82
		mat.metallic      = 0.15
		mat.emission_enabled = true
		mat.emission      = fighter_color
		mat.emission_energy_multiplier = 0.4
		_body_mesh.material_override = mat

	# Glow ring
	if _glow_ring:
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = fighter_color
		rmat.emission_enabled = true
		rmat.emission = fighter_color
		rmat.emission_energy_multiplier = 3.0
		rmat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.albedo_color.a = 0.0  # invisible mesh, only emission
		_glow_ring.material_override = rmat

# ── Physics process ───────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not alive:
		return

	attack_timer = maxf(0.0, attack_timer - delta)

	# Attack freeze: fighter stands still during windup
	if freeze_timer > 0.0:
		freeze_timer -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		return

	match state:
		State.IDLE, State.WANDERING, State.CHASING:
			_run_ai(delta)
		State.HIT_STUN:
			velocity = velocity.lerp(Vector3.ZERO, delta * 10.0)
			move_and_slide()

func _run_ai(_delta: float) -> void:
	var target := _nearest_enemy()
	if target == null:
		_do_wander()
		return

	var dist := global_position.distance_to(target.global_position)

	if dist <= attack_range and attack_timer <= 0.0:
		_do_attack(target)
	else:
		# Chase
		var dir := (target.global_position - global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
			velocity = dir * move_speed
			_face_direction(dir)
		state = State.CHASING
		_clamp_to_arena()
		move_and_slide()

func _do_wander() -> void:
	if wander_timer <= 0.0 or wander_target == Vector3.ZERO:
		var angle  := randf() * TAU
		var radius := randf_range(1.5, arena_radius * 0.72)
		wander_target = arena_center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		wander_timer  = randf_range(1.8, 3.8)

	var diff := wander_target - global_position
	diff.y = 0.0
	if diff.length_squared() < 0.4:
		velocity = Vector3.ZERO
		state = State.IDLE
		wander_timer = 0.0
	else:
		var dir := diff.normalized()
		velocity = dir * move_speed * 0.55
		_face_direction(dir)
		state = State.WANDERING
	_clamp_to_arena()
	move_and_slide()

func _do_attack(target: Fighter) -> void:
	state        = State.ATTACKING
	attack_timer = attack_cooldown * randf_range(0.9, 1.1)
	freeze_timer = 0.32

	# Face target
	var dir := (target.global_position - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		_face_direction(dir.normalized())

	var move_idx  := randi() % 2
	var names     := MOVE_NAMES.get(archetype, ["Strike", "Heavy Strike"])
	var mname     := names[move_idx]
	var dmg       := attack_damage * randf_range(0.85, 1.2) * (1.4 if move_idx == 1 else 1.0)
	var cdbonus   := 0.8 if move_idx == 1 else 0.0

	attack_timer += cdbonus

	# Deal damage after brief delay (reaction time feel)
	get_tree().create_timer(0.18).timeout.connect(func() -> void:
		if is_instance_valid(target) and target.alive:
			target.take_damage(dmg, self)
	)

	emit_signal("fighter_attacked", self, target, dmg, mname)

	# Return to idle after freeze
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if alive: state = State.IDLE
	)

# ── Take damage ───────────────────────────────────────────────────────────────
func take_damage(amount: float, attacker) -> void:
	if not alive:
		return

	hp = maxf(0.0, hp - amount)
	_flash_hit()
	emit_signal("took_damage", self, amount, attacker)

	# Brief stagger
	state = State.HIT_STUN
	get_tree().create_timer(0.14).timeout.connect(func() -> void:
		if alive: state = State.IDLE
	)

	if hp <= 0.0:
		_die(attacker)

func _die(killer) -> void:
	alive = false
	state = State.DEAD
	emit_signal("fighter_died", self)

	# Collapse animation
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector3(1.2, 0.05, 1.2), 0.35)
	tween.tween_callback(func() -> void: visible = false)

# ── Visual helpers ────────────────────────────────────────────────────────────
func _flash_hit() -> void:
	if not _body_mesh or not _body_mesh.material_override:
		return
	var mat : StandardMaterial3D = _body_mesh.material_override
	var orig := mat.albedo_color
	mat.albedo_color = Color.WHITE
	mat.emission_energy_multiplier = 6.0
	get_tree().create_timer(0.14).timeout.connect(func() -> void:
		if is_instance_valid(mat):
			mat.albedo_color = orig
			mat.emission_energy_multiplier = 0.4
	)

func _face_direction(dir: Vector3) -> void:
	if dir.length_squared() < 0.001:
		return
	var target_pos := global_position + dir
	target_pos.y = global_position.y
	look_at(target_pos, Vector3.UP)

func _clamp_to_arena() -> void:
	var flat := Vector2(global_position.x - arena_center.x, global_position.z - arena_center.z)
	var limit := arena_radius - 0.6
	if flat.length_squared() > limit * limit:
		flat = flat.normalized() * limit
		global_position.x = arena_center.x + flat.x
		global_position.z = arena_center.z + flat.y
		# Reflect velocity away from wall
		var wall_normal := Vector3(flat.x, 0.0, flat.y).normalized() * -1.0
		var dot := velocity.dot(wall_normal)
		if dot < 0.0:
			velocity -= wall_normal * dot * 1.5

# ── Accessors ─────────────────────────────────────────────────────────────────
func get_hp_pct() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0

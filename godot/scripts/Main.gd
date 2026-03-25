extends Node3D

# ── Fighter roster (4 starters) ───────────────────────────────────────────────
const FIGHTER_DATA := [
	{
		"name":     "Krath",
		"color":    Color(0.56, 0.38, 0.19),   # rust-brown
		"hp":       350.0,
		"speed":    3.4,
		"damage":   32.0,
		"cd":       2.6,
		"range":    1.9,
		"archetype":"bruiser"
	},
	{
		"name":     "Vex",
		"color":    Color(0.27, 0.49, 0.20),   # swamp green
		"hp":       200.0,
		"speed":    5.8,
		"damage":   23.0,
		"cd":       1.9,
		"range":    1.8,
		"archetype":"beast"
	},
	{
		"name":     "Zyn",
		"color":    Color(0.78, 0.56, 0.08),   # electric amber
		"hp":       175.0,
		"speed":    6.2,
		"damage":   38.0,
		"cd":       2.8,
		"range":    2.1,
		"archetype":"sniper"
	},
	{
		"name":     "Orvak",
		"color":    Color(0.36, 0.44, 0.58),   # steel blue
		"hp":       300.0,
		"speed":    2.9,
		"damage":   27.0,
		"cd":       2.4,
		"range":    2.0,
		"archetype":"tank"
	},
]

const SPAWN_OFFSETS := [
	Vector3(0.0,  0.0, -6.2),
	Vector3(6.2,  0.0,  0.0),
	Vector3(0.0,  0.0,  6.2),
	Vector3(-6.2, 0.0,  0.0),
]

# ── State ─────────────────────────────────────────────────────────────────────
enum GameState { MENU, INTRO, BATTLE, RESULTS }
var game_state := GameState.MENU

var fighters       : Array[Fighter] = []
var alive_fighters : Array[Fighter] = []
var winner         : Fighter       = null

# ── Scene refs ────────────────────────────────────────────────────────────────
@onready var fighter_container : Node3D    = $Fighters
@onready var hud               : Node      = $HUD
@onready var camera_rig        : Node3D    = $CameraRig
@onready var arena             : Node3D    = $Arena

var fighter_scene : PackedScene = preload("res://scenes/Fighter.tscn")

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	game_state = GameState.MENU
	if hud and hud.has_signal("start_pressed"):
		hud.start_pressed.connect(_on_start_pressed)
	if hud and hud.has_method("show_menu"):
		hud.show_menu()

func _on_start_pressed() -> void:
	_spawn_fighters()
	_start_battle()

# ── Spawn ─────────────────────────────────────────────────────────────────────
func _spawn_fighters() -> void:
	for i in FIGHTER_DATA.size():
		var data : Dictionary = FIGHTER_DATA[i]
		var f    : Fighter    = fighter_scene.instantiate()

		f.fighter_name    = data["name"]
		f.fighter_color   = data["color"]
		f.max_hp          = data["hp"]
		f.move_speed      = data["speed"]
		f.attack_damage   = data["damage"]
		f.attack_cooldown = data["cd"]
		f.attack_range    = data["range"]
		f.archetype       = data["archetype"]
		f.position        = SPAWN_OFFSETS[i]

		fighter_container.add_child(f)
		fighters.append(f)

	alive_fighters = fighters.duplicate()

	# Give each fighter the full list so they can target each other
	for f in fighters:
		f.all_fighters = fighters

	# Connect signals
	for f in fighters:
		f.fighter_died.connect(_on_fighter_died)
		f.fighter_attacked.connect(_on_fighter_attacked)
		f.took_damage.connect(_on_took_damage)

	# Pass fighter list to HUD and camera
	if hud and hud.has_method("init_fighters"):
		hud.init_fighters(fighters)
	if camera_rig and camera_rig.has_method("set_targets"):
		camera_rig.set_targets(fighters)

# ── Battle flow ───────────────────────────────────────────────────────────────
func _start_battle() -> void:
	game_state = GameState.INTRO

	# Brief intro freeze
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		game_state = GameState.BATTLE
	)

func _on_fighter_died(f: Fighter) -> void:
	alive_fighters.erase(f)

	if hud and hud.has_method("on_kill"):
		hud.on_kill(f)

	# Check win condition
	if alive_fighters.size() <= 1:
		winner = alive_fighters[0] if alive_fighters.size() == 1 else null
		get_tree().create_timer(1.2).timeout.connect(_show_results)

func _show_results() -> void:
	game_state = GameState.RESULTS
	if hud and hud.has_method("show_results"):
		hud.show_results(winner, fighters)

func _on_fighter_attacked(attacker: Fighter, _target: Fighter, _dmg: float, move_name: String) -> void:
	if hud and hud.has_method("announce_attack"):
		hud.announce_attack(attacker, move_name)

func _on_took_damage(f: Fighter, amount: float, attacker) -> void:
	if hud and hud.has_method("on_hit"):
		hud.on_hit(f, amount, attacker)
	if camera_rig and camera_rig.has_method("add_trauma"):
		var intensity := 0.3 if amount >= 40 else 0.15 if amount >= 18 else 0.0
		if intensity > 0.0:
			camera_rig.add_trauma(intensity)

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if game_state == GameState.RESULTS and event is InputEventKey and event.pressed and not event.echo:
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("speed_1"):
		Engine.time_scale = 1.0
	elif event.is_action_pressed("speed_2"):
		Engine.time_scale = 2.0
	elif event.is_action_pressed("speed_3"):
		Engine.time_scale = 3.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Engine.time_scale = 1.0

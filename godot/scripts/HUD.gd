extends CanvasLayer

# ── HUD: health bars, kill feed, combo, speed controls, attack announce ───────

signal start_pressed

var fighters       : Array  = []
var combo_count    : int    = 0
var combo_attacker          = null
var combo_timer    : float  = 0.0
const COMBO_WINDOW := 2.5

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var fighter_bars_container : HBoxContainer = $Control/FighterBars
@onready var kill_feed_container    : VBoxContainer = $Control/KillFeed
@onready var combo_number           : Label         = $Control/ComboDisplay/Number
@onready var combo_label            : Label         = $Control/ComboDisplay/Label
@onready var combo_display          : Control       = $Control/ComboDisplay
@onready var speed_label            : Label         = $Control/SpeedLabel
@onready var alive_label            : Label         = $Control/AliveLabel
@onready var announce_label         : Label         = $Control/AttackAnnounce
@onready var results_panel          : Panel         = $Control/ResultsPanel
@onready var results_label          : Label         = $Control/ResultsPanel/Label

var _bar_nodes   : Dictionary = {}   # fighter → {bar, label}
var _start_menu  : Control    = null

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_create_start_menu()

func _create_start_menu() -> void:
	var panel := Panel.new()
	panel.name              = "StartMenu"
	panel.anchor_left       = 0.5
	panel.anchor_top        = 0.5
	panel.anchor_right      = 0.5
	panel.anchor_bottom     = 0.5
	panel.offset_left       = -240.0
	panel.offset_top        = -170.0
	panel.offset_right      = 240.0
	panel.offset_bottom     = 170.0
	panel.grow_horizontal   = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical     = Control.GROW_DIRECTION_BOTH

	var vbox := VBoxContainer.new()
	vbox.anchor_left    = 0.0
	vbox.anchor_top     = 0.0
	vbox.anchor_right   = 1.0
	vbox.anchor_bottom  = 1.0
	vbox.offset_left    = 20.0
	vbox.offset_top     = 20.0
	vbox.offset_right   = -20.0
	vbox.offset_bottom  = -20.0
	vbox.alignment      = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)

	var title := Label.new()
	title.text                    = "SPACE RACES"
	title.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.85, 0.55, 1.0))

	var subtitle := Label.new()
	subtitle.text                  = "4 fighters enter.  1 survives."
	subtitle.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)

	var btn := Button.new()
	btn.text = "▶   START BATTLE"
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(220, 52)
	btn.pressed.connect(_on_start_pressed)

	vbox.add_child(title)
	vbox.add_child(subtitle)
	vbox.add_child(spacer)
	vbox.add_child(btn)
	panel.add_child(vbox)
	$Control.add_child(panel)
	_start_menu = panel

func show_menu() -> void:
	if _start_menu:
		_start_menu.visible = true
	if alive_label:
		alive_label.visible = false

func _on_start_pressed() -> void:
	if _start_menu:
		_start_menu.visible = false
	start_pressed.emit()

# ── Init ──────────────────────────────────────────────────────────────────────
func init_fighters(f_list: Array) -> void:
	fighters = f_list
	_build_health_bars()
	if _start_menu:
		_start_menu.visible = false
	if results_panel:
		results_panel.visible = false
	if combo_display:
		combo_display.modulate.a = 0.0
	if alive_label:
		alive_label.visible = true

func _build_health_bars() -> void:
	if not fighter_bars_container:
		return
	for child in fighter_bars_container.get_children():
		child.queue_free()
	_bar_nodes.clear()

	for f in fighters:
		var container := VBoxContainer.new()
		container.custom_minimum_size = Vector2(120, 0)

		var name_lbl := Label.new()
		name_lbl.text                      = f.fighter_name
		name_lbl.add_theme_color_override("font_color", f.fighter_color)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.horizontal_alignment      = HORIZONTAL_ALIGNMENT_CENTER

		var bar := ProgressBar.new()
		bar.min_value                      = 0.0
		bar.max_value                      = 1.0
		bar.value                          = 1.0
		bar.custom_minimum_size            = Vector2(120, 12)
		bar.show_percentage                = false
		# Style the bar with the fighter's color
		var bar_style := StyleBoxFlat.new()
		bar_style.bg_color    = f.fighter_color
		bar_style.corner_radius_top_left    = 3
		bar_style.corner_radius_top_right   = 3
		bar_style.corner_radius_bottom_left = 3
		bar_style.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("fill", bar_style)

		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.08, 0.06, 0.12)
		bar.add_theme_stylebox_override("background", bg_style)

		container.add_child(name_lbl)
		container.add_child(bar)
		fighter_bars_container.add_child(container)
		_bar_nodes[f] = {"bar": bar, "label": name_lbl, "container": container}

# ── Per-frame updates ─────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_update_health_bars()
	_update_alive_label()
	_update_combo(delta)

func _update_health_bars() -> void:
	for f in _bar_nodes:
		var nodes : Dictionary = _bar_nodes[f]
		if nodes.has("bar"):
			(nodes["bar"] as ProgressBar).value = f.get_hp_pct()
		if not f.alive and nodes.has("container"):
			(nodes["container"] as Control).modulate.a = 0.35

func _update_alive_label() -> void:
	if not alive_label:
		return
	var alive_count := fighters.filter(func(f) -> bool: return f.alive).size()
	alive_label.text = "⚙ %d Alive" % alive_count

# ── Kill feed ─────────────────────────────────────────────────────────────────
func on_kill(dead_fighter: Fighter) -> void:
	_add_kill_entry("☠  %s eliminated" % dead_fighter.fighter_name, dead_fighter.fighter_color)

func _add_kill_entry(text: String, col: Color) -> void:
	if not kill_feed_container:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	kill_feed_container.add_child(lbl)

	# Cap at 6 entries
	while kill_feed_container.get_child_count() > 6:
		kill_feed_container.get_child(0).queue_free()

	# Fade out after 4s
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if is_instance_valid(lbl):
			var tw := create_tween()
			tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
			tw.tween_callback(lbl.queue_free)
	)

# ── Attack announce ───────────────────────────────────────────────────────────
func announce_attack(attacker: Fighter, move_name: String) -> void:
	if not announce_label:
		return
	announce_label.text          = "%s  —  %s" % [attacker.fighter_name, move_name]
	announce_label.add_theme_color_override("font_color", attacker.fighter_color)
	announce_label.modulate.a    = 1.0

	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(announce_label, "modulate:a", 0.0, 0.3)

# ── Combo counter ─────────────────────────────────────────────────────────────
func on_hit(f: Fighter, amount: float, attacker) -> void:
	if attacker == null:
		return
	if attacker != combo_attacker:
		combo_count    = 0
		combo_attacker = attacker
	combo_count += 1
	combo_timer  = COMBO_WINDOW
	_update_combo_display()

func _update_combo(delta: float) -> void:
	if combo_timer <= 0.0:
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo_count    = 0
		combo_attacker = null
		if combo_display:
			var tw := create_tween()
			tw.tween_property(combo_display, "modulate:a", 0.0, 0.3)

func _update_combo_display() -> void:
	if combo_count < 2 or not combo_display:
		return

	if combo_number:
		combo_number.text = "%dx" % combo_count
	if combo_label:
		var labels := ["","","DOUBLE","TRIPLE","QUAD","PENTA","HEXA","MEGA","ULTRA","GODLIKE"]
		combo_label.text = labels[min(combo_count, labels.size()-1)] + " COMBO"

	var col := Color.WHITE
	if combo_count >= 8:   col = Color(1.0, 0.3, 1.0)
	elif combo_count >= 5: col = Color(1.0, 0.24, 0.67)
	elif combo_count >= 3: col = Color(1.0, 0.6, 0.0)
	else:                  col = Color(1.0, 0.9, 0.2)
	if combo_number: combo_number.add_theme_color_override("font_color", col)
	if combo_label:  combo_label.add_theme_color_override("font_color", col)

	combo_display.modulate.a = 1.0

# ── Speed display ─────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("speed_1") and speed_label:
		speed_label.text = "1×"
	elif event.is_action_pressed("speed_2") and speed_label:
		speed_label.text = "2×"
	elif event.is_action_pressed("speed_3") and speed_label:
		speed_label.text = "3×"

# ── Results screen ────────────────────────────────────────────────────────────
func show_results(winner: Fighter, all_fighters: Array) -> void:
	if not results_panel or not results_label:
		return
	results_panel.visible = true
	var txt := ""
	if winner:
		txt = "🏆  %s  WINS!\n\nPress SPACE or ENTER to rematch" % winner.fighter_name
		results_label.add_theme_color_override("font_color", winner.fighter_color)
	else:
		txt = "NO SURVIVORS\n\nPress SPACE or ENTER to rematch"
		results_label.add_theme_color_override("font_color", Color.WHITE)
	results_label.text = txt

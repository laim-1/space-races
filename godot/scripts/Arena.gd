extends Node3D

# ── Procedurally builds the octagon cage arena ────────────────────────────────

const RADIUS       := 8.0
const WALL_HEIGHT  := 2.2
const WALL_THICK   := 0.18
const BAR_RADIUS   := 0.06

# Neon colors for corner lights (cycles through 8 corners)
const CORNER_COLORS := [
	Color(0.0,  0.9,  1.0),   # cyan
	Color(1.0,  0.24, 0.67),  # magenta
	Color(0.71, 0.29, 1.0),   # purple
	Color(1.0,  0.6,  0.0),   # amber
	Color(0.0,  0.9,  1.0),
	Color(1.0,  0.24, 0.67),
	Color(0.71, 0.29, 1.0),
	Color(1.0,  0.6,  0.0),
]

func _ready() -> void:
	_build_floor()
	_build_walls()
	_build_cage_bars()
	_build_corner_lights()
	_build_crowd_silhouettes()

# ── Floor ─────────────────────────────────────────────────────────────────────
func _build_floor() -> void:
	var pts := _octagon_points(RADIUS - 0.2)

	var st  := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Fan triangulation from center
	for i in 8:
		var a := pts[i]
		var b := pts[(i + 1) % 8]
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(Vector3.ZERO)
		st.set_uv(Vector2(a.x / RADIUS * 0.5 + 0.5, a.y / RADIUS * 0.5 + 0.5))
		st.add_vertex(Vector3(a.x, -0.01, a.y))
		st.set_uv(Vector2(b.x / RADIUS * 0.5 + 0.5, b.y / RADIUS * 0.5 + 0.5))
		st.add_vertex(Vector3(b.x, -0.01, b.y))

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = st.commit()

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.055, 0.040, 0.080)
	floor_mat.roughness    = 0.95
	floor_mat.metallic     = 0.05
	# Subtle neon grid via emission (low intensity)
	floor_mat.emission_enabled          = true
	floor_mat.emission                  = Color(0.0, 0.22, 0.28)
	floor_mat.emission_energy_multiplier = 0.18
	mesh_inst.material_override = floor_mat

	add_child(mesh_inst)

	# Static floor collider
	var floor_body  := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box         := BoxShape3D.new()
	box.size = Vector3(RADIUS * 2.2, 0.2, RADIUS * 2.2)
	floor_shape.shape   = box
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

# ── Walls (invisible collision) ───────────────────────────────────────────────
func _build_walls() -> void:
	var pts := _octagon_points(RADIUS)
	for i in 8:
		var a  : Vector2 = pts[i]
		var b  : Vector2 = pts[(i + 1) % 8]
		var mid := (a + b) * 0.5
		var dir := (b - a).normalized()
		var len := a.distance_to(b) + 0.05

		var wall       := StaticBody3D.new()
		var col_shape  := CollisionShape3D.new()
		var box        := BoxShape3D.new()
		box.size = Vector3(len, WALL_HEIGHT, WALL_THICK)
		col_shape.shape    = box
		col_shape.position = Vector3(0.0, WALL_HEIGHT * 0.5, 0.0)
		wall.position      = Vector3(mid.x, 0.0, mid.y)
		wall.rotation.y    = atan2(-dir.x, dir.y)
		wall.add_child(col_shape)
		add_child(wall)

# ── Cage bars (visual) ────────────────────────────────────────────────────────
func _build_cage_bars() -> void:
	var pts := _octagon_points(RADIUS)

	for i in 8:
		var a  : Vector2 = pts[i]
		var b  : Vector2 = pts[(i + 1) % 8]
		var mid := (a + b) * 0.5
		var dir := (b - a).normalized()
		var len := a.distance_to(b)

		# Horizontal bar along each wall
		var bar_mat := _neon_mat(CORNER_COLORS[i], 2.5)

		# Top rail
		_add_bar(Vector3(mid.x, WALL_HEIGHT, mid.y), dir, len, BAR_RADIUS, bar_mat)
		# Bottom rail
		_add_bar(Vector3(mid.x, 0.05, mid.y),        dir, len, BAR_RADIUS, bar_mat)

		# Vertical bars every ~1.2m
		var steps := int(len / 1.2)
		for s in steps + 1:
			var t   := float(s) / float(steps) if steps > 0 else 0.5
			var pos := Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
			_add_vertical_bar(Vector3(pos.x, 0.0, pos.y), WALL_HEIGHT, BAR_RADIUS * 0.8, bar_mat)

func _add_bar(pos: Vector3, dir2d: Vector2, length: float, r: float, mat: Material) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius    = r
	cyl.bottom_radius = r
	cyl.height        = length
	cyl.radial_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh              = cyl
	mi.material_override = mat
	mi.position          = pos
	mi.rotation.z        = PI * 0.5
	mi.rotation.y        = atan2(-dir2d.x, dir2d.y)
	add_child(mi)

func _add_vertical_bar(pos: Vector3, height: float, r: float, mat: Material) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius    = r
	cyl.bottom_radius = r
	cyl.height        = height
	cyl.radial_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh              = cyl
	mi.material_override = mat
	mi.position          = pos + Vector3(0.0, height * 0.5, 0.0)
	add_child(mi)

# ── Corner lights ─────────────────────────────────────────────────────────────
func _build_corner_lights() -> void:
	var pts := _octagon_points(RADIUS * 1.02)
	for i in 8:
		var pt := pts[i]
		var light := OmniLight3D.new()
		light.position           = Vector3(pt.x, WALL_HEIGHT + 0.5, pt.y)
		light.light_color        = CORNER_COLORS[i]
		light.light_energy       = 1.8
		light.omni_range         = 5.5
		light.omni_attenuation   = 1.4
		light.shadow_enabled     = false
		add_child(light)

# ── Crowd silhouettes ─────────────────────────────────────────────────────────
func _build_crowd_silhouettes() -> void:
	const ROWS    := 2
	const PER_ROW := 24
	const ROW_GAP := 1.1

	var crowd_mat := StandardMaterial3D.new()
	crowd_mat.albedo_color = Color(0.04, 0.03, 0.06)
	crowd_mat.roughness    = 1.0

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color            = Color(0.0, 0.9, 1.0)
	eye_mat.emission_enabled        = true
	eye_mat.emission                = Color(0.0, 0.9, 1.0)
	eye_mat.emission_energy_multiplier = 3.0

	for row in ROWS:
		var r := RADIUS + 1.4 + row * ROW_GAP
		for i in PER_ROW:
			var angle  := (float(i) / PER_ROW) * TAU + randf() * 0.08
			var jitter := randf_range(-0.2, 0.2)
			var px     := cos(angle) * (r + jitter)
			var pz     := sin(angle) * (r + jitter)
			var height := randf_range(1.2, 1.9)

			# Body (capsule)
			var body_mesh := CapsuleMesh.new()
			body_mesh.radius = randf_range(0.2, 0.32)
			body_mesh.height = height
			var body_mi := MeshInstance3D.new()
			body_mi.mesh              = body_mesh
			body_mi.material_override = crowd_mat
			body_mi.position          = Vector3(px, height * 0.5, pz)
			add_child(body_mi)

			# Glowing eyes (1 or 2 small spheres)
			if randf() > 0.3:
				var eye_mesh := SphereMesh.new()
				eye_mesh.radius = 0.055
				eye_mesh.height = 0.11
				var eye_mi := MeshInstance3D.new()
				eye_mi.mesh              = eye_mesh
				eye_mi.material_override = eye_mat
				eye_mi.position          = Vector3(px, height * 0.85, pz)
				add_child(eye_mi)

# ── Helper ────────────────────────────────────────────────────────────────────
func _octagon_points(r: float) -> Array[Vector2]:
	var pts : Array[Vector2] = []
	for i in 8:
		var angle := i * TAU / 8.0 - TAU / 16.0
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	return pts

func _neon_mat(col: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color            = col
	mat.emission_enabled        = true
	mat.emission                = col
	mat.emission_energy_multiplier = energy
	mat.roughness               = 0.3
	return mat

class_name StageKit
extends Node3D
## The floor built from the owner's kit (v0.5.9 Step 4): StageDresser's placements turned into nodes. Walls and
## cover are one MeshInstance3D per piece, grouped by the sim wall they dress so occlusion fades them together.
## Decoration is one MultiMeshInstance3D per piece kind. Light props carry a warm OmniLight3D and a flame; the
## lights flicker (cosmetic, frame time) and only the SHADOW_LIGHTS nearest the view's focus cast shadows.
## Presentation only.

## How many light props cast shadows at once (the ones nearest the camera's focus).
const SHADOW_LIGHTS := 4
## v0.8.0 P3 (owner O30, "Lighting sometimes changes abruptly … appearing to switch on and off"): a light joining or
## leaving the SHADOW_LIGHTS fades its shadow in or out over this long (s) instead of switching it (the joining one
## once the leaving one is out, so never more than SHADOW_LIGHTS cast), and one keeps its shadow until another is
## nearer the focus by SHADOW_SWAP_M (no swapping back and forth on a border).
## v0.8.0 Step FS (owner O86; perf review Part 2 item 2): the margin grows with distance, SHADOW_SWAP_M plus
## SHADOW_SWAP_FRAC of the keeper's distance, so a challenger must be meaningfully nearer; each swap rebuilds shadow
## faces, so the set changes rarely.
const SHADOW_FADE_S := 0.45
const SHADOW_SWAP_M := 2.5
const SHADOW_SWAP_FRAC := 0.2
## v0.8.0 P3 (O30, O32): a light whose reach can't touch the view (farther from the focus than the view's half
## diagonal on the ground, VIEW_REACH x the camera's size, plus its range) fades out over LIGHT_FADE_S and is
## hidden, and fades back in on the way in; hidden lights skip the flicker's per-frame work.
const VIEW_REACH := 1.3
const LIGHT_FADE_S := 0.4
## How often (frames) the focus distances (the view fade) are refreshed.
const PICK_EVERY := 15
## v0.8.0 Step FS: how often (frames) the shadow casters are re-picked (was every PICK_EVERY); sooner when a caster
## leaves the view's reach, so its slot doesn't sit empty.
const SHADOW_PICK_EVERY := 60
## v0.8.0 P3 (owner O31): the flame teardrop's HDR colour factor and emission (were 1.6 and 2.0).
const FLAME_HDR := 1.2
const FLAME_EMISSION := 1.1
## Where the light sits above a prop's base, by piece (m).
const LIGHT_HEIGHT := {&"fire_barrel": 1.15, &"brazier_pole": 2.2}
const FADED_ALPHA := 0.3
## How strongly walls and cover take the biome's cover hue (0: the model's own colours).
const TINT_AMOUNT := 0.55
## v0.8.0 P3 (owner O29, "Red, Blue, and Original biomes experience lag"): decoration is drawn as one MultiMesh per
## piece kind per DECOR_CHUNK_M square of the floor, not one per kind over the whole floor. A floor-wide MultiMesh is
## never culled (its bounds are always on screen and in every shadow pass's reach), so all of the floor's kit grass,
## rubble and debris (10-13k triangles each, ~20 million a floor) was drawn every frame; a chunk is culled off screen
## and out of a light's reach, and each piece is drawn from its coarsest level of detail (KitModels.decor_mesh: 2.2-4x
## fewer triangles, for pieces a few dozen pixels tall). The pieces, their places and their look are kept.
const DECOR_CHUNK_M := 16.0
## v0.8.0 N12 (O70): a load adds the kit's pieces this many at a time (one job each, ~5-10 ms headless).
const PIECES_PER_JOB := 48
## v0.8.0 N12: and the procedural walls' meshes this many walls at a time.
const PROC_WALLS_PER_JOB := 8

var lights: Array[OmniLight3D] = []
## v0.8.0 N10: the procedural walls' meshes built (one per sim wall it draws) and their triangles.
var proc_nodes := 0
var proc_tris := 0
## Per dressed wall index: its pieces.
var wall_pieces: Array = []
## v0.8.0 P3: the decoration MultiMeshes built (one per piece kind per chunk).
var decor_nodes := 0
var shadows := true
var _light_energy: Array[float] = []
var _phase: Array[float] = []
## v0.8.0 P3: per light, its shadow's fade (0..1) and target, its view fade (0..1) and target.
var _shadow_k := PackedFloat32Array()
var _shadow_want := PackedByteArray()
var _view_k := PackedFloat32Array()
var _view_want := PackedByteArray()
var _solid := {}
var _faded := {}
var _faded_now := {}
var _t := 0.0
var _frame := 0


## Builds the nodes. `wall_count`: how many walls the stage dresses (the wall_specs size). `cover_hue`: the biome's
## cover colour, tinting walls and cover. v0.8.0 N10: `proc`, ProceduralWall.build's result (empty: none), drawn
## with `wall_tex` {"face": Texture2D, "top": Texture2D} (the owner's per-biome wall textures, untinted; v0.8.0 N15:
## and WallCalm.look_of's shader values).
func build(
	placements: Array,
	wall_count: int,
	cover_hue: Color,
	mood: BiomeMood,
	proc: Dictionary = {},
	wall_tex: Dictionary = {}
) -> void:
	var q := ViewBuildQueue.new()
	q.add("kit", queue_build.bind(q, placements, wall_count, cover_hue, mood, proc, wall_tex))
	q.run_all()


## v0.8.0 N12 (owner O70): build() as jobs right after the running one on `q` (ViewBuildQueue.add_next): the
## procedural walls' meshes PROC_WALLS_PER_JOB walls at a time, the pieces PIECES_PER_JOB at a time, then each
## decoration kind; a load runs them over frames behind the loading cover.
func queue_build(
	q: ViewBuildQueue,
	placements: Array,
	wall_count: int,
	cover_hue: Color,
	mood: BiomeMood,
	proc: Dictionary = {},
	wall_tex: Dictionary = {}
) -> void:
	wall_pieces.resize(wall_count)
	for i in wall_count:
		wall_pieces[i] = []
	if not proc.is_empty():
		var solid := _proc_material(wall_tex)
		var surfaces: Dictionary = proc.get("surfaces", {})
		var owners: Array = surfaces.keys()
		for from in range(0, owners.size(), PROC_WALLS_PER_JOB):
			q.add_next(
				"kit_proc_walls",
				_build_proc.bind(surfaces, owners.slice(from, from + PROC_WALLS_PER_JOB), solid)
			)
	var tint := _hue_tint(cover_hue)
	var decor := {}
	var pieces: Array = []
	for p: Dictionary in placements:
		if piece_of(p["piece"]).is_empty():
			continue
		if p["kind"] == &"decor":
			if not decor.has(p["piece"]):
				decor[p["piece"]] = []
			decor[p["piece"]].append(p["xform"])
			continue
		pieces.append(p)
	for from in range(0, pieces.size(), PIECES_PER_JOB):
		q.add_next(
			"kit",
			_add_pieces.bind(pieces.slice(from, from + PIECES_PER_JOB), wall_count, tint, mood)
		)
	for id: StringName in decor:
		q.add_next("kit_decor", _add_decor.bind(id, decor[id]))


func _add_pieces(pieces: Array, wall_count: int, tint: Color, mood: BiomeMood) -> void:
	for p: Dictionary in pieces:
		var piece := piece_of(p["piece"])
		var tinted: bool = p["kind"] == &"wall" or p["kind"] == &"cover"
		# v0.8.0 MI: a biome's own piece keeps its colours (KitModels "tint": its share of the hue).
		var share := float((KitModels.SPECS.get(p["piece"], {}) as Dictionary).get("tint", 1.0))
		var node := MeshInstance3D.new()
		node.mesh = piece["mesh"]
		node.material_override = _material(
			p["piece"], piece["material"], Color.WHITE.lerp(tint, share) if tinted else Color.WHITE
		)
		node.transform = p["xform"]
		node.set_meta(&"piece", p["piece"])
		add_child(node)
		if p["wall"] >= 0 and p["wall"] < wall_count:
			wall_pieces[p["wall"]].append(node)
		if p["kind"] == &"light":
			_add_light(p["piece"], (p["xform"] as Transform3D).origin, mood)


func _add_decor(id: StringName, xforms: Array) -> void:
	var piece := piece_of(id)
	var chunks := {}  # v0.8.0 P3: grid cell -> this piece's transforms in it
	for xf: Transform3D in xforms:
		var cell := Vector2i(
			floori(xf.origin.x / DECOR_CHUNK_M), floori(xf.origin.z / DECOR_CHUNK_M)
		)
		if not chunks.has(cell):
			chunks[cell] = []
		chunks[cell].append(xf)
	var group := Node3D.new()  # the piece kind's chunks under one node, as before
	group.name = "Decor_" + String(id)
	add_child(group)
	for cell: Vector2i in chunks:
		var xfs: Array = chunks[cell]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = KitModels.decor_mesh(piece["mesh"])  # v0.8.0 P3: its decoration detail
		mm.instance_count = xfs.size()
		for k in xfs.size():
			mm.set_instance_transform(k, xfs[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Chunk_%d_%d" % [cell.x, cell.y]
		mmi.multimesh = mm
		mmi.material_override = piece["material"]
		# v0.8.0 HR (O89; RenderSwitches.SCATTER_NO_SHADOW): small floor scatter casts no shadow.
		if RenderSwitches.SCATTER_NO_SHADOW and _tallest(xfs) < RenderSwitches.SCATTER_SHADOW_MAX_M:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(mmi)
		decor_nodes += 1


## v0.8.0 HR: the tallest of a decoration chunk's pieces (m): its transforms' height scale (the decoration meshes are
## one unit tall, KitModels / CodeProps).
static func _tallest(xfs: Array) -> float:
	var top := 0.0
	for xf: Transform3D in xfs:
		top = maxf(top, xf.basis.y.length())
	return top


## A kit piece, or (v0.7.5 NB1) a code-made one the kit lacks (CodeProps); {} when neither has it.
static func piece_of(id: StringName) -> Dictionary:
	var piece := KitModels.get_piece(id)
	return piece if not piece.is_empty() else CodeProps.get_piece(id)


## v0.8.0 MI: whether piece_of(id) would draw something, without reading the model (a file check): the dresser's
## pools drop a piece that is not installed (L15).
static func has_piece(id: StringName) -> bool:
	if CodeProps.has(id):
		return true
	return KitModels.SPECS.has(id) and ResourceLoader.exists(KitModels.dir + String(id) + ".glb")


## v0.8.0 N10 (option A): one mesh per sim wall the procedural wall draws, one surface, one material for the floor
## (ProceduralWall.material: the face and top textures in one shader); faded with the wall as its pieces are.
## v0.8.0 N12: the material made once (_proc_material), the meshes `owners` at a time (one job each).
func _proc_material(wall_tex: Dictionary) -> Material:
	var face: Texture2D = wall_tex.get("face", null)
	var top: Texture2D = wall_tex.get("top", null)
	var solid := ProceduralWall.material(face, top, false, wall_tex)
	_faded[solid] = ProceduralWall.material(face, top, true, wall_tex)
	return solid


func _build_proc(surfaces: Dictionary, owners: Array, solid: Material) -> void:
	for owner: int in owners:
		var mesh := ArrayMesh.new()
		for arr: Array in surfaces[owner]:
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			proc_tris += verts.size() / 3
		if mesh.get_surface_count() == 0:
			continue
		var node := MeshInstance3D.new()
		node.name = "ProcWall_%d" % owner
		node.mesh = mesh
		for k in mesh.get_surface_count():
			node.set_surface_override_material(k, solid)
		node.set_meta(&"piece", &"proc_wall")
		add_child(node)
		proc_nodes += 1
		if owner >= 0 and owner < wall_pieces.size():
			wall_pieces[owner].append(node)


## The biome hue at full brightness, mixed with white: walls keep their texture's light and dark and take the hue.
static func _hue_tint(c: Color) -> Color:
	var m := maxf(maxf(c.r, c.g), maxf(c.b, 0.001))
	return Color.WHITE.lerp(Color(c.r / m, c.g / m, c.b / m), TINT_AMOUNT)


func _material(id: StringName, base: StandardMaterial3D, tint: Color) -> StandardMaterial3D:
	var key := "%s/%s" % [id, tint.to_html()]
	if not _solid.has(key):
		var m := base.duplicate() as StandardMaterial3D
		m.albedo_color = tint
		_solid[key] = m
		var f := m.duplicate() as StandardMaterial3D
		f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
		f.albedo_color.a = FADED_ALPHA
		_faded[m] = f
	return _solid[key]


func _add_light(id: StringName, base: Vector3, mood: BiomeMood) -> void:
	var light := OmniLight3D.new()
	light.position = base + Vector3(0, LIGHT_HEIGHT.get(id, 1.2), 0)
	light.light_color = mood.warm_light_color
	light.light_energy = mood.warm_light_energy
	light.omni_range = mood.warm_light_range
	light.omni_attenuation = 1.1
	light.shadow_enabled = false
	if RenderSwitches.TORCH_DUAL_PARABOLOID:  # v0.8.0 HR (O89): 2 shadow renders, not the cube's 6
		light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	add_child(light)
	lights.append(light)
	_light_energy.append(mood.warm_light_energy)
	_phase.append(float(lights.size()) * 1.731)
	_shadow_k.append(0.0)
	_shadow_want.append(0)
	_view_k.append(1.0)
	_view_want.append(1)
	# The flame: a small glowing teardrop at the light (glow picks it up).
	var flame := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.13
	m.height = 0.34
	m.radial_segments = 8
	m.rings = 4
	flame.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# HDR (over 1) so it crosses the glow threshold and blooms (lighting pass, 2026-10-12). v0.8.0 P3 (owner O31,
	# "Glow intensity is still excessive … particularly on barrels, torches"): FLAME_HDR and FLAME_EMISSION (were 1.6
	# and 2.0), so it still glows but no longer blooms over what stands near it; the light it casts is unchanged.
	mat.albedo_color = mood.warm_light_color * FLAME_HDR
	mat.emission_enabled = true
	mat.emission = mood.warm_light_color
	mat.emission_energy_multiplier = FLAME_EMISSION
	flame.material_override = mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = light.position - Vector3(0, 0.22, 0)
	add_child(flame)


## The hero's light (owner Q3): a small warm omni light at chest height, carried by the hero's node. No shadow,
## so it costs little; enemies still carry no light (PRESENTATION_CONTRACTS §7).
static func hero_light(mood: BiomeMood) -> OmniLight3D:
	if mood == null or mood.hero_light_energy <= 0.0:
		return null
	var l := OmniLight3D.new()
	l.name = "HeroLight"
	l.light_color = mood.warm_light_color.lerp(Color.WHITE, 0.35)
	l.light_energy = mood.hero_light_energy
	l.omni_range = mood.hero_light_range
	l.omni_attenuation = 1.3
	l.position = Vector3(0, 1.3, 0)
	l.shadow_enabled = false
	return l


## Fades every piece of the walls at `indices` (dithered) and restores the rest; only changed walls are touched.
func set_faded(indices: PackedInt32Array) -> void:
	var want := {}
	for i in indices:
		if i >= 0 and i < wall_pieces.size():
			want[i] = true
	for i: int in _faded_now:
		if not want.has(i):
			_apply(i, false)
	for i: int in want:
		if not _faded_now.has(i):
			_apply(i, true)
	_faded_now = want


func _apply(i: int, faded: bool) -> void:
	for node: MeshInstance3D in wall_pieces[i]:
		if node.material_override == null:  # v0.8.0 N10: a procedural wall, one material per surface
			for k in node.get_surface_override_material_count():
				var m := node.get_surface_override_material(k)
				if faded:
					node.set_meta(StringName("solid_%d" % k), m)
					node.set_surface_override_material(k, _faded.get(m, m))
				elif node.has_meta(StringName("solid_%d" % k)):
					node.set_surface_override_material(k, node.get_meta(StringName("solid_%d" % k)))
			continue
		if faded:
			node.set_meta(&"solid", node.material_override)
			node.material_override = _faded.get(node.material_override, node.material_override)
		elif node.has_meta(&"solid"):
			node.material_override = node.get_meta(&"solid")


## Re-applies the mood's fire-light colour, energy and range to every light prop (the dev panel's lighting page).
func retune(mood: BiomeMood) -> void:
	for k in lights.size():
		lights[k].light_color = mood.warm_light_color
		lights[k].omni_range = mood.warm_light_range
		_light_energy[k] = mood.warm_light_energy
		lights[k].light_energy = mood.warm_light_energy


func set_shadows(on: bool) -> void:
	shadows = on
	if not on:
		for k in lights.size():
			lights[k].shadow_enabled = false
			_shadow_k[k] = 0.0
			_shadow_want[k] = 0
	_frame = 0


func _process(delta: float) -> void:
	_t += delta
	_frame += 1
	if _frame % PICK_EVERY == 1:
		_pick(shadows and _frame % SHADOW_PICK_EVERY == 1)
	var shadow_step := delta / SHADOW_FADE_S
	var view_step := delta / LIGHT_FADE_S
	var calm := ViewPrefs.reduced_motion
	# At most SHADOW_LIGHTS cast at once, fading ones included: a joining light waits for a leaving one's slot (its
	# shadow fades out, then the other's fades in), so a swap never costs more shadow passes than the budget.
	var casting := 0
	for k in lights.size():
		if _shadow_k[k] > 0.0:
			casting += 1
	for k in lights.size():
		var l := lights[k]
		var v := move_toward(_view_k[k], float(_view_want[k]), view_step)
		_view_k[k] = v
		if v <= 0.0:
			if l.visible:
				l.visible = false
				l.shadow_enabled = false
				_shadow_k[k] = 0.0
			continue
		if not l.visible:
			l.visible = true
		var f := 1.0
		if not calm:
			var ph := _phase[k]
			f = 1.0 + 0.07 * sin(_t * 11.0 + ph) + 0.05 * sin(_t * 6.3 + ph * 2.0)
		l.light_energy = _light_energy[k] * f * v
		var target := float(_shadow_want[k])
		if target > 0.0 and _shadow_k[k] <= 0.0:
			if casting >= SHADOW_LIGHTS:
				target = 0.0  # no free slot yet
			else:
				casting += 1
		var sk := move_toward(_shadow_k[k], target, shadow_step)
		_shadow_k[k] = sk
		var on := sk > 0.0
		if l.shadow_enabled != on:
			l.shadow_enabled = on
		if on:
			l.shadow_opacity = sk * sk * (3.0 - 2.0 * sk)  # smoothstep: no step at either end


## The camera's focus on the ground (its ray onto y = 0) and its size; [] without a camera.
func _focus() -> Array:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return []
	var fwd := -cam.global_transform.basis.z
	var origin := cam.global_position
	var focus := origin
	if absf(fwd.y) > 0.001:
		focus = origin + fwd * (-origin.y / fwd.y)
	return [focus, cam.size if cam.projection == Camera3D.PROJECTION_ORTHOGONAL else 30.0]


## Every PICK_EVERY frames: which lights are in the view's reach (the rest fade out), and, with `with_shadows` (every
## SHADOW_PICK_EVERY frames, or when a caster leaves the view's reach), which SHADOW_LIGHTS of them cast shadows (the
## nearest the focus; a light keeping its shadow wins unless another is nearer by the swap margin).
func _pick(with_shadows: bool) -> void:
	if lights.is_empty():
		return
	var at := _focus()
	if at.is_empty():
		return
	var focus: Vector3 = at[0]
	var reach := float(at[1]) * VIEW_REACH
	var d := PackedFloat32Array()
	d.resize(lights.size())
	for k in lights.size():
		var p := lights[k].global_position
		d[k] = Vector2(p.x - focus.x, p.z - focus.z).length()
		_view_want[k] = 1 if d[k] <= reach + lights[k].omni_range else 0
		if shadows and _view_want[k] == 0 and _shadow_want[k] == 1:
			with_shadows = true  # a caster left the view: re-pick now
	if not with_shadows:
		return
	var key := PackedFloat32Array()
	key.resize(lights.size())
	for k in lights.size():
		key[k] = d[k] - (SHADOW_SWAP_M + SHADOW_SWAP_FRAC * d[k]) * _shadow_want[k]
	var order: Array = []
	for k in lights.size():
		if _view_want[k] == 1:
			order.append(k)
	order.sort_custom(func(a: int, b: int) -> bool: return key[a] < key[b])
	for k in lights.size():
		_shadow_want[k] = 0
	for n in mini(SHADOW_LIGHTS, order.size()):
		_shadow_want[order[n]] = 1

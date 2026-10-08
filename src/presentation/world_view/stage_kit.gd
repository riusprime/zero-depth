class_name StageKit
extends Node3D
## The floor built from the owner's kit (v0.5.9 Step 4): StageDresser's placements turned into nodes. Walls and
## cover are one MeshInstance3D per piece, grouped by the sim wall they dress so occlusion fades them together.
## Decoration is one MultiMeshInstance3D per piece kind. Light props carry a warm OmniLight3D and a flame; the
## lights flicker (cosmetic, frame time) and only the SHADOW_LIGHTS nearest the view's focus cast shadows.
## Presentation only.

## How many light props cast shadows at once (the ones nearest the camera's focus).
const SHADOW_LIGHTS := 4
## Where the light sits above a prop's base, by piece (m).
const LIGHT_HEIGHT := {&"fire_barrel": 1.15, &"brazier_pole": 2.2}
const FADED_ALPHA := 0.3
## How strongly walls and cover take the biome's cover hue (0: the model's own colours).
const TINT_AMOUNT := 0.55

var lights: Array[OmniLight3D] = []
## Per dressed wall index: its pieces.
var wall_pieces: Array = []
var shadows := true
var _light_energy: Array[float] = []
var _phase: Array[float] = []
var _solid := {}
var _faded := {}
var _faded_now := {}
var _t := 0.0
var _frame := 0


## Builds the nodes. `wall_count`: how many walls the stage dresses (the wall_specs size). `cover_hue`: the biome's
## cover colour, tinting walls and cover.
func build(placements: Array, wall_count: int, cover_hue: Color, mood: BiomeMood) -> void:
	wall_pieces.resize(wall_count)
	for i in wall_count:
		wall_pieces[i] = []
	var tint := _hue_tint(cover_hue)
	var decor := {}
	for p: Dictionary in placements:
		var piece := KitModels.get_piece(p["piece"])
		if piece.is_empty():
			continue
		if p["kind"] == &"decor":
			if not decor.has(p["piece"]):
				decor[p["piece"]] = []
			decor[p["piece"]].append(p["xform"])
			continue
		var tinted: bool = p["kind"] == &"wall" or p["kind"] == &"cover"
		var node := MeshInstance3D.new()
		node.mesh = piece["mesh"]
		node.material_override = _material(
			p["piece"], piece["material"], tint if tinted else Color.WHITE
		)
		node.transform = p["xform"]
		node.set_meta(&"piece", p["piece"])
		add_child(node)
		if p["wall"] >= 0 and p["wall"] < wall_count:
			wall_pieces[p["wall"]].append(node)
		if p["kind"] == &"light":
			_add_light(p["piece"], (p["xform"] as Transform3D).origin, mood)
	for id: StringName in decor:
		var piece := KitModels.get_piece(id)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = piece["mesh"]
		mm.instance_count = decor[id].size()
		for k in decor[id].size():
			mm.set_instance_transform(k, decor[id][k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Decor_" + String(id)
		mmi.multimesh = mm
		mmi.material_override = piece["material"]
		add_child(mmi)


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
	add_child(light)
	lights.append(light)
	_light_energy.append(mood.warm_light_energy)
	_phase.append(float(lights.size()) * 1.731)
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
	mat.albedo_color = mood.warm_light_color
	mat.emission_enabled = true
	mat.emission = mood.warm_light_color
	mat.emission_energy_multiplier = 3.0
	flame.material_override = mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = light.position - Vector3(0, 0.22, 0)
	add_child(flame)


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
		if faded:
			node.set_meta(&"solid", node.material_override)
			node.material_override = _faded.get(node.material_override, node.material_override)
		elif node.has_meta(&"solid"):
			node.material_override = node.get_meta(&"solid")


func set_shadows(on: bool) -> void:
	shadows = on
	if not on:
		for l in lights:
			l.shadow_enabled = false
	_frame = 0


func _process(delta: float) -> void:
	_t += delta
	if not ViewPrefs.reduced_motion:
		for k in lights.size():
			var ph := _phase[k]
			var f := 1.0 + 0.07 * sin(_t * 11.0 + ph) + 0.05 * sin(_t * 6.3 + ph * 2.0)
			lights[k].light_energy = _light_energy[k] * f
	_frame += 1
	if shadows and _frame % 15 == 1:
		_pick_shadow_lights()


## Shadows on for the SHADOW_LIGHTS lights nearest where the camera looks (its ray onto the ground).
func _pick_shadow_lights() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or lights.is_empty():
		return
	var fwd := -cam.global_transform.basis.z
	var origin := cam.global_position
	var focus := origin
	if absf(fwd.y) > 0.001:
		focus = origin + fwd * (-origin.y / fwd.y)
	var order: Array = range(lights.size())
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return (
				lights[a].global_position.distance_squared_to(focus)
				< lights[b].global_position.distance_squared_to(focus)
			)
	)
	for k in order.size():
		lights[order[k]].shadow_enabled = k < SHADOW_LIGHTS

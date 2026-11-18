extends SceneTree
## G2 stills for the owner's pick on enemy looks per biome (feedback row F27): the same lineup in a biome's real game
## view (WorldViewRoot: its mood, floor and cast) in four looks. Nothing here changes the game: each option edits the
## enemies' materials and adds nodes at shot time only.
##   now: the game as it is; a: the biome's colour pulled into the bodies (35 %), casters glow in their element;
##   b: the bodies keep their colours, the biome adds a rim and a band, casters wear a floating rune ring;
##   c: a lighter tint (20 %), casters 1.1 x with a bright core and an orbiting spark.
## One look per process (the shared enemy materials are cached statics), so run one process per cell:
##   godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000
##     -s scripts/shots/enemy_looks.gd -- biome=red_canyon look=a
## or `bash scripts/shots/enemy_looks.sh [biome ...]` for every look of the given biomes (default: the three), which
## also writes the contact sheet. Writes build/shots/<version>/enemy_looks/<biome>_<look>.png.

const CELL := Vector2i(1280, 560)
const SPACING := 1.95
const HERO_AT := Vector2(0.0, -30.0)
const LOOKS := [&"now", &"a", &"b", &"c"]
## Per biome: the lineup (kind, caster), the biome's body colour (A, C), its accent (B) and the casters' element colour.
const BIOMES := {
	&"red_canyon":
	{
		"lineup":
		[
			[ActorStore.Kind.CHARGER, false],
			[ActorStore.Kind.EMBER_CHARGER, false],
			[ActorStore.Kind.ARC_CASTER, true],
			[ActorStore.Kind.CINDER_PRIEST, true],
		],
		"tint": Color(0.86, 0.36, 0.2),
		"accent": Color(1.0, 0.7, 0.18),
		"element": Color(1.0, 0.5, 0.12),
	},
	&"frozen_shore":
	{
		"lineup":
		[
			[ActorStore.Kind.CHARGER, false],
			[ActorStore.Kind.FROST_CHARGER, false],
			[ActorStore.Kind.ARC_CASTER, true],
			[ActorStore.Kind.FROST_SPITTER, true],
		],
		"tint": Color(0.55, 0.78, 1.0),
		"accent": Color(0.75, 0.97, 1.0),
		"element": Color(0.45, 0.85, 1.0),
	},
	&"starfall":
	{
		"lineup":
		[
			[ActorStore.Kind.CHARGER, false],
			[ActorStore.Kind.SNIPER, false],
			[ActorStore.Kind.SPLIT_SNIPER, false],
			[ActorStore.Kind.STAR_WARPER, true],
		],
		"tint": Color(0.6, 0.45, 1.0),
		"accent": Color(0.95, 0.55, 1.0),
		"element": Color(0.75, 0.55, 1.0),
	},
}
const RIM := """shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform vec4 band_color : source_color = vec4(1.0);
uniform float rim_power = 2.2;
uniform float rim_strength = 1.0;
uniform float base_y = 0.0;
uniform float band_lo = 0.4;
uniform float band_hi = 0.55;
varying float wy;
void vertex() { wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - base_y; }
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	float band = smoothstep(band_lo, band_lo + 0.03, wy) * (1.0 - smoothstep(band_hi - 0.03, band_hi, wy));
	ALBEDO = rim_color.rgb * f * rim_strength + band_color.rgb * band * 0.55;
}
"""

var _dir := ""
var _vp: SubViewport
var _view: WorldViewRoot
var _world: World
var _biome_id: StringName = &"red_canyon"
var _look: StringName = &"now"
var _ids: Array[int] = []
var _t := 0
var _settle := 0.0
var _dressed := false
var _right := Vector2(0.707, 0.707)


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_biome_id = StringName(args.get("biome", _biome_id))
	_look = StringName(args.get("look", _look))
	_dir = "res://build/shots/%s/enemy_looks/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var repo := ContentRepository.load_all()
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	_world = StageScenario.build(
		31, PlayerTable.starting_values(), ContentCompiler.compile_enemies(repo)
	)
	_world.actors.set_pos(0, HERO_AT)
	_world.actors.invuln[0] = 1 << 24
	var biome: BiomeDefinition = repo.get_def(&"biomes", _biome_id)
	_view = WorldViewRoot.new()
	_view.stage.prop_style = biome.id
	_view.stage.mood = biome.mood
	_view.stage.look = biome.look
	if biome.look != null:
		_view.actors.enemy_tint = biome.look.enemy_tint
	_vp.add_child(_view)
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.actors.cull = null
	_view.rig.view_size = 6.4
	_view.rig.camera.size = 6.4
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	var glow := StageKit.hero_light(biome.mood)  # (the hero is off screen: its warm light stands over the lineup)
	if glow != null:
		glow.position = SimPlane.to_3d(Vector2.ZERO) + Vector3(0, 0.6, 0)
		glow.omni_range = 9.0
		_view.add_child(glow)
	_view.rig.snap_to(SimPlane.to_3d(Vector2.ZERO))


func _line_up() -> void:
	# The screen's horizontal axis in sim coordinates, so the lineup runs left to right on the screen.
	var bx := _view.rig.camera.global_transform.basis.x
	print("enemy_looks: camera x ", bx)
	_right = Vector2(-bx.z, bx.x).normalized()
	var right := _right
	var lineup: Array = BIOMES[_biome_id]["lineup"]
	for k in lineup.size():
		var at: Vector2 = right * ((k - (lineup.size() - 1) * 0.5) * SPACING)
		_ids.append(_world.add_enemy(lineup[k][0], at))


func _process(delta: float) -> bool:
	_t += 1
	if _t == 1:
		_line_up()
	_world.actors.set_pos(0, HERO_AT)
	_view.sync()
	_view.rig.snap_to(SimPlane.to_3d(_right * 1.1))
	if _t == 3 and not _dressed:
		_dressed = true
		_dress()
	if _t < 90:
		return false
	_settle += delta
	if _settle < 0.8:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var path := _dir + "%s_%s.png" % [_biome_id, _look]
	img.save_png(path)
	print("enemy_looks: ", ProjectSettings.globalize_path(path))
	return true


# --- the looks ---------------------------------------------------------------------------------------------------


func _dress() -> void:
	if _look == &"now":
		return
	var cfg: Dictionary = BIOMES[_biome_id]
	var lineup: Array = cfg["lineup"]
	var tint: Color = cfg["tint"]
	var accent: Color = cfg["accent"]
	var element: Color = cfg["element"]
	for k in lineup.size():
		var node: Node3D = _view.actors._actors.get(_ids[k])
		if node == null:
			print("enemy_looks: no view for kind %d" % lineup[k][0])
			continue
		var caster: bool = lineup[k][1]
		var mats := _materials(node)
		var aabb := _extent(node)
		print(
			"enemy_looks: kind %d: %d materials, height %.2f" % [lineup[k][0], mats.size(), aabb.y]
		)
		match _look:
			&"a":
				_tint(mats, tint, 0.35)
				if caster:
					_glow(mats, element, 3.0)
					_light(node, element, 0.4, 1.1)
			&"b":
				_rim(mats, accent, aabb.y)
				if caster:
					_halo(node, element, 0.5)
			&"c":
				_tint(mats, tint, 0.2)
				if caster:
					(node.get_meta(&"facing") as Node3D).scale = Vector3.ONE * 1.1
					_glow(mats, element, 4.0)
					_core(node, element, 0.28, 0.55)


## The bodies' materials: every ShaderMaterial or StandardMaterial3D on the node's meshes (the shared horde looks
## are ShaderMaterials with albedo / emission parameters), once each.
func _materials(node: Node3D) -> Array[Material]:
	var out: Array[Material] = []
	for mi in _meshes(node.get_meta(&"facing")):
		if mi.mesh != null and (mi.global_transform * mi.get_aabb()).size.y < 0.05:
			continue  # (a flat disc or ring)
		var list: Array[Material] = [mi.material_override]
		for s in mi.get_surface_override_material_count():
			list.append(mi.get_surface_override_material(s))
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				list.append(mi.mesh.surface_get_material(s))
		for m in list:
			if (m is StandardMaterial3D or m is ShaderMaterial) and not out.has(m):
				out.append(m)
	return out


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visible:
			out.append(c)
		out.append_array(_meshes(c))
	return out


## (x, y, z): the body's extent above the node's origin; y is its height. Rings and bars (flat or high) are ignored
## by skipping meshes wider than they are deep and lower than 5 cm.
func _extent(node: Node3D) -> Vector3:
	var top := 0.0
	for mi in _meshes(node.get_meta(&"facing")):
		if mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		if b.size.y < 0.05:
			continue
		top = maxf(top, b.end.y - node.global_position.y)
	return Vector3(0.0, minf(top, 3.0), 0.0)


static func _is_glow(m: Material) -> bool:
	if m is StandardMaterial3D:
		return (
			(m as StandardMaterial3D).emission_enabled
			and (m as StandardMaterial3D).emission_energy_multiplier >= 1.0
		)
	return not EnemyLooks.is_body(m)


## Pulls each body plate's colour toward `c` by `k` (a grey keeps its light: the same rule the game's own cast uses),
## leaving the glowing parts' (eyes, gems) colours alone.
func _tint(mats: Array[Material], c: Color, k: float) -> void:
	for m in mats:
		if _is_glow(m):
			continue
		var base := _albedo(m)
		var target := Color(c) * (maxf(base.get_luminance(), 0.05) / maxf(c.get_luminance(), 0.1))
		var out := Color(base.lerp(target, k), base.a)
		_set_albedo(m, out)
		var em := _emission(m)
		if em.get_luminance() > 0.01:
			_set_emission(m, em.lerp(c, k))


## Makes the glowing parts (eyes, gems, crystals, staff tips) glow `c` at `energy`.
func _glow(mats: Array[Material], c: Color, energy: float) -> void:
	for m in mats:
		if not _is_glow(m):
			continue
		_set_albedo(m, Color(c.lerp(Color.WHITE, 0.25), 1.0))
		_set_emission(m, c)
		if m is StandardMaterial3D:
			(m as StandardMaterial3D).emission_enabled = true
			(m as StandardMaterial3D).emission_energy_multiplier = energy
		else:
			(m as ShaderMaterial).set_shader_parameter("emission_energy", energy)
			(m as ShaderMaterial).set_shader_parameter("emission", c)


## A second pass on every plate: a rim in the biome's accent and a band of it at about a third of the height.
func _rim(mats: Array[Material], accent: Color, height: float) -> void:
	for m in mats:
		if _is_glow(m):
			continue
		var p := ShaderMaterial.new()
		p.shader = FxTextures.shader(RIM)
		p.set_shader_parameter("rim_color", accent)
		p.set_shader_parameter("band_color", accent)
		p.set_shader_parameter("base_y", 0.0)
		p.set_shader_parameter("band_lo", height * 0.34)
		p.set_shader_parameter("band_hi", height * 0.46)
		(m as Material).next_pass = p


func _light(node: Node3D, c: Color, y: float, energy: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = 2.6
	l.position = Vector3(0, y, 0)
	l.shadow_enabled = false
	node.add_child(l)


## A rune ring (the Arc Caster's cast sigil, from the owner's fx_cast_sigils) lying flat above the head.
func _halo(node: Node3D, c: Color, y: float) -> void:
	var m := FxTextures.sigil_material(c, 1)
	if m == null:
		print("enemy_looks: fx_cast_sigils is not installed")
		return
	m.set_shader_parameter("alpha", 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = FxTextures.floor_quad(1.0)
	mi.material_override = m
	mi.position = Vector3(0, y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)


## A bright core at the chest and one spark orbiting the head (the pack's flare quads, camera-facing).
func _core(node: Node3D, c: Color, core_y: float, head_y: float) -> void:
	var core := FxTextures.flare_material(c, Color.WHITE, 0)
	if core == null:
		print("enemy_looks: fx_beam_impact is not installed")
		return
	_quad(node, core, 0.9, Vector3(0, core_y, 0))
	var spark := FxTextures.flare_material(c, Color.WHITE, 2)
	_quad(node, spark, 0.32, Vector3(0.55, head_y + 0.15, 0.2))
	_light(node, c, core_y, 1.6)


func _quad(node: Node3D, m: Material, size: float, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var q := FxTextures.flare_mesh()
	q.size = Vector2.ONE * size
	mi.mesh = q
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)


static func _albedo(m: Material) -> Color:
	if m is StandardMaterial3D:
		return (m as StandardMaterial3D).albedo_color
	return (m as ShaderMaterial).get_shader_parameter("albedo")


static func _set_albedo(m: Material, c: Color) -> void:
	if m is StandardMaterial3D:
		(m as StandardMaterial3D).albedo_color = c
	else:
		(m as ShaderMaterial).set_shader_parameter("albedo", c)


static func _emission(m: Material) -> Color:
	if m is StandardMaterial3D:
		return (
			(m as StandardMaterial3D).emission
			* (m as StandardMaterial3D).emission_energy_multiplier
		)
	var e = (m as ShaderMaterial).get_shader_parameter("emission")
	var en = (m as ShaderMaterial).get_shader_parameter("emission_energy")
	return (e if e is Color else Color.BLACK) * (float(en) if en != null else 0.0)


static func _set_emission(m: Material, c: Color) -> void:
	if m is StandardMaterial3D:
		(m as StandardMaterial3D).emission = c
	else:
		(m as ShaderMaterial).set_shader_parameter("emission", c)

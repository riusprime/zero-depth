class_name AscensionPortal
extends Node3D
## v0.7.5 AP (owner N4: "a feature like the blue portal but a new one … that fits the word ascension"): the Ascension
## portal, on a run's last floor of a loop where the gate would stand (the sim's gate: the same footprint, the same
## opening; BossFlow.ascension). Its own look, in the shard style; the blue gate (PortalGate) is never restyled:
## - a crystal spire behind the opening (it fills the gate's solid footprint): a tall gold-white cluster flanked by
##   two lavender obelisks, on a hexagonal dais of pale stone in front;
## - the column: a tall additive shaft of light rising from the dais where the hero walks in, golden white at its
##   core, lavender at its edges, with bands of light climbing it, a thin bright core inside, motes rising and
##   fragments circling its top;
## - dormant while the boss lives (the shards dim, no column); when the sim's portal opens the column rises from the
##   dais over RISE_SECONDS with a flare (reduced motion: it is there at once, no flare).
## Presentation only (EI-07): it reads nothing from the sim and decides nothing; WorldViewRoot unseals it when the
## portal opens, PortalTransitView flares it when the hero goes in. Its clock (rise, bands, orbit) is the
## presentation's (never an outcome, EI-03).
##
## Local frame (PortalGate's): the opening spans local Z, the portal faces local +X; setup() turns +X to the sim
## facing angle. Nothing solid stands in front of the wall line below the column's top, so the walk-in stays clear.

## The column's colours: the core's golden white and the edge's lavender (apart from the visor blue and Deep's violet
## and red at a glance: warm and pale, not saturated).
const GOLD := Color("#FFD98A")
const CORE := Color("#FFF6E0")
const LAVENDER := Color("#B79BFF")
const DAIS := Color("#CFC6D8")
const DAIS_TOP := Color("#E6DEEC")
## The column: radius at its foot and top (m), height (m), centre in front of the wall line (local x, m).
const COLUMN_X := 1.0
const COLUMN_R := 1.05
const COLUMN_TOP_R := 0.85
const COLUMN_H := 11.0
const CORE_R := 0.32
## Seconds the column takes to rise once the portal opens.
const RISE_SECONDS := 1.4
const LIGHT_SEALED := 0.5
const LIGHT_OPEN := 2.8
const FLARE_ENERGY := 6.0
const FLARE_SECONDS := 1.2
const SHARD_SEALED := 0.3
const SHARD_OPEN := 1.0
## Fragments circling the column's top: count, radius (m), height (m), turns per second.
const ORBIT_COUNT := 5
const ORBIT_R := 1.55
const ORBIT_Y := 3.6
const ORBIT_SPEED := 0.12

const COLUMN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform vec4 edge_color : source_color = vec4(0.72, 0.61, 1.0, 1.0);
uniform float strength = 1.0;
uniform float climb = 0.9;

void fragment() {
	// h: 0 at the foot, 1 at the top. Bright at the foot, gone well before the top; brighter at the silhouette.
	float h = 1.0 - UV.y;
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	float fade = (1.0 - smoothstep(0.35, 1.0, h)) * smoothstep(0.0, 0.03, h);
	// Bands of light climbing the shaft, twisted a little around it.
	float bands = 0.5 + 0.5 * sin((h * 9.0 - TIME * climb) * 6.2832 + UV.x * 12.566);
	float streak = smoothstep(0.6, 1.0, bands);
	vec3 col = mix(core_color.rgb, edge_color.rgb, clamp(rim * 1.4, 0.0, 1.0));
	ALBEDO = col * strength * fade * (0.28 + 0.7 * rim + 0.55 * streak);
}
"""

var column: MeshInstance3D
var core: MeshInstance3D
var column_material: ShaderMaterial
var core_material: ShaderMaterial
var light: OmniLight3D
var motes := CPUParticles3D.new()
var shard_material: StandardMaterial3D
var obelisk_material: StandardMaterial3D
var fragments: Array[Node3D] = []
var glow: MeshInstance3D
## v0.8.0 P2 (owner O28): its name over it once open ("Ascension"), as the Loop device's beside it.
var label := Label3D.new()
## Reduced motion (ViewPrefs, read at setup): the column appears at once, no flare.
var calm := false
## 0..1: how far the column has risen (tests read it).
var rise := 0.0
var _sealed := true
var _flare := 0.0
var _t := 0.0


func _init() -> void:
	name = "AscensionPortal"
	_build_dais()
	_build_spire()
	_build_column()
	_build_motes()
	_build_fragments()
	_build_label()
	set_sealed(true)


## Places the portal at `sim_pos` facing the sim direction `facing_angle` (1/4096 turn), as PortalGate.setup.
func setup(sim_pos: Vector2, facing_angle: int) -> void:
	position = SimPlane.to_3d(sim_pos)
	rotation = Vector3(0, SimPlane.yaw_of(facing_angle), 0)
	calm = ViewPrefs.reduced_motion


func set_sealed(sealed: bool) -> void:
	if _sealed and not sealed and is_inside_tree() and not calm:
		_flare = FLARE_SECONDS
	_sealed = sealed
	if sealed:
		rise = 0.0
	elif calm or not is_inside_tree():
		rise = 1.0
	motes.emitting = not sealed
	label.visible = not sealed
	_apply()


func is_sealed() -> bool:
	return _sealed


## A flare of light (the hero going in: PortalTransitView).
func flare() -> void:
	if not calm:
		_flare = FLARE_SECONDS


## The colour the hero's way in flashes (PortalTransitView).
static func flash_color() -> Color:
	return GOLD


func _process(delta: float) -> void:
	_t += delta
	if not _sealed and rise < 1.0:
		rise = minf(1.0, rise + delta / RISE_SECONDS)
	if _flare > 0.0:
		_flare = maxf(0.0, _flare - delta)
	_apply()
	for k in fragments.size():
		var a := TAU * (float(k) / ORBIT_COUNT + _t * ORBIT_SPEED)
		var f := fragments[k]
		var y: float = ORBIT_Y + 0.25 * sin(_t * 1.3 + k * 1.9)
		f.position = Vector3(COLUMN_X + cos(a) * ORBIT_R, y * maxf(rise, 0.35), sin(a) * ORBIT_R)
		f.rotation.y += delta * 0.8
		f.visible = rise > 0.05


## The look for the state now: the column's height and brightness, the light, the shards' glow.
func _apply() -> void:
	var k := _flare / FLARE_SECONDS
	var up := smoothstep(0.0, 1.0, rise)
	column.visible = up > 0.001
	core.visible = column.visible
	column.scale = Vector3(1.0, maxf(up, 0.001), 1.0)
	column.position.y = COLUMN_H * 0.5 * up
	core.scale = column.scale
	core.position.y = column.position.y
	column_material.set_shader_parameter("strength", 0.8 + 1.6 * k * k)
	core_material.set_shader_parameter("strength", 1.1 + 2.0 * k * k)
	light.light_energy = (
		(LIGHT_SEALED if _sealed else LIGHT_OPEN * (0.3 + 0.7 * up)) + FLARE_ENERGY * k * k
	)
	var e := SHARD_SEALED if _sealed else SHARD_OPEN
	shard_material.emission_energy_multiplier = e + 0.8 * k * k
	obelisk_material.emission_energy_multiplier = e * 0.8 + 0.6 * k * k
	var m := glow.material_override as StandardMaterial3D
	m.albedo_color.a = (0.18 if _sealed else 0.42) + 0.3 * k * k


## A pale hexagonal dais in front of the wall line (where the hero walks in) and a step behind it.
func _build_dais() -> void:
	var top := CylinderMesh.new()
	top.radial_segments = 6
	top.rings = 1
	top.top_radius = 1.75
	top.bottom_radius = 1.9
	top.height = 0.16
	var stone := StandardMaterial3D.new()
	stone.albedo_color = DAIS
	stone.roughness = 0.85
	var slab := MeshInstance3D.new()
	slab.name = "Dais"
	slab.mesh = top
	slab.material_override = stone
	slab.position = Vector3(COLUMN_X, 0.08, 0)
	slab.rotation.y = PI / 6.0
	add_child(slab)
	var inlay := CylinderMesh.new()
	inlay.radial_segments = 6
	inlay.rings = 1
	inlay.top_radius = 1.25
	inlay.bottom_radius = 1.25
	inlay.height = 0.04
	var inlay_mat := StandardMaterial3D.new()
	inlay_mat.albedo_color = DAIS_TOP
	inlay_mat.roughness = 0.5
	inlay_mat.emission_enabled = true
	inlay_mat.emission = GOLD
	inlay_mat.emission_energy_multiplier = 0.25
	var ring := MeshInstance3D.new()
	ring.name = "DaisInlay"
	ring.mesh = inlay
	ring.material_override = inlay_mat
	ring.position = Vector3(COLUMN_X, 0.18, 0)
	ring.rotation.y = PI / 6.0
	add_child(ring)
	glow = ShardMesh.glow(GOLD, 4.2, 0.18)
	glow.name = "DaisGlow"
	glow.position = Vector3(COLUMN_X, 0.4, 0)
	add_child(glow)


## The spire behind the opening (over the gate's solid footprint): a tall gold-white cluster and two lavender
## obelisks at the footprint's ends.
func _build_spire() -> void:
	shard_material = ShardMesh.crystal_material(CORE.lerp(GOLD, 0.4), SHARD_SEALED)
	obelisk_material = ShardMesh.crystal_material(LAVENDER, SHARD_SEALED)
	var back := ShardMesh.cluster(shard_material, 9, 3.6, 0.75, 41)
	back.name = "AscensionSpire"
	back.position = Vector3(-0.3, 0.0, 0.0)
	add_child(back)
	for side in [-1.0, 1.0]:
		var salt := 53 if side < 0.0 else 59
		var ob := ShardMesh.outlined(
			ShardMesh.crystal(6, 0.3, 2.7, 0.28, salt), obelisk_material, Vector3(0, 1.2, 0)
		)
		ob.name = "AscensionObelisk"
		ob.position = Vector3(0.0, 0.0, side * 1.55)
		ob.rotation = Vector3(0, salt * 0.3, side * 0.06)
		add_child(ob)
		var small := ShardMesh.cluster(obelisk_material, 4, 1.0, 0.45, salt + 7)
		small.name = "AscensionShards"
		small.position = Vector3(0.1, 0.0, side * 2.05)
		add_child(small)


func _build_column() -> void:
	column_material = _column_material(CORE, LAVENDER, 0.9)
	core_material = _column_material(Color.WHITE, GOLD, 1.4)
	column = _shaft("AscensionColumn", COLUMN_R, COLUMN_TOP_R, column_material)
	core = _shaft("AscensionCore", CORE_R, CORE_R * 0.7, core_material)
	light = OmniLight3D.new()
	light.light_color = CORE.lerp(GOLD, 0.5)
	light.omni_range = 7.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.position = Vector3(COLUMN_X, 1.6, 0)
	add_child(light)


func _column_material(c_core: Color, c_edge: Color, climb: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = COLUMN_SHADER
	m.set_shader_parameter("core_color", c_core)
	m.set_shader_parameter("edge_color", c_edge)
	m.set_shader_parameter("climb", climb)
	return m


func _shaft(node_name: String, r0: float, r1: float, mat: Material) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = r0
	cyl.top_radius = r1
	cyl.height = COLUMN_H
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var n := MeshInstance3D.new()
	n.name = node_name
	n.mesh = cyl
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.position = Vector3(COLUMN_X, COLUMN_H * 0.5, 0)
	add_child(n)
	return n


## Gold motes rising up the column while it is open (one small CPU emitter, presentation clock).
func _build_motes() -> void:
	motes.name = "AscensionMotes"
	motes.amount = 26
	motes.lifetime = 2.4
	motes.emitting = false
	motes.local_coords = true
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 0.9
	motes.direction = Vector3.UP
	motes.spread = 12.0
	motes.gravity = Vector3(0, 1.2, 0)
	motes.initial_velocity_min = 0.6
	motes.initial_velocity_max = 1.4
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.0
	var q := SphereMesh.new()
	q.radius = 0.05
	q.height = 0.1
	q.radial_segments = 6
	q.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = CORE
	m.emission_enabled = true
	m.emission = GOLD
	m.emission_energy_multiplier = 2.0
	q.material = m
	motes.mesh = q
	motes.position = Vector3(COLUMN_X, 0.4, 0)
	add_child(motes)


func _build_fragments() -> void:
	for k in ORBIT_COUNT:
		var mat := shard_material if k % 2 == 0 else obelisk_material
		var piece := ShardMesh.fragment(mat, 0.09 + 0.02 * (k % 3), 90 + k)
		piece.name = "AscensionFragment"
		piece.visible = false
		add_child(piece)
		fragments.append(piece)


## v0.8.0 P2: the name over the dais, facing the camera.
func _build_label() -> void:
	label.name = "Name"
	label.text = tr("WORLD_ASCENSION_NAME")
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 56
	label.pixel_size = 0.006
	label.outline_size = 10
	label.modulate = GOLD
	label.no_depth_test = true
	label.position = Vector3(COLUMN_X + 1.6, 4.6, 0)  # in front of the column, over the spire
	add_child(label)

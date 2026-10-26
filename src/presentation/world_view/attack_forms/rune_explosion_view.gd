class_name RuneExplosionView
extends Node3D
## v0.9.5 FC0 (owner: "a violet explosion that comes out of the player as an energy kind like shield that grown, just
## like a mage from world of warcraft"; FORM_COMBOS.md R0): the Rune Explosion's look. Each burst the sim has
## (WorldReader.rune_bursts: where the hero is, the edge radius now, its age) is drawn as
## - a translucent violet dome shell, a low hemisphere (height DOME_H of its radius) that grows with the sim's edge,
##   bright at its rim (blend_mix, alpha at most DOME_ALPHA_MAX);
## - on the floor, a flat ring quad whose bright band sits at the expanding edge and carries a strip of runes (12
##   angular glyphs drawn into an ImageTexture once, cached, repeated round the ring), with a soft inner glow behind
##   it (blend_add; the quad is masked to the ring's disc, so no square shows);
## - a small violet flash on each enemy it hits (HeroFx.flash into the effects layer).
## Colours: core #9B5CFF, rim #D9C2FF. It fades over the last 30 % of the growth and FADE ticks after. Effects density
## Low drops the inner glow and the flash's sparks; Reduced motion draws no dome and no shimmer (just the floor ring).
## All shaders are unshaded with fog_disabled. Pooled (BURSTS_MAX). Presentation only (EI-07): the sim decides the
## radius and the hits; this reads them.

const BURSTS_MAX := 6
## v0.9.5 FC5: the cards' floor rings (a held Ring, a shrinking shield, a trap, an Echo glyph) and Split's shards.
const EXTRAS_MAX := 12
const SHARDS_MAX := 24
const SHARD_SIZE := 0.14
const TRAP_FADE := 0.7
const GLYPH_FADE := 0.45
const DOME_H := 0.45
const DOME_ALPHA_MAX := 0.35
## The rune band's depth behind the edge (m), and the floor lift.
const BAND_M := 0.55
const LIFT := 0.03
const FLASH_TICKS := 8.0
const GLYPH_PX := 64
const GLYPH_REPEAT := 3.0
const CORE := Color("9B5CFF")
const RIM := Color("D9C2FF")

const DOME_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 core : source_color = vec4(0.608, 0.361, 1.0, 1.0);
uniform vec4 rim : source_color = vec4(0.851, 0.761, 1.0, 1.0);
uniform float fade = 1.0;
void fragment() {
	float f = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	ALBEDO = mix(core.rgb, rim.rgb, f);
	ALPHA = clamp((0.10 + 0.25 * f) * fade, 0.0, 0.35);
}
"""
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 core : source_color = vec4(0.608, 0.361, 1.0, 1.0);
uniform vec4 rim : source_color = vec4(0.851, 0.761, 1.0, 1.0);
uniform sampler2D runes : source_color, filter_linear, repeat_enable;
uniform float edge_f = 0.8;
uniform float band_f = 0.15;
uniform float fade = 1.0;
uniform float glow = 1.0;
uniform float motion = 1.0;
uniform float repeat_n = 3.0;
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float inner = edge_f - band_f;
	float inside = 1.0 - smoothstep(edge_f, edge_f + 0.02, r);
	float v = clamp((r - inner) / max(band_f, 0.001), 0.0, 1.0);
	float u = atan(d.y, d.x) / 6.2831853 + 0.5;
	float glyph = texture(runes, vec2(u * repeat_n, 1.0 - v)).r;
	float in_band = step(inner, r) * inside;
	float shimmer = 1.0 - 0.15 * motion + 0.15 * motion * sin(TIME * 9.0 + u * 40.0);
	float lip = exp(-pow((edge_f - r) * 38.0, 2.0)) * inside;
	float trail = exp(-max(edge_f - r, 0.0) * 9.0) * inside * smoothstep(0.0, 0.1, r) * 0.30;
	float fill = pow(clamp(1.0 - r / max(edge_f, 0.001), 0.0, 1.0), 1.6) * 0.20 * glow;
	vec3 col = core.rgb * (trail + fill) + rim.rgb * (lip * 1.1 + glyph * in_band * 1.2 * shimmer);
	float a = clamp((trail + fill + lip + glyph * in_band) * fade * inside, 0.0, 1.0);
	ALBEDO = col;
	ALPHA = a;
}
"""

## The glyphs: line segments (x0, y0, x1, y1) in a unit box, y down. Simple angular runes.
const GLYPHS: Array = [
	[[0.3, 0.1, 0.3, 0.9], [0.3, 0.4, 0.7, 0.2], [0.3, 0.6, 0.7, 0.4]],
	[[0.3, 0.1, 0.3, 0.9], [0.3, 0.1, 0.7, 0.3], [0.7, 0.3, 0.7, 0.9]],
	[[0.3, 0.1, 0.3, 0.9], [0.3, 0.3, 0.7, 0.5], [0.7, 0.5, 0.3, 0.7]],
	[[0.3, 0.1, 0.3, 0.9], [0.3, 0.15, 0.7, 0.35], [0.3, 0.4, 0.7, 0.6]],
	[[0.3, 0.1, 0.3, 0.9], [0.3, 0.1, 0.7, 0.3], [0.7, 0.3, 0.3, 0.55], [0.3, 0.55, 0.7, 0.9]],
	[[0.7, 0.15, 0.3, 0.5], [0.3, 0.5, 0.7, 0.85]],
	[[0.25, 0.15, 0.75, 0.85], [0.75, 0.15, 0.25, 0.85]],
	[[0.3, 0.1, 0.3, 0.9], [0.3, 0.1, 0.7, 0.3], [0.7, 0.3, 0.3, 0.5]],
	[[0.3, 0.1, 0.3, 0.9], [0.7, 0.1, 0.7, 0.9], [0.3, 0.45, 0.7, 0.55]],
	[[0.5, 0.1, 0.5, 0.9], [0.25, 0.35, 0.75, 0.6]],
	[[0.5, 0.1, 0.5, 0.9], [0.5, 0.5, 0.8, 0.7]],
	[[0.5, 0.1, 0.8, 0.5], [0.8, 0.5, 0.5, 0.9], [0.5, 0.9, 0.2, 0.5], [0.2, 0.5, 0.5, 0.1]],
]

static var _dome_shader: Shader = null
static var _ring_shader: Shader = null
static var _glyph_tex: ImageTexture = null

## What the last sync showed (tests read them): the bursts drawn, each one's edge radius (m) and fade (0..1), and
## whether the domes are shown (not with Reduced motion).
var bursts := 0
var edges: Array[float] = []
var fades: Array[float] = []
var domes_shown := false
## v0.9.5 FC5: the card rings and shards drawn now (the sim's RuneMods.read).
var extras := 0
var shards := 0

var _domes: Array[MeshInstance3D] = []
var _dome_mat: Array[ShaderMaterial] = []
var _rings: Array[MeshInstance3D] = []
var _ring_mat: Array[ShaderMaterial] = []
var _x_rings: Array[MeshInstance3D] = []
var _x_mat: Array[ShaderMaterial] = []
var _shard_nodes: Array[MeshInstance3D] = []
## The enemies already flashed (burst uid * 1000003 + actor id) and the flashes alive (place, tick).
var _flashed := {}
var _flash_at: Array[Vector3] = []
var _flash_tick: PackedFloat32Array = PackedFloat32Array()
var _tick := 0.0


func _init() -> void:
	name = "RuneExplosionView"
	if _dome_shader == null:
		_dome_shader = Shader.new()
		_dome_shader.code = DOME_SHADER
		_ring_shader = Shader.new()
		_ring_shader.code = RING_SHADER
	var hemi := SphereMesh.new()
	hemi.radius = 1.0
	hemi.height = 1.0
	hemi.is_hemisphere = true
	hemi.radial_segments = 40
	hemi.rings = 10
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	var tex := glyph_texture()
	for k in BURSTS_MAX:
		var dm := ShaderMaterial.new()
		dm.shader = _dome_shader
		var d := MeshInstance3D.new()
		d.mesh = hemi
		d.material_override = dm
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.visible = false
		add_child(d)
		_domes.append(d)
		_dome_mat.append(dm)
		var rm := ShaderMaterial.new()
		rm.shader = _ring_shader
		rm.set_shader_parameter(&"runes", tex)
		rm.set_shader_parameter(&"repeat_n", GLYPH_REPEAT)
		var g := MeshInstance3D.new()
		g.mesh = plane
		g.material_override = rm
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visible = false
		add_child(g)
		_rings.append(g)
		_ring_mat.append(rm)
	for k in EXTRAS_MAX:  # v0.9.5 FC5: the cards' floor rings, the same rune ring
		var xm := ShaderMaterial.new()
		xm.shader = _ring_shader
		xm.set_shader_parameter(&"runes", tex)
		xm.set_shader_parameter(&"repeat_n", GLYPH_REPEAT)
		var x := MeshInstance3D.new()
		x.mesh = plane
		x.material_override = xm
		x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		x.visible = false
		add_child(x)
		_x_rings.append(x)
		_x_mat.append(xm)
	var shard := SphereMesh.new()
	shard.radius = SHARD_SIZE
	shard.height = SHARD_SIZE * 2.0
	shard.radial_segments = 8
	shard.rings = 4
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = RIM
	sm.emission_enabled = true
	sm.emission = CORE
	sm.disable_fog = true
	for k in SHARDS_MAX:  # Split's rune shards
		var sh := MeshInstance3D.new()
		sh.mesh = shard
		sh.material_override = sm
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sh.visible = false
		add_child(sh)
		_shard_nodes.append(sh)


## The rune strip: GLYPHS drawn into one image (12 cells of GLYPH_PX), made once and cached.
static func glyph_texture() -> ImageTexture:
	if _glyph_tex != null:
		return _glyph_tex
	var n := GLYPHS.size()
	var img := Image.create(GLYPH_PX * n, GLYPH_PX, false, Image.FORMAT_L8)
	img.fill(Color(0, 0, 0))
	for c in n:
		for seg: Array in GLYPHS[c]:
			_stroke(img, c * GLYPH_PX, seg)
	_glyph_tex = ImageTexture.create_from_image(img)
	return _glyph_tex


static func _stroke(img: Image, ox: int, seg: Array) -> void:
	var a := Vector2(seg[0], seg[1]) * (GLYPH_PX - 1)
	var b := Vector2(seg[2], seg[3]) * (GLYPH_PX - 1)
	var steps := int(a.distance_to(b)) * 2 + 1
	for s in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if dx * dx + dy * dy > 5:
					continue
				var x := ox + int(p.x) + dx
				var y := int(p.y) + dy
				if x >= ox and x < ox + GLYPH_PX and y >= 0 and y < GLYPH_PX:
					img.set_pixel(x, y, Color(1, 1, 1))


## The burst's fade 0..1: full until 70 % of the growth, then down to nothing `fade` ticks after the growth ends.
static func fade_of(age: int, grow: int, fade: int) -> float:
	var start := 0.7 * grow
	var end := float(grow + fade)
	if age <= start:
		return 1.0
	return clampf(1.0 - (age - start) / maxf(1.0, end - start), 0.0, 1.0)


## Each tick: the bursts the sim has.
func sync(reader: WorldReader) -> void:
	_tick = float(reader.tick())
	var list: Array[Dictionary] = []
	if not reader.player_dead():
		list = reader.rune_bursts()
	bursts = mini(list.size(), BURSTS_MAX)
	edges.clear()
	fades.clear()
	domes_shown = not ViewPrefs.reduced_motion
	var low := ViewPrefs.effects_density == "low"
	var live := {}
	for k in BURSTS_MAX:
		_domes[k].visible = false
		_rings[k].visible = false
		if k >= bursts:
			continue
		var b: Dictionary = list[k]
		var edge := float(b["edge"])
		var fd := fade_of(int(b["age"]), int(b["grow"]), int(b["fade"]))
		edges.append(edge)
		fades.append(fd)
		var at := SimPlane.to_3d(b["pos"], LIFT)
		# The floor ring: a quad a little wider than the edge, the band inside it.
		var half := edge + 0.15
		var rm := _ring_mat[k]
		rm.set_shader_parameter(&"edge_f", edge / half)
		rm.set_shader_parameter(&"band_f", minf(BAND_M, edge) / half)
		rm.set_shader_parameter(&"fade", fd)
		rm.set_shader_parameter(&"glow", 0.0 if low else 1.0)
		rm.set_shader_parameter(&"motion", 0.0 if ViewPrefs.reduced_motion else 1.0)
		_rings[k].transform = Transform3D(Basis.IDENTITY.scaled(Vector3(half, 1.0, half)), at)
		_rings[k].visible = edge > 0.02
		# The dome: a low hemisphere over the edge (none with Reduced motion).
		if domes_shown and edge > 0.02:
			_dome_mat[k].set_shader_parameter(&"fade", fd)
			var basis := Basis.IDENTITY.scaled(Vector3(edge, DOME_H * edge, edge))
			_domes[k].transform = Transform3D(basis, at)
			_domes[k].visible = true
		# A flash on each enemy the edge just reached.
		var uid := int(b["uid"])
		live[uid] = true
		for foe: int in b["hits"]:
			var key := uid * 1000003 + foe
			if _flashed.has(key):
				continue
			_flashed[key] = uid
			var i := reader.actor_index(foe)
			if i >= 0:
				_flash_at.append(SimPlane.to_3d(reader.actor_pos(i), SimPlane.CORE_HEIGHT))
				_flash_tick.append(_tick)
	for key: int in _flashed.keys():  # a gone burst forgets its hits
		if not live.has(int(_flashed[key])):
			_flashed.erase(key)
	for j in range(_flash_at.size() - 1, -1, -1):
		if _tick - _flash_tick[j] > FLASH_TICKS:
			_flash_at.remove_at(j)
			_flash_tick.remove_at(j)
	_sync_cards(reader)


## v0.9.5 FC5: what the cards leave on the floor (WorldReader.rune_effects): a held Ring and a shrinking shield (the
## rune ring at the sim's radius), a trap (a small ring), an Echo glyph waiting (a dim ring at the burst point), and
## Split's shards (small violet beads).
func _sync_cards(reader: WorldReader) -> void:
	var fx: Dictionary = {} if reader.player_dead() else reader.rune_effects()
	extras = 0
	for key: String in ["holds", "shrinks", "mines", "glyphs"]:
		for row: Dictionary in fx.get(key, []):
			if extras >= EXTRAS_MAX:
				break
			var r := float(row["radius"])
			var life := maxf(1.0, float(row["life"]))
			var fd := 1.0
			match key:
				"holds":
					fd = clampf(1.0 - float(row["age"]) / life, 0.0, 1.0) * 0.8 + 0.2
				"shrinks":
					fd = 0.8
				"mines":
					fd = TRAP_FADE
				"glyphs":
					fd = GLYPH_FADE
			var half := r + 0.15
			var xm := _x_mat[extras]
			xm.set_shader_parameter(&"edge_f", r / half)
			xm.set_shader_parameter(&"band_f", minf(BAND_M, r) / half)
			xm.set_shader_parameter(&"fade", fd)
			xm.set_shader_parameter(&"glow", 0.0 if ViewPrefs.effects_density == "low" else 1.0)
			xm.set_shader_parameter(&"motion", 0.0 if ViewPrefs.reduced_motion else 1.0)
			_x_rings[extras].transform = Transform3D(
				Basis.IDENTITY.scaled(Vector3(half, 1.0, half)), SimPlane.to_3d(row["pos"], LIFT)
			)
			_x_rings[extras].visible = r > 0.02
			extras += 1
	for k in range(extras, EXTRAS_MAX):
		_x_rings[k].visible = false
	shards = 0
	for row: Dictionary in fx.get("shards", []):
		if shards >= SHARDS_MAX:
			break
		_shard_nodes[shards].transform = Transform3D(
			Basis.IDENTITY, SimPlane.to_3d(row["pos"], SimPlane.CORE_HEIGHT)
		)
		_shard_nodes[shards].visible = true
		shards += 1
	for k in range(shards, SHARDS_MAX):
		_shard_nodes[k].visible = false


## The effects layer's drawer (WorldViewRoot appends it): a small violet flash on each enemy hit.
func draw_fx(layer: VfxCore) -> void:
	var now := layer.now()
	for j in _flash_at.size():
		var u := (now - _flash_tick[j]) / FLASH_TICKS
		if u >= 0.0 and u < 1.0:
			var sparks := 1 if ViewPrefs.effects_density == "low" else 3
			HeroFx.flash(layer, _flash_at[j], RIM, CORE, u, 0.8, 7001 + j * 11, sparks, false)

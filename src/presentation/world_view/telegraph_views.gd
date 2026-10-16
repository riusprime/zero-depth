class_name TelegraphViews
extends Node3D
## Enemy attack telegraphs (PRESENTATION §4): the attack's area on the ground for its whole windup, drawn from
## WorldReader.telegraph() (the function that resolves the hit). A full-opacity outline, and a fill that grows
## from 0 to 100% so the player reads *when* as well as *where*. Unshaded, so no shadow hides it.
## The bosses' shapes (v0.3.0 C: ring, lanes, arc, discs, sweep, and the harmless ripple of a burrow) are drawn as
## flat triangles rebuilt each tick (ImmediateMesh) from the same dictionary the hit is resolved from.
## v0.3.5 AI: a telegraph with a "style" gets a mark on top of its shape: an Arc Caster's bolt a bright core line down
## each lane, its rune an inner ring with turning spokes, a Bomb Drone's bomb a cross-hair and the bomb itself flying
## from the drone ("from") to the circle's centre as the circle fills.
## v0.4.0 EN: a Sniper's line ("snipe") carries the bolt's bright core; a Shield Bearer's bash ("bash") two chevrons
## pointing down its lane; a Mine Layer's armed mines ("mine") a spiked star in each filling circle.
## v0.4.0 BO: a flood's standing lanes carry a style too: the Warlord's spears a row of spear heads down each lane,
## the Foundry's molten floor a hot core with cross bars (a fixed colour; nothing toggles emission at run time).
## v0.7.5 BF1 (owner N15, "Track, then lock 0.8 s"): a telegraph with "tracked" is drawn as a dull red outline (no
## fill) while it follows the player, and once "locked" as a bright filled flash that pulses until it strikes (steady
## with reduced motion). &"marks" draws each of its markers (circles, or a row and a column of lanes) in its own state.
## v0.7.5 EF (owner N16: "the ones that change don't have the trayectory drawn in the ground anymore"): a telegraph
## with "ground": false (the Arc Caster's, Lens Drone's and Bomb Drone's fireball windups and lobs) is not drawn here.
## v0.8.0 TG (owner O4, Q3): nor are the melee kinds' lanes and discs, the Sniper's line ("snipe"), the Shield
## Bearer's bash ("bash") or the Needle's lanes; their avatars tell the windup. Among normal enemies only the Arc
## Caster's rune and the Mine Layer's mines reach this view; the bosses' markers are unchanged.
## v0.8.0 AV (owner O7): the Gatekeeper's shock lanes (a `row_lanes` marks telegraph) are drawn as cracked ground
## instead of flat red: while they track the player, thin cracks glowing dimly along each lane (the dark outline kept);
## once locked, the ground chars and the cracks widen and glow hot, pulsing until the strike (steady with reduced
## motion), under the bright edge (the dodge cue). The strike itself is StoneSpikeViews' spikes.
## v0.8.0 FB3: a &"marks" item may be an &"arc" too (a Nemesis card's swing beside its volley's lines and its blast).
## v0.8.0 AV part 2 (owner O7): every other boss ground attack with a look (BossStrikeLooks: per boss kind and move)
## fills with its own ground pattern instead of flat red: stone cracks, steel scratches, bubbling acid, shimmering
## light, hazard stripes, molten seams. While it tracks it keeps the dull outline and no fill; once locked the pattern
## burns hot and pulses (steady with reduced motion) under the same bright edge, so the lock flash stays the dodge
## cue; an untracked windup's fill grows in the pattern, warming as it fills. The strike is BossStrikeViews'.

## Shapes drawn as rebuilt meshes (BossAi.telegraph).
const MESH_SHAPES: Array[StringName] = [
	&"ring", &"lanes", &"arc", &"discs", &"sweep", &"ripple", &"marks"
]
## v0.7.5 BF1: the lock flash's pulse (per second) and its fill's alpha range.
const FLASH_HZ := 7.0
const FLASH_ALPHA := Vector2(0.45, 0.8)
const ARC_STEPS := 40

const Y := 0.035
const EDGE := 0.06
## v0.8.0 AV: the cracked-ground marker's heat while tracking, and its pulse range once locked.
const CRACK_TRACK_HEAT := 0.2
const CRACK_LOCK_HEAT := Vector2(0.7, 1.0)
const CRACK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 hot : source_color = vec4(1.0, 0.42, 0.18, 1.0);
uniform vec4 char_color : source_color = vec4(0.08, 0.05, 0.04, 1.0);
uniform float heat = 0.2;
uniform float char_alpha = 0.0;
uniform float scale = 1.4;
uniform sampler2D cracks_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float cracks_on = 0.0;

varying vec3 wp;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz * scale;
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float d = length(g + hash2(i + g) - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float w = mix(0.05, 0.14, heat);
	float crack = 1.0 - smoothstep(w * 0.35, w, d2 - d1);
	if (cracks_on > 0.5) {  // v0.8.0 TX2: the owner's cracks (fx_ground_cracks' shape, the hot colour kept)
		vec4 k = texture(cracks_tex, wp.xz * 0.18);
		crack = k.a * mix(0.55, 1.0, heat) + k.a * k.g * heat * 0.5;
	}
	ALBEDO = mix(char_color.rgb, hot.rgb * (1.0 + heat * 1.6), clamp(crack, 0.0, 1.0));
	ALPHA = clamp(max(char_alpha, crack * mix(0.5, 1.0, heat)), 0.0, 1.0);
}
"""

var _nodes := {}
var _fill_mat := StandardMaterial3D.new()
var _edge_mat := StandardMaterial3D.new()
var _core_mat := StandardMaterial3D.new()
var _bomb_mat := StandardMaterial3D.new()
var _molten_mat := StandardMaterial3D.new()
## v0.7.5 BF1: a tracking marker's dull outline, a locked one's bright fill and edge.
var _dull_mat := StandardMaterial3D.new()
var _flash_fill_mat := StandardMaterial3D.new()
var _flash_edge_mat := StandardMaterial3D.new()
## v0.8.0 AV: the shock lanes' cracked ground, tracking and locked.
var _crack_track_mat := ShaderMaterial.new()
var _crack_lock_mat := ShaderMaterial.new()
## v0.8.0 AV part 2: per look, [the windup fill, the lock flash] (BossStrikeLooks.mark_material).
var _look_mats := {}
## The look of the telegraph being updated (&"" for none: the flat look).
var _look := &""
var _t := 0.0


func _ready() -> void:
	var c := ThemePalette.color(&"telegraph_hostile")
	for m: StandardMaterial3D in [_fill_mat, _edge_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = c
	_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_mat.albedo_color = Color(c, 0.45)
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_core_mat.albedo_color = ThemePalette.color(&"proj_hostile")
	_molten_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_molten_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_molten_mat.albedo_color = Color("#FF8A2E")
	_bomb_mat.albedo_color = Color("#1B1C20")
	_bomb_mat.emission_enabled = true
	_bomb_mat.emission = c
	_bomb_mat.emission_energy_multiplier = 0.6
	for m: StandardMaterial3D in [_dull_mat, _flash_fill_mat, _flash_edge_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dull_mat.albedo_color = Color(c.darkened(0.45), 0.85)
	_flash_fill_mat.albedo_color = Color(c.lightened(0.15), FLASH_ALPHA.y)
	_flash_edge_mat.albedo_color = Color(c.lightened(0.55), 1.0)
	var crack := Shader.new()
	crack.code = CRACK_SHADER
	var cracks := BossStrikeMeshes.texture("fx_ground_cracks")  # v0.8.0 TX2
	for m: ShaderMaterial in [_crack_track_mat, _crack_lock_mat]:
		m.shader = crack
		m.set_shader_parameter("cracks_tex", cracks)
		m.set_shader_parameter("cracks_on", 1.0 if cracks != null else 0.0)
	_crack_track_mat.set_shader_parameter("heat", CRACK_TRACK_HEAT)
	_crack_lock_mat.set_shader_parameter("heat", CRACK_LOCK_HEAT.y)
	_crack_lock_mat.set_shader_parameter("char_alpha", 0.4)


func _process(delta: float) -> void:
	_t += delta
	var a := FLASH_ALPHA.y
	var heat := CRACK_LOCK_HEAT.y
	if not ViewPrefs.reduced_motion:
		var wave := 0.5 + 0.5 * cos(_t * TAU * FLASH_HZ)
		a = lerpf(FLASH_ALPHA.x, FLASH_ALPHA.y, wave)
		heat = lerpf(CRACK_LOCK_HEAT.x, CRACK_LOCK_HEAT.y, wave)
	_flash_fill_mat.albedo_color.a = a
	_crack_lock_mat.set_shader_parameter("heat", heat)
	var motion := 0.0 if ViewPrefs.reduced_motion else 1.0
	for pair: Array in _look_mats.values():
		(pair[1] as ShaderMaterial).set_shader_parameter("heat", heat)
		for m: ShaderMaterial in pair:
			m.set_shader_parameter("motion", motion)


## v0.7.5 BF1: [fill, edge] materials for a telegraph: a tracking one has no fill and the dull edge, a locked one
## the flash; any other the usual pair.
func _mats(tg: Dictionary) -> Array:
	if not tg.get("tracked", false):
		return [_fill_mat if _look == &"" else _look_pair(_look)[0], _edge_mat]
	if tg.get("locked", false):
		return [_flash_fill_mat if _look == &"" else _look_pair(_look)[1], _flash_edge_mat]
	return [null, _dull_mat]


## v0.8.0 AV part 2: [windup fill, lock flash] of `look`, made on first use.
func _look_pair(look: StringName) -> Array:
	if not _look_mats.has(look):
		_look_mats[look] = [
			BossStrikeLooks.mark_material(look, 0.3, 0.25),
			BossStrikeLooks.mark_material(look, CRACK_LOCK_HEAT.y, 0.45)
		]
	return _look_mats[look]


## v0.8.0 AV part 2: the look of actor i's telegraph `tg` (a boss's ground attack with a look), else &"".
static func look_of(reader: WorldReader, i: int, tg: Dictionary) -> StringName:
	var kind := reader.actor_kind(i)
	if not WorldReader.is_boss_kind(kind):
		return &""
	return BossStrikeLooks.look_for(kind, int(tg.get("move", -1)))


func sync(reader: WorldReader) -> void:
	var seen := {}
	for i in reader.actor_count():
		var tg := reader.telegraph(i)
		if tg.is_empty() or not tg.get("ground", true):
			continue  # v0.7.5 EF: a body or air cue ("cast", "lob") draws nothing on the ground
		var id := reader.actor_id(i)
		seen[id] = true
		var n: Node3D = _nodes.get(id)
		var style: StringName = tg.get("style", &"")
		if n == null or n.get_meta(&"shape") != tg["shape"] or n.get_meta(&"style") != style:
			if n != null:
				n.queue_free()
			n = _make(tg["shape"], style)
			_nodes[id] = n
			add_child(n)
		_look = look_of(reader, i, tg)
		_update(n, tg)
		if _look != &"" and not tg.get("tracked", false):  # a windup's fill warms as it fills
			var heat := lerpf(0.15, 0.85, float(tg["progress"]) / 1000.0)
			(_look_pair(_look)[0] as ShaderMaterial).set_shader_parameter("heat", heat)
		if style != &"":
			_update_style(n, tg)
	_look = &""
	for id in _nodes.keys():
		if not seen.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)


## How many telegraphs are showing (tests and the tour).
func count() -> int:
	return _nodes.size()


func _make(shape: StringName, style: StringName = &"") -> Node3D:
	var root := _make_shape(shape)
	root.set_meta(&"style", style)
	if style == &"":
		return root
	var deco := MeshInstance3D.new()
	deco.name = "Deco"
	deco.mesh = ImmediateMesh.new()
	deco.top_level = true
	deco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(deco)
	if style == &"bomb":
		var bomb := MeshInstance3D.new()
		bomb.name = "Bomb"
		bomb.mesh = ArcCasterAvatar._octahedron(0.12)
		bomb.material_override = _bomb_mat
		bomb.top_level = true
		bomb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bomb)
	return root


func _make_shape(shape: StringName) -> Node3D:
	var root := Node3D.new()
	root.set_meta(&"shape", shape)
	if MESH_SHAPES.has(shape):
		for part in ["Fill", "Edge"]:
			var mi := MeshInstance3D.new()
			mi.name = part
			mi.mesh = ImmediateMesh.new()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		return root
	if shape == &"disc":
		var edge := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.rings = 48
		edge.mesh = torus
		edge.material_override = _edge_mat
		edge.name = "Edge"
		root.add_child(edge)
		var fill := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.height = 0.005
		cyl.top_radius = 1.0
		cyl.bottom_radius = 1.0
		cyl.radial_segments = 48
		fill.mesh = cyl
		fill.material_override = _fill_mat
		fill.name = "Fill"
		root.add_child(fill)
	else:
		for k in 4:
			var e := MeshInstance3D.new()
			e.mesh = BoxMesh.new()
			e.material_override = _edge_mat
			e.name = "Edge%d" % k
			root.add_child(e)
		var fill := MeshInstance3D.new()
		var q := BoxMesh.new()
		q.size = Vector3(1, 0.005, 1)
		fill.mesh = q
		fill.material_override = _fill_mat
		fill.name = "Fill"
		root.add_child(fill)
	for c in root.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


func _update(n: Node3D, tg: Dictionary) -> void:
	var p := float(tg["progress"]) / 1000.0
	if MESH_SHAPES.has(tg["shape"]):
		_update_mesh(n, tg, p)
		return
	var mats := _mats(tg)
	if tg.get("tracked", false):  # v0.7.5 BF1: no fill while tracking, a full flash once locked
		p = 1.0 if tg.get("locked", false) else 0.0
	for c in n.get_children():
		if c.name.begins_with("Edge"):
			(c as GeometryInstance3D).material_override = mats[1]
		elif c.name == "Fill":
			(c as GeometryInstance3D).material_override = mats[0] if mats[0] != null else _fill_mat
			(c as Node3D).visible = mats[0] != null
	if tg["shape"] == &"disc":
		var r: float = tg["radius"]
		n.position = SimPlane.to_3d(tg["center"], Y)
		var edge: MeshInstance3D = n.get_node("Edge")
		var torus: TorusMesh = edge.mesh
		torus.inner_radius = r - EDGE
		torus.outer_radius = r
		edge.scale = Vector3(1, 0.05, 1)
		var fill: Node3D = n.get_node("Fill")
		var fr := maxf(r * p, 0.01)
		fill.scale = Vector3(fr, 1, fr)
		return
	var box: Obb = tg["obb"]
	n.position = SimPlane.to_3d(box.center, Y)
	n.rotation = Vector3(0, SimPlane.yaw_of(box.angle), 0)
	var hx := box.half.x
	var hy := box.half.y
	var sides := [
		[Vector3(0, 0, -hy), Vector3(hx * 2.0, 0.01, EDGE)],
		[Vector3(0, 0, hy), Vector3(hx * 2.0, 0.01, EDGE)],
		[Vector3(-hx, 0, 0), Vector3(EDGE, 0.01, hy * 2.0)],
		[Vector3(hx, 0, 0), Vector3(EDGE, 0.01, hy * 2.0)],
	]
	for k in 4:
		var e: MeshInstance3D = n.get_node("Edge%d" % k)
		e.position = sides[k][0]
		(e.mesh as BoxMesh).size = sides[k][1]
	# The fill runs from the attacker's end (-x) toward the far end as the windup completes.
	var fill: Node3D = n.get_node("Fill")
	var len := maxf(hx * 2.0 * p, 0.01)
	fill.scale = Vector3(len, 1, hy * 2.0)
	fill.position = Vector3(-hx + len * 0.5, 0, 0)


# --- styles (v0.3.5 AI) ------------------------------------------------------------------------------------------


func _update_style(n: Node3D, tg: Dictionary) -> void:
	var deco: ImmediateMesh = (n.get_node("Deco") as MeshInstance3D).mesh
	deco.clear_surfaces()
	var p := float(tg["progress"]) / 1000.0
	var pts := []
	match tg["style"]:
		&"bolt", &"snipe":
			var lanes: Array = tg["obbs"] if tg.has("obbs") else [tg["obb"]]
			for o: Obb in lanes:
				var u := o.axis_u
				var side := o.axis_v * 0.035
				var a := o.center - u * o.half.x
				var b := o.center + u * o.half.x
				_quad(pts, a - side, b - side, b + side, a + side)
		&"rune":
			var c: Vector2 = tg["center"]
			var r: float = tg["radius"]
			_sector(pts, c, r * 0.6 - EDGE * 0.5, r * 0.6, 0.0, TAU)
			var turn := p * PI * 0.5
			for k in 6:
				var ang := turn + TAU * k / 6.0
				var d := Vector2(cos(ang), sin(ang))
				var sd := Vector2(-d.y, d.x) * EDGE * 0.4
				_quad(
					pts, c + d * r * 0.6 - sd, c + d * r - sd, c + d * r + sd, c + d * r * 0.6 + sd
				)
		&"bomb":
			var c: Vector2 = tg["center"]
			var r: float = tg["radius"]
			for d: Vector2 in [Vector2.RIGHT, Vector2.UP]:
				var sd := Vector2(-d.y, d.x) * EDGE * 0.4
				_quad(
					pts,
					c - d * r * 0.35 - sd,
					c + d * r * 0.35 - sd,
					c + d * r * 0.35 + sd,
					c - d * r * 0.35 + sd
				)
			# The bomb flies along an arc from the drone's hover to the circle's centre as the circle fills.
			var from: Vector2 = tg.get("from", c)
			var y := BombDroneAvatar.HOVER_Y * (1.0 - p) + 2.4 * p * (1.0 - p) + 0.12
			var bomb := n.get_node("Bomb") as Node3D
			bomb.global_position = SimPlane.to_3d(from.lerp(c, p), y)
			bomb.rotation = Vector3(p * 9.0, p * 5.0, 0)
		&"bash":
			var o: Obb = tg["obb"]
			for k in 2:
				var tip := o.center + o.axis_u * (o.half.x * (0.15 + 0.45 * k))
				var back := tip - o.axis_u * o.half.y * 0.8
				for sgn: float in [-1.0, 1.0]:
					var wing := back + o.axis_v * o.half.y * 0.7 * sgn
					var d := (tip - wing).normalized()
					var sd := Vector2(-d.y, d.x) * EDGE * 0.4
					_quad(pts, wing - sd, tip - sd, tip + sd, wing + sd)
		&"mine":
			var r: float = tg["radius"]
			for c: Vector2 in tg["centers"]:
				for k in 4:
					var ang := TAU * k / 8.0 + p * PI
					var d := Vector2(cos(ang), sin(ang))
					var sd := Vector2(-d.y, d.x) * EDGE * 0.4
					_quad(
						pts,
						c - d * r * 0.3 - sd,
						c + d * r * 0.3 - sd,
						c + d * r * 0.3 + sd,
						c - d * r * 0.3 + sd
					)
		&"spears", &"molten":
			for o: Obb in tg["obbs"]:
				_flood_marks(pts, o, tg["style"] == &"spears")
	var mat := _edge_mat
	if tg["style"] == &"bolt" or tg["style"] == &"snipe":
		mat = _core_mat
	elif tg["style"] == &"molten":
		mat = _molten_mat
	_emit(deco, pts, mat)


## v0.4.0 BO: a standing flood lane's marks: spear heads every SPEAR_STEP along it, or a molten core with bars.
func _flood_marks(pts: Array, o: Obb, spears: bool) -> void:
	var u := o.axis_u
	var v := o.axis_v
	var a := o.center - u * o.half.x
	var n := maxi(1, int(o.half.x * 2.0 / 0.7))
	if spears:
		for k in n:
			var c := a + u * (0.35 + 0.7 * k)
			var w := v * minf(o.half.y, 0.22)
			_quad(pts, c - u * 0.3, c - w, c + u * 0.3, c + w)
		return
	var side := v * o.half.y * 0.3
	_quad(pts, a - side, a + u * o.half.x * 2.0 - side, a + u * o.half.x * 2.0 + side, a + side)
	for k in n:
		var c := a + u * (0.35 + 0.7 * k)
		_quad(
			pts,
			c - u * 0.06 - v * o.half.y,
			c + u * 0.06 - v * o.half.y,
			c + u * 0.06 + v * o.half.y,
			c - u * 0.06 + v * o.half.y
		)


# --- boss shapes (v0.3.0 C) -------------------------------------------------------------------------------------


func _update_mesh(n: Node3D, tg: Dictionary, p: float) -> void:
	var fill: ImmediateMesh = (n.get_node("Fill") as MeshInstance3D).mesh
	var edge: ImmediateMesh = (n.get_node("Edge") as MeshInstance3D).mesh
	fill.clear_surfaces()
	edge.clear_surfaces()
	var ft := []
	var et := []
	var mats := _mats(tg)
	if tg.get("tracked", false):
		p = 1.0
	match tg["shape"]:
		&"marks":  # v0.7.5 BF1: each marker in its own state (dull while tracking, flashing once locked)
			_update_marks(n, tg)
			return
		&"ring":
			var c: Vector2 = tg["center"]
			var r0: float = tg["inner"]
			var r1: float = tg["outer"]
			_sector(ft, c, r0, r0 + (r1 - r0) * p, 0.0, TAU)
			_sector(et, c, r0, r0 + EDGE, 0.0, TAU)
			_sector(et, c, r1 - EDGE, r1, 0.0, TAU)
		&"lanes":
			for o: Obb in tg["obbs"]:
				_lane(ft, et, o, p)
		&"arc":
			var a := _rad(tg["angle"])
			var h := _rad(tg["half_arc"])
			_fan(ft, et, tg["center"], tg["own_r"], tg["own_r"] + tg["reach"], a - h, a + h, p)
		&"sweep":
			var a0 := _rad(tg["start"])
			var a1 := a0 + _rad(tg["span"])
			var c: Vector2 = tg["center"]
			var r0: float = tg["own_r"]
			var r1: float = r0 + float(tg["reach"])
			_fan(ft, et, c, r0, r1, minf(a0, a1), maxf(a0, a1), p)
			var b := _rad(tg["beam"])
			var d := Vector2(cos(b), sin(b))
			var side := Vector2(-d.y, d.x) * 0.12
			_quad(et, c + d * r0 - side, c + d * r1 - side, c + d * r1 + side, c + d * r0 + side)
		&"discs":
			for c: Vector2 in tg["centers"]:
				var r: float = tg["radius"]
				_sector(ft, c, 0.0, maxf(r * p, 0.01), 0.0, TAU)
				_sector(et, c, r - EDGE, r, 0.0, TAU)
		&"ripple":
			var c: Vector2 = tg["center"]
			var r: float = tg["radius"]
			for k in 3:
				var rr := r * (0.45 + 0.3 * k)
				_sector(et, c, rr - EDGE * 0.6, rr, 0.0, TAU)
	if mats[0] != null:
		_emit(fill, ft, mats[0])
	_emit(edge, et, mats[1])


## v0.7.5 BF1: a marks telegraph: the locked markers' flash in the fill mesh (and their bright edges), the tracking
## ones' dull outlines in the edge mesh.
func _update_marks(n: Node3D, tg: Dictionary) -> void:
	var fill: ImmediateMesh = (n.get_node("Fill") as MeshInstance3D).mesh
	var edge: ImmediateMesh = (n.get_node("Edge") as MeshInstance3D).mesh
	var flash_f := []
	var flash_e := []
	var dull := []
	var crack_lock := []
	var crack_track := []
	var cracked := is_cracked(tg)
	for item: Dictionary in tg["items"]:
		var locked: bool = item["locked"]
		var f := []
		var e := []
		if item["shape"] == &"disc":
			var c: Vector2 = item["center"]
			var r: float = item["radius"]
			_sector(f, c, 0.0, r, 0.0, TAU)
			_sector(e, c, r - EDGE, r, 0.0, TAU)
		elif item["shape"] == &"arc":  # v0.8.0 FB3: a card's swing (the Nemesis)
			var a := _rad(item["angle"])
			var h := _rad(item["half_arc"])
			var r0: float = item["own_r"]
			_fan(f, e, item["center"], r0, r0 + float(item["reach"]), a - h, a + h, 1.0)
		else:
			for o: Obb in item["obbs"]:
				_lane(f, e, o, 1.0)
		if cracked:  # v0.8.0 AV: the shock lanes crack the ground instead of a flat fill
			(crack_lock if locked else crack_track).append_array(f)
			(flash_e if locked else dull).append_array(e)
		elif locked:
			flash_f.append_array(f)
			flash_e.append_array(e)
		else:
			dull.append_array(e)
	_emit(fill, flash_f, _flash_fill_mat if _look == &"" else _look_pair(_look)[1])
	_emit(fill, crack_lock, _crack_lock_mat)
	_emit(fill, crack_track, _crack_track_mat)
	_emit(edge, flash_e, _flash_edge_mat)
	_emit(edge, dull, _dull_mat)


## v0.8.0 AV: a telegraph drawn as cracked ground (the Gatekeeper's shock lanes: a row_lanes marks telegraph).
static func is_cracked(tg: Dictionary) -> bool:
	return tg.get("shape", &"") == &"marks" and tg.get("move", -1) == WorldReader.MOVE_ROW_LANES


func _rad(units: int) -> float:
	return TAU * float(units) / 4096.0


## Triangles of an annular sector (sim plane) from radius r0 to r1, angles a0..a1 (radians).
func _sector(out: Array, c: Vector2, r0: float, r1: float, a0: float, a1: float) -> void:
	var steps := maxi(4, int(ceil(ARC_STEPS * absf(a1 - a0) / TAU)) + 4)
	for k in steps:
		var t0 := a0 + (a1 - a0) * k / steps
		var t1 := a0 + (a1 - a0) * (k + 1) / steps
		var d0 := Vector2(cos(t0), sin(t0))
		var d1 := Vector2(cos(t1), sin(t1))
		_quad(out, c + d0 * r0, c + d0 * r1, c + d1 * r1, c + d1 * r0)


## A sector fan: the fill grows outward from r0 with the windup, the outline is its two sides and both arcs.
func _fan(
	ft: Array, et: Array, c: Vector2, r0: float, r1: float, a0: float, a1: float, p: float
) -> void:
	_sector(ft, c, r0, r0 + maxf((r1 - r0) * p, 0.01), a0, a1)
	_sector(et, c, r1 - EDGE, r1, a0, a1)
	_sector(et, c, r0, r0 + EDGE, a0, a1)
	for a in [a0, a1]:
		var d := Vector2(cos(a), sin(a))
		var side := Vector2(-d.y, d.x) * EDGE * 0.5
		_quad(et, c + d * r0 - side, c + d * r1 - side, c + d * r1 + side, c + d * r0 + side)


## A lane: its outline, and a fill that runs from the attacker's end as the windup completes.
func _lane(ft: Array, et: Array, o: Obb, p: float) -> void:
	var u := o.axis_u
	var v := o.axis_v
	var hx := o.half.x
	var hy := o.half.y
	var back := o.center - u * hx
	var len := maxf(hx * 2.0 * p, 0.01)
	_quad(ft, back - v * hy, back + u * len - v * hy, back + u * len + v * hy, back + v * hy)
	var corners := [
		o.center - u * hx - v * hy,
		o.center + u * hx - v * hy,
		o.center + u * hx + v * hy,
		o.center - u * hx + v * hy
	]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var d := (b - a).normalized()
		var side := Vector2(-d.y, d.x) * EDGE * 0.5
		_quad(et, a - side, b - side, b + side, a + side)


func _quad(out: Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	out.append_array([a, b, c, a, c, d])


func _emit(im: ImmediateMesh, pts: Array, mat: Material) -> void:
	if pts.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	for q: Vector2 in pts:
		im.surface_set_normal(Vector3.UP)
		im.surface_add_vertex(SimPlane.to_3d(q, Y))
	im.surface_end()

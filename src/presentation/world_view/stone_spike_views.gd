class_name StoneSpikeViews
extends Node3D
## v0.8.0 AV (owner O7: "when they do long distance stonekeeper, it should be like spikes coming out of the ground that
## actually look like spikes and not … a red thingy"): the Gatekeeper's shock lanes (its `row_lanes` move) strike as
## rows of 3D stone spikes erupting along each lane: faceted grey stone with red-hot cracks, staggered heights, a quick
## thrust up from where the lanes cross, a hold, then they sink back (LIFE_TICKS, 0.6 s). With the new look's effects
## layer (VfxCore) the strike also throws rock debris and dust (the fx_debris_chunks and fx_smoke_puffs atlases),
## flashes a hot light and leaves crack marks on the floor (draw_fx, a VfxCore drawer).
## The strike is read, never decided: a lanes marker of a row_lanes telegraph (WorldReader.telegraph, the function
## that resolves the hit, EI-07) shows "locked" at progress 1000 on exactly its strike tick (BossDodge.mark_state 2),
## and the spikes rise along the very lanes it hits. The sim's timings are unchanged.
## Pooled: one MultiMesh of at most MAX_SPIKES spikes (one draw), at most MAX_STRIKES strikes alive; a strike's spikes
## return to the pool when it ends. Ticks are the sim's (WorldReader.tick plus the interpolation fraction), so the
## spikes pause with the game. Reduced motion: no overshoot on the thrust.
## The mesh is code-made (spike_mesh); an owner model `stone_spike` listed in assets/models/manifest.json at
## MODEL_PATH replaces it (one unit tall, its own proportions), as BossModels and KitModels do (L15). v0.9.0 MI2: the
## owner's spike (delivered 2026-10-22, the tallest of his three clusters, scripts/assets/mi2_prep.py) is drawn in its
## own colour map, its red crystal veins (the map's red) the hot cracks that glow on the strike.
## v0.8.0 FB1 (FINAL_BOSS.md F4: "the Gatekeeper's stone spikes, bigger"): the Colossus's chasing spike lines and
## radial bursts (`spike_chase`, `spike_burst`: a marks telegraph of disc items) erupt the same way, read the same way
## (an item locked at progress 1000 is its strike tick): each disc throws up a cluster of DISC_SPIKES spikes, the tall
## one in its middle DISC_TALL times a lane spike's height, the rest leaning out round it to the disc's edge.

const LIFE_TICKS := 36.0
const RISE_TICKS := 5.0
const HOLD_TICKS := 20.0
## The farthest spikes rise this many ticks after the ones where the lanes cross (the eruption runs outward).
const SPREAD_TICKS := 4.0
const STEP_M := 0.5
const MAX_SPIKES := 512
## v0.8.0 FB1: 48 (was 8): a Colossus burst raises a strike per spike disc, some thirty alive at once.
const MAX_STRIKES := 48
## v0.8.0 FB1: a Colossus spike disc's cluster: how many spikes, how much taller than a lane spike its middle one.
const DISC_SPIKES := 6
const DISC_TALL := 1.9
## The floor marks a lane leaves: at the crossing and every MARK_STEP m out, MARKS_EACH_WAY each way.
const MARK_STEP := 2.0
const MARKS_EACH_WAY := 2
const HOT := Color(1.0, 0.32, 0.12)
const CRACK_MARK := Color(0.07, 0.05, 0.045, 0.85)
const DUST := Color(0.6, 0.55, 0.5)
const MODEL_ID := "stone_spike"
const MODEL_PATH := "res://assets/models/fx/stone_spike.glb"
const MANIFEST := "res://assets/models/manifest.json"
## v0.8.0 BS1 (S1): a pillar's spikes: the tall one's height (m), how many shorter ones lean out of its corners, the
## ticks its cracks pulse before it sinks and the ticks it takes to sink (_draw_pillars).
const PILLAR_TALL := 1.9
const PILLAR_SATELLITES := 3
const PILLAR_WARN_TICKS := 60.0
const PILLAR_SINK_TICKS := 18.0

const SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 stone : source_color = vec4(0.46, 0.44, 0.42, 1.0);
uniform vec4 stone_dark : source_color = vec4(0.24, 0.22, 0.21, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.32, 0.12, 1.0);
uniform float energy = 4.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float stone_on = 0.0;
uniform sampler2D model_tex : source_color, filter_linear_mipmap;
uniform float model_on = 0.0;

varying float heat;
varying float seed;
varying vec3 lp;

void vertex() {
	heat = INSTANCE_CUSTOM.r;
	seed = INSTANCE_CUSTOM.g;
	lp = VERTEX;
}

void fragment() {
	float n = texture(noise_tex, vec2(lp.x * 1.3 + lp.z * 0.7 + seed, lp.y * 0.9 + seed * 2.0)).r;
	float veins = 1.0 - smoothstep(0.01, 0.05, abs(n - 0.5));
	float low = 1.0 - smoothstep(0.0, 0.85, lp.y);
	ALBEDO = mix(stone_dark.rgb, stone.rgb, smoothstep(0.3, 0.7, n));
	if (stone_on > 0.5) {  // v0.8.0 TX2: the owner's cracked stone round the spike, its cracks the hot veins
		vec4 s = texture(stone_tex, vec2(lp.x * 0.9 + lp.z * 0.9 + seed, lp.y * 0.8 + seed * 0.37));
		ALBEDO = s.rgb * (1.0 - s.a * 0.6) * 1.15;
		veins = s.a;
	}
	if (model_on > 0.5) {  // v0.9.0 MI2: the owner's spike in its own colours, its red veins the hot cracks
		vec3 m = texture(model_tex, UV).rgb;
		ALBEDO = m;
		veins = clamp((m.r - max(m.g, m.b)) * 3.0, 0.0, 1.0);
	}
	float g = veins * heat * mix(0.35, 1.0, low);
	EMISSION = hot.rgb * (energy * g + 0.5 * heat * low * low);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
"""

## Where the owner's model is looked up (tests point it elsewhere to see the fallback).
static var model_path := MODEL_PATH
static var _mesh: Mesh
static var _from_model := false
## v0.9.0 MI2: the owner's spike's colour map (null with the code spike).
static var _model_tex: Texture2D

## The effects layer for the debris, dust, light and floor marks (WorldViewRoot sets it with the new look).
var vfx: VfxCore
## Live strikes: {"tick", "seed", "center" (Vector3), "spikes": [[base, basis, height, delay, seed]], "marks":
## [Vector3], "dust": [Vector3]}.
var _strikes: Array[Dictionary] = []
## v0.8.0 BS1 (owner O5, S1): the pillars standing now (WorldReader.boss_pillars: [center, half, from, until]).
var _pillars: Array = []
var _pillars_drawn := 0
## Strikes already raised, by key (the boss's id and the marker's lanes), with their tick.
var _seen := {}
var _tick := 0
var _drawn := 0
## Where the drawn spikes stand (their bases on the floor; tests: a headless renderer keeps no MultiMesh state).
var _bases := PackedVector3Array()
var _node := MultiMeshInstance3D.new()
var _mat := ShaderMaterial.new()


func _init() -> void:
	name = "StoneSpikes"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = spike_mesh()
	mm.instance_count = MAX_SPIKES
	mm.visible_instance_count = 0
	_node.name = "Spikes"
	_node.multimesh = mm
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	_mat.set_shader_parameter("hot", HOT)
	var stone := BossStrikeMeshes.texture("tex_stone_spike")  # v0.8.0 TX2: the owner's spike stone
	_mat.set_shader_parameter("stone_tex", stone)
	_mat.set_shader_parameter("stone_on", 1.0 if stone != null else 0.0)
	_mat.set_shader_parameter("model_tex", _model_tex)
	_mat.set_shader_parameter("model_on", 1.0 if _from_model and _model_tex != null else 0.0)
	_node.material_override = _mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_node.extra_cull_margin = 16384.0  # the instances spread over the whole room
	add_child(_node)


func sync(reader: WorldReader) -> void:
	if reader.tick() < _tick:  # a new floor's world: its ticks start again
		_strikes.clear()
		_seen.clear()
	_tick = reader.tick()
	for i in reader.actor_count():
		var tg := reader.telegraph(i)
		var mv := int(tg.get("move", -1))
		if (
			tg.get("shape", &"") == &"marks"
			and (mv == WorldReader.MOVE_SPIKE_CHASE or mv == WorldReader.MOVE_SPIKE_BURST)
		):
			_detect_discs(reader.actor_id(i), tg)  # v0.8.0 FB1: the Colossus's spikes
			continue
		if tg.get("shape", &"") != &"marks" or mv != WorldReader.MOVE_ROW_LANES:
			continue
		var items: Array = tg["items"]
		for item: Dictionary in items:
			if not item.get("locked", false) or int(item.get("progress", 0)) < 1000:
				continue
			var obbs: Array = item["obbs"]
			var key := "%d:%s" % [reader.actor_id(i), str((obbs[0] as Obb).center)]
			if _seen.has(key) and _tick - int(_seen[key]) < LIFE_TICKS:
				continue
			_seen[key] = _tick
			_spawn(obbs, _tick)
	for key in _seen.keys():
		if _tick - int(_seen[key]) > LIFE_TICKS * 2.0:
			_seen.erase(key)
	var keep: Array[Dictionary] = []
	for s in _strikes:
		if _tick - int(s["tick"]) <= LIFE_TICKS + SPREAD_TICKS + 1.0:
			keep.append(s)
	_strikes = keep
	_pillars = reader.boss_pillars()  # v0.8.0 BS1
	_draw(float(_tick))


func _process(_delta: float) -> void:
	if not _strikes.is_empty() or not _pillars.is_empty():
		_draw(float(_tick) + Engine.get_physics_interpolation_fraction())


## Strikes alive now (tests).
func strike_count() -> int:
	return _strikes.size()


## Spikes standing above the floor in the last draw (tests and the tour).
func spike_count() -> int:
	return _drawn


## Where the spikes of the last draw stand on the floor (tests).
func spike_positions() -> PackedVector3Array:
	return _bases


## Spikes held by the live strikes (tests: bounded by MAX_SPIKES).
func pooled() -> int:
	var n := 0
	for s in _strikes:
		n += (s["spikes"] as Array).size()
	return n


## True when the owner's model replaced the code spike.
static func from_model() -> bool:
	spike_mesh()
	return _from_model


## The spike: the owner's model when listed and present, else the code-made one. One unit tall, its base on y = 0
## (a little below to plant it), about one unit across.
static func spike_mesh() -> Mesh:
	if _mesh == null:
		_mesh = _model_mesh()
		_from_model = _mesh != null
		if _mesh == null:
			_mesh = _code_mesh()
	return _mesh


## Drops the cached mesh (tests switch model_path).
static func clear_cache() -> void:
	_mesh = null
	_from_model = false
	_model_tex = null


## A faceted five-sided stone spike: a jagged base ring, a twisted waist and an off-centre point.
static func _code_mesh() -> ArrayMesh:
	var n := 5
	var base := []
	var mid := []
	for k in n:
		var a := TAU * k / n
		var rb := 0.5 * (0.8 + 0.35 * VfxCore.h(k, 71))
		var rm := 0.3 * (0.75 + 0.4 * VfxCore.h(k, 72))
		base.append(Vector3(cos(a) * rb, -0.1, sin(a) * rb))
		var am := a + 0.45
		mid.append(Vector3(cos(am) * rm, 0.42 + 0.08 * VfxCore.h(k, 73), sin(am) * rm))
	var tip := Vector3(0.05, 1.0, -0.04)
	var tris := []
	for k in n:
		var b0: Vector3 = base[k]
		var b1: Vector3 = base[(k + 1) % n]
		var m0: Vector3 = mid[k]
		var m1: Vector3 = mid[(k + 1) % n]
		tris.append([b0, b1, m0])
		tris.append([b1, m1, m0])
		tris.append([m0, m1, tip])
	return AvatarBase.flat_mesh(tris, Vector3(0, 0.35, 0))


## The owner's spike (stone_spike.glb), one unit tall like the code spike, its width in its own proportion (v0.9.0
## MI2: a spike, not squashed into the code spike's unit width), or null when it isn't listed in the manifest or isn't
## on disk. Keeps its colour map for the shader (_model_tex).
static func _model_mesh() -> Mesh:
	if not _listed() or not ResourceLoader.exists(model_path):
		return null
	var surface := ModelLibrary.first_surface(load(model_path) as PackedScene)
	if surface.is_empty():
		return null
	var arrays: Array = surface["arrays"]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var ext := (hi - lo).max(Vector3(0.0001, 0.0001, 0.0001))
	for k in verts.size():
		verts[k] = (verts[k] - Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)) / ext.y
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TANGENT] = null
	var mat := surface["material"] as StandardMaterial3D
	_model_tex = mat.albedo_texture if mat != null else null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func _listed() -> bool:
	if not FileAccess.file_exists(MANIFEST):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	for m: Dictionary in (data as Dictionary).get("models", []):
		if String(m.get("id", "")) == MODEL_ID:
			return true
	return false


## v0.8.0 FB1: every spike disc striking now (locked at progress 1000) raises its cluster once.
func _detect_discs(aid: int, tg: Dictionary) -> void:
	for item: Dictionary in tg["items"]:
		if not item.get("locked", false) or int(item.get("progress", 0)) < 1000:
			continue
		var c: Vector2 = item["center"]
		var key := "%d:%s" % [aid, str(c)]
		if _seen.has(key) and _tick - int(_seen[key]) < LIFE_TICKS:
			continue
		_seen[key] = _tick
		_spawn_disc(c, float(item["radius"]), _tick)


## v0.8.0 FB1: one disc's cluster at `tick`: a tall spike in the middle, the rest leaning out to the disc's edge, the
## middle first.
func _spawn_disc(c: Vector2, r: float, tick: int) -> void:
	var sd := tick * 31 + int(absf(c.x) * 97.0) + int(absf(c.y) * 13.0)
	var spikes := []
	for j in DISC_SPIKES:
		var hj := VfxCore.h(sd, j)
		var at := c
		var height := DISC_TALL * lerpf(0.9, 1.1, hj)
		var width := r * 0.75
		var turn := Basis(Vector3.UP, TAU * hj)
		if j > 0:
			var ang := TAU * (j - 1) / (DISC_SPIKES - 1) + 0.5 * VfxCore.h(sd + 1, j)
			at = c + Vector2(cos(ang), sin(ang)) * r * 0.6
			height *= lerpf(0.45, 0.7, VfxCore.h(sd + 2, j))
			width *= 0.55
			var out := (SimPlane.to_3d(at) - SimPlane.to_3d(c)).normalized()
			turn = Basis(out.cross(Vector3.UP).normalized(), -0.35) * turn
		var b := Basis(turn.x * width, turn.y * height, turn.z * width)
		var delay := 0.0 if j == 0 else 1.0 + VfxCore.h(sd + 3, j)
		spikes.append([SimPlane.to_3d(at, 0.0), b, height, delay, VfxCore.h(sd + 4, j)])
	while _strikes.size() >= MAX_STRIKES:
		_strikes.pop_front()
	var room := MAX_SPIKES - pooled()
	while room < spikes.size() and not _strikes.is_empty():
		_strikes.pop_front()
		room = MAX_SPIKES - pooled()
	var mark := SimPlane.to_3d(c, 0.0)
	_strikes.append(
		{
			"tick": tick,
			"seed": sd,
			"center": mark,
			"spikes": spikes,
			"marks": [mark],
			"dust": [mark]
		}
	)


## Raises one marker's lanes at `tick`: spikes every STEP_M down each lane, zig-zagging across it, taller and earlier
## where the lanes cross.
func _spawn(obbs: Array, tick: int) -> void:
	var c := _crossing(obbs)
	var sd := tick * 31 + int(absf(c.x) * 97.0) + int(absf(c.y) * 13.0)
	var spikes := []
	var marks := []
	var dust := []
	for li in obbs.size():
		var o: Obb = obbs[li]
		var n := maxi(1, int(o.half.x * 2.0 / STEP_M))
		for j in n:
			var s := -o.half.x + STEP_M * (j + 0.5)
			var hj := VfxCore.h(sd + li * 977, j)
			var side := (1.0 if j % 2 == 0 else -1.0) * o.half.y * (0.25 + 0.3 * hj)
			var at := o.center + o.axis_u * s + o.axis_v * side
			var dist := at.distance_to(c)
			if li > 0 and dist < o.half.y * 1.2:
				continue  # the first lane already raised the crossing
			var near := clampf(1.0 - dist / 3.0, 0.0, 1.0)
			var height := lerpf(0.55, 1.15, VfxCore.h(sd + li * 977 + 1, j)) * (1.0 + 0.35 * near)
			var width := lerpf(0.42, 0.62, VfxCore.h(sd + li * 977 + 2, j)) * o.half.y / 0.6
			var lean := (0.1 + 0.2 * VfxCore.h(sd + li * 977 + 3, j)) * signf(side)
			var axis := SimPlane.to_3d(o.axis_u) - SimPlane.to_3d(Vector2.ZERO)
			var turn := Basis(axis.normalized(), lean) * Basis(Vector3.UP, TAU * hj)
			var b := Basis(turn.x * width, turn.y * height, turn.z * width)
			var delay := minf(SPREAD_TICKS, dist / 3.0) + VfxCore.h(sd + li * 977 + 4, j)
			spikes.append([SimPlane.to_3d(at, 0.0), b, height, delay, VfxCore.h(sd, j + li * 500)])
			if j % 4 == 0:
				dust.append(SimPlane.to_3d(at, 0.0))
		for k in range(-MARKS_EACH_WAY, MARKS_EACH_WAY + 1):
			if li > 0 and k == 0:
				continue
			var along := (c - o.center).dot(o.axis_u) + MARK_STEP * k
			if absf(along) <= o.half.x:
				marks.append(SimPlane.to_3d(o.center + o.axis_u * along, 0.0))
	spikes.sort_custom(func(a: Array, b: Array) -> bool: return float(a[3]) < float(b[3]))
	while _strikes.size() >= MAX_STRIKES:
		_strikes.pop_front()
	var room := MAX_SPIKES - pooled()
	while room < spikes.size() and not _strikes.is_empty():  # the oldest strike gives its spikes back first
		_strikes.pop_front()
		room = MAX_SPIKES - pooled()
	if spikes.size() > room:
		spikes.resize(room)
	_strikes.append(
		{
			"tick": tick,
			"seed": sd,
			"center": SimPlane.to_3d(c, 0.0),
			"spikes": spikes,
			"marks": marks,
			"dust": dust
		}
	)


## Where a marker's two lanes cross (its locked point), or the first lane's centre.
static func _crossing(obbs: Array) -> Vector2:
	var a: Obb = obbs[0]
	if obbs.size() < 2:
		return a.center
	var b: Obb = obbs[1]
	var den := a.axis_u.cross(b.axis_u)
	if absf(den) < 0.0001:
		return a.center
	var t := (b.center - a.center).cross(b.axis_u) / den
	return a.center + a.axis_u * t


## How far out of the ground a spike stands `a` ticks after it starts rising (0 hidden .. 1 standing).
static func extent(a: float, still: bool) -> float:
	if a <= 0.0:
		return 0.0
	if a < RISE_TICKS:
		var k := a / RISE_TICKS
		var e := sin(k * PI * 0.5)
		return e if still else e * (1.0 + 0.15 * sin(k * PI))
	if a < HOLD_TICKS:
		return 1.0
	return 1.0 - smoothstep(HOLD_TICKS, LIFE_TICKS, a)


func _draw(now: float) -> void:
	var buf := PackedFloat32Array()
	var still := ViewPrefs.reduced_motion
	var n := 0
	_bases.clear()
	for s in _strikes:
		var age := now - float(s["tick"])
		var heat := clampf(1.0 - age / LIFE_TICKS, 0.0, 1.0)
		for sp: Array in s["spikes"]:
			var e := extent(age - float(sp[3]), still)
			if e <= 0.001:
				continue
			var b: Basis = sp[1]
			var o: Vector3 = sp[0] - Vector3.UP * (float(sp[2]) * (1.0 - e))
			buf.append_array(
				[
					b.x.x,
					b.y.x,
					b.z.x,
					o.x,
					b.x.y,
					b.y.y,
					b.z.y,
					o.y,
					b.x.z,
					b.y.z,
					b.z.z,
					o.z,
					heat,
					float(sp[4]),
					0.0,
					0.0
				]
			)
			n += 1
			_bases.append(sp[0])
	n = _draw_pillars(buf, n, now, still)
	var mm := _node.multimesh
	if n > 0:
		buf.resize(mm.instance_count * 16)
		mm.buffer = buf
	mm.visible_instance_count = n
	_drawn = n


## v0.8.0 BS1 (owner O5, S1, "Stone Spikes that stay"): each standing pillar is a cluster of the same stone spikes,
## a tall one filling its square and PILLAR_SATELLITES shorter ones leaning out of its corners. They thrust up with
## the strike (RISE_TICKS), stand for the pillar's whole life (the sim's wall), their cracks pulse hot over the last
## PILLAR_WARN_TICKS and they sink over the last PILLAR_SINK_TICKS: the wall goes on the sim's tick, read from
## WorldReader.boss_pillars (EI-07). Appends to `buf` from instance n (at most MAX_SPIKES) and returns the count.
func _draw_pillars(buf: PackedFloat32Array, n: int, now: float, still: bool) -> int:
	var drawn := 0
	for p: Array in _pillars:
		var c: Vector2 = p[0]
		var h: float = p[1]
		# The reader's tick is the next one to run: a pillar raised on it shows, and stands until the tick it goes.
		var age := now - float(p[2]) + 1.0
		var left := float(p[3]) - now + 1.0
		var e := 1.0 if age >= RISE_TICKS else extent(age, still)  # it rises, then stands
		if left < PILLAR_SINK_TICKS:
			e = minf(e, clampf(left / PILLAR_SINK_TICKS, 0.0, 1.0))
		if e <= 0.001:
			continue
		var heat := clampf(1.0 - age / LIFE_TICKS, 0.0, 1.0) * 0.8
		if left < PILLAR_WARN_TICKS:
			var k := 1.0 - left / PILLAR_WARN_TICKS
			var pulse := 0.5 if still else 0.5 + 0.5 * sin(now * 0.55)
			heat = maxf(heat, k * pulse)
		var sd := int(absf(c.x) * 131.0) + int(absf(c.y) * 17.0) * 7
		drawn += 1
		for j in PILLAR_SATELLITES + 1:
			if n >= MAX_SPIKES:
				_pillars_drawn = drawn
				return n
			var tall := PILLAR_TALL * (0.9 + 0.2 * VfxCore.h(sd, j))
			var width := h * 2.0 * 1.05
			var at := c
			var turn := Basis(Vector3.UP, TAU * VfxCore.h(sd + 1, j))
			if j > 0:  # a shorter spike leaning out of a corner
				var ang := TAU * (j - 1) / PILLAR_SATELLITES + 0.6 * VfxCore.h(sd + 2, j)
				at = c + Vector2(cos(ang), sin(ang)) * h * 0.75
				tall *= 0.55
				width *= 0.5
				var out := (SimPlane.to_3d(at) - SimPlane.to_3d(c)).normalized()
				turn = Basis(out.cross(Vector3.UP).normalized(), -0.28) * turn
			var b := Basis(turn.x * width, turn.y * tall, turn.z * width)
			var base := SimPlane.to_3d(at, 0.0)
			var o := base - Vector3.UP * (tall * (1.0 - e))
			buf.append_array(
				[
					b.x.x,
					b.y.x,
					b.z.x,
					o.x,
					b.x.y,
					b.y.y,
					b.z.y,
					o.y,
					b.x.z,
					b.y.z,
					b.z.z,
					o.z,
					heat,
					VfxCore.h(sd + 3, j),
					0.0,
					0.0
				]
			)
			n += 1
			_bases.append(base)
	_pillars_drawn = drawn
	return n


## Pillars standing (any part above the floor) in the last draw (tests and the tour).
func pillar_count() -> int:
	return _pillars_drawn


## A VfxCore drawer (WorldViewRoot adds it): each strike's rock debris thrown up, dust rising and spreading, a hot
## flash of light where the lanes cross and crack marks along the lanes. Thinned with the layer's density.
func draw_fx(layer: VfxCore) -> void:
	var now := float(_tick) + Engine.get_physics_interpolation_fraction()
	for s in _strikes:
		var age := now - float(s["tick"])
		if age < 0.0 or age > LIFE_TICKS + SPREAD_TICKS:
			continue
		var sd: int = s["seed"]
		var u := clampf(age / (LIFE_TICKS + SPREAD_TICKS), 0.0, 1.0)
		var dust: Array = s["dust"]
		for k in dust.size():
			if VfxCore.h(sd + 5, k) > layer.density:
				continue
			var base: Vector3 = dust[k]
			var a := TAU * VfxCore.h(sd + 6, k)
			var out := Vector3(cos(a), 0.0, sin(a))
			var t := clampf(age / 18.0, 0.0, 1.0)
			if t < 1.0:
				var q := base + out * 0.9 * t + Vector3(0, 0.1 + 2.4 * t - 2.6 * t * t, 0)
				layer.sprite(
					&"debris",
					q,
					0.45 + 0.2 * VfxCore.h(sd + 7, k),
					Color(0.85, 0.8, 0.76, 1.0 - t * t),
					(sd + k) % 4,
					age * 0.3 * (VfxCore.h(sd + 8, k) - 0.5)
				)
			var q2 := base + out * 0.4 * u + Vector3(0, 0.25 + 0.9 * u, 0)
			layer.sprite(
				&"smoke",
				q2,
				0.7 + 1.1 * u,
				Color(DUST, 0.7 * sin(PI * u)),
				(sd + k + 1) % 4,
				TAU * VfxCore.h(sd + 9, k)
			)
		var c: Vector3 = s["center"]
		layer.light_merged(c + Vector3(0, 0.8, 0), HOT, 3.5 * (1.0 - u) * (1.0 - u), 6.0, 1.0)
		var marks: Array = s["marks"]
		for k in marks.size():
			layer.mark(sd * 16 + k, BossStrikeFx.crack_mark(), marks[k], 1.1, CRACK_MARK)

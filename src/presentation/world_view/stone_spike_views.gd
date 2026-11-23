class_name StoneSpikeViews
extends Node3D
## v0.8.0 AV (owner O7: "when they do long distance stonekeeper, it should be like spikes coming out of the ground that
## actually look like spikes and not … a red thingy"): the Gatekeeper's shock lanes (its `row_lanes` move) strike as
## rows of 3D stone spikes erupting along each lane: faceted stone in the floor's colour with faint dark-red seams (no
## glow or light of their own), staggered heights, a quick
## thrust up, one after another outward from the boss's edge at the speed the sim strikes them, a hold, then they sink
## back (LIFE_TICKS, 0.6 s). Each kicks the floor's grit and a low dust up as it rises (GroundSlamViews.kick), and the
## strike leaves crack marks on the floor (draw_fx, a VfxCore drawer).
## The strike is read, never decided: a lanes marker of a row_lanes telegraph (WorldReader.telegraph, the function
## that resolves the hit, EI-07) shows "locked" at progress 1000 on exactly its strike tick (BossDodge.mark_state 2),
## and the spikes rise along the very lanes it hits. The sim's timings are unchanged.
## Pooled: one MultiMesh of at most MAX_SPIKES spikes (one draw), at most MAX_STRIKES strikes alive; a strike's spikes
## return to the pool when it ends. Ticks are the sim's (WorldReader.tick plus the interpolation fraction), so the
## spikes pause with the game. Reduced motion: no overshoot on the thrust.
## The mesh is code-made (spike_mesh); an owner model `stone_spike` listed in assets/models/manifest.json at
## MODEL_PATH replaces it (one unit tall, its own proportions), as BossModels and KitModels do. the
## owner's spike (delivered 2026-10-22, the tallest of his three clusters, scripts/assets/mi2_prep.py) is drawn in its
## own colour map, its red crystal veins (the map's red) the hot cracks that glow on the strike.
## FINAL_BOSS.md F4: "the Gatekeeper's stone spikes, bigger": the Colossus's chasing spike lines and
## radial bursts (`spike_chase`, `spike_burst`: a marks telegraph of disc items) erupt the same way, read the same way
## (an item locked at progress 1000 is its strike tick): each disc throws up a cluster of DISC_SPIKES spikes, the tall
## one in its middle DISC_TALL times a lane spike's height, the rest leaning out round it to the disc's edge.

## The Gatekeeper's quake pillars (WorldReader.boss_quake_pillars, BossQuake.ring_state)
## stand as taller, wider clusters of the same stone spikes, their seams warming with the 3 s pulse: dim, warming as
## the ring grows over its warning, flaring on the pulse. The ring (_ring, flat unshaded bands rebuilt each draw) is a
## dark ripple in the floor growing from the pillar out to the very radius the pulse hits, over a faint dark outline of
## that radius, and only as it strikes a thin bright edge flashes at that radius. A pillar the sim removes (its Shock
## Lanes shattered it) breaks: short broken spikes and the stone slam's chunks and grit (_shatter). Read only; the
## pillar, the ring and its clock are the sim's.

const LIFE_TICKS := 36.0
const RISE_TICKS := 5.0
const HOLD_TICKS := 20.0
## A spike with no wave speed to follow rises up to this many ticks after the first (the eruption runs outward).
const SPREAD_TICKS := 4.0
const STEP_M := 0.6
const MAX_SPIKES := 896
## 48 (was 8): a Colossus burst raises a strike per spike disc, some thirty alive at once.
const MAX_STRIKES := 48
## A Colossus spike disc's cluster: how many spikes, how much taller than a lane spike its middle one.
const DISC_SPIKES := 6
const DISC_TALL := 1.9
## The floor marks a lane leaves: at the crossing and every MARK_STEP m out, MARKS_EACH_WAY each way.
const MARK_STEP := 2.0
const MARKS_EACH_WAY := 2
## The spikes' seams: an ember red that glows a little while the spike is hot, so a row reads on any floor.
const HOT := Color(0.85, 0.3, 0.1)
const CRACK_MARK := Color(0.07, 0.05, 0.045, 0.85)
const MODEL_ID := "stone_spike"
const MODEL_PATH := "res://assets/models/fx/stone_spike.glb"
const MANIFEST := "res://assets/models/manifest.json"
## A pillar's spikes: the tall one's height (m), how many shorter ones lean out of its corners, the
## ticks its cracks pulse before it sinks and the ticks it takes to sink (_draw_pillars).
const PILLAR_TALL := 1.9
const PILLAR_SATELLITES := 3
const PILLAR_WARN_TICKS := 60.0
const PILLAR_SINK_TICKS := 18.0
## A quake pillar's cluster: its tall spike's height (m), its width over the pillar's side, how many
## shorter spikes stand round it; the crack's heat at rest, the ticks it flares after a pulse; the ring's band width
## (m), its colour, and the rubble a shattered pillar throws up.
const QUAKE_TALL := 2.7
const QUAKE_WIDE := 1.2
const QUAKE_SATELLITES := 4
const QUAKE_REST_HEAT := 0.18
const QUAKE_FLARE_TICKS := 14.0
const RING_BAND_M := 0.14
## The pulse's thin bright edge, and the ripple's dark (the floor pressed down).
const RING_COLOR := Color(1.0, 0.42, 0.15)
const RIPPLE := Color(0.05, 0.04, 0.035)
const RUBBLE := 6
## The grit a spike row kicks up (its size against the slam's), and a shattered pillar's slam (m round).
const KICK_SIZE := 0.28
const SHATTER_M := 1.8
const SHATTER := (
	GroundSlamViews.P_BIG | GroundSlamViews.P_MID | GroundSlamViews.P_GRIT | GroundSlamViews.P_DUST
)

const SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 stone : source_color = vec4(0.46, 0.44, 0.42, 1.0);
uniform vec4 stone_dark : source_color = vec4(0.24, 0.22, 0.21, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.32, 0.12, 1.0);
uniform float energy = 4.0;
uniform vec4 floor_col : source_color = vec4(0.5, 0.48, 0.46, 1.0);
uniform float floor_on = 0.0;
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
	if (floor_on > 0.5) {  // the floor's stone, lifted to a pale stone so the spikes stand out on dark floors
		vec3 pale = mix(floor_col.rgb, vec3(0.86, 0.82, 0.76), 0.8);
		ALBEDO = pale * (0.9 + 0.5 * dot(ALBEDO, vec3(0.3, 0.59, 0.11)));
	}
	ALBEDO = mix(ALBEDO, hot.rgb, smoothstep(0.4, 0.9, veins) * 0.7);  // ember seams
	EMISSION = hot.rgb * veins * heat * mix(0.5, 1.0, low) * 2.6;  // a visible ember glow, no light cast
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
"""

## Where the owner's model is looked up (tests point it elsewhere to see the fallback).
static var model_path := MODEL_PATH
static var _mesh: Mesh
static var _from_model := false
## The owner's spike's colour map (null with the code spike).
static var _model_tex: Texture2D

## The effects layer for the floor marks (WorldViewRoot sets it with the new look).
var vfx: VfxCore
## The grit and dust the spikes kick up, and the shattered pillars' slams.
var slams := GroundSlamViews.new(8)
## Live strikes: {"tick", "seed", "center" (Vector3), "spikes": [[base, basis, height, delay, seed]], "marks":
## [Vector3]}.
var _strikes: Array[Dictionary] = []
## The pillars standing now (WorldReader.boss_pillars: [center, half, from, until]).
var _pillars: Array = []
var _pillars_drawn := 0
## The quake pillars standing now (WorldReader.boss_quake_pillars), the ones seen last sync (centre by
## key, to shatter the ones gone), and the ring's flat mesh.
var _quakes: Array = []
var _quake_seen := {}
var _ring := MeshInstance3D.new()
var _ring_mesh := ImmediateMesh.new()
var _ring_bands := 0
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
	var stone := BossStrikeMeshes.texture("tex_stone_spike")  # The owner's spike stone
	_mat.set_shader_parameter("stone_tex", stone)
	_mat.set_shader_parameter("stone_on", 1.0 if stone != null else 0.0)
	_mat.set_shader_parameter("model_tex", _model_tex)
	_mat.set_shader_parameter("model_on", 1.0 if _from_model and _model_tex != null else 0.0)
	_node.material_override = _mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_node.extra_cull_margin = 16384.0  # the instances spread over the whole room
	add_child(_node)
	_ring.name = "QuakeRings"  # The quake pillars' rings
	_ring.mesh = _ring_mesh
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.vertex_color_use_as_albedo = true
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.extra_cull_margin = 16384.0
	add_child(_ring)
	add_child(slams)


## The biome's floor colours: the spikes, their grit and the shattered pillars' stone are the floor's.
func floor_palette(palette: Dictionary) -> void:
	slams.floor_palette(palette)
	if palette.has("ground"):
		_mat.set_shader_parameter("floor_col", palette["ground"])
		_mat.set_shader_parameter("floor_on", 1.0)


func sync(reader: WorldReader) -> void:
	if reader.tick() < _tick:  # a new floor's world: its ticks start again
		_strikes.clear()
		_seen.clear()
		_quake_seen.clear()
	_tick = reader.tick()
	for i in range(reader.actor_count() if reader.any_boss() else 0):
		var tg := reader.telegraph(i)
		var mv := int(tg.get("move", -1))
		if (
			tg.get("shape", &"") == &"marks"
			and (mv == WorldReader.MOVE_SPIKE_CHASE or mv == WorldReader.MOVE_SPIKE_BURST)
		):
			_detect_discs(reader.actor_id(i), tg)  # The Colossus's spikes
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
			_spawn(obbs, _tick, float(item.get("wave", 0.0)))
	for key in _seen.keys():
		if _tick - int(_seen[key]) > LIFE_TICKS * 2.0:
			_seen.erase(key)
	var keep: Array[Dictionary] = []
	for s in _strikes:
		if _tick - int(s["tick"]) <= LIFE_TICKS + float(s.get("span", SPREAD_TICKS)) + 1.0:
			keep.append(s)
	_strikes = keep
	_pillars = reader.boss_pillars()  # v0.8.0 BS1
	_sync_quakes(reader.boss_quake_pillars() + reader.boss_javelin_quakes())  # O3; F9: the great javelin's ring
	_draw(float(_tick))


func _process(_delta: float) -> void:
	if not _strikes.is_empty() or not _pillars.is_empty() or not _quakes.is_empty():
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
## A spike, not squashed into the code spike's unit width), or null when it isn't listed in the manifest or isn't
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


## Every spike disc striking now (locked at progress 1000) raises its cluster once.
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


## One disc's cluster at `tick`: a tall spike in the middle, the rest leaning out to the disc's edge, the
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
	var ring := []
	for j in 5:  # the floor's grit kicked up round the cluster as it bursts out
		var ang := TAU * j / 5.0 + VfxCore.h(sd + 5, j)
		ring.append(SimPlane.to_3d(c + Vector2(cos(ang), sin(ang)) * r * 0.8, 0.0))
	slams.kick(ring, KICK_SIZE)
	_strikes.append({"tick": tick, "seed": sd, "center": mark, "spikes": spikes, "marks": [mark]})


## Raises one marker's lanes at `tick`: spikes every STEP_M down each lane, zig-zagging across it, rising one after
## another outward from the lane's start at the boss's edge. `mpt` is the metres a tick the sim's strike runs out
## along the lanes (the item's "wave"): a spike rises on the tick the sim strikes its slice, so the look is the hit.
## Without it the spikes still spread out, over SPREAD_TICKS.
func _spawn(obbs: Array, tick: int, mpt := 0.0) -> void:
	var c := _origin(obbs)
	var sd := tick * 31 + int(absf(c.x) * 97.0) + int(absf(c.y) * 13.0)
	var spikes := []
	var marks := []
	var dust := []
	var delays := []
	var span := SPREAD_TICKS
	for li in obbs.size():
		var o: Obb = obbs[li]
		var n := maxi(1, int(o.half.x * 2.0 / STEP_M))
		var start := o.center - o.axis_u * o.half.x
		for j in n:
			var s := -o.half.x + STEP_M * (j + 0.5)
			var hj := VfxCore.h(sd + li * 977, j)
			var side := (1.0 if j % 2 == 0 else -1.0) * o.half.y * (0.25 + 0.3 * hj)
			var at := o.center + o.axis_u * s + o.axis_v * side
			var along := s + o.half.x
			var near := clampf(1.0 - along / 3.0, 0.0, 1.0)
			var height := lerpf(0.55, 1.15, VfxCore.h(sd + li * 977 + 1, j)) * (1.0 + 0.35 * near)
			var width := lerpf(0.42, 0.62, VfxCore.h(sd + li * 977 + 2, j)) * o.half.y / 0.6
			var lean := (0.1 + 0.2 * VfxCore.h(sd + li * 977 + 3, j)) * signf(side)
			var axis := SimPlane.to_3d(o.axis_u) - SimPlane.to_3d(Vector2.ZERO)
			var turn := Basis(axis.normalized(), lean) * Basis(Vector3.UP, TAU * hj)
			var b := Basis(turn.x * width, turn.y * height, turn.z * width)
			var delay := float(int(along / mpt)) if mpt > 0.0 else minf(SPREAD_TICKS, along / 3.0)
			delay += VfxCore.h(sd + li * 977 + 4, j) * 0.5  # a spike is never before its slice
			span = maxf(span, delay)
			spikes.append([SimPlane.to_3d(at, 0.0), b, height, delay, VfxCore.h(sd, j + li * 500)])
			if j % 3 == 0:  # the floor's grit kicked up as its spike bursts out
				dust.append(SimPlane.to_3d(at, 0.0))
				delays.append(delay / 60.0)
		for k in range(MARKS_EACH_WAY + 1):
			var along := MARK_STEP * k
			if along <= o.half.x * 2.0 and (li == 0 or k > 0):
				marks.append(SimPlane.to_3d(start + o.axis_u * along, 0.0))
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
			"span": span
		}
	)
	slams.kick(dust, KICK_SIZE, delays)


## Where a marker's lanes start: the first lane's start at the boss's edge.
static func _origin(obbs: Array) -> Vector2:
	var a: Obb = obbs[0]
	return a.center - a.axis_u * a.half.x


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
	n = _draw_quakes(buf, n, now, still)  # v0.11.0 O3
	_draw_rings(now, still)
	var mm := _node.multimesh
	if n > 0:
		buf.resize(mm.instance_count * 16)
		mm.buffer = buf
	mm.visible_instance_count = n
	_drawn = n


## Each standing pillar is a cluster of the same stone spikes,
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


## A VfxCore drawer (WorldViewRoot adds it): the crack marks each strike leaves along its lanes (its grit and dust
## are GroundSlamViews' kicks, with no light).
func draw_fx(layer: VfxCore) -> void:
	var now := float(_tick) + Engine.get_physics_interpolation_fraction()
	for s in _strikes:
		var age := now - float(s["tick"])
		if age < 0.0 or age > LIFE_TICKS + float(s.get("span", SPREAD_TICKS)):
			continue
		var sd: int = s["seed"]
		var marks: Array = s["marks"]
		for k in marks.size():
			layer.mark(sd * 16 + k, BossStrikeFx.crack_mark(), marks[k], 1.1, CRACK_MARK)


# --- v0.11.0 O3: the quake pillars -------------------------------------------------------------------------------


## The quake pillars standing now; one standing at the last sync and gone now (its lanes shattered it, or its boss
## fell) bursts.
func _sync_quakes(list: Array) -> void:
	var now := {}
	for q: Dictionary in list:
		if not q.has("javelin"):  # A great javelin's ring leaves no pillar to shatter
			now["%s:%d" % [str(q["center"]), int(q["rose"])]] = q["center"]
	for key: String in _quake_seen.keys():
		if not now.has(key):
			_shatter(_quake_seen[key], _tick)
	_quake_seen = now
	_quakes = list


## Quake pillars drawn in the last draw (tests and the shots).
func quake_count() -> int:
	return _quakes.size()


## Ring bands drawn in the last draw (tests: a growing ring, its outline, a flash).
func ring_bands() -> int:
	return _ring_bands


## [ticks since pillar q's last pulse (or its rise), the ring's growth 0..1 over its warning (-1 outside it), the
## crack's flare 0..1 after a pulse] at view time `now`. The reader's tick is the next one to run: a pulse struck on
## the tick before it.
static func quake_clock(q: Dictionary, now: float) -> Array:
	var pulse := float(q["pulse_ticks"])
	var warn := float(q["warn_ticks"])
	var age := now - float(q["rose"]) - 1.0
	var into := fposmod(age, pulse)
	var grow := -1.0
	if into >= pulse - warn:
		grow = clampf((into - (pulse - warn)) / maxf(1.0, warn), 0.0, 1.0)
	var flare := 0.0
	if age >= pulse and into < QUAKE_FLARE_TICKS:
		flare = 1.0 - into / QUAKE_FLARE_TICKS
	return [into, grow, flare]


## Each quake pillar: a tall spike filling its square and QUAKE_SATELLITES shorter ones round it, risen with the phase,
## its cracks at rest heat, warming as its ring grows and flaring on the pulse. Appends to `buf` from instance n.
func _draw_quakes(buf: PackedFloat32Array, n: int, now: float, still: bool) -> int:
	for q: Dictionary in _quakes:
		if q.has("javelin"):  # Only its ring (GreatJavelinViews draws the javelin)
			continue
		var c: Vector2 = q["center"]
		var h := float(q["half"])
		var age := now - float(q["rose"]) + 1.0
		var e := 1.0 if age >= RISE_TICKS else extent(age, still)
		if e <= 0.001:
			continue
		var clock := quake_clock(q, now)
		var heat := QUAKE_REST_HEAT
		if float(clock[1]) >= 0.0:
			heat += (1.0 - QUAKE_REST_HEAT) * float(clock[1]) * float(clock[1])
		heat = maxf(heat, float(clock[2]))
		var sd := int(absf(c.x) * 131.0) + int(absf(c.y) * 17.0) * 7 + 3
		for j in QUAKE_SATELLITES + 1:
			if n >= MAX_SPIKES:
				return n
			var tall := QUAKE_TALL * (0.95 + 0.1 * VfxCore.h(sd, j))
			var width := h * 2.0 * QUAKE_WIDE
			var at := c
			var turn := Basis(Vector3.UP, TAU * VfxCore.h(sd + 1, j))
			if j > 0:
				var ang := TAU * (j - 1) / QUAKE_SATELLITES + 0.5 * VfxCore.h(sd + 2, j)
				at = c + Vector2(cos(ang), sin(ang)) * h * 0.85
				tall *= 0.5
				width *= 0.45
				var out := (SimPlane.to_3d(at) - SimPlane.to_3d(c)).normalized()
				turn = Basis(out.cross(Vector3.UP).normalized(), -0.22) * turn
			var b := Basis(turn.x * width, turn.y * tall, turn.z * width)
			var base := SimPlane.to_3d(at, 0.0)
			buf.append_array(_instance(b, base - Vector3.UP * (tall * (1.0 - e)), heat, sd + j))
			n += 1
			_bases.append(base)
	return n


## One spike's 16 floats (its basis and origin, its heat and seed).
static func _instance(b: Basis, o: Vector3, heat: float, sd: int) -> PackedFloat32Array:
	return PackedFloat32Array(
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
			VfxCore.h(sd, 3),
			0.0,
			0.0
		]
	)


## The rings: while a pillar's warning runs, a dark ripple in the floor grows from the pillar out to the radius its
## pulse hits, over a faint dark outline of that radius; as it strikes, a thin bright edge flashes at that radius and
## fades. Rebuilt every draw.
func _draw_rings(now: float, still: bool) -> void:
	# An empty mesh is left alone: clearing it still has the renderer update every instance of it
	if _ring_mesh.get_surface_count() > 0:
		_ring_mesh.clear_surfaces()
	var bands := []
	for q: Dictionary in _quakes:
		var c: Vector2 = q["center"]
		var r := float(q["ring"])
		var clock := quake_clock(q, now)
		var grow := float(clock[1])
		if grow >= 0.0:
			var inner := float(q["half"]) * 1.45
			bands.append([c, lerpf(inner, r, grow), RING_BAND_M * 3.0, 0.2 + 0.25 * grow, RIPPLE])
			bands.append([c, r, RING_BAND_M * 0.6, 0.25, RIPPLE])
		var flare := float(clock[2])
		if flare > 0.0:
			var u := 1.0 - flare
			var spread := 0.0 if still else 0.08 * u
			bands.append(
				[c, r * (1.0 + spread), RING_BAND_M * (0.3 + 0.5 * flare), flare, RING_COLOR]
			)
	_ring_bands = bands.size()
	if bands.is_empty():
		return
	_ring_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for bd: Array in bands:
		_band(bd[0], float(bd[1]), float(bd[2]), Color(bd[4], clampf(float(bd[3]), 0.0, 1.0)))
	_ring_mesh.surface_end()


## A flat annulus round c at radius r, `width` wide, in `col`.
func _band(c: Vector2, r: float, width: float, col: Color) -> void:
	var steps := 40
	var r0 := maxf(0.0, r - width * 0.5)
	var r1 := r + width * 0.5
	for s in steps:
		var a0 := TAU * s / steps
		var a1 := TAU * (s + 1) / steps
		var p := [
			SimPlane.to_3d(c + Vector2(cos(a0), sin(a0)) * r0, 0.045),
			SimPlane.to_3d(c + Vector2(cos(a0), sin(a0)) * r1, 0.045),
			SimPlane.to_3d(c + Vector2(cos(a1), sin(a1)) * r1, 0.045),
			SimPlane.to_3d(c + Vector2(cos(a1), sin(a1)) * r0, 0.045)
		]
		for k: int in [0, 1, 2, 0, 2, 3]:
			_ring_mesh.surface_set_color(col)
			_ring_mesh.surface_add_vertex(p[k])


## A shattered quake pillar at c on `tick`: short broken spikes thrown up round it and sinking, the stone slam's chunks
## and grit (GroundSlamViews) and a crack mark (draw_fx), as a strike without lanes.
func _shatter(c: Vector2, tick: int) -> void:
	var sd := tick * 37 + int(absf(c.x) * 89.0) + int(absf(c.y) * 11.0)
	var spikes := []
	for j in RUBBLE:
		var ang := TAU * j / RUBBLE + 0.6 * VfxCore.h(sd, j)
		var at := c + Vector2(cos(ang), sin(ang)) * (0.3 + 0.5 * VfxCore.h(sd + 1, j))
		var height := lerpf(0.35, 0.7, VfxCore.h(sd + 2, j))
		var width := lerpf(0.25, 0.4, VfxCore.h(sd + 3, j))
		var out := (SimPlane.to_3d(at) - SimPlane.to_3d(c)).normalized()
		var turn := Basis(out.cross(Vector3.UP).normalized(), -0.7) * Basis(Vector3.UP, TAU * ang)
		var b := Basis(turn.x * width, turn.y * height, turn.z * width)
		spikes.append(
			[SimPlane.to_3d(at, 0.0), b, height, VfxCore.h(sd + 4, j), VfxCore.h(sd + 5, j)]
		)
	while _strikes.size() >= MAX_STRIKES:
		_strikes.pop_front()
	var mark := SimPlane.to_3d(c, 0.0)
	slams.slam(mark, SHATTER_M, {"parts": SHATTER})
	_strikes.append(
		{"tick": tick, "seed": sd, "center": mark, "spikes": spikes, "marks": [mark], "quake": true}
	)

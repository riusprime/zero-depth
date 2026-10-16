class_name BossStrikeViews
extends Node3D
## v0.8.0 AV part 2 (owner O7: "so the attacks look real … not … a red thingy"): the strike of every boss ground
## attack with a look (BossStrikeLooks) as a real 3D effect, as StoneSpikeViews does for the Gatekeeper's shock lanes:
## - Gatekeeper: a fist slam blows a crater (rocks thrown up, a dust shockwave, a hot cracked bowl); its sweep a dust
##   arc.
## - Warlord: spear lines thrust up rows of spears along the lanes (they stand while the lanes do, then retract); the
##   lunge leaves a scorched skid with sparks behind it; the shield bash a steel arc; the javelin rain plants javelins.
## - Brood Mother: an egg's circle gets the egg's shadow growing as it falls, then an acid splat; a leap lands as a
##   cracked impact with dust; a burrow erupts as a ring of dirt and rock; a brood hatches out of acid splats.
## - Hive Lens: the focus beam fires as a 3D beam down the locked lanes; the lens flare is a light shockwave ring; a
##   dive and a split flash as bursts of light.
## - Siege Engine: mortar and barrage shells fall onto their circles and explode (fireball, debris, a scorched crater);
##   the rail fires a streak down its lane and leaves a scorched line; the shockwave rolls out as a dust wall.
## - Foundry: the molten flood pours molten metal down the lanes, which cools from hot seams to a dark crust; the vent
##   blast is a ring of steam and heat; the firestorm sets the lanes burning; the bombs explode as shells.
## The strike is read, never decided (EI-07): the tick a marker shows locked at progress 1000 (BossDodge.mark_state 2
## and grid_state 2), the tick a windup turns active (the hit resolves on that tick), the tick a leap lands (boss_leap
## at 1.0) and the tick a burrow comes up (boss_hidden turns false), all from WorldReader; the geometry is the
## telegraph's, the very shapes the hit is resolved from. The sim's timings are unchanged. Sustained strikes (spears,
## beams, molten and burning lanes, the skid) last while the boss stays active in that move.
## Pooled: six MultiMeshes (rocks, blades, glowing bands, dust bands, beams, ground quads; one draw each) with fixed
## caps, two rebuilt arc meshes, at most MAX_STRIKES strikes alive. With the new look's effects layer (VfxCore) the
## strikes add sprites (debris, dust, smoke, sparks, flames), lights (through the 10-light pool, merged), floor marks
## (the decal cap) and explosions (VfxLayer.burst, the frame's burst budget; BurstBudget for the live ones).
## Effects density thins the rocks and the sprites (the blades and the ground stay: they show where it hit); reduced
## motion stills the tumbling, the overshoot and the shaders' flow. No camera shake is added.

const MAX_STRIKES := 24
## Pool -> [cap].
const CAPS := {
	&"rock": 384,
	&"blade": 384,
	&"band_add": 64,
	&"band_mix": 48,
	&"beam": 32,
	&"ground": 160,
}
const DENSITY := {"low": 0.4, "medium": 0.7, "high": 1.0}
## Ticks each strike kind lasts after its strike (after its end for the sustained ones).
const LIFE := {
	&"crater": 48.0,
	&"acid_splat": 70.0,
	&"crack_impact": 40.0,
	&"eruption": 54.0,
	&"shell": 44.0,
	&"javelins": 80.0,
	&"light_burst": 30.0,
	&"light_ring": 30.0,
	&"shock_ring": 40.0,
	&"steam_ring": 54.0,
	&"dust_arc": 22.0,
	&"steel_arc": 18.0,
	&"spears": 16.0,
	&"beam": 16.0,
	&"rail": 26.0,
	&"molten": 100.0,
	&"fire_lanes": 40.0,
	&"skid": 100.0,
}
## v0.8.0 FB3: the Nemesis's moves that strike on the tick their telegraph says "striking".
const NEMESIS_MOVES: Array[int] = [WorldReader.MOVE_MIMIC_COMBO, WorldReader.MOVE_CARD_CAST]
const SUSTAINED: Array[StringName] = [&"spears", &"beam", &"molten", &"fire_lanes", &"skid"]
## A marker strike already raised is not raised again for this many ticks (one strike, seen once).
const SEEN_TICKS := 30
const CRACK_MARK := Color(0.07, 0.05, 0.045, 0.85)
## A mark key well apart from VfxLayer's and StoneSpikeViews' (keys only suppress repeats).
const MARK_BASE := 1 << 40

## The effects layer for the sprites, lights, floor marks and explosions (WorldViewRoot sets it with the new look).
var vfx: VfxCore
## Live strikes: {"look", "kind", "tick", "end" (-1 while sustained), "aid", "seed", "glow", "glow_i", and the
## geometry: "discs" [[centre, radius, fx?]], "ring" [centre, inner, outer], "arc" [centre, own_r, reach, a0, a1],
## "lanes" [Obb], or "lane" Obb with "from"/"to" (the skid)}.
var _strikes: Array[Dictionary] = []
## Marker strikes already raised, by key (the boss's id and the circle's centre), with their tick.
var _seen := {}
## A locked marker's progress when it was first seen locked (how far its egg or shell has fallen).
var _lock0 := {}
## Per boss id: {"state", "move", "tg" (its last windup telegraph), "hidden", "disc" [centre, radius]}.
var _last := {}
## This tick's falling eggs and shells: [look, centre, radius, fall 0..1, lobbed].
var _incoming: Array = []
## The live explosions and splats (BurstBudget.admit's list).
var _bursts: Array[Dictionary] = []
var _tick := 0
var _pools := {}
var _swoosh_add := MeshInstance3D.new()
var _swoosh_mix := MeshInstance3D.new()
var _glow_mats: Array[ShaderMaterial] = []
var _shapes := BossStrikeShapes.new()


func _init() -> void:
	name = "BossStrikes"
	_shapes.pools = _pools
	_pool(&"rock", BossStrikeMeshes.rock(), _mat(BossStrikeMeshes.ROCK), true)
	_pool(&"blade", BossStrikeMeshes.blade(), _mat(BossStrikeMeshes.BLADE), true)
	_pool(&"band_add", BossStrikeMeshes.band(), _glow(BossStrikeMeshes.GLOW % "blend_add"), false)
	_pool(&"band_mix", BossStrikeMeshes.band(), _glow(BossStrikeMeshes.GLOW % "blend_mix"), false)
	var beam := _glow(BossStrikeMeshes.GLOW % "blend_add")
	var strip := FxTextures.get_tex("fx_beam")  # v0.8.0 TX1: the Focus Beam in the owner's beam strip
	if strip != null:
		beam.set_shader_parameter("beam_tex", strip)
		beam.set_shader_parameter("tex_on", 1.0)
	_pool(&"beam", BossStrikeMeshes.tube(), beam, false)
	var ground := _glow(BossStrikeMeshes.GROUND)
	ground.render_priority = 1  # over the telegraph's fill of the same lanes (both transparent)
	_pool(&"ground", BossStrikeMeshes.ground(), ground, false)
	for pair: Array in [[_swoosh_add, "SwooshAdd", true], [_swoosh_mix, "SwooshMix", false]]:
		var mi: MeshInstance3D = pair[0]
		mi.name = pair[1]
		mi.mesh = ImmediateMesh.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.no_depth_test = false
		if pair[2]:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mi.material_override = m
		add_child(mi)


func _mat(code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BossStrikeMeshes.shader(code)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	return m


func _glow(code: String) -> ShaderMaterial:
	var m := _mat(code)
	_glow_mats.append(m)
	return m


func _pool(id: StringName, mesh: Mesh, mat: Material, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = int(CAPS[id])
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = "Strike_" + String(id)
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	node.extra_cull_margin = 16384.0  # the instances spread over the whole room
	add_child(node)
	_pools[id] = {"mm": mm, "used": 0, "cap": int(CAPS[id]), "drawn": 0}


# --- Reading the strikes -----------------------------------------------------------------------------------------
func sync(reader: WorldReader) -> void:
	if reader.tick() < _tick:  # a new floor's world: its ticks start again
		_strikes.clear()
		_seen.clear()
		_lock0.clear()
		_last.clear()
		_bursts.clear()
	_tick = reader.tick()
	_incoming.clear()
	var alive := {}
	for i in reader.actor_count():
		var kind := reader.actor_kind(i)
		if not WorldReader.is_boss_kind(kind):
			continue
		var aid := reader.actor_id(i)
		alive[aid] = true
		var tg := reader.telegraph(i)
		var move := reader.boss_move(i)
		var state := reader.actor_state(i)
		var hidden := reader.boss_hidden(i)
		var prev: Dictionary = _last.get(aid, {})
		var look := BossStrikeLooks.look_for(kind, move)
		if look != &"":
			_detect(reader, i, aid, look, move, state, hidden, tg, prev)
		var now := {"state": state, "move": move, "hidden": hidden}
		now["tg"] = tg if state == WorldReader.STATE_WINDUP and not tg.is_empty() else {}
		if tg.get("shape", &"") == &"disc":
			now["disc"] = [tg["center"], float(tg["radius"])]
		elif prev.has("disc") and prev.get("move", -1) == move:
			now["disc"] = prev["disc"]
		_last[aid] = now
	for aid in _last.keys():
		if not alive.has(aid):
			_last.erase(aid)
	_keep_up(reader)
	_prune()
	_draw(float(_tick))


func _process(_delta: float) -> void:
	if not _strikes.is_empty() or not _incoming.is_empty():
		_draw(float(_tick) + Engine.get_physics_interpolation_fraction())


func _detect(
	reader: WorldReader,
	i: int,
	aid: int,
	look: StringName,
	move: int,
	state: int,
	hidden: bool,
	tg: Dictionary,
	prev: Dictionary
) -> void:
	if move == WorldReader.MOVE_MARKS or move == WorldReader.MOVE_GRID:
		if tg.get("shape", &"") == &"marks":
			_detect_marks(aid, look, tg)
		return
	if move == WorldReader.MOVE_COMBO or NEMESIS_MOVES.has(move):
		_detect_strikes(aid, move, tg)
		return
	if move == WorldReader.MOVE_SPIKE_CHASE or move == WorldReader.MOVE_SPIKE_BURST:
		return  # v0.8.0 FB1: StoneSpikeViews raises them
	if move == WorldReader.MOVE_LEAP:
		var leap := reader.boss_leap(i)
		if bool(leap[0]) and float(leap[1]) >= 1.0 and tg.get("shape", &"") == &"disc":
			_spawn(look, aid, {"discs": [[tg["center"], float(tg["radius"])]]})
		return
	if move == WorldReader.MOVE_BURROW:
		if (
			bool(prev.get("hidden", false))
			and not hidden
			and state == WorldReader.STATE_ACTIVE
			and prev.has("disc")
		):
			_spawn(look, aid, {"discs": [[prev["disc"][0], float(prev["disc"][1])]]})
		return
	if (
		int(prev.get("state", -1)) != WorldReader.STATE_WINDUP
		or state != WorldReader.STATE_ACTIVE
		or int(prev.get("move", -1)) != move
	):
		return
	var t0: Dictionary = prev.get("tg", {})
	match t0.get("shape", &""):
		&"ring":
			_spawn(look, aid, {"ring": [t0["center"], float(t0["inner"]), float(t0["outer"])]})
		&"lanes":
			_spawn(look, aid, {"lanes": t0["obbs"]})
		&"arc":
			var a := TAU * float(t0["angle"]) / 4096.0
			var h := TAU * float(t0["half_arc"]) / 4096.0
			var r0 := float(t0["own_r"])
			_spawn(look, aid, {"arc": [t0["center"], r0, r0 + float(t0["reach"]), a - h, a + h]})
		&"lane":
			var o: Obb = t0["obb"]
			var back := o.center - o.axis_u * o.half.x
			_spawn(look, aid, {"lane": o, "from": back, "to": reader.actor_pos(i)})
		&"discs":
			var discs := []
			for c: Vector2 in t0["centers"]:
				discs.append([c, float(t0["radius"])])
			_spawn(look, aid, {"discs": discs})


## A marker (or grid) telegraph: each circle strikes on the tick it shows locked at 1000; before that, a falling egg's
## or shell's shadow grows on it.
func _detect_marks(aid: int, look: StringName, tg: Dictionary) -> void:
	var strike := BossStrikeLooks.strike_of(look)
	var falls := strike == &"shell" or strike == &"acid_splat"
	var discs := []
	for item: Dictionary in tg["items"]:
		if not item.get("locked", false) or item.get("shape", &"") != &"disc":
			continue
		var c: Vector2 = item["center"]
		var key := "%d:%s" % [aid, str(c)]
		var pr := int(item.get("progress", 0))
		if pr < 1000:
			if not falls:
				continue
			if not _lock0.has(key):
				_lock0[key] = pr
			var f := float(pr - int(_lock0[key])) / maxf(1.0, 1000.0 - float(_lock0[key]))
			var lob: Dictionary = item.get("lob", {})
			if not lob.is_empty():
				f = float(lob.get("progress", 0)) / 1000.0
			_incoming.append(
				[look, c, float(item["radius"]), clampf(f, 0.0, 1.0), not lob.is_empty()]
			)
			continue
		_lock0.erase(key)
		if _seen.has(key) and _tick - int(_seen[key]) < SEEN_TICKS:
			continue
		_seen[key] = _tick
		discs.append([c, float(item["radius"])])
	if not discs.is_empty():
		_spawn(look, aid, {"discs": discs})


## v0.8.0 FB1: the Colossus's combo strikes on the tick its telegraph says "striking": a swing throws a dust arc where
## it locked, the closing slam blows a crater round its feet.
func _detect_combo(aid: int, tg: Dictionary) -> void:
	if not bool(tg.get("striking", false)):
		return
	match tg.get("shape", &""):
		&"arc":
			var a := TAU * float(tg["angle"]) / 4096.0
			var h := TAU * float(tg["half_arc"]) / 4096.0
			var r0 := float(tg["own_r"])
			_spawn(
				&"cl_fists", aid, {"arc": [tg["center"], r0, r0 + float(tg["reach"]), a - h, a + h]}
			)
		&"disc":
			_spawn(&"cl_slam", aid, {"discs": [[tg["center"], float(tg["radius"])]]})


## v0.8.0 FB1: the Colossus's combo (each swing and the slam on the tick it lands); FB3: the Nemesis's swings, a card's
## arc and blast.
func _detect_strikes(aid: int, move: int, tg: Dictionary) -> void:
	if move == WorldReader.MOVE_COMBO:
		_detect_combo(aid, tg)
	else:
		_detect_nemesis(aid, tg)


## v0.8.0 FB3: the Nemesis's strikes on the tick its telegraph says "striking": a combo swing's arc, a card's arc
## (each repeat) and its blast, in its own look.
func _detect_nemesis(aid: int, tg: Dictionary) -> void:
	if not bool(tg.get("striking", false)):
		return
	var items: Array = tg.get("strike_items", [tg])
	for item: Dictionary in items:
		match item.get("shape", &""):
			&"arc":
				var a := TAU * float(item["angle"]) / 4096.0
				var h := TAU * float(item["half_arc"]) / 4096.0
				var r0 := float(item["own_r"])
				_spawn(
					&"nm_slash",
					aid,
					{"arc": [item["center"], r0, r0 + float(item["reach"]), a - h, a + h]}
				)
			&"disc":
				_spawn(&"nm_cast", aid, {"discs": [[item["center"], float(item["radius"])]]})


## The sustained strikes follow their boss: the skid runs to where the boss is now; each ends when its boss leaves
## the active move (or is gone).
func _keep_up(reader: WorldReader) -> void:
	for s in _strikes:
		if int(s["end"]) >= 0:
			continue
		var i := reader.actor_index(int(s["aid"]))
		var on := i >= 0 and reader.actor_state(i) == WorldReader.STATE_ACTIVE
		var last: Dictionary = _last.get(int(s["aid"]), {})
		on = (
			on
			and (
				BossStrikeLooks.look_for(reader.actor_kind(i), int(last.get("move", -1)))
				== s["look"]
			)
		)
		if on and s.has("lane"):
			s["to"] = reader.actor_pos(i)
		if not on:
			s["end"] = _tick


func _prune() -> void:
	var keep: Array[Dictionary] = []
	for s in _strikes:
		var from := int(s["end"]) if int(s["end"]) >= 0 else _tick
		if _tick - from <= int(LIFE[s["kind"]]):
			keep.append(s)
	_strikes = keep
	for key in _seen.keys():
		if _tick - int(_seen[key]) > SEEN_TICKS * 4:
			_seen.erase(key)
	if _lock0.size() > 256:
		_lock0.clear()
	var live: Array[Dictionary] = []
	for b in _bursts:
		if float(_tick) - float(b["start"]) <= LIFE[&"shell"]:
			live.append(b)
	_bursts = live


func _spawn(look: StringName, aid: int, geo: Dictionary) -> void:
	var kind := BossStrikeLooks.strike_of(look)
	var s := geo.duplicate()
	s["look"] = look
	s["kind"] = kind
	s["tick"] = _tick
	s["end"] = -1 if SUSTAINED.has(kind) else _tick
	s["aid"] = aid
	s["seed"] = (_tick * 131 + aid * 7 + _strikes.size() * 3) & 0xFFFFFF
	s["glow"] = BossStrikeLooks.glow_of(look)
	s["glow_i"] = _glow_index(BossStrikeLooks.pattern_of(look))
	if s.has("discs") and (kind == &"shell" or kind == &"acid_splat"):
		for d: Array in s["discs"]:  # v0.8.0 PF's budget: crowded explosions merge, the oldest go
			var e := {"origin": d[0], "start": float(_tick), "vfx_burst": true}
			var r := BurstBudget.admit(_bursts, e)
			d.append(r != BurstBudget.MERGED)
			if r >= 0:
				_bursts.remove_at(r)
			if r != BurstBudget.MERGED:
				_bursts.append(e)
	while _strikes.size() >= MAX_STRIKES:
		_strikes.pop_front()
	_strikes.append(s)


static func _glow_index(pattern: int) -> float:
	match pattern:
		BossStrikeLooks.Pattern.ACID:
			return 1.0
		BossStrikeLooks.Pattern.LIGHT:
			return 2.0
		BossStrikeLooks.Pattern.MOLTEN:
			return 3.0
	return 0.0


# --- Counts (tests and the tour) ---------------------------------------------------------------------------------
func strike_count() -> int:
	return _strikes.size()


## The live strikes' [look, kind, tick] (tests).
func strikes() -> Array:
	var out := []
	for s in _strikes:
		out.append([s["look"], s["kind"], s["tick"]])
	return out


## Instances pool `pool` drew in the last draw.
func drawn(pool: StringName) -> int:
	return int(_pools[pool]["drawn"])


## Every pool's drawn instances in the last draw, and the arc meshes' quads.
func drawn_total() -> int:
	var n := 0
	for id: StringName in _pools:
		n += drawn(id)
	return n + (_shapes.arc_add.size() + _shapes.arc_mix.size()) / 6


func pool_cap(pool: StringName) -> int:
	return int(_pools[pool]["cap"])


func multimesh(pool: StringName) -> MultiMesh:
	return _pools[pool]["mm"]


func falling_count() -> int:
	return _incoming.size()


func live_bursts() -> int:
	return _bursts.size()


# --- Drawing -----------------------------------------------------------------------------------------------------


func _draw(now: float) -> void:
	for p: Dictionary in _pools.values():
		p["used"] = 0
	_shapes.arc_add.clear()
	_shapes.arc_mix.clear()
	var still := ViewPrefs.reduced_motion
	for m in _glow_mats:
		m.set_shader_parameter("motion", 0.0 if still else 1.0)
	var dens: float = DENSITY.get(ViewPrefs.effects_density, 1.0)
	for s in _strikes:
		var age := now - float(s["tick"])
		var after := now - float(s["end"]) if int(s["end"]) >= 0 else -1.0
		_shapes.strike(s, age, after, dens, still)
	for f: Array in _incoming:
		_shapes.falling(f)
	for p: Dictionary in _pools.values():
		(p["mm"] as MultiMesh).visible_instance_count = int(p["used"])
		p["drawn"] = p["used"]
	_emit(_swoosh_add, _shapes.arc_add)
	_emit(_swoosh_mix, _shapes.arc_mix)


func _emit(mi: MeshInstance3D, verts: Array) -> void:
	var im := mi.mesh as ImmediateMesh
	im.clear_surfaces()
	if verts.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Array in verts:
		im.surface_set_color(v[1])
		im.surface_set_normal(Vector3.UP)
		im.surface_add_vertex(v[0])
	im.surface_end()


# --- The effects layer -------------------------------------------------------------------------------------------
## A VfxCore drawer (WorldViewRoot adds it): each strike's sprites (debris, dust, smoke, sparks, flames), its light
## (merged, into the 10-light pool), its floor marks (the decal cap) and its explosions (VfxLayer.burst: the frame's
## burst budget). Thinned with the layer's density.
func draw_fx(layer: VfxCore) -> void:
	BossStrikeFx.draw(layer, _strikes, float(_tick) + Engine.get_physics_interpolation_fraction())

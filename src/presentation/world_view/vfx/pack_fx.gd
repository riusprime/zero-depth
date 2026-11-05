class_name PackFx
extends Node3D
## v0.10.0 VX0 (docs/roadmap/v0.9.5/VFX_PACK.md I1-I9; the owner's purchased Binbun VFX pack): the one way the game
## spawns a pack effect. Each effect is a pooled scene (assets/BinbunVFX/...) named by a short id in
## data/vfx/pack_fx.tres (PackFxDefinition). Cosmetic only: it reads the sim through the caller's position and
## decides nothing (EI-03, EI-07).
## - spawn(id, pos, scale, colors): an idle instance (or a new one) is moved, recoloured, restarted and shown; it goes
##   back to its pool when its animation ends or after its life (I5).
## - Caps per family (CAPS, I5), scaled by Effects density (ViewPrefs.effects_density, I9). Past a cap the family's
##   oldest live instance is reused.
## - Lights are off on every instance (I3): a family that should glow asks VfxCore for its merged light.
## - Colours (I6): the table's, or the caller's (`primary`, `secondary`, `tertiary`); an alpha of 0 keeps the scene's.
## - Pause (I8): while the sim holds (follow() sees no tick for HOLD_S), every live instance's speed_scale is 0.
## - warm(id) (I2): the id once, in front of the camera, for WARM_FRAMES frames, so its shaders compile before the first
##   fight. v0.10.0 VX-W: once a session, at the main menu (PackFxSessionWarm), never one spawn an id on every floor
##   load; the effect scenes are kept for the session, so a later floor reuses the compiled pipelines.

## Live instances per family at Effects density High (I5; starting values).
const CAPS := {
	&"hit": 24,
	&"impact": 12,
	&"explosion": 12,
	&"area": 16,
	&"beam": 8,
	&"cloud": 4,
	&"projectile": 96,
	&"status": 32,
	&"enemy_shot": 128,  # v0.10.0: hostile shots have their own cap, so hero bolts never starve them
	&"bolt": 48,  # v0.10.0 VX6: lightning strikes, chains and forks
	&"trail": 8,  # v0.10.0 VX8: blade swing ribbons
	&"mark": 48,  # v0.10.0 VX7: lasting floor marks
}
## v0.10.0 FX (owner, 2026-10-31: oversized glows and flares, "lighting artifacts"): the pack's particles live in world
## space, and Godot does not size a world-space particle by its node's scale, so a spark scaled to 0.1 still drew its
## flares and glows full size (the white starbursts at every bolt's end, the hits' flashes). Every effect that stands
## where it was spawned now has local particles (the node's scale sizes them); only the families that fly keep world
## space, for their trails (FireballViews and the forms size those by hand).
const WORLD_SPACE: Array[StringName] = [&"projectile", &"enemy_shot", &"trail"]
## v0.10.0 FX (owner, 2026-10-31: effects "appear in unintended screen positions"): the pack's particles live in
## world space, so a held effect moved further than JUMP_M in one frame (a key handed to another shot, a pooled
## instance taken over) would draw its old trail across the screen; settle() starts its particles again.
const JUMP_M := 1.5
## ViewPrefs.effects_density -> the factor on CAPS (I9).
const DENSITY_FACTOR := {"low": 0.25, "medium": 0.55, "high": 1.0}
const DEFS_DIR := "res://data/vfx"
const WARM_FRAMES := 2
## Real seconds without a new sim tick before the effects hold (a pause); well over a frame at 30 fps.
const HOLD_S := 0.1
## A little past an effect's own length before it returns to its pool (s).
const LIFE_MARGIN_S := 0.1
const ANIM := &"main"
const WARM_AHEAD_M := 2.0
## v0.10.5 W3-S4 (owner F10, 2026-11-04: attack particles "remain visible for several seconds after impact ...
## approximately 0.2 seconds would feel more appropriate"): a player hit's scenes (the bolt and slash hits, the heavy
## impacts, the guard / weak / deflect sparks, the forms' crit, bounce and rune hits) ran their own 0.8-1.3 s (an
## animated scene's particles re-emitted for all of it, an impact's smoke lived 1.2 s). Now each plays whole within
## [seconds] (its scene sped up) and goes back to its pool once the draw time is [ticks] sim ticks past its spawn
## (follow() reads VfxCore.now, so it pauses and replays with the sim; no Timer). Starting values.
const SHORT := {
	&"vx1_hit_ember": [0.2, 15.0],
	&"vx1_hit_frost": [0.2, 15.0],
	&"vx1_hit_storm": [0.2, 15.0],
	&"vx1_hit_venom": [0.2, 15.0],
	&"vx1_hit_bleed": [0.2, 15.0],
	&"vx1_hit_plain": [0.2, 15.0],
	&"vx1_slash": [0.2, 15.0],
	&"vx1_guard": [0.2, 15.0],
	&"vx1_weak": [0.2, 15.0],
	&"vx1_deflect": [0.2, 15.0],
	&"vx1_impact_ember": [0.25, 18.0],
	&"vx1_impact_frost": [0.25, 18.0],
	&"vx1_impact_other": [0.25, 18.0],
	&"vx2_hit_rune": [0.2, 15.0],
	&"vx2_hit_bounce": [0.2, 15.0],
	&"vx2_hit_crit": [0.2, 15.0],
}

static var _shared: PackFxDefinition
## How floor loads warm the pack (VX-W): &"menu" (PackFxSessionWarm warms at the main menu; a load warms what is
## left), &"session" (the first load warms everything, later loads nothing), &"load" (every load warms every id: VX0),
## &"none". The probes set it (scripts/checks/load_probe.gd --warm=).
static var warm_mode := &"menu"
static var _scenes := {}  # scene path -> PackedScene, kept for the session
static var _requested := {}  # scene path -> true, once asked of the loader threads
static var _warmed := {}  # id -> true, once warm() ran it this session
## v0.10.5: id -> the most instances of it live at once this session (PackPrefill sizes a floor's pools by it).
static var _peak := {}

## The camera the warm-up places the effects in front of (WorldViewRoot sets it).
var camera: Camera3D = null
var spawned := 0
var reused := 0

var _def: PackFxDefinition
## id -> Array[Node3D]. v0.10.5 PC (owner PERF_PLAYLOG_2: the filled pools put ~2,300 idle nodes in the tree, paid
## for every frame): an idle instance waits outside the scene tree (kept here, freed with the pack) and joins it again
## when spawned.
var _idle := {}
var _live: Array[Dictionary] = []  # oldest first: {node, id, family, left}
var _info := {}  # Node3D -> {anim, colors, speed, life, lights}
var _live_n := {}  # id -> its live instances
## v0.10.5 W3-Q6: the live instances by instance id, and how many each family has live, kept with _live, so is_live
## and has_room (every held effect asks them every frame) read one key instead of walking every live effect.
var _live_ids := {}
var _family_n := {}
var _held := false
var _warm_nodes: Array[Dictionary] = []  # {node, left: frames}
var _last_tick := -1
var _tick_at_ms := 0
var _now := 0.0  # the draw time (sim ticks) of the last follow()


func _init(def: PackFxDefinition = null) -> void:
	_def = def if def != null else shared_def()


## The table in data/vfx (discovered through ContentScanner), or null without it. v0.10.0: every PackFxDefinition
## there joins one table (each VX step ships its own file, data/vfx/pack_fx_<step>.tres), in path order.
static func shared_def() -> PackFxDefinition:
	if _shared == null:
		var paths := Array(ContentScanner.scan(DEFS_DIR))
		paths.sort()
		for path: String in paths:
			var d := load(path) as PackFxDefinition
			if d == null:
				continue
			if _shared == null:
				_shared = d.duplicate(true) as PackFxDefinition
			else:
				_shared.append_rows(d)
	return _shared


## True when the table is there.
static func available() -> bool:
	return shared_def() != null


func has_id(effect_id: StringName) -> bool:
	return _def != null and _def.row(effect_id) >= 0


## The live cap of `family` at the current Effects density, at least 1 (I9).
func cap_for(family: StringName) -> int:
	var f: float = DENSITY_FACTOR.get(ViewPrefs.effects_density, 1.0)
	return maxi(1, ceili(float(CAPS.get(family, 8)) * f))


func live_count(family: StringName = &"") -> int:
	if family == &"":
		return _live.size()
	return int(_family_n.get(family, 0))


## The instances of `effect_id` the pool holds (live or idle).
func pooled(effect_id: StringName) -> int:
	var n: int = (_idle.get(effect_id, []) as Array).size()
	for e in _live:
		if e["id"] == effect_id:
			n += 1
	return n


## Plays effect `effect_id` at world position `pos`, `scale` times the table's scale; `colors` may hold `primary`,
## `secondary` and `tertiary`. Returns the instance (null for an unknown id). v0.10.0: `life` -1 is the scene's own
## length; 0 keeps it until the caller's release() (a bolt, a zone, a status that follows something); above 0, seconds.
## v0.10.0 FX: `speed` plays the scene that many times faster (a Blink's flash pops in a fraction of its length).
func spawn(
	effect_id: StringName, pos: Vector3, scale := 1.0, colors := {}, life := -1.0, speed := 1.0
) -> Node3D:
	var k := _def.row(effect_id) if _def != null else -1
	if k < 0:
		return null
	var family := _def.families[k]
	while live_count(family) >= cap_for(family):
		_release(_oldest(family)["node"])
		reused += 1
	var node := _take(effect_id, _def.scenes[k])
	if node == null:
		return null
	var info: Dictionary = _info[node]
	node.scale = Vector3.ONE * scale * _def.scales[k]
	if node.is_inside_tree():
		node.global_position = pos
	else:
		node.position = pos
	_colour(node, info, colors, k)
	# v0.10.0 lead (VX2-VX5's findings): a held effect keeps emitting and looping until release(); a timed one runs
	# its scene's one pass (an animation-less scene's particles fire once).
	var short: Array = SHORT.get(effect_id, []) if life != 0.0 else []
	for p in _particles(node):
		p.one_shot = life != 0.0 and (info["anim"] == null or not short.is_empty())
		p.local_coords = not WORLD_SPACE.has(family)
	var left := float(info["life"]) / speed if life < 0.0 else (INF if life == 0.0 else life)
	var entry := {"node": node, "id": effect_id, "family": family, "left": left}
	if not short.is_empty():  # W3-S4 (F10): the whole scene within short[0] s, gone short[1] ticks on
		var s: float = short[0]
		speed = maxf(speed, float(info["life"]) / s)
		entry["left"] = minf(left, s + LIFE_MARGIN_S)
		entry["until"] = _now + float(short[1])
	info["mul"] = speed
	_restart(node, info)
	_live.append(entry)
	entry["iid"] = node.get_instance_id()
	_live_ids[entry["iid"]] = true
	_family_n[family] = int(_family_n.get(family, 0)) + 1
	var n_live := int(_live_n.get(effect_id, 0)) + 1
	_live_n[effect_id] = n_live
	if n_live > int(_peak.get(effect_id, 0)):
		_peak[effect_id] = n_live
	spawned += 1
	return node


## Every id in the table once (warm()), all in one call.
func warm_all() -> void:
	for id in warm_ids():
		warm(id)


## The ids warm_all() plays (a loading queue can warm them one a frame: warm(id)).
func warm_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if _def != null:
		out.append_array(_def.ids)
	return out


## The ids a floor load still has to warm (VX-W): all of them, none, or the ones this session has not warmed.
func pending_warm_ids() -> Array[StringName]:
	if warm_mode == &"none":
		return []
	var out: Array[StringName] = []
	for id in warm_ids():
		if warm_mode == &"load" or not _warmed.has(id):
			out.append(id)
	return out


## One id in front of the camera, hidden only by the loading cover (the shaders and pipelines really compile);
## WARM_FRAMES frames later it goes back to its pool.
func warm(effect_id: StringName) -> void:
	var n := spawn(effect_id, _focus())
	_warmed[effect_id] = true
	if n != null:
		_warm_nodes.append({"node": n, "left": WARM_FRAMES})


## Called once a frame with the draw time in ticks (VfxLayer.begin): a tick that has not moved for HOLD_S is a pause.
func follow(now: float) -> void:
	var tick := floori(now)
	var ms := Time.get_ticks_msec()
	if tick != _last_tick:
		_last_tick = tick
		_tick_at_ms = ms
	set_held(float(ms - _tick_at_ms) / 1000.0 > HOLD_S)
	_expire(now)


## v0.10.5 W3-S4 (F10): the draw time is `now` (sim ticks): the SHORT effects whose ticks are up go back to their pool.
func _expire(now: float) -> void:
	_now = now
	var done: Array[Node3D] = []
	for e in _live:
		# (a draw time far before it: a new floor's world, its ticks started again)
		if e.has("until") and (now >= float(e["until"]) or now < float(e["until"]) - 120.0):
			done.append(e["node"])
	for n in done:
		_release(n)


## Pause (I8): live instances stop (speed_scale 0) while held and run again after.
func set_held(on: bool) -> void:
	if on == _held:
		return
	_held = on
	for e in _live:
		_set_speed(e["node"], 0.0 if on else _speed_of(_info[e["node"]]))


func is_held() -> bool:
	return _held


## Ends the effects whose life is over (called by _process; tests call it with a time).
func advance(delta: float) -> void:
	if _held:
		return
	var done: Array[Node3D] = []
	for e in _live:
		e["left"] = float(e["left"]) - delta
		if float(e["left"]) <= 0.0:
			done.append(e["node"])
	for n in done:
		_release(n)


func _process(delta: float) -> void:
	advance(delta)
	var keep: Array[Dictionary] = []
	for w in _warm_nodes:
		w["left"] = int(w["left"]) - 1
		if int(w["left"]) <= 0:
			_release(w["node"])
		else:
			keep.append(w)
	_warm_nodes = keep


# --- Pools ------------------------------------------------------------------------------------------------------
func _oldest(family: StringName) -> Dictionary:
	for e in _live:
		if e["family"] == family:
			return e
	return {}


## v0.10.5 (PERF_PLAYLOG_1: a floor's first fireballs cost 47-53 ms of script, each new shot instancing its scene):
## fills `effect_id`'s pool to `n` idle instances now (a floor's load, behind the cover), so the floor's first `n`
## spawns take them instead of instancing mid-fight. Returns the instances it made (hidden, idle).
func prefill(effect_id: StringName, n: int) -> Array[Node3D]:
	var made: Array[Node3D] = []
	var k := _def.row(effect_id) if _def != null else -1
	if k < 0:
		return made
	var idle: Array = _idle.get(effect_id, [])
	_idle[effect_id] = idle
	while idle.size() < n:
		var node := _make(_def.scenes[k])
		if node == null:
			break
		_park(node)
		idle.append(node)
		made.append(node)
	return made


## v0.10.5 PC: the idle instances waiting outside the tree (tests, scripts/checks/pool_node_count.gd).
func idle_outside() -> int:
	return idle_detached().size()


## v0.10.5: those instances (WorldViewRoot.idle_pool_nodes). Not named idle_pieces: ShaderWarmup would walk them, and
## the pack's own warm-up (WorldViewRoot._queue_pack_warmup) draws them.
func idle_detached() -> Array[Node]:
	var out: Array[Node] = []
	for id: StringName in _idle:
		for node: Variant in _idle[id]:
			if is_instance_valid(node) and (node as Node).get_parent() == null:
				out.append(node)
	return out


## v0.10.5 PC: an idle instance leaves the tree (it was made in it: its scripts are ready, its parts built).
func _park(node: Node3D) -> void:
	if node.get_parent() == self:
		remove_child(node)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:  # the idle instances outside the tree go with the pack
		for id: StringName in _idle:
			for node: Variant in _idle[id]:  # (a Variant: freeing the pack frees its in-tree instances first)
				if is_instance_valid(node) and (node as Node).get_parent() == null:
					(node as Node).free()
		_idle.clear()


## An idle instance of `effect_id`, or a new one.
func _take(effect_id: StringName, scene_path: String) -> Node3D:
	var idle: Array = _idle.get(effect_id, [])
	if not idle.is_empty():
		var node: Node3D = idle.pop_back()
		if node.get_parent() == null:
			add_child(node)  # v0.10.5 PC: back in the tree
		return node
	return _make(scene_path)


## A new instance of the scene at `scene_path`: hidden, in the tree, its materials its own (null: no scene).
func _make(scene_path: String) -> Node3D:
	var scene := _scene(scene_path)
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	if node == null:
		return null
	# The controller would play and loop by itself on entering the tree; this pool plays it on spawn.
	if "autoplay" in node:
		node.set("autoplay", false)
	var info := {"anim": null, "colors": {}, "speed": 1.0, "life": 1.0, "lights": []}
	for key in [&"primary_color", &"secondary_color", &"tertiary_color"]:
		if key in node:
			(info["colors"] as Dictionary)[key] = node.get(key)
	if "speed_scale" in node:
		info["speed"] = float(node.get("speed_scale"))
	node.visible = false
	_own_materials(node)
	var anim := node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim != null:
		anim.autoplay = ""  # (before the tree: the scene's RESET would play on entering it)
	add_child(node)
	var longest := 0.0
	if anim != null:
		anim.stop()
		anim.animation_finished.connect(_on_anim_done.bind(node))
		info["anim"] = anim
		if anim.has_animation(ANIM):
			longest = anim.get_animation(ANIM).length
	for p in _particles(node):
		if anim == null:
			p.one_shot = true
			longest = maxf(longest, p.lifetime * 2.0)
		else:
			longest = maxf(longest, p.lifetime)
	info["life"] = maxf(longest, 0.2) + LIFE_MARGIN_S
	_unlight(node, info)
	_info[node] = info
	return node


## I3: no light of its own, whatever the scene had.
func _unlight(node: Node3D, info: Dictionary) -> void:
	if "light_enable" in node:
		node.set("light_enable", false)
	var found: Array[Node] = node.find_children("*", "Light3D", true, false)
	for l in found:
		(l as Light3D).visible = false
	info["lights"] = found


func _colour(node: Node3D, info: Dictionary, colors: Dictionary, row: int) -> void:
	var from_table := {
		&"primary_color": _def.primary[row],
		&"secondary_color": _def.secondary[row],
		&"tertiary_color": _def.tertiary[row],
	}
	var asked := {
		&"primary_color": &"primary",
		&"secondary_color": &"secondary",
		&"tertiary_color": &"tertiary",
	}
	for key: StringName in from_table:
		if not key in node:
			continue
		var c: Color = (info["colors"] as Dictionary).get(key, Color.WHITE)  # the scene's own
		var t: Color = from_table[key]
		if t.a > 0.0:
			c = t
		if colors.has(asked[key]):
			c = colors[asked[key]]
		node.set(key, c)


func _restart(node: Node3D, info: Dictionary) -> void:
	node.visible = true
	_set_speed(node, 0.0 if _held else _speed_of(info))
	for p in _particles(node):
		p.restart()
	var anim := info["anim"] as AnimationPlayer
	if anim != null and anim.has_animation(ANIM):
		anim.play(ANIM)
		anim.seek(0.0)


## The scene's own speed times the spawn's (v0.10.0 FX).
static func _speed_of(info: Dictionary) -> float:
	return float(info["speed"]) * float(info.get("mul", 1.0))


func _set_speed(node: Node3D, speed: float) -> void:
	if "speed_scale" in node:
		node.set("speed_scale", speed)


func _particles(node: Node3D) -> Array[GPUParticles3D]:
	var out: Array[GPUParticles3D] = []
	for c in node.get_children():
		if c is GPUParticles3D:
			out.append(c as GPUParticles3D)
	return out


func _on_anim_done(anim_name: StringName, node: Node3D) -> void:
	if anim_name != ANIM:
		return
	for e in _live:
		if e["node"] == node and is_inf(float(e["left"])):  # held: play again until the caller's release()
			(_info[node]["anim"] as AnimationPlayer).play(ANIM)
			return
	_release(node, true)  # (v0.10.5 PC: out of the tree after the player's signal, not inside it)


## v0.10.0 lead (VX3's finding): the instances of one scene share its ShaderMaterials, so a recolour of one would
## recolour them all. Each new instance takes its own copies of its pieces' material_override (the VFXController sets
## its colours there, and the AnimationPlayer animates them through the node, so the tracks still reach the copies).
func _own_materials(node: Node) -> void:
	if node is GeometryInstance3D:
		var g := node as GeometryInstance3D
		if g.material_override != null:
			g.material_override = g.material_override.duplicate()
	for c in node.get_children():
		_own_materials(c)


## v0.10.0 FX: a held effect moved further than JUMP_M in one frame starts its particles again (the holds call it
## after each move).
static func settle(node: Node3D, was: Vector3, now_at: Vector3) -> void:
	if was.distance_to(now_at) <= JUMP_M:
		return
	for c in node.get_children():
		if c is GPUParticles3D:
			(c as GPUParticles3D).restart()


## v0.10.0 lead: `node` is playing (not back in its pool, not taken over past a cap).
func is_live(node: Node3D) -> bool:
	return node != null and _live_ids.has(node.get_instance_id())


## v0.10.0: the family has a free slot (a caller with a fallback look draws that instead of reusing the oldest).
func has_room(family: StringName) -> bool:
	return live_count(family) < cap_for(family)


## v0.10.0: the caller is done with `node` (a bolt ended, a zone or a status went): back to its pool.
func release(node: Node3D) -> void:
	if node != null:
		_release(node)


## Back to the pool, hidden.
func _release(node: Node3D, later := false) -> void:
	for k in _live.size():
		if _live[k]["node"] == node:
			var id: StringName = _live[k]["id"]
			var fam: StringName = _live[k]["family"]
			_live_ids.erase(_live[k]["iid"])
			_live.remove_at(k)
			_family_n[fam] = int(_family_n.get(fam, 1)) - 1
			_live_n[id] = int(_live_n.get(id, 1)) - 1
			node.visible = false
			var anim := (_info[node] as Dictionary)["anim"] as AnimationPlayer
			if anim != null:
				anim.stop()
			for p in _particles(node):
				p.emitting = false
			if not _idle.has(id):
				_idle[id] = []
			(_idle[id] as Array).append(node)
			if later:
				_park_if_idle.call_deferred(node)
			else:
				_park(node)
			return


## v0.10.5 PC: a deferred park, unless a spawn took the instance again meanwhile.
func _park_if_idle(node: Variant) -> void:  # (a Variant: the instance may be freed meanwhile)
	if is_instance_valid(node) and not is_live(node as Node3D):
		_park(node as Node3D)


## The ground point the camera looks at, a little toward the camera (inside the frame).
func _focus() -> Vector3:
	var cam := camera
	if cam == null and is_inside_tree():
		cam = get_viewport().get_camera_3d()
	if cam == null or not cam.is_inside_tree():  # (a view still being built: its camera is not in the tree yet)
		return Vector3.ZERO
	var fwd := -cam.global_transform.basis.z
	var from := cam.global_position
	if fwd.y >= -0.001:
		return Vector3(from.x, 0.0, from.z)
	var hit := from + fwd * (-from.y / fwd.y)
	var back := Vector3(-fwd.x, 0.0, -fwd.z).normalized()
	return Vector3(hit.x, 0.0, hit.z) + back * WARM_AHEAD_M


## v0.10.5: the most instances of `effect_id` that were live at once this session (0: not spawned yet).
static func peak(effect_id: StringName) -> int:
	return int(_peak.get(effect_id, 0))


## The idle instances of `effect_id` waiting in the pool (tests).
func idle_count(effect_id: StringName) -> int:
	return (_idle.get(effect_id, []) as Array).size()


## True once `effect_id` has been through warm() this session.
static func is_warmed(effect_id: StringName) -> bool:
	return _warmed.has(effect_id)


## Asks the loader threads for every effect scene in the table (once; PackFxSessionWarm calls it at the menu).
static func request_scenes() -> void:
	var def := shared_def()
	if def == null:
		return
	for path in def.scenes:
		if not _scenes.has(path) and not _requested.has(path):
			_requested[path] = true
			ResourceLoader.load_threaded_request(path)


## True when the scene of `effect_id` is read (or its read failed, so nothing waits on it for ever).
static func scenes_ready(effect_id: StringName) -> bool:
	var def := shared_def()
	var k := def.row(effect_id) if def != null else -1
	if k < 0:
		return true
	var path: String = def.scenes[k]
	if _scenes.has(path) or not _requested.has(path):
		return true
	return ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS


## The effect's scene, read once per session and kept: while it is held, its shaders and their compiled pipelines stay
## in the renderer, so a PackFx made by a later floor does not compile them again (VX-W).
static func _scene(scene_path: String) -> PackedScene:
	if not _scenes.has(scene_path):
		if _requested.has(scene_path):
			_scenes[scene_path] = ResourceLoader.load_threaded_get(scene_path) as PackedScene
		else:
			_scenes[scene_path] = load(scene_path) as PackedScene
	return _scenes[scene_path]

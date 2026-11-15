class_name LensFeedViews
extends Node3D
## The Hive Lens's feeding drones as the player sees them, drawn from WorldReader.boss_lens (EI-07: which drones feed
## it, how much it takes and which its own beam cuts are the sim's, BossLens). No word anywhere (the owner: the player
## discovers it from glows and motion).
## - Fed: a thin, dim thread of the Lens's light (the pack's beam in a dark rose, hl_thread) runs from each feeding
##   drone into the Lens, and the Lens wears one floating ring of light (hl_layer) per feeding drone round its body;
##   a drone's death takes the outermost ring with a flash (hl_flash). The hero's hits on it give the dull grey spark
##   of an ARMOURED hit (HitFeel: the sim tags them) and the boss bar turns its fed tone with a pip per drone
##   (BossBarTones.FED). While the web of the Lattice stands its strands carry the read, so the threads hide.
## - The cut: while a Focus Beam is drawn, a feeding drone its lane touches wears a gold glow (hl_glow), the beam's own
##   light; when the beam cuts it down it bursts in that gold (hl_cut, hl_flash) and its thread snaps back into the
##   Lens.
## A beam the pack has no room for is drawn as a plain glowing rod. Nothing here decides.

const THREAD_ID := &"hl_thread"
const LAYER_ID := &"hl_layer"
const FLASH_ID := &"hl_flash"
const CUT_ID := &"hl_cut"
const GLOW_ID := &"hl_glow"
const CUT_EVENT := &"lens_drone_cut"
## A thread's drawn half width (m): a sixth of a strand's.
const THREAD_R := 0.05
## The shield's rings: the first this far (m) outside the Lens's body, each next one further out and higher; the
## rim scene's size per metre of radius (as the Foundry's).
const LAYER_OUT := 0.35
const LAYER_STEP := 0.32
const LAYER_RISE := 0.16
const RIM_PER_M := 0.55
const FLASH_SCALE := 0.9
const CUT_SCALE := 1.1
const GLOW_SCALE := 0.55
## How long (s) a cut drone's thread takes to snap back into the Lens.
const SNAP_S := 0.25

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := LensPackHold.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _on := false
var _lens_at := Vector3.ZERO
var _boss_r := 1.0
## The feeding drones now: [id, body (3D), radius].
var _feeders: Array = []
var _web_up := false
## Ids of the feeding drones a Focus Beam's lane touches now.
var _on_lane: Array[int] = []
var _was_fed := 0
## Threads snapping back: [from (3D), seconds so far, key].
var _snaps: Array = []
var _threads: Array = []
var _rods: Array[MeshInstance3D] = []
var _last_seq := 0
var _primed := false


func _init() -> void:
	name = "LensFeedViews"


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	var lens := reader.boss_lens()
	_on = not lens.is_empty()
	_feeders = []
	_on_lane = []
	_web_up = false
	if _on:
		var b := int(lens["boss"])
		_lens_at = SimPlane.to_3d(reader.actor_pos(b), LensLooks.LENS_Y)
		_boss_r = reader.actor_radius(b)
		for d: Dictionary in lens["drones"]:
			var j := reader.actor_index(int(d["id"]))
			var r := reader.actor_radius(j) if j >= 0 else 0.4
			_feeders.append([int(d["id"]), SimPlane.to_3d(d["position"], LensLooks.DRONE_Y), r])
		_web_up = bool((lens["lattice"] as Dictionary).get("running", false))
		_lanes(reader, b, lens["drones"])
	if _feeders.size() < _was_fed and _on:
		_flash(_lens_at, FLASH_SCALE, LensLooks.LAYER_COLORS)  # a ring drops with its drone
	_was_fed = _feeders.size()
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == CUT_EVENT:
			var at := SimPlane.to_3d(e.pos, LensLooks.DRONE_Y)
			if pack_fx != null and pack_fx.has_id(CUT_ID) and pack_fx.has_room(&"impact"):
				pack_fx.spawn(CUT_ID, at, CUT_SCALE, LensLooks.BEAM_COLORS)
			_flash(at, FLASH_SCALE, LensLooks.BEAM_COLORS)
			_snaps.append([at, 0.0, [&"snap", e.seq]])


## The feeding drones a Focus Beam's lane touches while it is drawn (its windup and its burn).
func _lanes(reader: WorldReader, b: int, drones: Array) -> void:
	if reader.boss_move(b) != WorldReader.MOVE_LANES:
		return
	var tg := reader.telegraph(b)
	if tg.get("shape", &"") != &"lanes":
		return
	for d: Dictionary in drones:
		var j := reader.actor_index(int(d["id"]))
		var r := reader.actor_radius(j) if j >= 0 else 0.4
		for o: Obb in tg["obbs"]:
			if LensLooks.on_lane(d["position"], r, o):
				_on_lane.append(int(d["id"]))
				break


func _flash(at: Vector3, size: float, colors: Dictionary) -> void:
	if pack_fx != null and pack_fx.has_id(FLASH_ID) and pack_fx.has_room(&"impact"):
		pack_fx.spawn(FLASH_ID, at, size, colors)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	if not _on and _snaps.is_empty() and hold.count() == 0 and _threads.is_empty():
		if not quiet:
			for r in _rods:
				r.visible = false
		quiet = true
		return
	quiet = false
	hold.begin()
	_threads = []
	var rod := 0
	if not _web_up:
		for f: Array in _feeders:
			rod = _thread([&"thread", f[0]], f[1], _lens_at, rod)
	rod = _draw_snaps(delta, rod)
	for k in range(rod, _rods.size()):
		_rods[k].visible = false
	for k in _feeders.size() if _on else 0:
		var r := _boss_r + LAYER_OUT + LAYER_STEP * k
		var at := _lens_at + Vector3(0, LAYER_RISE * k - 0.2, 0)
		hold.put(
			[&"layer", k],
			LAYER_ID,
			&"area",
			SiegeLooks.at(at, r * RIM_PER_M),
			LensLooks.LAYER_COLORS
		)
	for f: Array in _feeders:
		if _on_lane.has(int(f[0])):
			hold.put(
				[&"lane", f[0]],
				GLOW_ID,
				&"status",
				SiegeLooks.at(f[1], GLOW_SCALE + float(f[2])),
				LensLooks.BEAM_COLORS
			)
	hold.end()


## One thread from `a` into `b` under `key`: the pack's dim beam, else plain rod `rod` (returns the next free rod).
func _thread(key: Variant, a: Vector3, b: Vector3, rod: int) -> int:
	_threads.append([a, b])
	var n := hold.put(key, THREAD_ID, &"status", Transform3D(Basis(), a), LensLooks.THREAD_COLORS)
	if n != null:
		LensLooks.place_beam(n, a, b, THREAD_R)
		return rod
	if rod >= _rods.size():
		_rods.append(LensLooks.rod(self, Color(LensLooks.LENS, 0.28)))
	_rods[rod].visible = true
	LensLooks.place_rod(_rods[rod], a, b, THREAD_R)
	return rod + 1


func _draw_snaps(delta: float, rod: int) -> int:
	var keep: Array = []
	for s: Array in _snaps:
		s[1] = float(s[1]) + delta
		var t := clampf(float(s[1]) / SNAP_S, 0.0, 1.0)
		if t >= 1.0:
			continue
		keep.append(s)
		rod = _thread(s[2], (s[0] as Vector3).lerp(_lens_at, t * t), _lens_at, rod)
	_snaps = keep
	return rod


# --- tests and the shot scripts ----------------------------------------------------------------------------------


## The feeding threads drawn now (snapping ones included): [from (3D), to (3D)].
func threads() -> Array:
	return _threads


## The shield's rings round the Lens now.
func layers() -> int:
	var n := 0
	for k in _feeders.size():
		n += 1 if hold.has([&"layer", k]) else 0
	return n


## The ids of the drones wearing the Focus Beam's gold glow now.
func lane_glows() -> Array[int]:
	var out: Array[int] = []
	for f: Array in _feeders:
		if hold.has([&"lane", f[0]]):
			out.append(int(f[0]))
	return out


## Threads still snapping back into the Lens.
func snapping() -> int:
	return _snaps.size()


## A thread's pack beam node (null when it fell back to a rod; tests).
func thread_node(drone_id: int) -> Node3D:
	return hold.node([&"thread", drone_id])

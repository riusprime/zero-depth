class_name ForgeSlagViews
extends Node3D
## The Foundry's cooling slag and its Overpressure, drawn from WorldReader.boss_forge (EI-07: which pool cools, where
## a slab lies, how long it lasts, which slabs are safe and when the floor burns are the sim's, BossSlag). No word
## anywhere.
## - A pool cooling: dark crust (CRUST_SHADER) grows over the burning pool (HazardViews' lava) through its `cooling`,
##   and the lava between the patches dims: bright lava turns to a dull crust.
## - A slab: a dark basalt plate of the pool's exact radius with a cool blue rim (SLAB_SHADER), clearly not lava; its
##   cracks glow dull orange as its time runs low, it fades over its last moments and crumbles in the pack's dust
##   (vx1_impact_other, dark); shattered by the vent blast it bursts in the dust at once and goes.
## - A slag drop (a pool dropped at the hero's feet): a molten blob (fo_drop) falls into its warning ring and lands in
##   the pack's ember impact.
## - The Overpressure: through its cast the open floor heats (HEAT_SHADER, a room-wide glow rising with `cast`, sorted
##   under the bodies and telegraphs and never above half opaque); every whole slab is cut out of it, ringed cool, and
##   the safe ones carry the pack's cool rim (fo_safe): the only cool islands. While it burns the floor flickers with
##   flame; it fades out when it ends. The hint arrows (ObjectiveHints, `foundry_slab`) and the HUD's edge glow
##   (ForgeHud) are the HUD's.
## Every slot is built hidden at the start (the warm-up draws them). Reduced motion stills the floor's flicker.

const SAFE_ID := &"fo_safe"
const DROP_ID := &"fo_drop"
const SPLASH_ID := &"vx1_impact_ember"
const DUST_ID := &"vx1_impact_other"
const DUST_HIDE := ["Core", "Smoke", "Ground_Impact", "Impact_Streaks1", "Impact_Streaks2"]
const CRUMBLED := &"slab_crumbled"
const SHATTERED := &"slab_shattered"
const SLAG_DROP := &"slag_drop"
const SLOTS := 8
## The pack scenes' size per metre of radius.
const RIM_PER_M := 0.55
const DUST_PER_M := 0.42
const SPLASH_PER_M := 0.45
const DROP_SCALE := 0.8
## The drop's fall (m) over its pool's warning.
const DROP_M := 9.0
## A slab's fade over its last ticks.
const FADE_TICKS := 45.0
## The floor's level through the cast (it reaches this at the cast's end), and its fade at the end (s).
const CAST_LEVEL := 0.75
const FADE_S := 0.5

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _rows: Array = []
var _over := {}
var _room := Rect2()
var _hazards := {}
## Slab id -> the most ticks it was seen to have left (its whole life, the first time it is seen).
var _life := {}
## Hazard id -> true: a slag drop still falling into its warning ring.
var _drops := {}
var _last_seq := 0
var _primed := false
var _clock := 0.0
var _level := 0.0
var _fade := 0.0
var _crusts: Array[MeshInstance3D] = []
var _slabs: Array[MeshInstance3D] = []
var _heat: MeshInstance3D


func _init() -> void:
	name = "ForgeSlagViews"
	for k in SLOTS:
		_crusts.append(ForgeLooks.floor_mesh(self, ForgeLooks.CRUST_SHADER, 2.0, 1))
		_slabs.append(ForgeLooks.floor_mesh(self, ForgeLooks.SLAB_SHADER, 2.0, 1))
		ForgeLooks.param(_crusts[k], &"seed", float(k) * 0.37)
		ForgeLooks.param(_slabs[k], &"seed", float(k) * 0.61)
		ForgeLooks.param(_slabs[k], &"basalt", ForgeLooks.BASALT)
		ForgeLooks.param(_slabs[k], &"rim", ForgeLooks.COOL)
	_heat = ForgeLooks.floor_mesh(self, ForgeLooks.HEAT_SHADER, 1.0, ForgeLooks.UNDER)
	ForgeLooks.param(_heat, &"cool", ForgeLooks.COOL)


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	var forge := reader.boss_forge()
	_rows = forge.get("slabs", [])
	_over = forge.get("overpressure", {})
	if not forge.is_empty():
		_room = ForgeLooks.room_of(reader, reader.actor_pos(int(forge["boss"])))
	_hazards = {}
	if not _drops.is_empty():
		for h: Dictionary in reader.boss_hazards():
			_hazards[int(h["id"])] = h
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.STATUS_APPLY:
			_event(e, reader)


func _event(e: SimEvent, reader: WorldReader) -> void:
	match e.effect_id:
		CRUMBLED:
			_dust(_slab_at(e.amount, e.pos), 1.0)
		SHATTERED:
			_dust(_slab_at(e.amount, e.pos), 1.6)
		SLAG_DROP:
			_drops[e.amount] = true
			for h: Dictionary in reader.boss_hazards():
				_hazards[int(h["id"])] = h


## Where slab `id` lies (its row; else the event's own place).
func _slab_at(id: int, fallback: Vector2) -> Vector2:
	for row: Dictionary in _rows:
		if bool(row["slab"]) and int(row["id"]) == id:
			return row["centre"]
	return fallback


func _dust(at: Vector2, size: float) -> void:
	if pack_fx == null or not pack_fx.has_id(DUST_ID) or not pack_fx.has_room(&"impact"):
		return
	pack_fx.spawn(
		DUST_ID,
		SimPlane.to_3d(at, 0.05),
		3.0 * DUST_PER_M * size,
		ForgeLooks.DUST_COLORS,
		-1.0,
		1.0,
		DUST_HIDE
	)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	var idle := _rows.is_empty() and _over.is_empty() and _drops.is_empty() and _fade <= 0.0
	if idle and hold.count() == 0:
		if quiet:
			return
		quiet = true
		_hide_all()
		return
	quiet = false
	_clock += delta * (0.0 if ViewPrefs.reduced_motion else 1.0)
	hold.begin()
	_draw_rows()
	_draw_drops()
	_draw_heat(delta)
	hold.end()


func _hide_all() -> void:
	for mi in _crusts + _slabs:
		mi.visible = false
	_heat.visible = false
	_level = 0.0
	hold.begin()
	hold.end()


func _draw_rows() -> void:
	var pools := 0
	var slabs := 0
	var live := {}
	for row: Dictionary in _rows:
		var at := row["centre"] as Vector2
		var r := float(row["radius"])
		if not bool(row["slab"]):
			if pools < SLOTS:
				var c := _crusts[pools]
				c.visible = true
				c.position = SimPlane.to_3d(at, 0.04)
				c.scale = Vector3.ONE * r
				ForgeLooks.param(c, &"cool", float(row["cooling"]) / 1000.0)
			pools += 1
			continue
		var id := int(row["id"])
		live[id] = true
		if bool(row["shattered"]) or slabs >= SLOTS:
			continue
		var left := float(row["left"])
		_life[id] = maxf(float(_life.get(id, 0.0)), left)
		var s := _slabs[slabs]
		slabs += 1
		s.visible = true
		s.position = SimPlane.to_3d(at, 0.05)
		s.scale = Vector3.ONE * r
		var safe := not _over.is_empty() and bool(row["safe"])
		ForgeLooks.param(s, &"crack", clampf(1.0 - left / maxf(1.0, float(_life[id])), 0.0, 1.0))
		ForgeLooks.param(s, &"alpha", clampf(left / FADE_TICKS, 0.0, 1.0))
		ForgeLooks.param(s, &"safe", 1.0 if safe else 0.0)
		ForgeLooks.param(s, &"clock", _clock)
		if safe:
			hold.put(
				[&"safe", id],
				SAFE_ID,
				&"area",
				SiegeLooks.at(s.position + Vector3(0, 0.03, 0), r * RIM_PER_M)
			)
	for k in range(pools, SLOTS):
		_crusts[k].visible = false
	for k in range(slabs, SLOTS):
		_slabs[k].visible = false
	for id: int in _life.keys():
		if not live.has(id):
			_life.erase(id)


func _draw_drops() -> void:
	for id: int in _drops.keys():
		var h: Dictionary = _hazards.get(id, {})
		if h.is_empty():
			_drops.erase(id)
			continue
		var c: Vector2 = h["centre"]
		if bool(h["armed"]):
			_drops.erase(id)
			if pack_fx != null and pack_fx.has_id(SPLASH_ID) and pack_fx.has_room(&"impact"):
				pack_fx.spawn(SPLASH_ID, SimPlane.to_3d(c, 0.1), float(h["radius"]) * SPLASH_PER_M)
			continue
		var u := 1.0 - float(h["warn"]) / 1000.0
		hold.put(
			[&"drop", id],
			DROP_ID,
			&"projectile",
			SiegeLooks.at(SimPlane.to_3d(c, 0.3 + DROP_M * u), DROP_SCALE)
		)


func _draw_heat(delta: float) -> void:
	var burn := 0.0
	if not _over.is_empty():
		var cast := int(_over["cast"])
		_level = CAST_LEVEL * float(cast) / 1000.0 if cast >= 0 else 1.0
		burn = 0.0 if cast >= 0 else 1.0
		_fade = FADE_S
	elif _fade > 0.0:
		_fade = maxf(0.0, _fade - delta)
		_level = minf(_level, _fade / FADE_S)
	else:
		_level = 0.0
	_heat.visible = _level > 0.001
	if not _heat.visible:
		return
	_heat.position = SimPlane.to_3d(_room.get_center(), 0.03)
	_heat.scale = Vector3(_room.size.x, 1.0, _room.size.y)
	ForgeLooks.param(_heat, &"room_size", _room.size)
	ForgeLooks.param(_heat, &"level", _level)
	ForgeLooks.param(_heat, &"burn", burn)
	ForgeLooks.param(_heat, &"clock", _clock)
	var holes := PackedVector3Array()
	holes.resize(ForgeLooks.HOLES)
	var n := 0
	for row: Dictionary in _rows:
		if n >= ForgeLooks.HOLES or not bool(row["slab"]) or bool(row["shattered"]):
			continue
		var off := SimPlane.to_3d(row["centre"]) - SimPlane.to_3d(_room.get_center())
		holes[n] = Vector3(off.x, off.z, float(row["radius"]))
		n += 1
	ForgeLooks.param(_heat, &"holes", holes)
	ForgeLooks.param(_heat, &"hole_n", n)


# --- tests and the shot scripts ----------------------------------------------------------------------------------


## The pools drawn cooling now: [{centre (sim), radius, cool 0..1}].
func crusts() -> Array:
	var out := []
	for c in _crusts:
		if c.visible:
			var cool := float(ForgeLooks.get_param(c, &"cool"))
			out.append({"centre": SimPlane.to_sim(c.position), "radius": c.scale.x, "cool": cool})
	return out


## The slabs drawn now: [{centre (sim), radius, crack 0..1, alpha, safe}].
func slabs() -> Array:
	var out := []
	for s in _slabs:
		if s.visible:
			(
				out
				. append(
					{
						"centre": SimPlane.to_sim(s.position),
						"radius": s.scale.x,
						"crack": float(ForgeLooks.get_param(s, &"crack")),
						"alpha": float(ForgeLooks.get_param(s, &"alpha")),
						"safe": float(ForgeLooks.get_param(s, &"safe")) > 0.5,
					}
				)
			)
	return out


## The burning floor now: {} hidden; else "level", "burn", "holes" (the slabs cut out, [(x, z) from the room's centre,
## radius]).
func heat_read() -> Dictionary:
	if not _heat.visible:
		return {}
	var n := int(ForgeLooks.get_param(_heat, &"hole_n"))
	var holes: PackedVector3Array = ForgeLooks.get_param(_heat, &"holes")
	return {
		"level": float(ForgeLooks.get_param(_heat, &"level")),
		"burn": float(ForgeLooks.get_param(_heat, &"burn")),
		"holes": holes.slice(0, n),
	}


## Slag drops still falling.
func drops_falling() -> int:
	return _drops.size()

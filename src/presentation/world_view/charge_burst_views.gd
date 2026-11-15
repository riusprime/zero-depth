class_name ChargeBurstViews
extends Node3D
## The burst at the end of a boss's charge (any boss whose charge bursts), drawn from WorldReader (EI-07: where it
## ends, when it locks and when it bursts are the sim's, BossChargeBurst).
## - Through the wind-up: a red-orange danger circle of the burst's exact radius where the lane ends (the telegraph's
##   "burst"), with the pack's rim on it. It follows the aim, dull and slowly pulsing, while the aim tracks; once the
##   aim locks it flashes white-hot and pulses fast, like every other telegraph's lock.
## - Armed (the run has stopped, WorldReader.boss_charge_bursts): the circle stays where it was armed and fills from
##   its middle out as the burst comes.
## - The burst: the pack's explosion, sized to the radius, where an armed circle went off.
## Every slot is built hidden at the start. Reduced motion stills the hatching and the pulse. Nothing here decides.

const SLOTS := 4
const RIM_ID := &"tw_burst_rim"
const BURST_ID := &"tw_burst"
## The pack scenes' size per metre of radius (the rim: 0.55; the explosion: about 2 m across at 1).
const RIM_PER_M := 0.55
const BURST_PER_M := 0.6
## The lock's flash (s).
const FLASH_S := 0.18

## The pack's effects (WorldViewRoot hands them over; a view built alone draws its own circles only).
var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
## The circles drawn this frame: [centre (sim), radius, locked, fill 0..1 (an armed one), its key].
var _circles: Array = []
var _discs: Array[MeshInstance3D] = []
## Key -> the seconds since it locked (its flash), and the armed bursts last seen (key -> [centre, radius, left]).
var _locked_at := {}
var _armed := {}
var _clock := 0.0


func _init() -> void:
	name = "ChargeBurstViews"
	for k in SLOTS:
		_discs.append(WardenLooks.floor_mesh(self, true, WardenLooks.DANGER))


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	_circles = []
	for i in range(reader.actor_count() if reader.any_boss() else 0):
		if not WorldReader.is_boss_kind(reader.actor_kind(i)):
			continue
		var tg := reader.telegraph(i)
		var b: Dictionary = tg.get("burst", {})
		if tg.get("shape", &"") != &"lane" or b.is_empty() or float(b["radius"]) <= 0.0:
			continue
		var locked := bool(tg.get("locked", true))
		_circles.append([b["center"], float(b["radius"]), locked, 0.0, "w%d" % reader.actor_id(i)])
	var seen := {}
	for row: Dictionary in reader.boss_charge_bursts():
		var key := "a%d" % int(row["boss"])
		seen[key] = true
		_armed[key] = [row["centre"], float(row["radius"]), int(row["left"])]
		_circles.append(
			[row["centre"], float(row["radius"]), true, float(row["progress"]) / 1000.0, key]
		)
	for key: String in _armed.keys():
		if seen.has(key):
			continue
		var last: Array = _armed[key]
		if int(last[2]) <= 2:  # it went off (a burst cancelled early leaves without one)
			_explode(last[0], float(last[1]))
		_armed.erase(key)


func _explode(centre: Vector2, radius: float) -> void:
	if pack_fx != null and pack_fx.has_id(BURST_ID) and pack_fx.has_room(&"explosion"):
		pack_fx.spawn(BURST_ID, SimPlane.to_3d(centre, 0.1), radius * BURST_PER_M)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	if _circles.is_empty() and hold.count() == 0:
		if quiet:
			return
		quiet = true
	else:
		quiet = false
	_clock += delta * (0.0 if ViewPrefs.reduced_motion else 1.0)
	hold.begin()
	var live := {}
	for k in SLOTS:
		var mi := _discs[k]
		mi.visible = k < _circles.size()
		if not mi.visible:
			continue
		var c: Array = _circles[k]
		var key: String = c[4]
		live[key] = true
		var locked := bool(c[2])
		if locked and not _locked_at.has(key):
			_locked_at[key] = 0.0
		elif locked:
			_locked_at[key] = float(_locked_at[key]) + delta
		var flash := 0.0
		if locked:
			flash = 1.0 - clampf(float(_locked_at[key]) / FLASH_S, 0.0, 1.0)
		var radius: float = c[1]
		mi.position = SimPlane.to_3d(c[0], 0.05 + 0.003 * k)
		mi.scale = Vector3.ONE * radius
		WardenLooks.param(mi, &"locked", 1.0 if locked else 0.0)
		WardenLooks.param(mi, &"flash", flash)
		WardenLooks.param(mi, &"fill", float(c[3]))
		WardenLooks.param(mi, &"alpha", 1.0 if locked else 0.7)
		WardenLooks.param(mi, &"clock", _clock)
		hold.put([&"rim", key], RIM_ID, &"area", WardenLooks.at(mi.position, radius * RIM_PER_M))
	for key: String in _locked_at.keys():
		if not live.has(key):
			_locked_at.erase(key)
	hold.end()


## Tests and the shot scripts: the circles drawn now, each [centre (sim), radius, locked, fill].
func circles() -> Array:
	var out := []
	for k in mini(SLOTS, _circles.size()):
		var mi := _discs[k]
		(
			out
			. append(
				[
					SimPlane.to_sim(mi.position),
					mi.scale.x,
					(
						float(
							(mi.material_override as ShaderMaterial).get_shader_parameter("locked")
						)
						> 0.5
					),
					float((mi.material_override as ShaderMaterial).get_shader_parameter("fill")),
				]
			)
		)
	return out


func shown() -> int:
	return _discs.filter(func(n: MeshInstance3D) -> bool: return n.visible).size()

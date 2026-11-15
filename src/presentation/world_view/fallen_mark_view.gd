class_name FallenMarkView
extends Node3D
## The mark on The Fallen's back while it holds a card of yours, drawn from WorldReader.boss_fallen ("mark", "taken",
## "theft_cast"; FallenTheft decides it all, EI-07). No word: a violet glow (the pack's orb flare, hl_glow, in violet)
## sits on its back and turns with its facing; round it a ring of small glows, one for each hit still needed (8 down
## to 0), so the count reads without a number; each hit that counts flashes it (hl_flash) and makes it swell. Through
## the theft's cast the glow grows on its back. FallenRememberedViews owns and syncs it. Reduced motion stills the
## swell and the breathing.

const GLOW_ID := &"hl_glow"
const FLASH_ID := &"hl_flash"
const COLORS := {
	&"primary": Color(0.86, 0.62, 1.0),
	&"secondary": Color(0.62, 0.26, 1.0),
	&"tertiary": Color(0.3, 0.08, 0.55),
}
## Its height on the body (m), how far out from the body's edge (m), its size, the pips' ring and size.
const MARK_Y := 1.3
const OUT_M := 0.05
const MARK_SCALE := 0.75
const RING_M := 0.55
const PIP_SCALE := 0.16
## A counted hit's swell (share of the size) and how long it lasts (s); the flash's size.
const SWELL := 0.6
const SWELL_S := 0.25
const FLASH_SCALE := 0.7
const BREATHE_HZ := 1.2

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
var _on := false
var _cast := -1
var _at := Vector3.ZERO
var _back := Vector2.ZERO
var _left := 0
var _swell := 0.0
var _clock := 0.0
var _last_seq := 0
var _primed := false
var _pulses := 0


func _init() -> void:
	name = "FallenMarkView"


func sync(reader: WorldReader, st: Dictionary) -> void:
	var mark: Dictionary = st.get("mark", {})
	_cast = int(st.get("theft_cast", -1))
	_on = not mark.is_empty() or _cast >= 0
	if not st.is_empty():
		var i := int(st["boss"])
		_back = mark["dir"] if not mark.is_empty() else -Kin.dir(reader.actor_facing(i))
		var p: Vector2 = reader.actor_pos(i) + _back * (reader.actor_radius(i) + OUT_M)
		_at = SimPlane.to_3d(p, MARK_Y)
		_left = int(mark.get("hits_left", 0))
	if not _primed:
		_primed = true
		_last_seq = reader.last_event_seq()  # Joining a fight under way replays nothing
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if (
			e.kind == SimEvent.Kind.STATUS_APPLY
			and e.effect_id == WorldReader.EFFECT_FALLEN_MARK_HIT
		):
			_pulse()


func _pulse() -> void:
	_pulses += 1
	_swell = SWELL_S
	if pack_fx != null and pack_fx.has_id(FLASH_ID) and pack_fx.has_room(&"impact"):
		pack_fx.spawn(FLASH_ID, _at, FLASH_SCALE, COLORS)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (tests call it too).
func advance(delta: float) -> void:
	var still := ViewPrefs.reduced_motion
	_clock += 0.0 if still else delta
	_swell = maxf(0.0, _swell - delta)
	hold.begin()
	if _on:
		var grow := 1.0 if _cast < 0 else float(_cast) / 1000.0
		var breathe := 0.0 if still else 0.08 * sin(_clock * TAU * BREATHE_HZ)
		var swell := 0.0 if still else SWELL * _swell / SWELL_S
		hold.put(
			&"mark",
			GLOW_ID,
			&"status",
			SiegeLooks.at(_at, MARK_SCALE * grow * (1.0 + breathe + swell)),
			COLORS
		)
		for k in _left if _cast < 0 else 0:
			hold.put([&"pip", k], GLOW_ID, &"status", SiegeLooks.at(pip_at(k), PIP_SCALE), COLORS)
	hold.end()


## Pip k's place: a ring round the mark, upright across the body's back.
func pip_at(k: int) -> Vector3:
	var a := TAU * float(k) / 8.0
	var side := (
		Vector3(-_back.y, 0.0, -_back.x).normalized() if _back != Vector2.ZERO else Vector3.RIGHT
	)
	return _at + side * cos(a) * RING_M + Vector3.UP * sin(a) * RING_M


# --- tests ------------------------------------------------------------------------------------------------------------


## The mark shows (a card held, or the theft's cast).
func shown() -> bool:
	return _on


## The pips drawn (one per hit still needed).
func pips() -> int:
	return _left if _on and _cast < 0 else 0


## Where the mark is (3D) and the way it faces out of the body's back (sim plane).
func mark_at() -> Vector3:
	return _at


func back_dir() -> Vector2:
	return _back


## Counted hits seen (each one flashes the mark).
func pulses() -> int:
	return _pulses

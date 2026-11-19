class_name AudioVoicePool
extends RefCounted
## The players the director's one-shot sounds play on, made once and reused: a sound takes a free player of its
## kind (screen-wide, or panned where it happens), sets its stream, volume, pitch, bus and place and plays; no node
## is made or freed per sound. A player is free once its sound has ended. When every player of the kind is busy, the
## sound takes the one whose sound ends soonest (the least of a sound is cut). SfxMixer's per-cue limits stay the
## rule for what may play; the pool only decides where.

## Players of each kind, at most (starting values): the sum of every cue's voice limit is far more than ever sounds
## together, and an idle player still costs a node.
const MAX_FLAT := 32
const MAX_PANNED := 48
## A voice is held this much past its sound's length (a pitched-down tail).
const TAIL_S := 0.05

var _flat: Array[AudioStreamPlayer] = []
var _panned: Array[AudioStreamPlayer3D] = []
## When each player's sound ends (director clock, seconds), parallel to the arrays above.
var _flat_end: PackedFloat64Array = []
var _panned_end: PackedFloat64Array = []


## Makes the players under `parent`: as many of each kind as the cues could sound at once (`cues`: cue id ->
## AudioCueDefinition), capped at MAX_FLAT / MAX_PANNED.
func build(parent: Node, cues: Dictionary) -> void:
	var caps := capacity(cues)
	for k in caps.x:
		var p := AudioStreamPlayer.new()
		p.name = "Voice%d" % k
		parent.add_child(p)
		_flat.append(p)
	for k in caps.y:
		var p3 := AudioStreamPlayer3D.new()
		p3.name = "Voice3D%d" % k
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		p3.attenuation_filter_cutoff_hz = 20500.0
		p3.panning_strength = 0.7
		parent.add_child(p3)
		_panned.append(p3)
	_flat_end.resize(_flat.size())
	_flat_end.fill(0.0)
	_panned_end.resize(_panned.size())
	_panned_end.fill(0.0)


## (screen-wide, panned) player counts for `cues`: each voice key's limit summed over the cues that can sound
## that way (only world sounds pan), capped.
static func capacity(cues: Dictionary) -> Vector2i:
	var flat := {}
	var panned := {}
	for id: StringName in cues:
		var c: AudioCueDefinition = cues[id]
		if c.kind == &"ambience":
			continue
		var key := c.voice_key()
		flat[key] = maxi(int(flat.get(key, 0)), c.max_voices)
		if c.bus == &"sfx":
			panned[key] = maxi(int(panned.get(key, 0)), c.max_voices)
	var nf := 0
	for key: StringName in flat:
		nf += int(flat[key])
	var np := 0
	for key: StringName in panned:
		np += int(panned[key])
	return Vector2i(mini(nf, MAX_FLAT), mini(np, MAX_PANNED))


## Plays `stream` now (`now` the director clock) for `seconds`: panned at 3D `at` when `panned`, else
## screen-wide. Returns false when the pool has no player of that kind (not built).
func start(
	stream: AudioStream,
	volume_db: float,
	pitch: float,
	bus: StringName,
	panned: bool,
	at: Vector3,
	now: float,
	seconds: float
) -> bool:
	var ends := _panned_end if panned else _flat_end
	var k := _pick(ends, now)
	if k < 0:
		return false
	var p: Node = _panned[k] if panned else _flat[k]
	p.set(&"stream", stream)
	p.set(&"volume_db", volume_db)
	p.set(&"pitch_scale", pitch)
	p.set(&"bus", bus)
	if panned:
		(p as AudioStreamPlayer3D).position = at
		_panned_end[k] = now + seconds + TAIL_S
	else:
		_flat_end[k] = now + seconds + TAIL_S
	p.call(&"play")
	return true


## How many players are sounding at `now` (tests).
func busy(now: float) -> int:
	var n := 0
	for t in _flat_end:
		n += 1 if t > now else 0
	for t in _panned_end:
		n += 1 if t > now else 0
	return n


func size() -> int:
	return _flat.size() + _panned.size()


## A free player's index, else the one ending soonest; -1 when there are none.
static func _pick(ends: PackedFloat64Array, now: float) -> int:
	var best := -1
	for k in ends.size():
		if ends[k] <= now:
			return k
		if best < 0 or ends[k] < ends[best]:
			best = k
	return best

class_name LatchedReader
extends WorldReader
## v0.10.5 Q5 (owner: "Q5 yes fix it"): the world views' reader. The views sync once a rendered frame
## (SimDriver.frame_ticked), and a frame that falls behind runs several ticks. What the sim shows for one tick only,
## and keeps in no log, is noted here on every tick (`note`, from WorldViewRoot.note_tick on SimDriver.ticked) and
## shown to the next sync (`settle`), so a view sees it once, as it did when it synced every tick:
## - shot_fired: a Gun shot in any tick since the last sync (the sim's is true for the shot's own tick only).
## - actor_state: an actor that was STATE_ACTIVE in a tick since the last sync reads STATE_ACTIVE once (most enemy
##   strikes are active one tick: the avatars' strike motions, the tracers and the boss attack cues key on it).
## The events need nothing here: each view reads the log from its own cursor (events_since). Everything else reads
## the latest tick. Presentation only (EI-07): it reads the World through WorldReader and decides nothing.
## v0.10.5 W3-Q6: telegraph(i) is read by several views in one sync (the telegraphs, the enemy models' windups, the
## elites, the lobs, the bosses' cues): each actor's is worked out once per tick and handed to them all, until the
## next tick, note or settle (a Playground edit syncs through settle). Callers only read it.

var _shots := 0
var _active := {}
## What this sync shows (set by `settle`).
var _shot := false
var _struck := {}
var _tg := {}
var _tg_tick := -1


func _init(r: WorldReader) -> void:
	super(r._w)


## Every tick, after the world stepped.
func note() -> void:
	_tg.clear()
	if super.shot_fired():
		_shots += 1
	for i in super.actor_count():
		if super.actor_state(i) == STATE_ACTIVE:
			_active[super.actor_id(i)] = true


## At the start of each sync: the one-tick facts of the ticks noted since the last sync. A sync with no tick noted
## (a test, the Playground's edit, the first sync) reads the latest tick only.
func settle() -> void:
	_tg.clear()
	_shot = _shots > 0
	_shots = 0
	_struck = _active
	_active = {}


func shot_fired() -> bool:
	return _shot or super.shot_fired()


func actor_state(i: int) -> int:
	var s := super.actor_state(i)
	if _struck.is_empty() or s == STATE_ACTIVE:
		return s
	return STATE_ACTIVE if _struck.has(super.actor_id(i)) else s


func telegraph(i: int) -> Dictionary:
	var t := tick()
	if t != _tg_tick:
		_tg.clear()
		_tg_tick = t
	var tg: Variant = _tg.get(i)
	if tg == null:
		tg = super.telegraph(i)
		_tg[i] = tg
	return tg

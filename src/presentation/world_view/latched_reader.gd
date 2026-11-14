class_name LatchedReader
extends WorldReader
## The world views' reader. The views sync once a rendered frame
## (SimDriver.frame_ticked), and a frame that falls behind runs several ticks. What the sim shows for one tick only,
## and keeps in no log, is noted here on every tick (`note`, from WorldViewRoot.note_tick on SimDriver.ticked) and
## shown to the next sync (`settle`), so a view sees it once, as it did when it synced every tick:
## - shot_fired: a Gun shot in any tick since the last sync (the sim's is true for the shot's own tick only).
## - actor_state: an actor that was STATE_ACTIVE in a tick since the last sync reads STATE_ACTIVE once (most enemy
##   strikes are active one tick: the avatars' strike motions, the tracers and the boss attack cues key on it).
## The events need nothing here: each view reads the log from its own cursor (events_since). Everything else reads
## the latest tick. Presentation only (EI-07): it reads the World through WorldReader and decides nothing.
## telegraph(i) is read by several views in one sync (the telegraphs, the enemy models' windups, the
## elites, the lobs, the bosses' cues): each actor's is worked out once per tick and handed to them all, until the
## next tick, note or settle (a Playground edit syncs through settle). Callers only read it.
## v0.10.5 W3-Q7 (owner playtest, 2026-11-05: the fireball bolt "appears at some spots and flickers", "lags or
## sticks"): the shot views draw a shot between its place at the last sync and its place now, by the frame's fraction
## of the latest tick. A frame that ran two ticks or more put it up to a tick or more behind (a Gun bolt ~0.3 m), then
## the next frame caught up: it stuttered whenever the game ran under 60 fps. Each tick's shot places are noted, and
## projectile_pos_before(id) gives the place at the tick before the latest for such a frame, so the shot is drawn
## between the last two ticks as on a one-tick frame.
## The same for the actors (the hero, the enemies, the elites, the bosses), whose nodes Godot's physics
## interpolation moved from where the last sync put them: each tick's actor places are noted, and actor_pos_before(i)
## gives actor i's place at the tick before the latest for such a frame (ActorViews starts the interpolation there).

var _shots := 0
var _active := {}
## What this sync shows (set by `settle`).
var _shot := false
var _struck := {}
var _tg := {}
var _tg_tick := -1
## The shots (id, place) at the latest tick and the one before, the ticks noted since the last sync,
## whether this sync's frame ran two or more, and the earlier tick's places by id (made at its first ask).
var _last_ids := PackedInt32Array()
var _last_xs := PackedFloat32Array()
var _last_ys := PackedFloat32Array()
var _was_ids := PackedInt32Array()
var _was_xs := PackedFloat32Array()
var _was_ys := PackedFloat32Array()
var _ticks := 0
var _multi := false
var _was := {}
var _was_made := false
## The actors (id, place) at the latest tick and the one before, and the earlier tick's places by id.
var _a_last_ids := PackedInt32Array()
var _a_last_xs := PackedFloat32Array()
var _a_last_ys := PackedFloat32Array()
var _a_was_ids := PackedInt32Array()
var _a_was_xs := PackedFloat32Array()
var _a_was_ys := PackedFloat32Array()
var _a_was := {}
var _a_was_made := false


func _init(r: WorldReader) -> void:
	super(r._w)


## Every tick, after the world stepped. The places are kept as the sim's columns (copied whole, not read an actor
## at a time); the earlier tick's places by id are built only when a sync asks for them.
func note() -> void:
	_tg.clear()
	if super.shot_fired():
		_shots += 1
	for i in indices_in_state(STATE_ACTIVE):
		_active[super.actor_id(i)] = true
	_ticks += 1
	_was_ids = _last_ids
	_was_xs = _last_xs
	_was_ys = _last_ys
	_last_ids = projectile_ids()
	_last_xs = projectile_xs()
	_last_ys = projectile_ys()
	_a_was_ids = _a_last_ids
	_a_was_xs = _a_last_xs
	_a_was_ys = _a_last_ys
	_a_last_ids = actor_ids()
	_a_last_xs = actor_xs()
	_a_last_ys = actor_ys()


## At the start of each sync: the one-tick facts of the ticks noted since the last sync. A sync with no tick noted
## (a test, the Playground's edit, the first sync) reads the latest tick only.
func settle() -> void:
	_tg.clear()
	_shot = _shots > 0
	_shots = 0
	_struck = _active
	_active = {}
	_multi = _ticks >= 2
	_ticks = 0
	_was_made = false
	_a_was_made = false


## Shot `id`'s place at the tick before the latest when this sync's frame ran two ticks or more (the
## shot views draw it from there); null on a one-tick frame (the last sync's place is that tick's) or for a shot that
## was not flying then.
func projectile_pos_before(id: int) -> Variant:
	if not _multi:
		return null
	if not _was_made:
		_was_made = true
		_was.clear()
		for k in _was_ids.size():
			_was[_was_ids[k]] = Vector2(_was_xs[k], _was_ys[k])
	return _was.get(id)


## Actor i's place at the tick before the latest when this sync's frame ran two ticks or more (its
## node's interpolation starts there); null on a one-tick frame or for an actor that was not there then.
func actor_pos_before(i: int) -> Variant:
	if not _multi:
		return null
	if not _a_was_made:
		_a_was_made = true
		_a_was.clear()
		for k in _a_was_ids.size():
			_a_was[_a_was_ids[k]] = Vector2(_a_was_xs[k], _a_was_ys[k])
	return _a_was.get(super.actor_id(i))


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

class_name BatchAvatars
extends RefCounted
## The batched enemies' avatars (EnemyBatch) run by the native library: each avatar's state (AvatarBase's,
## HordeAvatar's, ChargerAvatar's, StoneThrowerAvatar's, NeedleAvatar's (BatchNeedleRow), RockLurkerAvatar's
## (BatchLurker), WardenAvatar's (BatchWarden), SniperAvatar's (BatchSniperRow), ArcCasterAvatar's (BatchArcCaster),
## LensDroneAvatar's (BatchLensDrone), BombDroneAvatar's (BatchBombDrone), ScrapHoundAvatar's (BatchScrapHound) or
## KilnBeetleAvatar's (BatchKilnBeetle)
## fields that change after setup) is a row of packed doubles here, and ZdCrowd (native/src/zd_avatar*, the same
## arithmetic in the same order) applies each sync, steps each frame and writes VatCrowd's body and shadow instances
## from the rows: one call each, none per enemy.
## The rows hold the state while `on`; the avatar objects then hold old numbers, except around an event:
## - an event on an avatar (a flinch, a hold, a death, a sync or a step called on it: AvatarBase._touch) first copies
##   its row into it (pull) and marks it the holder (dirty); its own GDScript runs the event as before, and the batch
##   copies it back (push) before its next native call;
## - a read (a test's, a tool's: AvatarBase._peek) pulls the row without taking the state;
## - the hit look (show_hit) is written into the row straight away.
## The sync's inputs come from EnemyBatch.update (note_sync) and are applied in one call at the end of the views'
## sync (flush), with the catch-up steps of the enemies that came on screen (warm). Without the library, with
## EnemyBatch.native off, or with any avatar no native class covers, `on` is false and every avatar runs its own code.
## A row's layout and its copies to and from its avatar are BatchRows'; the fallback's sync is BatchScriptSync's.
## Presentation only (EI-07).

## A Stone Thrower's sync inputs past the common ones, a slot (zd_avatar.h MORE): its ticks into the state, its
## facing (x, y), the sim's lift, flight and recovery ticks; a Needle's and a Sniper's: its HP (the first); a Rock
## Lurker's: disguised, rumbling. A Warden's: its HP, the telegraph's slam radius, whether it gave one
## (BatchWarden.note). A Scrap Hound's: its HP, whether a hit stopped it (BatchScrapHound.note).
const MORE := 6
## The native classes (zd_avatar.h Class) by kind; 0: none.
const CHARGER_CLASS := 8
const STONE_THROWER_CLASS := 10
const NEEDLE_CLASS := 11
const WARDEN_CLASS := 12
const ROCK_LURKER_CLASS := 13
const SNIPER_CLASS := 14
const ARC_CASTER_CLASS := 15
const LENS_DRONE_CLASS := 17
const BOMB_DRONE_CLASS := 16
const SCRAP_HOUND_CLASS := 18
const KILN_BEETLE_CLASS := 19
const FROST_SPITTER_CLASS := 21
const CLASS_OF := {
	WorldReader.KIND_SWARMER: 1,
	WorldReader.KIND_SPLITTER: 2,
	WorldReader.KIND_SPLITLING: 3,
	WorldReader.KIND_SHIELD_BEARER: 4,
	WorldReader.KIND_MENDER: 5,
	WorldReader.KIND_MINE_LAYER: 6,
	WorldReader.KIND_CHARGER: 8,
	WorldReader.KIND_HATCHLING: 9,
	WorldReader.KIND_STONE_THROWER: STONE_THROWER_CLASS,
	WorldReader.KIND_NEEDLE: NEEDLE_CLASS,
	WorldReader.KIND_ROCK_LURKER: ROCK_LURKER_CLASS,
	WorldReader.KIND_WARDEN: WARDEN_CLASS,
	WorldReader.KIND_RUBBLE_WARDEN: WARDEN_CLASS,
	WorldReader.KIND_SNIPER: SNIPER_CLASS,
	WorldReader.KIND_ARC_CASTER: ARC_CASTER_CLASS,
	WorldReader.KIND_LENS_DRONE: LENS_DRONE_CLASS,
	WorldReader.KIND_BOMB_DRONE: BOMB_DRONE_CLASS,
	WorldReader.KIND_SCRAP_HOUND: SCRAP_HOUND_CLASS,
	WorldReader.KIND_KILN_BEETLE: KILN_BEETLE_CLASS,
	WorldReader.KIND_FROST_SPITTER: FROST_SPITTER_CLASS,
}
## The owner's model kinds: native only with the model (their code bodies are never VAT-drawn).
const MODEL_CLASSES := [2, 3, 4, 5, 6]

## Whether the rows hold the state now.
var on := false
## The rows' serial: each native call that changes them moves it on (a row pulled at an older serial is old).
var serial := 0

var _rows := BatchRows.new()
var _cls := PackedInt32Array()
var _avatars: Array[AvatarBase] = []
var _ids := PackedInt32Array()
## Add order (VatCrowd's entries are in it), and each slot's VatCrowd body and shadow set (-1: none).
var _seq := PackedInt64Array()
var _next_seq := 0
var _body_of := PackedInt32Array()
var _shadow_of := PackedInt32Array()
## The facing: its rotation.y, and (mode 1, once leaned by the Void) its whole transform.
var _fyaw := PackedFloat32Array()
var _fmode := PackedByteArray()
var _fx := PackedFloat32Array()
## The sync's inputs (note_sync) waiting for flush, and the catch-up steps.
var _pending := PackedByteArray()
var _in_state := PackedInt32Array()
var _in_heal := PackedByteArray()
var _in_windup := PackedFloat64Array()
var _in_x := PackedFloat32Array()
var _in_y := PackedFloat32Array()
var _in_more := PackedFloat64Array()
var _warm := PackedByteArray()
var _tick := 0
var _any_pending := false
## Whether each avatar processes (its set_process; the batch steps it) and holds the state (dirty), and the serial
## its object was last pulled at.
var _proc := PackedByteArray()
var _dirty := PackedByteArray()
var _pulled := PackedInt64Array()
var _any_dirty := false
var _none := 0
var _slot_of := {}


## The native class of `avatar` (0: none: its GDScript runs it).
static func class_of(avatar: AvatarBase) -> int:
	var h := avatar as HordeAvatar
	if h != null:
		if not h.vat:
			return 0
		var c: int = CLASS_OF.get(h.kind, 0)
		if c >= CHARGER_CLASS or (MODEL_CLASSES.has(c) and not h.has_model()):
			return 0
		return c
	var ch := avatar as ChargerAvatar
	if ch != null and ch.vat:
		return CLASS_OF.get(ch.kind, 0)
	var st := avatar as StoneThrowerAvatar
	if st != null and st.vat:
		return STONE_THROWER_CLASS
	var nd := avatar as NeedleAvatar
	if nd != null and nd.vat:
		return NEEDLE_CLASS
	var lk := avatar as RockLurkerAvatar
	if lk != null and lk.vat:
		return ROCK_LURKER_CLASS
	var wd := avatar as WardenAvatar
	if wd != null and wd.vat:
		return WARDEN_CLASS
	var sn := avatar as SniperAvatar
	if sn != null and sn.vat:
		return SNIPER_CLASS
	var ac := avatar as ArcCasterAvatar
	if ac != null and ac.vat:
		return ARC_CASTER_CLASS
	var ld := avatar as LensDroneAvatar
	if ld != null and ld.vat:
		return LENS_DRONE_CLASS
	var bd := avatar as BombDroneAvatar
	if bd != null and bd.vat:
		return BOMB_DRONE_CLASS
	if avatar is ScrapHoundAvatar and (avatar as ScrapHoundAvatar).vat:
		return SCRAP_HOUND_CLASS
	var kb := avatar as KilnBeetleAvatar
	if kb != null and kb.vat:
		return KILN_BEETLE_CLASS
	if avatar is FrostSpitterAvatar and (avatar as FrostSpitterAvatar).vat:
		return FROST_SPITTER_CLASS
	return 0


## Whether every slot has a native class (else the whole batch runs in GDScript).
func all_native() -> bool:
	return _none == 0


func count() -> int:
	return _ids.size()


func add(id: int, avatar: AvatarBase, facing: Node3D, sets: Vector2i) -> void:
	var k := _ids.size()
	_slot_of[id] = k
	_ids.append(id)
	_avatars.append(avatar)
	avatar.set_meta(&"batch_id", id)
	var c := class_of(avatar)
	_cls.append(c)
	if c == 0:
		_none += 1
	_seq.append(_next_seq)
	_next_seq += 1
	_body_of.append(sets.x)
	_shadow_of.append(sets.y)
	_fyaw.append(facing.rotation.y)
	_fmode.append(0)
	for q in 12:
		_fx.append(0.0)
	_pending.append(0)
	_in_state.append(0)
	_in_heal.append(0)
	_in_windup.append(0.0)
	_in_x.append(0.0)
	_in_y.append(0.0)
	for q in MORE:
		_in_more.append(0.0)
	_warm.append(0)
	_proc.append(1 if avatar.is_processing() else 0)
	_dirty.append(0)
	_pulled.append(-1)
	_rows.grow()
	if on:
		_export(k)
		avatar.native_owner = self


## Slot `k` goes (the last one takes its place, as EnemyBatch's columns do).
func remove(k: int) -> void:
	var last := _ids.size() - 1
	var a: Variant = _avatars[k]
	if on and is_instance_valid(a):
		if _dirty[k] == 0:  # The object keeps the latest numbers (a falling body's root may still be read)
			_import(k)
		a.native_owner = null
	if _cls[k] == 0:
		_none -= 1
	_slot_of.erase(_ids[k])
	if k != last:
		_ids[k] = _ids[last]
		_slot_of[_ids[k]] = k
		_avatars[k] = _avatars[last]
		for q in 12:
			_fx[k * 12 + q] = _fx[last * 12 + q]
		for q in MORE:
			_in_more[k * MORE + q] = _in_more[last * MORE + q]
	_ids.resize(last)
	_avatars.resize(last)
	_rows.move_last(k)
	_fx.resize(last * 12)
	_in_more.resize(last * MORE)
	for col: StringName in [
		&"_cls",
		&"_seq",
		&"_body_of",
		&"_shadow_of",
		&"_fyaw",
		&"_fmode",
		&"_pending",
		&"_in_state",
		&"_in_heal",
		&"_in_windup",
		&"_in_x",
		&"_in_y",
		&"_warm",
		&"_proc",
		&"_dirty",
		&"_pulled",
	]:
		var arr: Variant = get(col)
		if k != last:
			arr[k] = arr[last]
		arr.resize(last)
		set(col, arr)


## Turns the rows on (each avatar's state copied in) or off (copied back), as `want` says.
func set_on(want: bool) -> void:
	if want == on:
		return
	if want:
		for k in _ids.size():
			if not is_instance_valid(_avatars[k]):
				continue
			_export(k)
			_dirty[k] = 0
			_pulled[k] = -1
			_avatars[k].native_owner = self
			_proc[k] = 1 if _avatars[k].is_processing() else 0
	else:
		_flush_inputs_in_script()
		for k in _ids.size():
			if not is_instance_valid(_avatars[k]):
				continue
			if _dirty[k] == 0:
				_import(k)
			_dirty[k] = 0
			_avatars[k].native_owner = null
		_any_dirty = false
	on = want


## AvatarBase._touch: the event about to run on `avatar` runs on its row's numbers, and the object holds the state
## until the next native call.
func touch(avatar: AvatarBase) -> void:
	var k: int = _slot_of.get(avatar.get_meta(&"batch_id", -1), -1)
	if k < 0 or _dirty[k] == 1:
		return
	if _pulled[k] != serial:
		_import(k)
	_dirty[k] = 1
	_any_dirty = true


## AvatarBase._peek: the object gets its row's numbers (the rows keep the state).
func peek(avatar: AvatarBase) -> void:
	var k: int = _slot_of.get(avatar.get_meta(&"batch_id", -1), -1)
	if k < 0 or _dirty[k] == 1 or _pulled[k] == serial:
		return
	_import(k)


## AvatarBase.show_hit: the hit look `v` on `avatar`'s row (and its object).
func show_hit(avatar: AvatarBase, v: Vector4) -> void:
	var k: int = _slot_of.get(avatar.get_meta(&"batch_id", -1), -1)
	if k < 0:
		return
	_rows.set_hit(k, v)


## EnemyBatch.update: slot `k`'s sync from actor row `i` (the avatar's sync(), its inputs kept for flush).
func note_sync(k: int, reader: WorldReader, i: int) -> void:
	var state := reader.actor_state(i)
	_tick = reader.tick()
	_in_state[k] = state
	var c := _cls[k]
	if c == STONE_THROWER_CLASS:  # (its sync reads no windup: its own ticks into the state, its facing, the ticks)
		var o := k * MORE
		var fwd := Kin.dir(reader.actor_facing(i))
		var ticks := reader.thrower_ticks(i)
		_in_more[o] = reader.actor_state_ticks(i)
		_in_more[o + 1] = fwd.x
		_in_more[o + 2] = fwd.y
		_in_more[o + 3] = ticks.x
		_in_more[o + 4] = ticks.y
		_in_more[o + 5] = ticks.z
	elif c == ROCK_LURKER_CLASS:  # (its sync reads the windup in any state, and its disguise)
		var o := k * MORE
		_in_windup[k] = float(reader.telegraph(i).get("progress", 0)) / 1000.0
		_in_more[o] = 1.0 if RockLurkerAvatar.disguised(reader, i) else 0.0
		_in_more[o + 1] = 1.0 if reader.lurker_rumbling(i) else 0.0
	elif c == WARDEN_CLASS:
		var v := BatchWarden.note(reader, i)
		var o := k * MORE
		_in_windup[k] = v[0]
		_in_more[o] = v[1]
		_in_more[o + 1] = v[2]
		_in_more[o + 2] = v[3]
	else:
		_in_windup[k] = (
			float(reader.telegraph(i).get("progress", 0)) / 1000.0
			if state == WorldReader.STATE_WINDUP
			else 0.0
		)
		if c == NEEDLE_CLASS or c == SNIPER_CLASS or c == BOMB_DRONE_CLASS:  # (its HP: a hit's flinch)
			_in_more[k * MORE] = reader.actor_hp(i)
		elif c == SCRAP_HOUND_CLASS:  # (and whether a hit stopped it: the yelp)
			BatchScrapHound.note(reader, i, _in_more, k * MORE)
		elif c == KILN_BEETLE_CLASS:  # (its HP and full HP: a hit's scrabble, the heat)
			_in_more[k * MORE] = reader.actor_hp(i)
			_in_more[k * MORE + 1] = reader.actor_max_hp(i)
		elif c == FROST_SPITTER_CLASS:  # (its HP: a hit's flinch)
			_in_more[k * MORE] = reader.actor_hp(i)
	if c >= CHARGER_CLASS:
		var p := reader.actor_pos(i)
		_in_x[k] = p.x
		_in_y[k] = p.y
	else:
		_in_heal[k] = 1 if c == 5 and reader.actor_heal_target(i) >= 0 else 0
	_pending[k] = 1
	_any_pending = true


## The facing of slot `k` turned to `yaw` (EnemyBatch.update), or leaned (`facing` given: its whole transform kept).
func facing_moved(k: int, facing: Node3D, leaned: bool) -> void:
	_fyaw[k] = facing.rotation.y
	if leaned:
		_fmode[k] = 1
	if _fmode[k] == 1:
		_put_fx(k * 12, facing.transform)


func set_processing(k: int, p_on: bool) -> void:
	_proc[k] = 1 if p_on else 0


## ActorViews' catch-up as slot `k` comes on screen (four 0.05 s steps after its sync).
func warm(k: int) -> void:
	_warm[k] = 1
	_any_pending = true


## The syncs noted since the last flush, applied in one native call (then the catch-ups).
func flush(crowd: Object, frame: Array) -> void:
	if not _any_pending:
		return
	_push()
	_rows.st = crowd.call(
		&"apply_sync",
		_rows.st,
		_cls,
		frame,
		_pending,
		_tick,
		_in_state,
		_in_heal,
		_in_windup,
		_in_x,
		_in_y,
		_in_more,
		_warm,
		_consts()
	)
	_pending.fill(0)
	_warm.fill(0)
	_any_pending = false
	serial += 1


## The frame step of every processing avatar not added this frame, in one native call.
func step(crowd: Object, frame: Array, born: PackedInt32Array, delta: float) -> void:
	_push()
	_rows.st = crowd.call(
		&"step_avatars",
		_rows.st,
		_cls,
		frame,
		_proc,
		born,
		Engine.get_process_frames(),
		delta,
		_consts()
	)
	serial += 1


## VatCrowd's sets `sets` ([index, body, period, drive floats, capacity] each) written natively: by set, [count,
## capacity, buffer, drive buffer].
func write_bodies(crowd: Object, frame: Array, bo: PackedVector3Array, sets: Array) -> Array:
	_push()
	var index := PackedInt32Array()
	var body := PackedByteArray()
	var period := PackedFloat64Array()
	var dn := PackedInt32Array()
	var caps := PackedInt32Array()
	for s: Array in sets:
		index.append(s[0])
		body.append(1 if s[1] else 0)
		period.append(s[2])
		dn.append(s[3])
		caps.append(s[4])
	return crowd.call(
		&"write_bodies",
		_rows.st,
		_cls,
		frame,
		_body_of,
		_shadow_of,
		_seq,
		bo,
		index,
		body,
		period,
		dn,
		caps,
		_consts()
	)


## Slot `k`'s row's value at `field` (BatchWarden).
func row_value(k: int, field: int) -> float:
	return _rows.value(k, field)


## Slot `k`'s avatar's own transform now (its row's while the rows hold the state).
func avatar_xf(k: int) -> Transform3D:
	if on and _dirty[k] == 0:
		return _rows.transform_of(k)
	return _avatars[k].transform


## The frame columns the native calls read beside the rows (the root at the batch's latest place).
func frame_columns(x1: PackedFloat32Array, y1: PackedFloat32Array, z1: PackedFloat32Array) -> Array:
	return [x1, y1, z1, _fyaw, _fmode, _fx]


## The pending syncs run on the objects (the rows are being turned off with syncs not yet applied).
func _flush_inputs_in_script() -> void:
	if not _any_pending:
		return
	_push()
	for k in _ids.size():
		if (_pending[k] == 0 and _warm[k] == 0) or not is_instance_valid(_avatars[k]):
			continue
		_import(k)
		var a := _avatars[k]
		a.native_owner = null
		if _pending[k] == 1:
			BatchScriptSync.apply(
				a,
				_cls[k],
				_tick,
				Vector2(_in_x[k], _in_y[k]),
				_in_state[k],
				_in_windup[k],
				_in_heal[k] == 1,
				_in_more,
				k * MORE
			)
		if _warm[k] == 1:
			for q in 4:
				a.advance(0.05)
		_export(k)
		a.native_owner = self
	_pending.fill(0)
	_warm.fill(0)
	_any_pending = false


func _consts() -> PackedFloat64Array:
	return PackedFloat64Array(
		[
			1.0 if ViewPrefs.reduced_motion else 0.0,
			WorldReader.STATE_SPAWN,
			WorldReader.STATE_MOVE,
			WorldReader.STATE_WINDUP,
			WorldReader.STATE_ACTIVE,
			WorldReader.STATE_RECOVER,
		]
	)


## The objects that held the state since the last native call copied back into their rows.
func _push() -> void:
	if not _any_dirty:
		return
	for k in _ids.size():
		if _dirty[k] == 1 and is_instance_valid(_avatars[k]):
			_export(k)
			_dirty[k] = 0
	_any_dirty = false


func _put_fx(o: int, xf: Transform3D) -> void:
	var b := xf.basis
	var v := [
		b.x.x,
		b.y.x,
		b.z.x,
		xf.origin.x,
		b.x.y,
		b.y.y,
		b.z.y,
		xf.origin.y,
		b.x.z,
		b.y.z,
		b.z.z,
		xf.origin.z
	]
	for q in 12:
		_fx[o + q] = v[q]


## Slot `k`'s avatar's fields into its row.
func _export(k: int) -> void:
	_rows.from_avatar(k, _avatars[k])


## Slot `k`'s row into its avatar's fields (then the object is as new as the row).
func _import(k: int) -> void:
	_pulled[k] = serial
	_rows.to_avatar(k, _avatars[k])

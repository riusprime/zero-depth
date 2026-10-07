class_name ReadableCause
extends RefCounted
## The readable-cause check (PLAN v0.1.0 Step 9, carried to v0.3.0 O): every DAMAGE the player takes must come from
## an attack whose telegraph was visible for at least SimTick.MIN_TELEGRAPH_TICKS before the hit, or from a
## projectile that was on screen for at least PROJECTILE_MIN_TICKS (or was fired by a telegraphed attack), and it
## must have a death-recap cause line in en and es.
## "Visible" is what the view is handed: WorldReader.telegraph (the same function that resolves the hit, EI-07).
## The harmless burrow ripple marks where a boss is, not the area it hits, so it doesn't count as a telegraph.
## Call observe(w) after every World.step. A read-only observer: it never changes the world.

## A projectile on screen this long is readable by itself (starting value: the telegraph minimum, 0.4 s).
const PROJECTILE_MIN_TICKS := SimTick.MIN_TELEGRAPH_TICKS

## Every DAMAGE to the player seen, and the ones that failed (each a Dictionary describing the hit).
var damage_count := 0
var violations: Array[Dictionary] = []
## Hits per cause key (the recap line), to show what the run covered.
var by_cause := {}
## The cause key of the latest hit (the death recap must show it when that hit kills).
var last_cause := ""
## Extra context written into each violation (seed, floor, phase).
var context := {}

var _reader: WorldReader
var _seq := 0
var _player_id := 0
## Per actor id: ticks its current telegraph has been visible, and the length of its last finished one.
var _streak := {}
var _last_run := {}
## Per actor id: kind, and (bosses) the attack in progress as of the last observe.
var _kind := {}
var _attack := {}
## Per projectile id: [birth tick, owner id, owner telegraph ticks at birth, boss attack at birth].
var _birth := {}
var _locale := {}


func _init(w: World) -> void:
	_reader = WorldReader.new(w)
	_seq = w.last_event_seq()
	_player_id = w.actors.ids[0]
	_locale = locale_rows()


func observe(w: World) -> void:
	for e in w.events_since(_seq):
		_seq = e.seq
		if e.kind == SimEvent.Kind.SPAWN and e.source_id != e.owner_id:  # a projectile (its owner fired it)
			_birth[e.source_id] = [
				e.tick, e.owner_id, _telegraphed(e.owner_id), _attack.get(e.owner_id, -1)
			]
		elif e.kind == SimEvent.Kind.DAMAGE and e.target_id == _player_id:
			_check(w, e)
	_update_streaks(w)


## The cause line the recap shows for a hit by actor kind `kind` (boss attack index `attack`, or -1).
static func cause_key(w: World, kind: int, attack: int, tags: int) -> String:
	var bt := w.boss_table_of_kind(kind)
	if bt != null:
		if attack >= 0 and attack < bt.attacks.size():
			return String(bt.attacks[attack].cause_key)
		for atk in bt.attacks:
			if atk.move == BossAttackTable.Move.BOLT_FAN and tags & SimEvent.TAG_PROJECTILE:
				return String(atk.cause_key)
		return ""
	return String(EndPanel.CAUSES.get(kind, ""))


## locale/strings.csv as {key: [en, es]}.
static func locale_rows() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	if f == null:
		return out
	var header := f.get_csv_line()
	var en := header.find("en")
	var es := header.find("es")
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() > maxi(en, es):
			out[row[0]] = [row[en], row[es]]
	return out


func _check(w: World, e: SimEvent) -> void:
	damage_count += 1
	var problems := PackedStringArray()
	var kind: int = _kind.get(e.owner_id, -1)
	var attack: int = _attack.get(e.owner_id, -1)
	var shown := 0
	var age := -1
	if e.effect_id == &"arena_band":
		_arena_hit(e)
		return
	if _birth.has(e.source_id):
		var b: Array = _birth[e.source_id]
		age = e.tick - int(b[0])
		shown = int(b[2])
		attack = int(b[3])
		if age < PROJECTILE_MIN_TICKS and shown < SimTick.MIN_TELEGRAPH_TICKS:
			problems.append(
				"projectile on screen %d ticks, fired after a %d-tick telegraph" % [age, shown]
			)
	else:
		shown = _telegraphed(e.owner_id)
		if shown < SimTick.MIN_TELEGRAPH_TICKS:
			problems.append("telegraph visible %d ticks" % shown)
	if kind < 0:
		problems.append("no attacker (owner %d)" % e.owner_id)
	var key := cause_key(w, kind, attack, e.tags)
	if key.is_empty():
		problems.append("no recap cause")
	elif (
		not _locale.has(key)
		or String(_locale[key][0]).is_empty()
		or String(_locale[key][1]).is_empty()
	):
		problems.append("cause %s missing en or es" % key)
	by_cause[key] = int(by_cause.get(key, 0)) + 1
	last_cause = key
	if problems.is_empty():
		return
	var v := context.duplicate()
	(
		v
		. merge(
			{
				"tick": e.tick,
				"owner_kind": kind,
				"attack": attack,
				"cause": key,
				"tags": e.tags,
				"projectile_age": age,
				"telegraph_ticks": shown,
				"problems": ", ".join(problems),
			}
		)
	)
	violations.append(v)


## The closing arena's band (v0.3.0 BX) hurts as damage over time from the boss, not from its attack in progress: its
## recap line is the band's, and its warning is the band's own mark (content checks it lasts MIN_TELEGRAPH_TICKS).
## v0.3.5 AI: before, such a hit was booked to the attack the boss was making, and a death by the band failed the
## recap match once the faster bosses made that happen.
func _arena_hit(e: SimEvent) -> void:
	var key := "CAUSE_BOSS_ARENA"
	by_cause[key] = int(by_cause.get(key, 0)) + 1
	last_cause = key
	if (
		not _locale.has(key)
		or String(_locale[key][0]).is_empty()
		or String(_locale[key][1]).is_empty()
	):
		var v := context.duplicate()
		v.merge({"tick": e.tick, "cause": key, "problems": "cause %s missing en or es" % key})
		violations.append(v)


func _telegraphed(id: int) -> int:
	var s: int = _streak.get(id, 0)
	return s if s > 0 else int(_last_run.get(id, 0))


func _update_streaks(w: World) -> void:
	var a := w.actors
	for i in range(1, a.size()):
		var id := a.ids[i]
		_kind[id] = a.kinds[i]
		if BossAi.is_boss_kind(a.kinds[i]):
			var b := BossAi.entry_of(w, i)
			_attack[id] = w.bosses.attack[b] if b >= 0 else -1
		var tel: Dictionary = _reader.telegraph(i) if a.dead[i] == 0 else {}
		var visible: bool = not tel.is_empty() and tel.get("shape", &"") != &"ripple"
		if visible:
			_streak[id] = int(_streak.get(id, 0)) + 1
		elif int(_streak.get(id, 0)) > 0:
			_last_run[id] = _streak[id]
			_streak[id] = 0

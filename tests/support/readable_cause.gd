class_name ReadableCause
extends RefCounted
## The readable-cause check (PLAN v0.1.0 Step 9, carried to v0.3.0 O): every DAMAGE the player takes must come from
## an attack whose telegraph was visible for at least SimTick.MIN_TELEGRAPH_TICKS before the hit, or from a
## projectile that was on screen for at least PROJECTILE_MIN_TICKS (or was fired by a telegraphed attack), and it
## must have a death-recap cause line in en and es.
## "Visible" is what the view is handed: WorldReader.telegraph (the same function that resolves the hit, EI-07).
## The harmless burrow ripple marks where a boss is, not the area it hits, so it doesn't count as a telegraph.
## Call observe(w) after every World.step. A read-only observer: it never changes the world.
## v0.9.0 EL: an elite's hit is booked to the attack it was making at the last observe (its ability, its plain attack,
## or, while it walked, a touch of its body: ELITE_CONTACT, readable by the body itself, no telegraph needed); its line
## is EliteAi's.
## v0.11.0 O9: a horde critter's hit is its touch (EnemyAi._critter_touch), readable by its body too; its line is
## EndPanel's.

## A projectile on screen this long is readable by itself (starting value: the telegraph minimum, 0.4 s).
const PROJECTILE_MIN_TICKS := SimTick.MIN_TELEGRAPH_TICKS
## v0.9.0 EL: _attack's value for an elite that was walking (its touch).
const ELITE_CONTACT := -100

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
## v0.8.0 BS2: per projectile id, the boss attack it carried at the last observe (ProjectileStore.cause: a returning
## javelin's, an egg's burst, a gaze's orbs, a shot after its ricochet carry their attack's late part).
var _carried := {}
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


## The cause line the recap shows for a hit by actor kind `kind` (boss attack index `attack`, or -1; v0.8.0 BS1/BS2:
## an attack's late part, BossSignatures.LATE_CAUSE + the attack, reads its late_cause_key, a turret's ricochet
## through the live boss's table, as BossAi.cause_key).
static func cause_key(w: World, kind: int, attack: int, tags: int) -> String:
	if EliteAi.is_elite_kind(kind):  # v0.9.0 EL
		var keys: Array = EliteAi.CAUSE_KEYS[kind]
		if tags & SimEvent.TAG_PROJECTILE or attack == EliteAi.Attack.BASIC:
			return String(keys[EliteAi.CAUSE_BASIC])
		return String(
			keys[EliteAi.CAUSE_CONTACT if attack == ELITE_CONTACT else EliteAi.CAUSE_ABILITY]
		)
	var bt := w.boss_table_of_kind(kind)
	if attack >= BossSignatures.LATE_CAUSE:
		if bt == null:
			for b in w.bosses.size():
				var i := w.actors.index_of(w.bosses.ids[b])
				if i >= 0:
					bt = BossAi.table_of(w, i)
					break
		return String(BossSignatures.late_cause_key(bt, attack)) if bt != null else ""
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
	if _no_actor_hit(w, e):  # the floor's and the bosses' hazards (v0.11.0 O13a: moved out, max-returns)
		return
	if _birth.has(e.source_id):
		var b: Array = _birth[e.source_id]
		age = e.tick - int(b[0])
		shown = int(b[2])
		attack = int(b[3])
		if int(_carried.get(e.source_id, -1)) >= 0:
			attack = int(_carried[e.source_id])
		if age < PROJECTILE_MIN_TICKS and shown < SimTick.MIN_TELEGRAPH_TICKS:
			problems.append(
				"projectile on screen %d ticks, fired after a %d-tick telegraph" % [age, shown]
			)
	elif EnemyAi.is_critter(kind):  # v0.11.0 O9: a critter's touch, readable by its body (as an elite's)
		pass
	elif attack != ELITE_CONTACT or not EliteAi.is_elite_kind(kind):
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


## v0.8.0 BS2 (S6): molten floor hurts as damage over time from the boss: lava (its flood stood, telegraphed, where
## it now burns) reads its attack's late line, the meltdown (warned by its glow) its own attack's line.
func _molten_hit(w: World, e: SimEvent) -> void:
	var key := ""
	var bs := w.bosses
	for k in bs.lava_x.size():
		if BossLava.lava_rect(bs, k).has_point(e.pos):
			key = cause_key(w, -1, BossSignatures.LATE_CAUSE + bs.lava_attack[k], 0)
			break
	if key.is_empty():
		var shapes := BossLava.melt_shapes(w)
		for k in shapes.size():
			var atk := BossLava.melt_attack(w, k)
			if atk != null and BossLava.melt_covers(shapes[k], e.pos, 0.0):
				key = String(atk.cause_key)
				break
	by_cause[key] = int(by_cause.get(key, 0)) + 1
	last_cause = key
	if not key.is_empty() and _locale.has(key) and not String(_locale[key][1]).is_empty():
		return
	var v := context.duplicate()
	v.merge({"tick": e.tick, "cause": key, "problems": "molten floor without a recap line"})
	violations.append(v)


## v0.9.0 DX (Q23): an explosive barrel's blast is no actor's attack: its warning is its own lit fuse (seen and heard
## for Breakables.fuse_ticks, at least the telegraph minimum), its recap line CAUSE_EXPLOSIVE_BARREL.
func _barrel_hit(w: World, e: SimEvent) -> void:
	var key := String(Breakables.CAUSE_KEY)
	by_cause[key] = int(by_cause.get(key, 0)) + 1
	last_cause = key
	var problems := PackedStringArray()
	if w.breakables == null or w.breakables.fuse_ticks < SimTick.MIN_TELEGRAPH_TICKS:
		problems.append("a barrel's fuse shorter than the telegraph minimum")
	if (
		not _locale.has(key)
		or String(_locale[key][0]).is_empty()
		or String(_locale[key][1]).is_empty()
	):
		problems.append("cause %s missing en or es" % key)
	if problems.is_empty():
		return
	var v := context.duplicate()
	v.merge({"tick": e.tick, "cause": key, "problems": ", ".join(problems)})
	violations.append(v)


## v0.9.0 LK (Q21): a Hazard Lockdown's strike is no actor's attack: its warning is its own ground mark (seen for
## LockdownTable.hazard_warn_ticks, at least the telegraph minimum), its recap line CAUSE_LOCKDOWN_HAZARD.
func _hazard_hit(w: World, e: SimEvent) -> void:
	var key := String(Lockdowns.CAUSE_KEY)
	by_cause[key] = int(by_cause.get(key, 0)) + 1
	last_cause = key
	var problems := PackedStringArray()
	if w.lockdown == null or w.lockdown.table.hazard_warn_ticks < SimTick.MIN_TELEGRAPH_TICKS:
		problems.append("a hazard's warning shorter than the telegraph minimum")
	if (
		not _locale.has(key)
		or String(_locale[key][0]).is_empty()
		or String(_locale[key][1]).is_empty()
	):
		problems.append("cause %s missing en or es" % key)
	if problems.is_empty():
		return
	var v := context.duplicate()
	v.merge({"tick": e.tick, "cause": key, "problems": ", ".join(problems)})
	violations.append(v)


func _telegraphed(id: int) -> int:
	var s: int = _streak.get(id, 0)
	return s if s > 0 else int(_last_run.get(id, 0))


func _update_streaks(w: World) -> void:
	var p := w.projectiles
	for k in p.size():
		var c := p.cause_of(k)
		if c >= 0:
			_carried[p.ids[k]] = c
	var a := w.actors
	for i in range(1, a.size()):
		var id := a.ids[i]
		_kind[id] = a.kinds[i]
		if BossAi.is_boss_kind(a.kinds[i]):
			var b := BossAi.entry_of(w, i)
			_attack[id] = w.bosses.attack[b] if b >= 0 else -1
		elif EliteAi.is_elite_kind(a.kinds[i]):  # v0.9.0 EL: walking (a touch) or the attack it makes
			_attack[id] = ELITE_CONTACT if a.state[i] == EnemyAi.State.MOVE else a.pick[i]
		var tel: Dictionary = _reader.telegraph(i) if a.dead[i] == 0 else {}
		var visible: bool = not tel.is_empty() and tel.get("shape", &"") != &"ripple"
		if visible:
			_streak[id] = int(_streak.get(id, 0)) + 1
		elif int(_streak.get(id, 0)) > 0:
			_last_run[id] = _streak[id]
			_streak[id] = 0


## v0.11.0 O3 (owner L5): a quake pillar's pulse is damage over time from the boss, not from its attack in progress:
## its warning is its own ring, growing for QuakeTable.warn_ticks (at least the telegraph minimum) before it hits,
## its recap line the table's cause_key.
func _quake_hit(w: World, e: SimEvent) -> void:
	var bi := w.actors.index_of(e.owner_id)
	var q: QuakeTable = BossAi.table_of(w, bi).quake if bi >= 0 else null
	var key := String(q.cause_key) if q != null else ""
	by_cause[key] = int(by_cause.get(key, 0)) + 1
	last_cause = key
	var problems := PackedStringArray()
	if q == null or q.warn_ticks < SimTick.MIN_TELEGRAPH_TICKS:
		problems.append("a quake pillar's ring warns shorter than the telegraph minimum")
	if (
		not _locale.has(key)
		or String(_locale[key][0]).is_empty()
		or String(_locale[key][1]).is_empty()
	):
		problems.append("cause %s missing en or es" % key)
	if problems.is_empty():
		return
	var v := context.duplicate()
	v.merge({"tick": e.tick, "cause": key, "problems": ", ".join(problems)})
	violations.append(v)


## v0.11.0 O13a: an Ember Charger's fire trail is no attack of its own: its warning is the fire itself, on the ground
## for its arm time (at least the telegraph minimum) before it burns; its recap line Variants.CAUSE_KEY.
func _trail_hit(w: World, e: SimEvent) -> void:
	var key := String(Variants.CAUSE_KEY)
	by_cause[key] = int(by_cause.get(key, 0)) + 1
	last_cause = key
	var problems := PackedStringArray()
	var t := w.enemy_table(ActorStore.Kind.EMBER_CHARGER)
	if t == null or t.trail_arm_ticks < SimTick.MIN_TELEGRAPH_TICKS:
		problems.append("a fire trail that burns before the telegraph minimum")
	if (
		not _locale.has(key)
		or String(_locale[key][0]).is_empty()
		or String(_locale[key][1]).is_empty()
	):
		problems.append("cause %s missing en or es" % key)
	if problems.is_empty():
		return
	var v := context.duplicate()
	v.merge({"tick": e.tick, "cause": key, "problems": ", ".join(problems)})
	violations.append(v)


## A hit no actor's attack landed (each booked by its own rule), dispatched by its effect; false for any other hit.
func _no_actor_hit(w: World, e: SimEvent) -> bool:
	match e.effect_id:
		&"arena_band":
			_arena_hit(e)
		&"molten_floor":  # v0.8.0 BS2: lava or the meltdown
			_molten_hit(w, e)
		BossQuake.EFFECT:  # v0.11.0 O3: a quake pillar's pulse
			_quake_hit(w, e)
		Breakables.EFFECT:  # v0.9.0 DX: an explosive barrel's blast
			_barrel_hit(w, e)
		Lockdowns.HAZARD_EFFECT:  # v0.9.0 LK: a Hazard Lockdown's strike
			_hazard_hit(w, e)
		Variants.FIRE_EFFECT:  # v0.11.0 O13a: an Ember Charger's fire trail
			_trail_hit(w, e)
		RuinsRocks.CABLE_EFFECT:  # v0.11.0 O13b: a Wire Weaver's live cable
			_cable_hit(w, e)
		CanyonShore.BURST_EFFECT, CanyonShore.VENT_EFFECT, CanyonShore.CHUNK_EFFECT:  # v0.11.0 O13c
			_canyon_shore_hit(w, e)
		_:
			return false
	return true


## v0.11.0 O13b: a Wire Weaver's live cable is no attack of its own: its warning is the Weaver's marked line and the
## posts sparking as they go in (its windup, at least the telegraph minimum), then the cable itself in plain sight; its
## recap line RuinsRocks.CAUSE_KEY.
func _cable_hit(w: World, e: SimEvent) -> void:
	var key := String(RuinsRocks.CAUSE_KEY)
	by_cause[key] = int(by_cause.get(key, 0)) + 1
	last_cause = key
	var problems := PackedStringArray()
	var t := w.enemy_table(ActorStore.Kind.WIRE_WEAVER)
	if t == null or t.windup_ticks < SimTick.MIN_TELEGRAPH_TICKS:
		problems.append("a cable planted before the telegraph minimum")
	if (
		not _locale.has(key)
		or String(_locale[key][0]).is_empty()
		or String(_locale[key][1]).is_empty()
	):
		problems.append("cause %s missing en or es" % key)
	if problems.is_empty():
		return
	var v := context.duplicate()
	v.merge({"tick": e.tick, "cause": key, "problems": ", ".join(problems)})
	violations.append(v)


## v0.11.0 O13c: a Kiln Beetle's burst, a lava vent's eruption or an ice chunk is no actor's attack: each one's warning
## is on the floor first (the burst's circle for its delay, the vent's pulse, the chunk sliding), at least the telegraph
## minimum (CanyonShore.warning_ticks); its recap line CanyonShore.cause_of_effect.
func _canyon_shore_hit(w: World, e: SimEvent) -> void:
	var key := String(CanyonShore.cause_of_effect(e.effect_id))
	by_cause[key] = int(by_cause.get(key, 0)) + 1
	last_cause = key
	var problems := PackedStringArray()
	if CanyonShore.warning_ticks(w, e.effect_id) < SimTick.MIN_TELEGRAPH_TICKS:
		problems.append("%s warned for less than the telegraph minimum" % e.effect_id)
	if (
		not _locale.has(key)
		or String(_locale[key][0]).is_empty()
		or String(_locale[key][1]).is_empty()
	):
		problems.append("cause %s missing en or es" % key)
	if problems.is_empty():
		return
	var v := context.duplicate()
	v.merge({"tick": e.tick, "cause": key, "problems": ", ".join(problems)})
	violations.append(v)

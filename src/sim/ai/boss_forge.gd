class_name BossForge
extends RefCounted
## The Foundry's forge (BossTable.forge, a BossForgeTable; BossFightStore.fg_*): a plate its own bomb drones blow off,
## and the scald gauge the hero carries in its last phase. The cooling slag and Overpressure are BossSlag's. All are
## beside the boss's attacks (casts, not attacks: it goes on fighting).
## - The Forged Plate, from plate_phase: the first forging begins plate_first_ticks into that phase, then one is due
##   plate_every_ticks after each blow (never while it wears one). The forging lasts plate_cast_ticks; then the boss
##   takes plate_taken per mille of every hit and damage tick from the hero (Damage, taken_permille). A bomb drone's
##   lobbed bomb landing within drone_blast_m of the boss's edge is the only thing that takes it off: the boss is
##   exposed for exposed_ticks at exposed_taken per mille. The drone's bomb is its detonation: a drone the hero kills
##   does not explode, so it counts for nothing. The drone aims its bomb at the hero, so a hero standing by the boss
##   when a drone throws brings the bomb down on the boss. While it wears the plate and no drone of drone_kind is
##   alive or arriving, it launches one drone_distance_m past its edge (no sooner than drone_gap_ticks after the last
##   it launched), so the answer is always on the floor. Nothing else of the drone's blast touches the boss.
## - The scald gauge, from scald_phase, 0..scald_max, on the hero: + scald_hit for each of the boss's own shots that
##   hurts it (Damage, on_hero_hurt); every scald_step_ticks + scald_lava standing in molten floor, a pool or the
##   meltdown's melt, and - scald_drain standing on a slab (BossSlag); + scald_open each Overpressure step off a slab
##   (BossSlag). It never falls by itself. At scald_max the hero burns for scald_burn per mille of max HP each step
##   (SafeArea STEP: the hurt invulnerability neither swallows a step nor is given by one) until it is below the max.
## - Neither begins while the boss kneels at a phase change. With the hero dead or outside the room the gauge empties
##   and Overpressure ends (cancel); with the boss gone everything goes (on_boss_gone).
## Pure: no stream is drawn; everything follows from the clock, the positions and the drones' own bombs.

const S := EnemyAi.State
## STATUS_APPLY effects for the views and the tests (source the boss). FORGE_CAST: a forging begins (amount = its
## ticks). PLATE_ON: the plate is on. PLATE_BLOWN: a drone's bomb blew it off (pos = where the bomb landed, target =
## the drone, amount = the exposed ticks). PLATE_DRONE: the boss launched a drone for its plate (pos = where).
## SCALD_BURN: the gauge is full and the hero burns (target the hero). SCALD_BURN_END: it is below full again.
const FORGE_CAST := &"forge_cast"
const PLATE_ON := &"plate_forged"
const PLATE_BLOWN := &"plate_blown"
const PLATE_DRONE := &"plate_drone"
const SCALD_BURN := &"scald_burn"
const SCALD_BURN_END := &"scald_burn_end"
## The damage effect id of the scald's burn.
const SCALD_EFFECT := &"boss_scald"
## Angles tried round the boss for a drone's spot, from the line to the hero (1/4096 turns apart).
const DRONE_TRIES := 8
## A drone's spot keeps this far from every wall.
const DRONE_CLEAR_M := 0.6


## Tick phase 6 (BossSignatures.advance, after the arena hazards and the molten floor): the boss with a forge runs it.
static func advance(w: World) -> void:
	var i := _forger(w)
	if i < 0:
		return
	if BossSlow.fight_over(w):
		cancel(w)
		return
	var f := BossAi.table_of(w, i).forge
	var phase := w.bosses.phase[BossAi.entry_of(w, i)]
	_plate(w, i, f, phase)
	BossSlag.advance(w, i, f, phase)
	_scald(w, i, f, phase)


## The boss that runs the forge (its actor index), or -1. The first live one with a forge takes the clocks once it
## has reached the forge's first phase (so its earlier phase hashes as before); one at a time.
static func _forger(w: World) -> int:
	var bs := w.bosses
	var fs := w.boss_fight
	var a := w.actors
	if fs.fg_boss >= 0:
		var i := a.index_of(fs.fg_boss)
		return i if i >= 0 and a.dead[i] == 0 else -1
	for b in bs.size():
		var t: BossTable = w.boss_tables[bs.table[b]]
		var i := a.index_of(bs.ids[b])
		if t.forge == null or i < 0 or a.dead[i] == 1 or a.state[i] == S.SPAWN:
			continue
		if bs.phase[b] < t.forge.first_phase():
			continue
		fs.clear_forge()
		fs.fg_boss = bs.ids[b]
		return i
	return -1


## The forge of the boss with actor id `boss_id` when it runs the forge, else null.
static func forge_of(w: World, boss_id: int) -> BossForgeTable:
	if w.boss_fight.fg_boss < 0 or w.boss_fight.fg_boss != boss_id:
		return null
	var i := w.actors.index_of(boss_id)
	return BossAi.table_of(w, i).forge if i >= 0 else null


# --- the plate ----------------------------------------------------------------------------------------------------


static func _plate(w: World, i: int, f: BossForgeTable, phase: int) -> void:
	var bs := w.boss_fight
	if phase < f.plate_phase:
		return
	if bs.fg_plate_due < 0:
		bs.fg_plate_due = w.tick + f.plate_first_ticks
	if bs.fg_cast_from >= 0:
		if w.tick - bs.fg_cast_from >= f.plate_cast_ticks:
			bs.fg_cast_from = -1
			bs.fg_plate = 1
			bs.fg_exposed_until = 0
			_event(w, i, PLATE_ON, w.actors.pos(i))
	elif (
		bs.fg_plate == 0
		and w.tick >= bs.fg_plate_due
		and w.tick >= bs.fg_exposed_until
		and w.actors.state[i] != BossAi.GATE
	):
		bs.fg_cast_from = w.tick
		_event(w, i, FORGE_CAST, w.actors.pos(i)).amount = f.plate_cast_ticks
	if bs.fg_plate == 1:
		_blasts(w, i, f)
	if bs.fg_plate == 1:
		_drone(w, i, f)


## A drone's bomb landing this tick within drone_blast_m of boss i's edge blows its plate off (the first one, in
## actor order). A bomb lands on the tick its lob ends (the drone's BURST pattern's lob_ticks into its attack), where
## its throw was aimed.
static func _blasts(w: World, i: int, f: BossForgeTable) -> void:
	var a := w.actors
	var reach := a.radius[i] + f.drone_blast_m
	for j in range(1, a.size()):
		if a.kinds[j] != f.drone_kind or a.dead[j] == 1 or a.state[j] != S.ACTIVE:
			continue
		var pat := EnemyAi.pattern_of(w, j)
		if (
			pat == null
			or pat.kind != BulletPatternTable.Kind.BURST
			or a.state_t[j] != pat.lob_ticks
		):
			continue
		var at := Vector2(a.lock_x[j], a.lock_y[j])
		if Kin.length(at - a.pos(i)) > reach:
			continue
		var bs := w.boss_fight
		bs.fg_plate = 0
		bs.fg_exposed_until = w.tick + f.exposed_ticks
		bs.fg_plate_due = w.tick + f.plate_every_ticks
		var e := _event(w, i, PLATE_BLOWN, at)
		e.target_id = a.ids[j]
		e.amount = f.exposed_ticks
		return


## While plated with no drone alive or arriving, one is launched (not while the boss kneels).
static func _drone(w: World, i: int, f: BossForgeTable) -> void:
	var bs := w.boss_fight
	if f.drone_kind < 0 or w.enemy_table(f.drone_kind) == null or w.actors.state[i] == BossAi.GATE:
		return
	if BossAi.alive_of(w, f.drone_kind) > 0:
		return
	if bs.fg_drone_at >= 0 and w.tick - bs.fg_drone_at < f.drone_gap_ticks:
		return
	var at := drone_spot(w, i, f)
	if not at.is_finite():
		return
	w.queue_enemy(f.drone_kind, at)
	bs.fg_drone_at = w.tick
	_event(w, i, PLATE_DRONE, at)


## Where boss i launches a drone: drone_distance_m past its edge, toward the hero, else the next of DRONE_TRIES
## angles round it, the first clear of walls and inside the room. Vector2.INF when none is.
static func drone_spot(w: World, i: int, f: BossForgeTable) -> Vector2:
	var c := w.actors.pos(i)
	var aim := Kin.angle_of(w.player_pos() - c)
	var d := w.actors.radius[i] + f.drone_distance_m
	var room := w.bosses.arena
	for k in DRONE_TRIES:
		var p := c + Kin.dir(aim + k * 4096 / DRONE_TRIES) * d
		if room.has_area() and not room.grow(-DRONE_CLEAR_M).has_point(p):
			continue
		if EnemyAi.clear_of_walls(w, p, DRONE_CLEAR_M):
			return p
	return Vector2.INF


## Damage: the share of a hit or tick from the hero that boss `target` (an actor index) takes: plate_taken while it
## wears the plate, exposed_taken while it is exposed, else 1000.
static func taken_permille(w: World, target: int) -> int:
	var bs := w.boss_fight
	if bs.fg_boss < 0 or w.actors.ids[target] != bs.fg_boss:
		return 1000
	var f := BossAi.table_of(w, target).forge
	if f == null:
		return 1000
	if bs.fg_plate == 1:
		return f.plate_taken
	if w.tick < bs.fg_exposed_until:
		return f.exposed_taken
	return 1000


# --- the scald gauge ----------------------------------------------------------------------------------------------


static func _scald(w: World, i: int, f: BossForgeTable, phase: int) -> void:
	var bs := w.boss_fight
	if phase < f.scald_phase or w.player_dead():
		return
	if bs.fg_scald_at < 0:
		bs.fg_scald_at = w.tick + f.scald_step_ticks
	if w.tick < bs.fg_scald_at:
		return
	# On its own beat: a step a hit's freeze held back is taken on the first tick after it and the beat stays
	bs.fg_scald_at = maxi(bs.fg_scald_at + f.scald_step_ticks, w.tick + 1)
	var p := w.player_pos()
	var g := bs.fg_scald
	if in_lava(w, i, p):
		g += f.scald_lava
	if BossSlag.slab_under(w, p) >= 0:
		g -= f.scald_drain
	set_scald(w, i, f, g)
	if bs.fg_burning == 1:
		SafeArea.hurt(w, i, f.scald_burn, SafeArea.Mode.STEP, f.scald_cause, SCALD_EFFECT)


## True when p stands in boss i's molten floor, an armed burning pool of its, or its meltdown's melt.
static func in_lava(w: World, i: int, p: Vector2) -> bool:
	var bs := w.bosses
	var id := w.actors.ids[i]
	for k in bs.lava_x.size():
		if (
			bs.lava_boss[k] == id
			and bs.lava_from[k] <= w.tick
			and BossLava.lava_rect(bs, k).has_point(p)
		):
			return true
	for k in bs.hz_x.size():
		if bs.hz_boss[k] != id or bs.hz_arm[k] > w.tick or bs.hz_kind[k] != HazardTable.Kind.DAMAGE:
			continue
		if Kin.length(Vector2(bs.hz_x[k], bs.hz_y[k]) - p) <= bs.hz_r[k]:
			return true
	for m: Array in BossLava.melt_shapes(w):
		if BossLava.melt_covers(m, p, 0.0):
			return true
	return false


## The gauge set to g (held to 0..scald_max); the burn starts at the max and stops below it.
static func set_scald(w: World, i: int, f: BossForgeTable, g: int) -> void:
	var bs := w.boss_fight
	bs.fg_scald = clampi(g, 0, f.scald_max)
	var full := 1 if bs.fg_scald >= f.scald_max else 0
	if full == bs.fg_burning:
		return
	bs.fg_burning = full
	var e := _event(w, i, SCALD_BURN if full == 1 else SCALD_BURN_END, w.player_pos())
	e.target_id = w.actors.ids[0]


## Damage._apply: the hero lost `applied` HP to a hit owned by `owner_id`: one of the forging boss's own shots fills
## the gauge in its scald phase.
static func on_hero_hurt(w: World, owner_id: int, tags: int, applied: int) -> void:
	var bs := w.bosses
	var fs := w.boss_fight
	if fs.fg_boss < 0 or owner_id != fs.fg_boss or applied <= 0:
		return
	if not (tags & SimEvent.TAG_PROJECTILE) or tags & SimEvent.TAG_DOT:
		return
	var i := w.actors.index_of(owner_id)
	if i < 0 or w.player_dead():
		return
	var f := BossAi.table_of(w, i).forge
	if f == null or bs.phase[BossAi.entry_of(w, i)] < f.scald_phase:
		return
	set_scald(w, i, f, fs.fg_scald + f.scald_hit)


# --- the end of a fight -------------------------------------------------------------------------------------------


## The hero is dead or outside the room: the gauge empties and Overpressure ends (the plate and the slabs stay).
static func cancel(w: World) -> void:
	var bs := w.boss_fight
	var i := w.actors.index_of(bs.fg_boss) if bs.fg_boss >= 0 else -1
	if bs.fg_burning == 1 and i >= 0:
		_event(w, i, SCALD_BURN_END, w.player_pos()).target_id = w.actors.ids[0]
	bs.fg_scald = 0
	bs.fg_burning = 0
	BossSlag.cancel(w, i)


## BossSignatures.on_boss_gone: the boss that ran the forge takes it, its slabs and the marker with it.
static func on_boss_gone(w: World, boss_id: int) -> void:
	if w.boss_fight.fg_boss != boss_id:
		return
	w.boss_fight.clear_forge()
	w.objectives.clear(ObjectiveMarkers.FOUNDRY_SLAB)


static func _event(w: World, i: int, effect: StringName, at: Vector2) -> SimEvent:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, at)
	e.effect_id = effect
	return e


## BossSlag's events.
static func event(w: World, i: int, effect: StringName, at: Vector2) -> SimEvent:
	return _event(w, i, effect, at)


# --- the view's read (WorldReader.boss_forge) ---------------------------------------------------------------------


## {} with no boss running a forge; else "boss" (its actor index), "plate" ({"forging" (0..1000 through the forging
## cast, -1 none), "on" (worn), "exposed_left" (ticks of exposure left, 0 none), "taken" (the share of the hero's
## damage it takes now, per mille), "next_in" (ticks until the next forging may begin, -1 not in its phase yet),
## "blast" (how far from the boss's edge a drone's bomb may land and still blow the plate off, m)}),
## "slabs" (BossSlag.rows: the cooling pools and the slabs), "overpressure" (BossSlag.over_state), "overpressure_in",
## "scald" ({} before its phase; else "gauge", "max", "burning", "draining" (the hero stands on a slab and the gauge
## is above 0)).
static func state(w: World) -> Dictionary:
	var bs := w.bosses
	var fs := w.boss_fight
	var i := w.actors.index_of(fs.fg_boss) if fs.fg_boss >= 0 else -1
	if i < 0:
		return {}
	var f := BossAi.table_of(w, i).forge
	var phase := bs.phase[BossAi.entry_of(w, i)]
	var forging := -1
	if fs.fg_cast_from >= 0:
		forging = clampi((w.tick - fs.fg_cast_from) * 1000 / maxi(1, f.plate_cast_ticks), 0, 1000)
	var scald := {}
	if phase >= f.scald_phase:
		scald = {
			"gauge": fs.fg_scald,
			"max": f.scald_max,
			"burning": fs.fg_burning == 1,
			"draining": fs.fg_scald > 0 and BossSlag.slab_under(w, w.player_pos()) >= 0,
		}
	return {
		"boss": i,
		"plate":
		{
			"forging": forging,
			"on": fs.fg_plate == 1,
			"exposed_left": maxi(0, fs.fg_exposed_until - w.tick),
			"taken": taken_permille(w, i),
			"next_in": maxi(0, fs.fg_plate_due - w.tick) if fs.fg_plate_due >= 0 else -1,
			"blast": f.drone_blast_m,
		},
		"slabs": BossSlag.rows(w, i, f),
		"overpressure": BossSlag.over_state(w, f),
		"overpressure_in": maxi(0, fs.fg_over_due - w.tick) if fs.fg_over_due >= 0 else -1,
		"scald": scald,
	}

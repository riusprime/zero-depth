class_name AudioEvents
extends RefCounted
## Which sounds one tick asks for (PLAN v0.3.0 L27). It reads the sim only through WorldReader (EI-07): the event
## log for hits, kills, pickups and the run flow, and edges in read state for what has no event (a swing starting,
## a dash, a blink, a telegraph, a stagger, a reward opening, low HP). Nothing here changes an outcome.
## Each request is [cue id, sim-plane position (or null = not positional), pitch factor].

## Below this share of max HP (per mille) the heartbeat plays (L24's 30 %).
const LOW_HP_PERMILLE := 300
## Ticks between heartbeats while HP is low (starting value).
const HEARTBEAT_TICKS := 54
## Boss hits and deaths are pitched down a little.
const BOSS_PITCH := 0.8
## A crit's hit is pitched up, so it rings sharper (v0.4.0 BS).
const CRIT_PITCH := 1.6

const BOSS_FLAVOUR := {
	WorldReader.KIND_GATEKEEPER: &"boss_telegraph_gatekeeper",
	WorldReader.KIND_BROOD_MOTHER: &"boss_telegraph_brood_mother",
	WorldReader.KIND_SIEGE_ENGINE: &"boss_telegraph_siege_engine",
	WorldReader.KIND_WARLORD: &"boss_telegraph_warlord",
	WorldReader.KIND_HIVE_LENS: &"boss_telegraph_hive_lens",
	WorldReader.KIND_FOUNDRY: &"boss_telegraph_foundry",
}
const DEATHS := {
	WorldReader.KIND_CHARGER: &"enemy_death_charger",
	WorldReader.KIND_WARDEN: &"enemy_death_warden",
	WorldReader.KIND_NEEDLE: &"enemy_death_needle",
	WorldReader.KIND_HATCHLING: &"enemy_death_hatchling",
	WorldReader.KIND_ARC_CASTER: &"enemy_death_arc_caster",
	WorldReader.KIND_BOMB_DRONE: &"enemy_death_bomb_drone",
	WorldReader.KIND_SWARMER: &"enemy_death_swarmer",
	WorldReader.KIND_SPLITTER: &"enemy_death_splitter",
	WorldReader.KIND_SPLITLING: &"enemy_death_hatchling",
	WorldReader.KIND_SHIELD_BEARER: &"enemy_death_shield_bearer",
	WorldReader.KIND_MENDER: &"enemy_death_mender",
	WorldReader.KIND_MINE_LAYER: &"enemy_death_mine_layer",
	WorldReader.KIND_SNIPER: &"enemy_death_sniper",
	WorldReader.KIND_LENS_DRONE: &"enemy_death_lens_drone",
}

var _last_seq := 0
var _kinds := {}
var _states := {}
var _phases := {}
var _projectiles := {}
## v0.3.5 AI: where each enemy's area spell (a rune, a bomb) is aimed, from its telegraph at the windup.
var _targets := {}
## v0.4.0 EN: each mine's last fuse (-1 idle), so arming and blowing play once.
var _mines := {}
var _dashing := false
var _swing_t := 0
var _echo_tick := -1
var _blink_tick := -1
var _choosing := false
var _denied_tick := -1
var _heartbeat_left := 0
## Overclock heat edges (v0.3.0 H): the last threshold-cross, overheat and vent ticks seen.
var _heat_ticks := [-1, -1, -1, 0]


## Starts from the reader's current state, so attaching mid-run plays nothing for what already happened.
func prime(reader: WorldReader) -> void:
	_last_seq = reader.last_event_seq()
	_dashing = reader.is_dashing()
	_swing_t = reader.swing_tick()
	_echo_tick = reader.echo_tick()
	_blink_tick = reader.blink_tick()
	_choosing = reader.choosing()
	_denied_tick = reader.reward_denied_tick()
	_heartbeat_left = 0
	_heat_ticks = _heat_edges(reader.heat_state())
	_kinds.clear()
	_states.clear()
	_phases.clear()
	_projectiles.clear()
	_targets.clear()
	_mines.clear()
	_scan_mines(reader, [])
	_scan_actors(reader, [])
	_scan_projectiles(reader, [])


## The sounds this tick asks for.
func collect(reader: WorldReader) -> Array:
	var out: Array = []
	_scan_actors(reader, out)
	_scan_mines(reader, out)
	_events(reader, out)
	_player(reader, out)
	_scan_projectiles(reader, out)
	_rewards(reader, out)
	_low_hp(reader, out)
	_heat(reader, out)
	return out


func _events(reader: WorldReader, out: Array) -> void:
	var player_id := reader.actor_id(0)
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		match e.kind:
			SimEvent.Kind.DAMAGE:
				if e.tags & SimEvent.TAG_DOT:
					continue  # ticks are silent (SFX_NEEDS)
				if e.target_id == player_id:
					out.append([&"hit_taken", null, 1.0])
				else:
					var p := BOSS_PITCH if _is_boss(e.target_id) else 1.0
					var proj := (e.tags & SimEvent.TAG_PROJECTILE) != 0
					if e.tags & SimEvent.TAG_CRIT:  # v0.4.0 BS: a crit rings sharper (the hit, pitched up)
						p *= CRIT_PITCH
					out.append([&"bolt_hit" if proj else &"enemy_hit", e.pos, p])
			SimEvent.Kind.HIT:
				if e.tags & (SimEvent.TAG_GUARDED | SimEvent.TAG_BLOCKED):
					out.append([&"guard_block", e.pos, 1.0])
			SimEvent.Kind.KILL:
				if e.target_id == player_id:
					out.append([&"player_death", null, 1.0])
				elif DEATHS.has(_kinds.get(e.target_id, -1)):
					out.append([DEATHS[_kinds[e.target_id]], e.pos, 1.0])
			SimEvent.Kind.PICKUP:
				out.append([&"item_pickup", null, 1.0])
			SimEvent.Kind.COMBO_UNLOCKED:
				out.append([&"combo_unlock", null, 1.0])
			SimEvent.Kind.BOSS_DEFEATED:
				out.append([&"boss_death", e.pos, 1.0])
			SimEvent.Kind.SHARDS:
				out.append([&"shard_collect", e.pos, 1.0])
			SimEvent.Kind.BOSS_ROOM_SEALED:
				out.append([&"boss_door_seal", null, 1.0])
			SimEvent.Kind.PORTAL_OPENED:
				out.append([&"portal_open", null, 1.0])
				if e.amount == 1:  # v0.5.0 RT: the Deep gate opened beside it
					out.append([&"deep_portal_open", e.pos, 1.0])
			SimEvent.Kind.FLOOR_EXIT:  # v0.3.5 PT: the hero goes into the portal (the blink's whoosh, lower)
				out.append([&"blink_out", null, 0.7])
			SimEvent.Kind.SKILL_USED:  # v0.3.5 K: the build skill, by its kind
				out.append([skill_cue(e.amount), e.pos, 1.0])
			SimEvent.Kind.VENT_COLD:  # v0.3.5 K: Vent pressed under Hot
				out.append([&"vent_cold", null, 1.0])
			SimEvent.Kind.HEAL:  # v0.4.0 EN: a Mender's beam lands a heal on an ally
				if e.target_id != player_id:
					out.append([&"mender_heal", e.pos, 1.0])


## Mines (v0.4.0 EN): a beep as one arms, the blast when an armed one goes off the floor.
func _scan_mines(reader: WorldReader, out: Array) -> void:
	var seen := {}
	for k in reader.mine_count():
		var id := reader.mine_id(k)
		var fuse := reader.mine_fuse(k)
		seen[id] = true
		if fuse >= 0 and int(_mines.get(id, [-1])[0]) < 0:
			out.append([&"mine_arm", reader.mine_pos(k), 1.0])
		_mines[id] = [fuse, reader.mine_pos(k)]
	for id in _mines.keys():
		if not seen.has(id):
			if int(_mines[id][0]) >= 0:
				out.append([&"mine_blast", _mines[id][1], 1.0])
			_mines.erase(id)


func _is_boss(actor_id: int) -> bool:
	return WorldReader.is_boss_kind(_kinds.get(actor_id, -1))


## Enemy windups, boss telegraphs, boss attacks landing, staggers and phase changes: edges in each actor's state.
func _scan_actors(reader: WorldReader, out: Array) -> void:
	for i in range(1, reader.actor_count()):
		var id := reader.actor_id(i)
		var kind := reader.actor_kind(i)
		_kinds[id] = kind
		if reader.actor_dead(i):
			continue
		var st := reader.actor_state(i)
		var was: int = _states.get(id, st)
		_states[id] = st
		var boss := WorldReader.is_boss_kind(kind)
		var phase := reader.boss_phase(i) if boss else 0
		var was_phase: int = _phases.get(id, phase)
		_phases[id] = phase
		if st == was:
			if boss and phase > was_phase:
				out.append([&"boss_phase", null, 1.0])
			continue
		var at := reader.actor_pos(i)
		if not boss:
			_enemy_cue(reader, i, kind, st, at, out)
			continue
		if st == WorldReader.STATE_WINDUP:
			out.append([&"boss_telegraph", null, 1.0])
			out.append([BOSS_FLAVOUR.get(kind, &"boss_telegraph"), at, 1.0])
		elif st == WorldReader.STATE_ACTIVE:
			var cue := attack_cue(reader.boss_move(i))
			if cue != &"":
				out.append([cue, at, 1.0])
		elif st == WorldReader.STATE_STAGGERED:
			out.append([&"boss_stagger", null, 1.0])
		if phase > was_phase:
			out.append([&"boss_phase", null, 1.0])


## A normal enemy's windup; the new kinds' own sounds (v0.3.5 AI): the Bomb Drone's lob and blast (at the circle),
## the Arc Caster's bolt and rune.
func _enemy_cue(reader: WorldReader, i: int, kind: int, st: int, at: Vector2, out: Array) -> void:
	if st == WorldReader.STATE_WINDUP:
		out.append(
			[&"bomb_lob" if kind == WorldReader.KIND_BOMB_DRONE else &"enemy_windup", at, 1.0]
		)
		var tg := reader.telegraph(i)
		if tg.has("center"):
			_targets[reader.actor_id(i)] = tg["center"]
	elif st == WorldReader.STATE_ACTIVE:
		var target: Vector2 = _targets.get(reader.actor_id(i), at)
		_targets.erase(reader.actor_id(i))
		if kind == WorldReader.KIND_BOMB_DRONE:
			out.append([&"bomb_blast", target, 1.0])
		elif kind == WorldReader.KIND_ARC_CASTER:
			var rune := reader.actor_spell(i) == WorldReader.SPELL_RUNE
			out.append([&"rune_erupt" if rune else &"arc_bolt", target if rune else at, 1.0])
		elif kind == WorldReader.KIND_SNIPER:  # v0.4.0 EN
			out.append([&"sniper_shot", at, 1.0])
		elif kind == WorldReader.KIND_SHIELD_BEARER:
			out.append([&"shield_bash", at, 1.0])


## The sound of a boss attack's active phase, by its move.
static func attack_cue(move: int) -> StringName:
	match move:
		WorldReader.MOVE_SLAM_RING, WorldReader.MOVE_LEAP, WorldReader.MOVE_BURROW, WorldReader.MOVE_CHARGE:
			return &"boss_slam"
		WorldReader.MOVE_SWEEP, WorldReader.MOVE_RAIL, WorldReader.MOVE_LANES:
			return &"boss_laser"
		WorldReader.MOVE_BARRAGE, WorldReader.MOVE_BOLT_FAN, WorldReader.MOVE_DEPLOY, WorldReader.MOVE_BROOD:
			return &"boss_mortar"
		WorldReader.MOVE_FLOOD:  # v0.4.0 BO: spears or molten floor bursting up along the lanes.
			return &"boss_floor_burst"
	return &""


## The blade (one cue per kind of swing), the dash and the blink.
func _player(reader: WorldReader, out: Array) -> void:
	var here := reader.player_pos()
	var t := reader.swing_tick()
	if t == 1 and _swing_t != 1:  # a swing's first tick (a hit-stop may hold it there; it plays once)
		out.append([swing_cue(reader.swing_motion(), reader.combo_step()), here, 1.0])
	_swing_t = t
	var et := reader.echo_tick()
	if et != _echo_tick and et >= 0:  # Twin Arc's echo swing: the third slash sound
		out.append([&"blade_slash_3", here, 1.0])
	_echo_tick = et
	var dashing := reader.is_dashing()
	if dashing and not _dashing:
		out.append([&"dash", here, 1.0])
	_dashing = dashing
	var bt := reader.blink_tick()
	if bt != _blink_tick and bt >= 0:
		out.append([&"blink_out", reader.blink_from(), 1.0])
		out.append([&"blink_in", here, 1.0])
	_blink_tick = bt


## v0.3.5 K: the sound of a build skill (SkillUsed's amount).
static func skill_cue(kind: int) -> StringName:
	return (
		&"skill_lunge_cleave" if kind == WorldReader.SKILL_LUNGE_CLEAVE else &"skill_scatter_blast"
	)


## The first two slashes have their own sounds (right-to-left, then the backhand); any later slash in the combo
## (and Twin Arc's echo, in _player) the third; the thrust and the spinning finisher theirs.
static func swing_cue(motion: int, step: int) -> StringName:
	match motion:
		WorldReader.MOTION_THRUST:
			return &"blade_thrust"
		WorldReader.MOTION_SPIN:
			return &"blade_spin"
	if step >= 2:
		return &"blade_slash_3"
	return (
		&"blade_slash_2" if motion == WorldReader.MOTION_SLASH_LEFT_TO_RIGHT else &"blade_slash_1"
	)


## A new projectile is a shot: the player's bolts and the enemies' shots, once per tick each.
func _scan_projectiles(reader: WorldReader, out: Array) -> void:
	var seen := {}
	var fired := false
	var hostile := false
	for i in reader.projectile_count():
		var id := reader.projectile_id(i)
		seen[id] = true
		if _projectiles.has(id):
			continue
		if reader.projectile_team(i) == 0:
			fired = fired or not reader.projectile_is_shard(i)
		else:
			hostile = true
	_projectiles = seen
	if fired:
		out.append([&"bolt_fire", reader.player_pos(), 1.0])
	if hostile:
		out.append([&"enemy_fire", null, 1.0])


func _rewards(reader: WorldReader, out: Array) -> void:
	var choosing := reader.choosing()
	if choosing and not _choosing:
		var r := reader.choice_reward()
		var altar := r >= 0 and reader.reward_kind(r) == WorldReader.REWARD_ALTAR
		out.append([&"altar_open" if altar else &"chest_open", null, 1.0])
	_choosing = choosing
	var denied := reader.reward_denied_tick()
	if denied != _denied_tick and denied >= 0:
		out.append([&"chest_refuse", null, 1.0])
	_denied_tick = denied


func _low_hp(reader: WorldReader, out: Array) -> void:
	var low := (
		not reader.player_dead()
		and reader.player_hp() * 1000 < reader.player_max_hp() * LOW_HP_PERMILLE
	)
	if not low:
		_heartbeat_left = 0
		return
	_heartbeat_left -= 1
	if _heartbeat_left <= 0:
		out.append([&"low_hp_heartbeat", null, 1.0])
		_heartbeat_left = HEARTBEAT_TICKS


static func _heat_edges(h: Dictionary) -> Array:
	if h.is_empty():
		return [-1, -1, -1, 0]
	return [int(h["tier_tick"]), int(h["overheat_tick"]), int(h["vent_tick"]), int(h["tier"])]


func _heat(reader: WorldReader, out: Array) -> void:
	var now := _heat_edges(reader.heat_state())
	var cues := [&"heat_threshold", &"heat_overheat", &"heat_vent"]
	for k in 3:
		var rising: bool = k != 0 or now[3] > _heat_ticks[3]  # a threshold sounds only on the way up
		if now[k] != _heat_ticks[k] and now[k] >= 0 and rising:
			out.append([cues[k], null, 1.0])
	_heat_ticks = now

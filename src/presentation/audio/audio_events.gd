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
## v0.9.0 DS (owner C35, Q19): `boss_door_impact.wav` peaks about 0.3 s in, so its cue starts this many ticks before
## the slab touches down (WorldReader.boss_door_open_ticks), and the boom lands with the slab.
const DOOR_IMPACT_LEAD_TICKS := 18

const BOSS_FLAVOUR := {
	WorldReader.KIND_GATEKEEPER: &"boss_telegraph_gatekeeper",
	WorldReader.KIND_BROOD_MOTHER: &"boss_telegraph_brood_mother",
	WorldReader.KIND_SIEGE_ENGINE: &"boss_telegraph_siege_engine",
	WorldReader.KIND_WARLORD: &"boss_telegraph_warlord",
	WorldReader.KIND_HIVE_LENS: &"boss_telegraph_hive_lens",
	WorldReader.KIND_FOUNDRY: &"boss_telegraph_foundry",
	# v0.8.0 FB1 (FINAL_BOSS.md F9: the existing boss sounds until audio is made): the stone one, the light one, the
	# blade one.
	WorldReader.KIND_COLOSSUS: &"boss_telegraph_gatekeeper",
	WorldReader.KIND_PRISM: &"boss_telegraph_hive_lens",
	WorldReader.KIND_NEMESIS: &"boss_telegraph_warlord",
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

## v0.4.0 AB: the element abilities' hits (and their combos') by effect: their own sound.
const ELEMENT_CUES := {
	&"arc_field": &"arc_field",
	&"superconductor": &"arc_field",
	&"frost_nova": &"frost_nova",
	&"flame_trail": &"flame_trail",
	&"napalm_drone": &"flame_trail",
	&"ember_ward": &"flame_trail",
	&"storm_bombs": &"arc_field",
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
var _shop_open := false
var _shop_denied := -1
var _heartbeat_left := 0
## Overclock heat edges (v0.3.0 H): the last threshold-cross, overheat and vent ticks seen.
var _heat_ticks := [-1, -1, -1, 0]
## v0.5.0 EV: the event panel open, the ambush on, and the last curse and payout ticks seen.
var _event_open := false
var _ambush := false
var _curse_tick := -1
var _done_tick := -1
## v0.4.0 AB: the Overrun room's last state (inside, cleared).
var _overrun := [false, false]
## v0.5.5 AR: the sealed arena's last state (sealed room, arenas cleared).
var _arena := [-1, 0]
## v0.9.0 DS: the boss door's last opening progress (-1 when it isn't opening), for the impact cue's edge.
var _door_progress := -1.0
## v0.9.0 SA: the arrival's last progress (-1 when none plays), for the altar cue's edge.
var _arrive_progress := -1.0
## v0.9.0 FA: the final approach's last lit pylons (bits), buildup progress and state, for their cues' edges.
var _pylons := 0
var _buildup := -1.0
var _approach := -1
## v0.9.0 TD: the timed door's last state, beeps heard and switches on (bits), for their cues' edges.
var _timed := -1
var _timed_beeps := 0
var _timed_switches := 0
## v0.9.0 RA: the rune pillars' last press ticks and whether the puzzle was solved, for their cues' edges.
var _rune_presses := PackedInt32Array()
var _rune_solved := false
## v0.9.0 DX: the cracked wall's last hit and break, and each prop's broken / fuse marks, for their cues' edges.
var _crack_hit := -1
var _crack_broken := false
var _props := PackedInt32Array()


## Starts from the reader's current state, so attaching mid-run plays nothing for what already happened.
func prime(reader: WorldReader) -> void:
	_last_seq = reader.last_event_seq()
	_dashing = reader.is_dashing()
	_swing_t = reader.swing_tick()
	_echo_tick = reader.echo_tick()
	_blink_tick = reader.blink_tick()
	_choosing = reader.choosing()
	_denied_tick = reader.reward_denied_tick()
	_shop_open = reader.shop_open()
	_shop_denied = reader.shop_denied_tick()
	_heartbeat_left = 0
	_heat_ticks = _heat_edges(reader.heat_state())
	var o := reader.overrun()
	_overrun = [o["inside"], o["cleared"]]
	var a := reader.arenas()
	_arena = [int(a["sealed"]), (a["cleared"] as PackedInt32Array).size()]
	_door_progress = reader.boss_door_progress()
	_arrive_progress = reader.arrival_progress()
	_pylons = pylon_mask(reader)
	_buildup = reader.approach_buildup_progress()
	_approach = reader.approach_state()
	_timed = reader.timed_door_state()
	_timed_beeps = TimedDoorView.beeps_now(reader)
	_timed_switches = switch_mask(reader)
	_rune_presses = rune_presses(reader)
	_rune_solved = reader.rune_solved()
	_crack_hit = reader.crack_hit_tick()
	_crack_broken = reader.crack_broken()
	_props = prop_marks(reader)
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
	_event_rooms(reader, out)  # v0.5.0 EV
	_overrun_edges(reader, out)
	_door_impact(reader, out)
	_arrival(reader, out)
	_final_approach(reader, out)
	_timed_door(reader, out)
	_rune_puzzle(reader, out)
	_breakables(reader, out)
	return out


## v0.9.0 DX (owner W §4 C, §5; Q23): a Skill hit on the cracked wall (`container_break`, at it) and its break
## (`wall_break`); a container breaking (`container_break`); a barrel's fuse lit (`barrel_fuse`) and its blast
## (`barrel_blast`).
func _breakables(reader: WorldReader, out: Array) -> void:
	if reader.has_cracked_wall():
		var at := reader.crack_door_center()
		if reader.crack_broken() and not _crack_broken:
			out.append([&"wall_break", at, 1.0])
		elif reader.crack_hit_tick() != _crack_hit:
			out.append([&"container_break", at, 1.0])
		_crack_hit = reader.crack_hit_tick()
		_crack_broken = reader.crack_broken()
	var marks := prop_marks(reader)
	for i in marks.size():
		var was := _props[i] if i < _props.size() else 0
		if marks[i] == was:
			continue
		var at := reader.breakable_pos(i)
		var barrel := reader.breakable_kind(i) == WorldReader.BREAKABLE_EXPLOSIVE
		if marks[i] == 2:
			out.append([&"barrel_blast" if barrel else &"container_break", at, 1.0])
		elif marks[i] == 1:
			out.append([&"barrel_fuse", at, 1.0])
	_props = marks


## Each prop's mark: 0 whole, 1 its fuse burning, 2 broken (or blown).
static func prop_marks(reader: WorldReader) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in reader.breakable_count():
		out.append(2 if reader.breakable_broken(i) else (1 if reader.breakable_fusing(i) else 0))
	return out


## v0.9.0 RA (owner Q22; "the pillar turns with a grind"): a pillar turning a quarter (`pillar_turn`, at it), and the
## slab sinking once all three match (the boss door's `boss_door_opening`, at the doorway).
func _rune_puzzle(reader: WorldReader, out: Array) -> void:
	if not reader.has_rune_puzzle():
		return
	var presses := rune_presses(reader)
	for k in presses.size():
		if k < _rune_presses.size() and presses[k] != _rune_presses[k]:
			out.append([&"pillar_turn", reader.interactable_pos(reader.rune_pillar_entry(k)), 1.0])
	_rune_presses = presses
	if reader.rune_solved() and not _rune_solved:
		out.append([&"boss_door_opening", reader.rune_door_center(), 1.0])
	_rune_solved = reader.rune_solved()


## Each rune pillar's last press tick (pillar k at k).
static func rune_presses(reader: WorldReader) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in reader.rune_pillar_count():
		out.append(reader.interactable_press_tick(reader.rune_pillar_entry(k)))
	return out


## v0.9.0 TD (owner W §2, Q20: "the boss door's opening sound, accelerating beeps, the door's impact on the shut"): a
## switch locking in (the pylons' lock-in), the door opening (`boss_door_opening`), each beep of the timer, faster as
## it runs out (TimedDoorView.beep_ticks; `timer_beep`, captioned), and the slab's heavy shut (`boss_door_impact`).
func _timed_door(reader: WorldReader, out: Array) -> void:
	if not reader.has_timed_door():
		return
	var mask := switch_mask(reader)
	for k in reader.timed_switch_count():
		if (mask & (1 << k)) != 0 and (_timed_switches & (1 << k)) == 0:
			out.append([&"pylon_lock", reader.interactable_pos(reader.timed_switch_entry(k)), 1.0])
	_timed_switches = mask
	var st := reader.timed_door_state()
	var at := reader.timed_door_center()
	if st == WorldReader.TIMED_OPEN and _timed == WorldReader.TIMED_SHUT:
		out.append([&"boss_door_opening", at, 1.0])
	elif st == WorldReader.TIMED_SHUT and _timed >= 0 and _timed != WorldReader.TIMED_SHUT:
		out.append([&"boss_door_impact", at, 1.0])
	var beeps := TimedDoorView.beeps_now(reader)
	if st == WorldReader.TIMED_OPEN and beeps > _timed_beeps:
		out.append([&"timer_beep", at, 1.0])
	_timed_beeps = beeps
	_timed = st


## The timed door's switches that are on, as bits (switch k: 1 << k).
static func switch_mask(reader: WorldReader) -> int:
	var m := 0
	for k in reader.timed_switch_count():
		if reader.interactable_state(reader.timed_switch_entry(k)) == 1:
			m |= 1 << k
	return m


## v0.9.0 FA (owner Q18: "it locks in with a sound"): a pylon switching on, the purple altar's buildup (its peak on the
## buildup's end, as SA's arrival), the walls of light rising (the boss door's seal).
func _final_approach(reader: WorldReader, out: Array) -> void:
	if not reader.final_approach():
		return
	var lit := pylon_mask(reader)
	for k in reader.approach_pylon_count():
		if (lit & (1 << k)) != 0 and (_pylons & (1 << k)) == 0:
			out.append([&"pylon_lock", reader.approach_pylon_pos(k), 1.0])
	_pylons = lit
	var b := reader.approach_buildup_progress()
	var at := final_cue_at(reader)
	if at >= 0.0 and b >= at and _buildup < at:
		out.append([AltarStage.final().cue, null, 1.0])
	_buildup = b
	var st := reader.approach_state()
	if (
		st == WorldReader.APPROACH_FIGHT
		and _approach != WorldReader.APPROACH_FIGHT
		and _approach >= 0
	):
		out.append([&"boss_door_seal", null, 1.0])
	_approach = st


## The final approach's lit pylons as bits (pylon k: 1 << k).
static func pylon_mask(reader: WorldReader) -> int:
	var m := 0
	for k in reader.approach_pylon_count():
		if reader.approach_pylon_lit(k):
			m |= 1 << k
	return m


## The share of the final approach's buildup at which the altar's cue starts, so its peak lands on the buildup's end
## (-1: the buildup is shorter than the cue's lead).
static func final_cue_at(reader: WorldReader) -> float:
	var seconds := float(reader.approach_buildup_ticks()) / SimTick.TICKS_PER_SECOND
	var lead := AltarStage.final().cue_peak_s / maxf(seconds, 0.001)
	return 1.0 - lead if lead <= 1.0 else -1.0


## v0.9.0 SA (owner Q16: "Your model, my sound": the lead's placeholder, `arrival_altar`): floor 1's altar hum and pop
## start so the file's peak (AltarStage.Look.cue_peak_s in) lands on the altar's pop (C18: "synchronized with the main
## audio cue"). An arrival shorter than the hum (reduced motion's fade-in) plays none.
func _arrival(reader: WorldReader, out: Array) -> void:
	var p := reader.arrival_progress()
	var at := arrival_cue_at(reader)
	if reader.arrival_altar() and at >= 0.0 and p >= at and _arrive_progress < at:
		out.append([AltarStage.arrival().cue, null, 1.0])
	_arrive_progress = p


## The share of the arrival at which the altar's cue starts (-1: the arrival is too short for it).
static func arrival_cue_at(reader: WorldReader) -> float:
	var l := AltarStage.arrival()
	var seconds := float(reader.arrival_ticks()) / SimTick.TICKS_PER_SECOND
	var lead := l.cue_peak_s / maxf(seconds, 0.001)
	return l.pop_at - lead if lead <= l.pop_at else -1.0


## v0.9.0 DS: the door's impact plays DOOR_IMPACT_LEAD_TICKS before the slab is down, so the file's peak meets the
## touchdown (the camera's thud stays on the touchdown, WorldViewRoot).
func _door_impact(reader: WorldReader, out: Array) -> void:
	var progress := reader.boss_door_progress()
	var at := door_impact_at(reader)
	if progress >= at and _door_progress >= 0.0 and _door_progress < at:
		out.append([&"boss_door_impact", reader.boss_door_center(), 1.0])
	_door_progress = progress


## The share of the door's opening at which its impact cue starts.
static func door_impact_at(reader: WorldReader) -> float:
	var ticks := reader.boss_door_open_ticks()
	return float(ticks - DOOR_IMPACT_LEAD_TICKS) / float(ticks)


## v0.4.0 AB: walking into the Overrun room sounds its alarm; clearing it, its fanfare.
func _overrun_edges(reader: WorldReader, out: Array) -> void:
	var o := reader.overrun()
	if o["inside"] and not _overrun[0]:
		out.append([&"overrun_enter", null, 1.0])
	if o["cleared"] and not _overrun[1]:
		out.append([&"overrun_clear", null, 1.0])
	_overrun = [o["inside"], o["cleared"]]
	# v0.5.5 AR: a regular arena sealing sounds the boss door's seal; its clear, the Overrun's fanfare (the Overrun
	# keeps its own alarm and fanfare above).
	var a := reader.arenas()
	var sealed := int(a["sealed"])
	var cleared := (a["cleared"] as PackedInt32Array).size()
	if sealed >= 0 and sealed != _arena[0] and not a["overrun_sealed"]:
		out.append([&"boss_door_seal", null, 1.0])
	if cleared > _arena[1] and int(a["last_cleared"]) != int(a["overrun"]):
		out.append([&"overrun_clear", null, 1.0])
	_arena = [sealed, cleared]


func _events(reader: WorldReader, out: Array) -> void:
	var player_id := reader.actor_id(0)
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		match e.kind:
			SimEvent.Kind.DAMAGE:
				if e.tags & SimEvent.TAG_DOT:
					continue  # ticks are silent (SFX_NEEDS)
				if ELEMENT_CUES.has(e.effect_id):  # v0.4.0 AB: the element's own sound
					out.append([ELEMENT_CUES[e.effect_id], e.pos, 1.0])
					continue
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
			SimEvent.Kind.BOSS_DOOR_OPENING:  # v0.8.0 BD (O83): the owner's sounds, at the door
				out.append([&"boss_door_opening", e.pos, 1.0])
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
			SimEvent.Kind.SHOP_BUY:  # v0.5.0 SH: a purchase, the heal or a reroll
				out.append([&"shop_buy", null, 1.0])
			SimEvent.Kind.SHOP_SALVAGE:  # v0.5.0 SH: a sale or an ability salvaged
				out.append([&"shop_sell", null, 1.0])
			SimEvent.Kind.GAMBLE_FAIL:  # v0.8.0 N14 (O72): the shrine's fizzle (Vent's cold click, lower)
				out.append([&"vent_cold", e.pos, 0.8])
			SimEvent.Kind.HEAL:  # v0.4.0 EN: a Mender's beam lands a heal on an ally
				if e.target_id != player_id:
					out.append([&"mender_heal", e.pos, 1.0])
			SimEvent.Kind.STATUS_APPLY:  # v0.8.0 FB3: the Nemesis dashes with the hero's dash cue, lower
				if e.effect_id == WorldReader.EFFECT_NEMESIS_DASH:
					out.append([&"dash", e.pos, 0.8])
			SimEvent.Kind.BLAST:  # v0.9.0 BM: a bomb bursts
				out.append([&"bomb_blast", e.pos, 1.0])


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
		if kind == WorldReader.KIND_BOMB_DRONE:  # v0.7.5 EF: the fireball's throw, toward where it lands
			out.append([&"bomb_blast", reader.telegraph(i).get("to", target), 1.0])
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
		WorldReader.MOVE_MARKS:  # v0.7.5 BF1: the tracked circle strikes; the lanes crack; the pattern fires
			return &"boss_slam"
		WorldReader.MOVE_ROW_LANES:
			return &"boss_laser"
		WorldReader.MOVE_PATTERN:
			return &"boss_mortar"
		WorldReader.MOVE_GRID:  # v0.7.5 BF3: the board's shells land; the molten rows burst up
			return &"boss_mortar"
		WorldReader.MOVE_ROW_FLOOD:
			return &"boss_floor_burst"
		WorldReader.MOVE_GAZE:  # v0.8.0 BS2: the beam opens; the ring melts
			return &"boss_laser"
		WorldReader.MOVE_MELT:
			return &"boss_floor_burst"
		WorldReader.MOVE_CROSS:  # v0.8.0 FB2: the Prism's Cross opens
			return &"boss_laser"
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
	if fired:  # v0.9.0 BM: the Bomb form's throw has its own toss
		out.append(
			[&"bomb_throw" if reader.bomb_active() else &"bolt_fire", reader.player_pos(), 1.0]
		)
	if hostile:
		out.append([&"enemy_fire", null, 1.0])


func _rewards(reader: WorldReader, out: Array) -> void:
	var choosing := reader.choosing()
	if choosing and not _choosing:
		var r := reader.choice_reward()
		var altar := (
			r >= 0 and reader.reward_kind(r) in [WorldReader.REWARD_ALTAR, WorldReader.REWARD_DROP]
		)
		out.append([&"altar_open" if altar else &"chest_open", null, 1.0])
	_choosing = choosing
	var denied := reader.reward_denied_tick()
	if denied != _denied_tick and denied >= 0:
		out.append([&"chest_refuse", null, 1.0])
	_denied_tick = denied
	var shop := reader.shop_open()  # v0.5.0 SH: the terminal wakes; a refused action buzzes
	if shop and not _shop_open:
		out.append([&"shop_open", null, 1.0])
	_shop_open = shop
	if reader.shop_denied_tick() != _shop_denied and reader.shop_denied_tick() >= 0:
		out.append([&"chest_refuse", null, 1.0])
	_shop_denied = reader.shop_denied_tick()


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


## v0.5.0 EV: a pedestal waking (its panel opening), an ambush starting, a curse taken, an event paying out.
func _event_rooms(reader: WorldReader, out: Array) -> void:
	var open := reader.event_open()
	if open and not _event_open:
		out.append([&"event_open", null, 1.0])
	_event_open = open
	var ambush := reader.event_ambush() >= 0
	if ambush and not _ambush:
		out.append([&"ambush_start", null, 1.0])
	_ambush = ambush
	if reader.curse_tick() != _curse_tick:
		if reader.curse_tick() >= 0:
			out.append([&"curse_gain", null, 1.0])
		_curse_tick = reader.curse_tick()
	if reader.event_done_tick() != _done_tick:
		if reader.event_done_tick() >= 0:
			out.append([&"event_done", null, 1.0])
		_done_tick = reader.event_done_tick()

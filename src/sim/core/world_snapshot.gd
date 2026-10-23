class_name WorldSnapshot
extends RefCounted
## v0.4.0 SV: the canonical snapshot of a whole World as plain data (SIM_CONTRACTS §10b), and its restore. Pure: no
## file I/O (the application's RunSaveStore writes the bytes).
##
## Every script variable of World, and of every state object it holds (STATE_CLASSES), is copied field by field,
## so state a workstream adds later is snapshotted without a list to keep. What is NOT copied is named here:
## - WORLD_KEPT: World fields the base world already has, because it was built from the same generation inputs
##   (the run seed, the floor, the build, the content), or that are derived and rebuilt on restore;
## - LOADOUT_CLASSES: content tables compiled at setup and never written in play, kept wherever they appear.
## An object of a class in neither list is an error naming it (the guard test fails), never a silent skip.
##
## Restore (apply) writes the snapshot into a base World built the way the original was: same seed, floor and
## loadout, any tick. Packed arrays are duplicated both ways, so a snapshot never shares memory with a world.

const FORMAT := 1
const CLASS_KEY := "@class"
## An Array[Obb] (the walls) is copied as packed columns: a dictionary per wall cost ~1.4 ms a snapshot.
const OBBS := &"Obb[]"
## World fields not copied field by field, and why. A value of "rebuilt" means apply() derives it again.
const WORLD_KEPT := {
	&"player": "loadout",
	&"enemy_tables": "loadout",
	&"encounter": "loadout",
	&"spawner": "loadout",
	&"floor_layout": "loadout (generated from the floor seed)",
	&"item_tables": "loadout",
	&"boss_tables": "loadout",
	&"reward_table": "loadout",
	&"gamble_table": "loadout",
	&"combo_tables": "loadout",
	&"ability_tables": "loadout",
	&"stat_tables": "loadout",
	&"overrun_table": "loadout",  # v0.4.0 AB
	&"shop_table": "loadout",  # v0.5.0 SH
	&"catch_up_table": "loadout",  # v0.5.5 DS
	&"arena_table": "loadout",  # v0.5.5 AR
	&"legendary_table": "loadout",  # v0.5.5 AR
	&"loot_pacing": "loadout",  # v0.8.0 FL
	&"attack_book": "rebuilt: compiled from the build again (v0.6.0 MX1, Modifiers)",
	&"hit_spec": "transient within a tick (v0.6.0 MX2): null between ticks",
	&"last_hit_crit": "transient within a hit (v0.6.5 WN1): read right after the hit that set it",
	&"hit_proc_permille": "transient within a hit (v0.8.0 MR): 1000 between hits",
	&"wand_table": "loadout",  # v0.6.5 WN1
	&"blade_table": "loadout",  # v0.6.5 WN4
	&"slot_table": "loadout",  # v0.9.0 AS
	&"elite_rules": "loadout",  # v0.9.0 EL
	&"ice": "loadout (v0.7.5 NB1: IcePatches lays it from the floor seed)",
	&"_events": "the presentation's event log, not state (its counter _event_seq is copied)",
	&"_wall_grid": "rebuilt: derived from walls",
	&"_wall_next": "setup (prepare_wall): only whether it is still pending is copied",
	&"_nav_next": "setup (prepare_wall): only whether it is still pending is copied",
	&"nav": "rebuilt from walls; its last flood and a build in progress (NF) are copied",
	&"_nav_open": "rebuilt: the field before the door sealed (apply's add_wall_now keeps it)",
	&"curse_totals": "rebuilt: Curses.total's cache, summed from curses_owned (v0.7.0 audit C-12)",
	&"phase_probe": "debug (v0.8.0 HS): the perf probe's phase timer, null in play, not state",
	&"debug_aoe_misses": "debug (v0.8.0 HS): a test's superset check, off in play",
	&"debug_aoe_full": "debug (v0.8.0 HS): a test's reference run, off in play",
	&"_hit_grid": "transient within a tick (v0.8.0 HS): built inside _projectile_hits only",
	&"_hit_grid_state": "transient within a tick (v0.8.0 HS): 0 between ticks",
	&"_every_index": "derived (v0.8.0 HS): 1 .. n - 1, rebuilt from the actor count",
}
## Content tables: compiled from content at setup, read-only in play (the guard test checks they don't change).
const LOADOUT_CLASSES: Array[StringName] = [
	&"PlayerTable",
	&"EnemyTable",
	&"EncounterTable",
	&"SpawnTable",
	&"FloorLayout",
	&"ShopRoomTable",  # v0.8.0 SR: the shop rooms (content, read when a floor is built)
	&"RoomLayoutTable",  # v0.8.0 RT/SR: a designed layout (content)
	&"RoomLayoutGroupTable",
	&"RoomLayoutPieceTable",
	&"ItemTable",
	&"BossTable",
	&"RewardTable",
	&"GambleTable",
	&"ComboTable",
	&"AbilityTable",
	&"StatTable",
	&"HeatTable",
	&"BossAttackTable",
	&"SwingStep",
	&"SkillTable",
	&"OverrunTable",  # v0.4.0 AB
	&"ShopTable",  # v0.5.0 SH
	&"ArenaTable",  # v0.5.5 AR
	&"LockdownTable",  # v0.9.0 LK: the Lockdowns' numbers (LockdownState.table)
	&"ShrineTable",  # v0.9.0 SH, HF: the shrines' and the fountain's numbers (ShrineState.table)
	&"CurveTable",  # v0.4.0 TU's difficulty curve (SpawnTable.curve); the save lab builds floors with it, as Main
	&"LegendaryTable",
	&"LootPacingTable",  # v0.8.0 FL
	&"EventTable",  # v0.5.0 EV
	&"CurseTable",
	&"EventRules",
	&"CatchUpTable",  # v0.5.5 DS
	&"ModifierTable",  # v0.6.0 MX1
	&"ModifierOp",
	&"RemnantRule",  # v0.8.0 RM: a REMNANT op's rule (content)
	&"WandTable",  # v0.6.5 WN1
	&"BladeTable",  # v0.6.5 WN4
	&"SimTuning",  # the dev panel's Step 6: the sim's designer numbers
	&"IceField",  # v0.7.5 NB1: a floor's ice, laid from the floor seed at setup and never written in play
	&"IntensityTable",  # v0.8.0 N5: the intensity director's numbers (SpawnTable.intensity)
	&"BulletPatternTable",  # v0.7.5 BF1: a boss attack's bullet pattern (BossAttackTable.pattern)
	&"SlotTable",  # v0.9.0 AS: the wand's slot limits, caps and form × card table (content, read in play)
	&"EliteTable",  # v0.9.0 EL: an elite archetype's ability and plain attack (EnemyTable.elite)
	&"EliteRules",  # v0.9.0 EL: where elites appear and the core drop (EliteState.rules)
	&"AffinityTable",  # v0.9.0 RB: the run's rune affinity's numbers (AffinityState.table)
]
## State objects: every script variable is copied.
const STATE_CLASSES: Array[StringName] = [
	&"RngStream",
	&"ActorStore",
	&"ProjectileStore",
	&"PickupStore",
	&"MineStore",
	&"HealOrbStore",  # v0.4.0 TU
	&"BossStore",
	&"RewardStore",
	&"AbilityState",
	&"KitState",
	&"HeatState",
	&"PlayerBuildState",
	&"BladeState",  # v0.6.5 WN4
	&"ProcLedger",
	&"BossFlow",
	&"ItemMods",
	&"DenseGrid",
	&"Obb",
	&"OverrunState",  # v0.4.0 AB
	&"ShopState",  # v0.5.0 SH
	&"EventState",  # v0.5.0 EV: pedestals, rolls, defence, cursed offers (its tables are loadout)
	&"CatchUpState",  # v0.5.5 DS: the floor's hidden catch-up
	&"ArenaState",  # v0.5.5 AR: the sealed arena, its waves, streams and barriers; the arenas cleared
	# v0.6.0 MX1: the compiled specs (World.attack_book is kept out and compiled again on restore; listed so the
	# guard knows them).
	&"AttackBook",
	&"AttackSpec",
	&"AttackHook",
	&"CurseState",  # v0.6.0 CU: the trade-off curses in play (stun, dodges, shots counted)
	&"CoreState",  # v0.6.0 CU: core carriers, staggers, steal windows, the drops on the floor
	&"ModifierState",  # v0.6.0 MX4: queued launches, every-N counters, the moments' and body rules' marks
	&"FinalFight",  # v0.8.0 FB1: the final boss's fight (its bodies, the phase, the shatter)
	&"NemesisCast",  # v0.8.0 FB3: the Nemesis's hostile copies of the player's shot and cards (FinalFight)
	&"IntensityState",  # v0.8.0 N5: the intensity director's state
	&"FinalApproach",  # v0.9.0 FA: the final approach (the pylons, the buildup, the walls of light)
	&"Interactables",  # v0.9.0 IX: the shared interactables and the puzzles' calm rooms
	&"TimedDoor",  # v0.9.0 TD: the timed door (its state, timer and reward)
	&"RuneAlignment",  # v0.9.0 RA: the rune puzzle (its pillars, solved, slab and reward)
	&"Breakables",  # v0.9.0 DX: the cracked wall, the containers and the explosive barrels
	&"PurpleRunes",  # v0.9.0 DP: the purple-rune dais (awakened, the Deep gate's footprint)
	&"LockdownState",  # v0.9.0 LK: the Lockdown sealed, its formations, the safety, the strikes; those opened
	&"ShrineState",  # v0.9.0 SH, HF: the Blood or Chaos shrine (used, the challenge, its altars) and the fountain
	&"EliteState",  # v0.9.0 EL: the floor's elite rooms, the elites alive, their contact clocks, the escort
	&"AffinityState",  # v0.9.0 RB: the rune affinity's ward and dash crackle on this floor
]

## v0.6.0 MX2 (old saves): fields added since v0.5 that an older snapshot may lack, by class. A missing one keeps the
## base world's value (its default, or what the carry gave it) instead of failing the restore; apply() then pads
## the per-entry arrays to their store's size and migrates the build into the slots (BuildSlots.migrate). Any other
## missing field still fails.
const ADDED_SINCE_V05 := {
	&"World":
	[
		&"hook_chain",
		&"launch_tick",
		&"launch_count",
		&"shot_tick",  # v0.8.0 PF: the player-shot cap's per-tick count
		&"shot_count",
		&"blast_tick",  # v0.8.0 BL: the blast merge's per-tick marks
		&"blast_pos",
		&"blast_merged",
		&"shot_window",  # v0.9.0 AS: the last second's player launches (a save from before AS: none)
		&"shot_window_tick",
		&"mod_slots",
		&"swap_code",
		&"swap_source",
		&"swap_ref",
		&"migrate_slots",
		&"mx",  # v0.6.0 MX4 (a v0.6.0 MX2 save lacks it too: the base's fresh state)
		&"card_levels",  # v0.6.5 WN3 (an older save's cards are all level 1)
		&"blade",  # v0.6.5 WN4 (the base's fresh state)
		&"tuning",  # the dev panel's Step 6 (loadout, SimTuning; a v0.6.1 save keeps the base's, v0.6.5 WN5b)
		&"loop",  # v0.7.5 AP: the loop fields (an older save is loop 1: the base's, from RunState.prepare)
		&"run_floor",
		&"loop_threat",
		&"loop_cap_permille",
		&"final_fight",  # v0.8.0 FB1: the final boss's fight (a save from before FB1 holds none: null, as the base's)
		&"approach",  # v0.9.0 FA: the final approach (a save from before FA holds none: FloorPlan builds that one bare)
		&"interactables",  # v0.9.0 IX: a save from before IX keeps the base's registry (apply re-syncs the pylons)
		&"timed",  # v0.9.0 TD: a floor saved before TD has none (built under floor rules 1-9: none in the base either)
		&"runes",  # v0.9.0 RA: a floor saved before RA has none (built under floor rules 1-10: none in the base either)
		&"breakables",  # v0.9.0 DX: the same (floor rules 1-10 build none)
		&"purple",  # v0.9.0 DP: a floor saved before DP has none (built under floor rules 1-11: none in the base either)
		&"lockdown",  # v0.9.0 LK: a floor saved before LK has none (built under floor rules 1-12: none in the base either)
		&"shrine",  # v0.9.0 SH, HF: a floor saved before SH has none (floor rules 1-13 build none in the base either)
		&"elites",  # v0.9.0 EL: a floor saved before EL has no elite rooms (floor rules 1-14 build none either)
		&"affinity",  # v0.9.0 RB: a save from before RB is a run without one (None: null in the base too)
		&"legendary_picks",  # v0.8.0 RR: a boss altar's extra picks (an older save has none: 0)
		&"loot_guaranteed",  # v0.8.0 FL: an older save's floor used no guarantee (0) and holds no jackpot
		&"loot_jackpots",
		&"intensity",  # v0.8.0 N5: the intensity director (an older save's floor starts in BUILD_UP: the base's)
		&"gamble_wins",  # v0.8.0 N14: an older save's shrine counts its uses as wins (apply), and never failed
		&"gamble_fail_tick",
		&"stat_rules",  # v0.8.0 SG: an older save's stat rules are 0 (apply rebuilds them: Stats.migrate_rules)
	],
	# v0.7.5 AP: the Ascension portal (an older save's last floor gets the base's, from RunState.prepare)
	&"BossFlow":
	[
		&"ascension",
		&"ascend_open",
		&"ascend_declined",
		&"ascend_choice",
		&"final_next",  # v0.8.0 FB1: an older save gets the base's (RunState.prepare: today's content)
		&"door",  # v0.8.0 BD: an older save's floor (rules 1-7) gets the base's: Door.PASSAGE (RunState.prepare)
		&"door_press_tick",
	],
	# v0.8.0 BS1: the signature mechanics' pillars and javelins (lists of their own; an older save has none)
	&"BossStore":
	[
		&"pillar_x",
		&"pillar_y",
		&"pillar_h",
		&"pillar_from",
		&"pillar_until",
		&"pillar_boss",
		&"jav_x",
		&"jav_y",
		&"jav_a",
		&"jav_boss",
		&"jav_attack",
		&"jav_from",
		&"jav_back",
		# v0.8.0 BS2: the Foundry's lava and meltdown and their burn clock (an older save has none)
		&"lava_x",
		&"lava_y",
		&"lava_hx",
		&"lava_hy",
		&"lava_from",
		&"lava_until",
		&"lava_boss",
		&"lava_attack",
		&"melt_boss",
		&"melt_attack",
		&"melt_from",
		&"melt_r0",
		&"melt_x",
		&"melt_y",
		&"melt_ex",
		&"melt_ey",
		&"melt_exit",
		&"burn_cd",
		&"sig_boss",  # v0.9.0 NB1: the Tidecaller's Pull cadence (an older save has no Tidecaller: none)
		&"sig_due",
		&"twin_lead",  # v0.9.0 NB2: the Twin Wardens' pair (an older save has no Wardens: none)
		&"twin_body",
		&"twin_angry",
		&"twin_anger_t",
		&"twin_burn_cd",
	],
	&"ProjectileStore":
	[
		&"spec_key",
		&"pierce_left",  # v0.6.0 MX4 (ProjectileMoves; padded with "no behaviour")
		&"ret",
		&"home",
		&"orbit_t",
		&"orbit_n",
		&"orbit_a",
		&"life0",
		&"speed",
		&"moves",
		&"spiral",  # v0.6.5 WN3 (GunForms; padded with "none")
		&"mine_t",
		&"look",  # v0.7.5 BF1 (fireball looks; empty = none, as a store that never held one)
		&"cause",  # v0.7.5 BF2 fix (the attack that fired a boss shot; padded with "none")
		&"second",  # v0.8.0 MR (a secondary bolt or a repeat's; empty = none, as a store that never held one)
	],
	&"ActorStore": [&"poison_stacks", &"poison_t", &"poison_cd"],  # v0.6.0 MX4 (Venom; padded with 0)
	# v0.8.0 FB2: the final fight's centre and damage meter (an FB1 save has neither: the base's, a fresh meter)
	# v0.8.0 FB3: the mimic body's state (an FB2 save has none: a fresh one, the build read at the Nemesis's next tick)
	&"FinalFight":
	[
		&"home",
		&"dps_secs",
		&"dps_head",
		&"dps_closed",
		&"dps_acc",
		&"dps_t",
		&"ready",
		&"weapon",
		&"hit",
		&"hit_cap",
		&"combo_half",
		&"combo_reach",
		&"shot",
		&"casts",
		&"echo_x",
		&"echo_y",
		&"echo_head",
		&"echo_n",
		&"dash_due",
		&"dash_dir",
		&"dash_t",
		&"dash_vel",
		&"stance",
		&"stance_t",
		# v0.8.0 N2: the body's pace and The Fallen's window copy (an older save: unpaced, set again from the meter)
		&"paced",
		&"pace_dps",
		&"pace_budget",
		&"copying",
	],
	&"ModifierState":
	[
		&"hold_t",  # v0.6.5 WN3 (G13 Charge: an older save charges nothing)
		&"recoil_t",  # v0.9.0 AF1b (the Lance's push back: an older save has none)
		&"recoil_step",
		&"cast_tick",  # v0.6.5 WN5a (WandCasts: view-only marks; an older save has none)
		&"cast_key",
		&"cast_pos",
		&"cast_angle",
		&"cast_flag",
		&"void_shot",  # v0.9.0 VP (the Void form's aura waits; an older save has none: its black holes are dropped)
		&"void_foe",
		&"void_next",
		&"ramp_n",  # v0.8.0 MR (FireRhythm, SecondaryProc: an older save has no ramp, no burst, no carry)
		&"ramp_tick",
		&"burst_n",
		&"burst_free",
		&"sec_carry",
		&"rem_uid",  # v0.8.0 RM (Remnants, Dodge Imprint: an older save has none)
		&"rem_kind",
		&"rem_card",
		&"rem_key",
		&"rem_slot",
		&"rem_section",
		&"rem_depth",
		&"rem_proc",
		&"rem_root",
		&"rem_born",
		&"rem_life",
		&"rem_gap",
		&"rem_charges",
		&"rem_basis",
		&"rem_a",
		&"rem_b",
		&"rem_dir",
		&"rem_target",
		&"rem_target2",
		&"rem_count",
		&"rem_group",
		&"rem_next",
		&"gap_uid",
		&"gap_target",
		&"gap_tick",
		&"rem_act_tick",
		&"rem_act_n",
		&"link_id",
		&"link_tick",
		&"link_key",
		&"finale_tick",
		&"imprint_at",
		&"imprint_until",
	],
	&"ItemMods": [&"bleed_move_period_ticks"],  # v0.6.5 WN5a (S5 Bleed: an older save has the base's)
	# v0.7.5 MG (N10: an older save's floor counts its cursed chests from 0); v0.8.0 N17: the curse room's altar (an
	# older save's floor has none: -1, apply)
	&"EventState": [&"cursed_rolled", &"curse_k"],
	&"AbilityState":
	[
		&"bomb_spec",
		&"bomb_depth",
		&"bomb_proc",
		&"fire_spec",
		&"fire_depth",
		&"fire_proc",
		&"fire_cap",
		&"ring_pos",
		&"ring_r",
		&"ring_start",
		&"ring_end",
		&"ring_dmg",
		&"ring_root",
		&"ring_spec",
		&"ring_depth",
		&"ring_proc",
		&"ring_vel",  # v0.8.0 N3 (travelling rings: an older save's rings are plain, ModifierAbilities pads them)
		&"ring_orb",
		&"ring_orb_a",
		&"ring_pulse",
		&"ring_k",
		&"ring_seen",
		&"lob_count",
		&"streak_n",
		&"streak_last",
	],
}

## script_fields' cache (Script -> Array[StringName]); derived from the class declarations only.
static var _fields := {}


## The snapshot of `w` between ticks. `errors` (optional) collects every unclassified object found.
static func take(w: World, errors: PackedStringArray = PackedStringArray()) -> Dictionary:
	var data := _encode_object(w, WORLD_KEPT, "World", errors)
	data[&"nav"] = {
		"size": w.nav.size,
		"dist": w.nav.dist.duplicate(),
		"flooded": w.nav.get(&"_flooded"),
		"work": w.nav.last_work,  # v0.8.0 NF: the next build's budget
		"build": w.nav.build_state(),  # v0.8.0 NF: the flood being built ({} none), run again on restore
	}
	data[&"_wall_next"] = w.get(&"_wall_next") != null
	data[&"_nav_next"] = w.get(&"_nav_next") != null
	return {"format": FORMAT, "world": data}


## Writes `snap` into `base` (a World built from the same generation inputs). Returns "" or what went wrong; on an
## error the base is partly written and must be dropped.
static func apply(base: World, snap: Dictionary) -> String:
	if int(snap.get("format", -1)) != FORMAT or typeof(snap.get("world")) != TYPE_DICTIONARY:
		return "snapshot format %s, expected %d" % [str(snap.get("format")), FORMAT]
	var data: Dictionary = snap["world"]
	var walls_before := base.walls.size()
	# The base's walls come from generating the floor; the snapshot's start with the same ones (in play only the boss
	# door is added, and v0.5.0 PB removes it again once the boss is dead). A difference means another floor or other
	# content: the save doesn't fit this build.
	var saved: Dictionary = data.get(&"walls", {})
	var built := _encode_obbs(base.walls)
	var saved_c: PackedVector2Array = saved.get("center", PackedVector2Array())
	if saved_c.size() < walls_before or saved_c.slice(0, walls_before) != built["center"]:
		return "World.walls: the snapshot's floor differs from the one generated from its inputs"
	# v0.8.0 BS1: the Gatekeeper's standing pillars are walls added in play too (barriers, never in the flow field).
	var pillars := _saved_pillars(data)
	# v0.9.0 TD: the timed door's slab is a barrier added in play (before or after the boss door): left out here;
	# v0.9.0 RA: the rune puzzle's slab too (Secrets.slabs); v0.9.0 DP: the Deep gate's footprint once earned.
	var plain := _without_slab(base, saved_c, walls_before)
	# The boss door sealed in play: add it the way play did (its prepared flow field swaps in, no rebuild).
	# v0.9.0 FV: found among every wall play added, so a sealed arena's barriers (added on the same tick, before or
	# after it) don't hide it. Missed, the restored world kept no field from before the door (World._nav_open) and,
	# once the door opened, rebuilt one where play swapped its kept field back: the two flow fields parted.
	var door: Obb = base.get(&"_wall_next")
	if (
		door != null
		and plain.size() >= walls_before + 1 + pillars
		and plain.slice(walls_before).has(door.center)
		and not bool(data.get(&"_wall_next", true))
	):
		base.add_wall_now(door)
		walls_before += 1
	var err := _apply_object(base, data, WORLD_KEPT, "World")
	if err != "":
		return err
	_pad_added(base)  # v0.6.0 MX2: an older save's stores get their new per-entry arrays
	if not data.has(&"gamble_wins"):  # v0.8.0 N14 (O72): every use before N14 won a stat
		base.gamble_wins = base.gamble_uses
		base.gamble_fail_tick = -1
	if not data.has(&"stat_rules"):  # v0.8.0 SG (O91): damage and attack speed compounded before SG
		base.stat_rules = 0
		Stats.migrate_rules(base)
	var ev_data: Variant = data.get(&"ev", {})
	if typeof(ev_data) == TYPE_DICTIONARY and not (ev_data as Dictionary).has(&"curse_k"):
		base.ev.curse_k = -1  # v0.8.0 N17 (O75): a floor saved before the curse room has none
	if not data.has(&"interactables") and base.approach != null:  # v0.9.0 IX: the pylons follow the saved lit ones
		base.approach.sync_registry(base)
	if not data.has(&"mod_slots"):  # v0.6.0 MX2: a v0.5 build into the six slots
		base.mod_slots = PackedInt32Array()
		BuildSlots.migrate(base)
	Modifiers.invalidate(base)  # v0.6.0 MX1: the restored build's specs compile on their next read
	Events.drop_retired(base)  # v0.9.0 EL (Q25): an Ambush Cache pedestal closes, a held Marked curse goes
	CoreTheft.drop_plain(base)  # v0.9.0 EL: a pre-EL elite's core (a normal enemy's) goes; it drops nothing now
	Curses.invalidate(base)  # v0.7.0 audit C-12: the curse sums are summed again from what was restored
	# v0.5.5 AR: a sealed arena's barriers came back with the walls: they never enter the flow field (World.add_barrier),
	# so only the wall grid is rebuilt for them.
	var barriers := base.arenas.barriers.size() + base.bosses.pillar_x.size()  # v0.8.0 BS1: pillars too
	barriers += Secrets.slabs_up(base)  # v0.9.0 TD, RA: the secret rooms' slabs while they stand
	if base.lockdown != null:  # v0.9.0 LK: a sealed Lockdown's bars, as an arena's
		barriers += base.lockdown.barriers.size()
	if base.walls.size() == walls_before + barriers and barriers > 0:
		base.rebuild_wall_grid()
	elif base.walls.size() != walls_before:  # any other wall added in play: the grid and field are rebuilt
		base.set_walls(base.walls)
	var nav: Dictionary = data.get(&"nav", {})
	if nav.get("size") != base.nav.size:
		return (
			"World.nav: field size %s, the rebuilt walls give %s" % [nav.get("size"), base.nav.size]
		)
	if BossSignatures.has_extra(base):  # v0.8.0 BS1/BS2: the flow field goes round them again
		BossSignatures.set_nav_extra(base, false)
	base.nav.dist = (nav["dist"] as PackedInt32Array).duplicate()
	base.nav.set(&"_flooded", nav["flooded"])
	# v0.8.0 NF: a save from before NF has no build in progress and no work (the next build's budget starts small).
	base.nav.last_work = int(nav.get("work", 0))
	base.nav.restore_build(nav.get("build", {}))
	for f: StringName in [&"_wall_next", &"_nav_next"]:
		if not bool(data.get(f, false)):
			base.set(f, null)
		elif base.get(f) == null:
			return "World.%s: pending in the snapshot, missing in the base" % f
	return ""


## v0.9.0 TD: the saved walls' centres without the secret rooms' slabs (barriers past the floor's walls; v0.9.0 RA:
## every slab of Secrets.slabs), as saved.
static func _without_slab(
	base: World, saved_c: PackedVector2Array, walls_before: int
) -> PackedVector2Array:
	var out := saved_c
	for slab in Secrets.slabs(base):
		for k in range(walls_before, out.size()):
			if out[k] == slab.center:
				out = out.duplicate()
				out.remove_at(k)
				break
	return out


## v0.8.0 BS1: how many of the Gatekeeper's pillars stood in the snapshot (0 for an older save).
static func _saved_pillars(data: Dictionary) -> int:
	var bosses: Variant = data.get(&"bosses", {})
	if typeof(bosses) != TYPE_DICTIONARY:
		return 0
	var xs: Variant = (bosses as Dictionary).get(&"pillar_x", PackedFloat32Array())
	return (xs as PackedFloat32Array).size() if xs is PackedFloat32Array else 0


## v0.6.0 MX2: per-entry arrays an older save didn't have, padded to their store's size with the "none" value (a
## projectile, a bomb or a patch without a spec runs as before MX2).
static func _pad_added(w: World) -> void:
	var p := w.projectiles
	while p.spec_key.size() < p.ids.size():
		p.spec_key.append("")
	if p.speed.size() != p.ids.size():  # v0.6.0 MX4: an older save's projectiles have no behaviour
		var zeros := PackedInt32Array()
		zeros.resize(p.ids.size())
		zeros.fill(0)
		for f in ProjectileStore.MOVE_INT_FIELDS:
			p.set(f, zeros.duplicate())
		var none := PackedFloat32Array()
		none.resize(p.ids.size())
		none.fill(0.0)
		p.speed = none
		p.moves = false
	if p.mine_t.size() != p.ids.size():  # v0.6.5 WN3: an older save's projectiles neither spiral nor wait
		var none_i := PackedInt32Array()
		none_i.resize(p.ids.size())
		none_i.fill(0)
		p.spiral = none_i.duplicate()
		p.mine_t = none_i.duplicate()
	var a := w.actors
	if a.poison_stacks.size() != a.ids.size():  # v0.6.0 MX4: an older save's actors carry no poison
		var zero := PackedInt32Array()
		zero.resize(a.ids.size())
		zero.fill(0)
		for f in ActorStore.VENOM_FIELDS:
			a.set(f, zero.duplicate())
	var s := w.ab
	while s.bomb_spec.size() < s.bomb_pos.size():
		s.bomb_spec.append("")
		s.bomb_depth.append(0)
		s.bomb_proc.append(100)
	while s.fire_spec.size() < s.fire_pos.size():
		s.fire_spec.append("")
		s.fire_depth.append(0)
		s.fire_proc.append(100)
		s.fire_cap.append(0)
	if s.ring_pulse.size() != s.ring_pos.size():  # v0.8.0 N3: an older save's rings are plain (they don't travel)
		for f: StringName in [&"ring_vel", &"ring_orb", &"ring_orb_a", &"ring_pulse", &"ring_k"]:
			var arr: Variant = s.get(f)
			arr.resize(s.ring_pos.size())
			s.set(f, arr)


## The script variables of `obj`, in declaration order (cached per script: a class's fields don't change).
static func script_fields(obj: Object) -> Array[StringName]:
	var s: Script = obj.get_script()
	if s != null and _fields.has(s):
		return _fields[s]
	var out: Array[StringName] = []
	for p: Dictionary in obj.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(StringName(p["name"]))
	if s != null:
		_fields[s] = out
	return out


## The global class name of a script instance ("" for a plain Object).
static func class_of(obj: Object) -> StringName:
	var s: Script = obj.get_script()
	return s.get_global_name() if s != null else &""


static func _encode_object(
	obj: Object, kept: Dictionary, where: String, errors: PackedStringArray
) -> Dictionary:
	var out := {CLASS_KEY: class_of(obj)}
	for f in script_fields(obj):
		if kept.has(f):
			continue
		var v: Variant = obj.get(f)
		out[f] = _encode(v, "%s.%s" % [where, f], errors) if _is_ref(v) else _copy(v)
	return out


## Objects, arrays and dictionaries are copied deeply (_encode); the rest by _copy.
static func _is_ref(v: Variant) -> bool:
	var t := typeof(v)
	return t == TYPE_OBJECT or t == TYPE_ARRAY or t == TYPE_DICTIONARY


static func _encode(v: Variant, where: String, errors: PackedStringArray) -> Variant:
	match typeof(v):
		TYPE_OBJECT:
			if v == null:
				return null
			var cls := class_of(v)
			if STATE_CLASSES.has(cls):
				return _encode_object(v, {}, where, errors)
			if not LOADOUT_CLASSES.has(cls):
				(
					errors
					. append(
						(
							(
								"%s holds a %s: add it to WorldSnapshot.STATE_CLASSES (copy its fields) or "
								+ "LOADOUT_CLASSES (content, never written in play)"
							)
							% [where, cls if cls != &"" else "plain Object"]
						)
					)
				)
			return null
		TYPE_ARRAY:
			var arr: Array = v
			if arr.get_typed_script() == Obb:
				return _encode_obbs(arr)
			var out := []
			for i in arr.size():
				out.append(
					(
						_encode(arr[i], "%s[%d]" % [where, i], errors)
						if _is_ref(arr[i])
						else _copy(arr[i])
					)
				)
			return out
		TYPE_DICTIONARY:
			var out := {}
			var d: Dictionary = v
			for k: Variant in d:
				out[k] = (
					_encode(d[k], "%s[%s]" % [where, str(k)], errors)
					if _is_ref(d[k])
					else _copy(d[k])
				)
			return out
	return _copy(v)


## Value types as they are; packed arrays duplicated (a packed array read from a field is shared with it).
static func _copy(v: Variant) -> Variant:
	if typeof(v) >= TYPE_PACKED_BYTE_ARRAY:
		return (v as Variant).duplicate()
	return v


static func _apply_object(obj: Object, data: Dictionary, kept: Dictionary, where: String) -> String:
	if StringName(data.get(CLASS_KEY, &"")) != class_of(obj):
		return (
			"%s: a %s in the snapshot, a %s in the base"
			% [where, data.get(CLASS_KEY), class_of(obj)]
		)
	for f in script_fields(obj):
		if kept.has(f):
			continue
		if not data.has(f):
			if (ADDED_SINCE_V05.get(class_of(obj), []) as Array).has(f):
				continue  # v0.6.0 MX2: an older save; apply() fills it in
			return "%s.%s: not in the snapshot" % [where, f]
		var cur: Variant = obj.get(f)
		var r: Array = _decode(cur, data[f], "%s.%s" % [where, f])
		if r[1] != "":
			return r[1]
		if typeof(cur) != TYPE_ARRAY and typeof(cur) != TYPE_DICTIONARY:
			obj.set(f, r[0])
	return ""


## [value, error]. Objects, arrays and dictionaries are written in place into `cur` when it has the same shape (typed
## arrays keep their type); value types are returned for the caller to set.
static func _decode(cur: Variant, v: Variant, where: String) -> Array:
	if typeof(v) == TYPE_DICTIONARY and (v as Dictionary).get(CLASS_KEY) == OBBS:
		if typeof(cur) != TYPE_ARRAY:
			return [null, "%s: walls in the snapshot, no array in the base" % where]
		_decode_obbs(cur, v)
		return [cur, ""]
	if typeof(v) == TYPE_DICTIONARY and (v as Dictionary).has(CLASS_KEY):
		var cls := StringName(v[CLASS_KEY])
		var target: Object = cur if typeof(cur) == TYPE_OBJECT and cur != null else _make(cls)
		if target == null:
			return [null, "%s: can't make a %s" % [where, cls]]
		return [target, _apply_object(target, v, {}, where)]
	if typeof(cur) == TYPE_OBJECT and cur != null and v == null:
		var cls := class_of(cur)
		return [cur if LOADOUT_CLASSES.has(cls) else null, ""]
	if typeof(v) == TYPE_ARRAY and typeof(cur) == TYPE_ARRAY:
		var arr: Array = cur
		var old := arr.duplicate()  # v0.5.0 EV: an array of content tables (World.ev.events) keeps its tables
		arr.clear()
		var src: Array = v
		for i in src.size():
			var r: Array = _decode(
				old[i] if i < old.size() else null, src[i], "%s[%d]" % [where, i]
			)
			if r[1] != "":
				return r
			arr.append(r[0])
		return [arr, ""]
	if typeof(v) == TYPE_DICTIONARY and typeof(cur) == TYPE_DICTIONARY:
		var d: Dictionary = cur
		d.clear()
		var src: Dictionary = v
		for k: Variant in src:
			var r: Array = _decode(null, src[k], "%s[%s]" % [where, str(k)])
			if r[1] != "":
				return r
			d[k] = r[0]
		return [d, ""]
	if typeof(v) == TYPE_ARRAY or typeof(v) == TYPE_DICTIONARY:
		return [(v as Variant).duplicate(true), ""]
	return [_copy(v), ""]


## A fresh state object for a class the base didn't hold (an element of an array, such as a wall added in play).
static func _make(cls: StringName) -> Object:
	match cls:
		&"Obb":
			return Obb.new()
		&"TimedDoor":  # v0.9.0 TD, RA, DX: a base built without its floor's secrets (a lab)
			return TimedDoor.new()
		&"RuneAlignment":
			return RuneAlignment.new()
		&"Breakables":
			return Breakables.new()
		&"PurpleRunes":  # v0.9.0 DP
			return PurpleRunes.new()
		&"LockdownState":  # v0.9.0 LK
			return LockdownState.new()
		&"ShrineState":  # v0.9.0 SH, HF
			return ShrineState.new()
		&"EliteState":  # v0.9.0 EL: a base whose floor had no elite before play brought one
			return EliteState.new()
		&"RngStream":
			return RngStream.new()
		&"ActorStore":
			return ActorStore.new()
		&"ProjectileStore":
			return ProjectileStore.new()
		&"PickupStore":
			return PickupStore.new()
		&"MineStore":
			return MineStore.new()
		&"HealOrbStore":
			return HealOrbStore.new()
		&"BossStore":
			return BossStore.new()
		&"RewardStore":
			return RewardStore.new()
		&"AbilityState":
			return AbilityState.new()
		&"KitState":
			return KitState.new()
		&"PlayerBuildState":
			return PlayerBuildState.new()
		&"ProcLedger":
			return ProcLedger.new()
		&"BossFlow":
			return BossFlow.new()
		&"ItemMods":
			return ItemMods.new()
		&"DenseGrid":
			return DenseGrid.new()
		&"CatchUpState":
			return CatchUpState.new()
		&"ArenaState":
			return ArenaState.new()
		&"FinalFight":
			return FinalFight.new()
		&"NemesisCast":
			return NemesisCast.new()
		&"IntensityState":
			return IntensityState.new()
	return null  # HeatState needs its table: a base without heat can't take a snapshot with it


static func _encode_obbs(arr: Array) -> Dictionary:
	var c := PackedVector2Array()
	var h := PackedVector2Array()
	var a := PackedInt32Array()
	var u := PackedVector2Array()
	var v := PackedVector2Array()
	for o: Obb in arr:
		c.append(o.center)
		h.append(o.half)
		a.append(o.angle)
		u.append(o.axis_u)
		v.append(o.axis_v)
	return {CLASS_KEY: OBBS, "center": c, "half": h, "angle": a, "axis_u": u, "axis_v": v}


static func _decode_obbs(arr: Array, d: Dictionary) -> void:
	arr.clear()
	var c: PackedVector2Array = d["center"]
	var h: PackedVector2Array = d["half"]
	var a: PackedInt32Array = d["angle"]
	var u: PackedVector2Array = d["axis_u"]
	var v: PackedVector2Array = d["axis_v"]
	for i in c.size():
		var o := Obb.new()
		o.center = c[i]
		o.half = h[i]
		o.angle = a[i]
		o.axis_u = u[i]
		o.axis_v = v[i]
		arr.append(o)

# gdlint: disable=max-public-methods, max-file-lines
class_name World
extends RefCounted
## The whole simulation state, mutated in place one tick at a time (SIM_CONTRACTS §2).
## Determinism: the same (seed, content, loadout, InputFrame log) gives the same state_hash() at every tick.

const EVENT_LOG_CAP := 4096
const EVENT_LOG_TRIM := 512
const BUTTON_BITS: Array[int] = [
	InputFrame.PRIMARY, InputFrame.UTILITY, InputFrame.DASH, InputFrame.INTERACT
]
const DASH_SLOT := 2
## How far a body may drift during the collision passes before its wall check is redone (_move_and_collide).
const WALL_SKIP_M := 0.5
## aoe_candidates' query grows by this past the reach (and the largest radius), over float rounding.
const AOE_MARGIN_M := 0.01

## Where a new world gets its optional native side (NativeWorld): the app layer sets it when the native library is
## loaded and switched on (the sim itself never looks a class up). An empty Callable: every world runs GDScript.
static var native_factory := Callable()
## The native kernels a new world runs (NativeWorld.MOVE, AI, ...); 0: none, and no native side is made.
static var native_kernels := 0

var tick := 0
var freeze_ticks := 0
var seed_value := 0

var rng_map: RngStream
var rng_loot: RngStream
var rng_combat: RngStream
var rng_ai: RngStream
## Enemy AI: the normal enemies' own draws (windup lengths, spell picks), a sub-stream of ai
## (SIM_CONTRACTS §5), so the spawn director's ai draws stay where they were. Hashed only with enemy tables.
var rng_enemy: RngStream

var player: PlayerTable
var actors := ActorStore.new()
var projectiles := ProjectileStore.new()
var walls: Array[Obb] = []

## Player state.
var aim_angle := 0
var aim_dist_cm := 0
var move_intent := Vector2i.ZERO
var dash_ticks_left := 0
var dash_cooldown_left := 0
var dash_dir := Vector2.ZERO
## Player velocity in metres per tick (eases toward the move target).
var vel := Vector2.ZERO
## Buttons held this tick (InputFrame bits).
var held_buttons := 0
## Attacks (PlayerKit): swing tick (0 = none), its locked angle and root, combo step and window, shot cooldown.
var swing_t := 0
var swing_angle := 0
var swing_root := 0
var combo_step := 0
var combo_window := 0
var shot_cd := 0
## The carried remainders, so a fraction the integer maths
## drops is kept for the next one and every stat card counts: the player's hits (Stats.outgoing: the damage stat and
## crits) and DoT ticks (Stats.dot) in thousandths of a point, and the Gun's shot period in thousandths of a tick
## (ItemEffects.next_shot_cd). 0..999 each; hashed once any leaves 0; an older save has 0.
var dmg_carry := 0
var dot_carry := 0
var shot_carry := 0
## The held Constellations, ids in pick order (Constellations; owner W7).
var constellations := PackedInt32Array()
## Starfall: the hero's crits counted, the root attacks counted for Meteor, and the meteors in the
## air (Starfall.METEOR_FIELDS ints each). Hashed once any leaves 0 / empty; an older save has none.
var starfall_crits := 0
var meteor_attacks := 0
var meteors := PackedInt32Array()
## The loop's Constellation offer (ids; empty: none open). While it holds any, the world runs only
## the pick (Constellations.choose). A new loop's floor 1 gets it from the carry (RunState.finish_floor).
var constellation_offer := PackedInt32Array()
## Starbound; owner W7: the compiled Starbound cards (loadout), the picks of each (run-long,
## RunCarry; empty until the first), the crits and kills counted since the room was last cleared (Rising Edge,
## Fervour), and Detonation's bursts this tick (its cap). Hashed once a card was taken.
var starbound_tables: Array[StarboundTable] = []
var starbound := PackedInt32Array()
var starbound_crits := 0
var starbound_kills := 0
var starbound_burst_tick := -1
var starbound_bursts := 0
## The roots that already started an Arc Jump chain (the last Starbound.JUMP_ROOTS_MAX: one chain a
## root), and the damage of Echo Cast repeats that had no shot room left (ShotCap), merged into the next own shot.
var starbound_jump_roots := PackedInt32Array()
var starbound_echo_carry := 0
## The view's recent bursts and jumps (Starbound.FX_*: kind, start tick, from, to), at most Starbound.FX_MAX, the
## oldest dropped: presentation only, never hashed.
var starbound_fx_kind := PackedInt32Array()
var starbound_fx_tick := PackedInt32Array()
var starbound_fx_from := PackedVector2Array()
var starbound_fx_to := PackedVector2Array()
## Relics; OWNER_QUESTIONS N1: the compiled relics (loadout), the held ones (one entry per relic once
## the first is taken: 0 not held, else 1 + its uses this run; RunCarry), and the City's Heart's last saved blow (the
## tick, -1 none, and where its shock ring pulsed). Hashed once a relic was taken.
var relic_tables: Array[RelicTable] = []
var relics := PackedInt32Array()
var relic_pulse_tick := -1
var relic_pulse_pos := Vector2.ZERO
## Spells; owner Q17-Q20: the compiled spells and their rules (loadout); the spell slots (spell indices,
## pick order), their levels and cooldowns (ticks left) and the tick each last cast (run-long but the cooldowns,
## RunCarry); the Fireballs in flight (position, locked point, spell, level, root) and Frost Nova's pushes (actor id,
## direction, metres a tick, ticks left). Hashed once a spell was taken.
var spell_tables: Array[SpellTable] = []
var spell_rules: SpellRules
var spell_slots := PackedInt32Array()
var spell_levels := PackedInt32Array()
var spell_cd := PackedInt32Array()
var spell_cast_tick := PackedInt32Array()
var spell_ball_pos := PackedVector2Array()
var spell_ball_to := PackedVector2Array()
var spell_ball_spell := PackedInt32Array()
var spell_ball_level := PackedInt32Array()
var spell_ball_root := PackedInt32Array()
var spell_push_id := PackedInt32Array()
var spell_push_dir := PackedVector2Array()
var spell_push_step := PackedFloat32Array()
var spell_push_left := PackedInt32Array()
## SpellZones: the lasting spells (a storm, a patch, a mark, an orb, a field, a pool, a cloud and its
## puffs, a vine, a ring to come, a wall, a Hemorrhage mark, a Leech): kind, spell, level, root, the tick it ends, its
## next pulse, damage a pulse, two counters of its own, centre, velocity (m a tick) and radius (m). Oldest first.
var spell_zone_kind := PackedInt32Array()
var spell_zone_spell := PackedInt32Array()
var spell_zone_level := PackedInt32Array()
var spell_zone_root := PackedInt32Array()
var spell_zone_end := PackedInt32Array()
var spell_zone_next := PackedInt32Array()
var spell_zone_dmg := PackedInt32Array()
var spell_zone_aux := PackedInt32Array()
var spell_zone_aux2 := PackedInt32Array()
var spell_zone_pos := PackedVector2Array()
var spell_zone_vel := PackedVector2Array()
var spell_zone_r := PackedFloat32Array()
## The spells' holds on enemies (Sky Strike's stun, Meteor's knock-down: per mille 0; Toxic Cloud's slow):
## actor id, ticks left, the speed left (per mille).
var spell_hold_id := PackedInt32Array()
var spell_hold_t := PackedInt32Array()
var spell_hold_permille := PackedInt32Array()
## The view's recent casts (Spells.FX_*: kind, tick, from, to, radius m), at most Spells.FX_MAX: view only, never
## hashed.
var spell_fx_kind := PackedInt32Array()
var spell_fx_tick := PackedInt32Array()
var spell_fx_from := PackedVector2Array()
var spell_fx_to := PackedVector2Array()
var spell_fx_size := PackedFloat32Array()
## The spell each cast belongs to (view only).
var spell_fx_spell := PackedInt32Array()
## Detonation's bursts waiting within one kill's chain (transient within a hit: empty between hits).
var sb_burst_pos := PackedVector2Array()
var sb_burst_dmg := PackedInt32Array()
var sb_burst_root := PackedInt32Array()
var sb_draining := false
## Utility: blink cooldown, and the last blink (tick and start point) for the view.
var blink_cd := 0
var blink_tick := -1
var blink_from := Vector2.ZERO
## Remaining ticks per button slot (BUTTON_BITS order) for buffered presses.
var input_buffer := PackedInt32Array([0, 0, 0, 0])

## Dummy movers (kernel scenario): speed in metres per tick, shot period and life in ticks.
var dummy_speed := 3.0 / SimTick.TICKS_PER_SECOND
## The hero's HP never drops below this (0: off; the Training Room's 1, so the hero can't die
## there). Set only by a world built for the Training Room; never in a run, a save or the hash.
var player_hp_floor := 0

var dummy_fire_period := 0
var projectile_speed := 10.0 / SimTick.TICKS_PER_SECOND
var projectile_life := 120
var projectile_radius := 0.1
## Bench knobs (0 = off, the golden's behaviour): movers hold this distance from the player, and shots
## get up to this much random aim error (1/4096 turns, from the ai stream).
var dummy_keep_distance := 0.0
var dummy_aim_spread := 0
## Damage of a dummy's shot: 0 keeps the kernel scenario harmless.
var dummy_shot_damage := 0

## Compiled enemy kinds (ActorStore.Kind -> EnemyTable), part of the loadout like the player table.
var enemy_tables := {}
## The encounter (null in the kernel scenario), its spawn slots, and the run's progress: the last wave spawned
## (-1 before the first), ticks until the next wave (-1 = waiting for a clear), cleared, and who killed the player.
var encounter: EncounterTable
var spawn_points := PackedVector2Array()
var wave_index := -1
var wave_timer := -1
var cleared := false
var killer_kind := -1
var killer_tags := 0
## Continuous spawning (null = off): the compiled director, run ticks counted while the player lives, ticks
## until the next spawn, and enemies killed this run.
var spawner: SpawnTable
## The generated floor this world runs on (null in the arena and kernel scenarios). Static: not hashed.
var floor_layout: FloorLayout
var run_ticks := 0
var spawn_cd := 0
var kills := 0
## Mine Layers' mines (v0.4.0 EN; Mines), hashed once one was dropped.
var mines := MineStore.new()
## Heal orbs on the floor, the meter and the cooldown (v0.4.0 TU, owner D8; v0.11.0 F3; HealOrbs), hashed once used.
var orbs := HealOrbStore.new()
## Kill shards lying on the floor, hashed once one was dropped.
var shard_drops := ShardDropStore.new()
## The objective markers boss code points at (the view's hint arrow), hashed once touched.
## No gameplay outcome reads them.
var objectives := ObjectiveMarkers.new()
## The share of max HP restored when the boss room seals (per mille; RunState.prepare sets it
## from the run's per-floor table: floor 1 full, later floors none). Setup, not hashed.
var boss_room_heal_permille := 0
## Enemy pathing: a flow field toward the player, rebuilt every NavField.PERIOD ticks (derived, not hashed;
## built over NavField.SLICES ticks, its build in progress saved by WorldSnapshot).
var nav := NavField.new()

# --- Items ---------------------------------------------------------------------------------------
## Compiled items (part of the loadout, like enemy_tables); items_owned and pickups hold indices into it.
var item_tables: Array[ItemTable] = []
## Items no offer may draw (indices into
## item_tables, ascending), from the run's locked cards (RunState.locked_cards; FloorPlan). Empty: nothing locked.
var locked_items := PackedInt32Array()
## Items the player holds, in pickup order (indices into item_tables, no duplicates).
var items_owned := PackedInt32Array()
## The owned items folded into modifiers (derived from items_owned, so not hashed).
var item_mods := ItemMods.new()
## The build's compiled attack specs (Modifiers.book compiles them when null; the build changing sets it
## back to null). Derived from the build: a snapshot keeps it out and a restore compiles again; Modifiers.hash_into
## hashes its digest.
var attack_book: AttackBook = null
## Attacks: the hooks running now (the ancestry guard; empty between ticks), and the launches counted
## in tick launch_tick (the per-tick cap).
var hook_chain := PackedStringArray()
var launch_tick := -1
var launch_count := 0
## The player's projectiles counted against SimTuning.player_shots_max in tick shot_tick: those
## alive and queued at the tick's first player bolt, plus the bolts launched since (Attacks._shot_room). Derived per
## tick, so not hashed.
var shot_tick := -1
var shot_count := 0
## BLADE_AUDIT B6: the merge-tracked blasts (Explosive's) set off in tick blast_tick, where, and how many
## merged into them that tick (Attacks.merged). Derived per tick, so not hashed.
var blast_tick := -1
var blast_pos := PackedVector2Array()
var blast_merged := 0
## The player projectiles a Gun run launched in each of the last 60 ticks (indexed
## tick % 60; shot_window_tick the last tick written): the per-second budget. Snapshotted with the world; not hashed (it
## only changes an outcome past the budget, and no golden build reaches it).
var shot_window := PackedInt32Array()
var shot_window_tick := -1
## ElementLevelsFsf: the hits that could chain while Lightning is Lv 3 (every el_strike_every-th calls
## a strike), and the ticks of the strikes and the shatters in the last second (their budgets). Hashed only while
## Lightning or Frost runs at Lv 3.
var el_chain_hits := 0
var el_strike_log := PackedInt32Array()
var el_shatter_log := PackedInt32Array()
## ElementPairs: the pairs' numbers (loadout; null: no pairs), the pairs on now (bit X per pair, set when
## the wand compiles), the (pair, tick) of each firing in the last second (the 4-a-second budget, flat) and the Toxic
## Fumes clouds (x mm, y mm, ticks left, flat). Hashed only while a pair is on.
var pair_table: ElementPairTable
var pair_mask := 0
## 2 bits per pair (bit 2*x): its level 1-3 while on; 0 for an older save's pair (read as Lv 3).
var pair_levels := 0
var pair_log := PackedInt32Array()
var pair_clouds := PackedInt32Array()
## Item pickups lying on the floor.
var pickups := PickupStore.new()
## Twin Arc: ticks until the pending echo (0 = none), its angle, combo step (its shape), root and damage, and the
## tick it last swung.
var echo_t := 0
var echo_angle := 0
var echo_step := 0
var echo_root := 0
var echo_damage := 0
var echo_tick := -1
## Overcharge: swings started while it is owned, whether the current swing is the Nth, the tick it last fired.
var swing_count := 0
var swing_overcharged := false
var overcharge_tick := -1
## Kinetic Dash: this dash's root (0 until its first hit), the ids it already hit, the tick it last hit.
var dash_root := 0
var dash_hit_ids := PackedInt32Array()
var dash_hit_tick := -1
# Items, the second eight (v0.2.0 J; ItemProcs).
## Vampiric Core: the heal cap's window (start tick, -1 = none; HP healed in it) and the tick it last healed.
var heal_window_start := -1
var heal_window_used := 0
var heal_tick := -1
## Static Chain: landed player bolts counted, the root that last chained, and the last jump (tick, from, to).
var chain_count := 0
var chain_root := 0
var chain_tick := -1
var chain_from := Vector2.ZERO
var chain_to := Vector2.ZERO
## Momentum: ticks left to start an empowered swing (0 = none), and whether the current swing took it.
var momentum_t := 0
var swing_momentum := false
## Thorn Mantle: the tick the last ring was released.
var thorn_tick := -1
## Phase Strike: the tick it last discharged, and the first tick a guard block may discharge it again.
var phase_tick := -1
var phase_guard_next := 0
# --- end Items ---------------------------------------------------------------------------------------------

# --- Bosses --------------------------------------------------------------------------------------
## Compiled bosses (part of the loadout, like enemy_tables); spawn_boss takes an index into it.
var boss_tables: Array[BossTable] = []
## The live bosses' own state (stagger, phase, the attack in progress).
var bosses := BossStore.new()
## The boss attack (index in its table) that killed the player, or -1 (the recap's cause line).
var killer_attack := -1
## The actor id of the last boss spawned while it lives, or -1 (the dev panel's Kill boss, the run flow).
var boss_id := -1
## The final boss's fight (its three bodies), null in every other world.
var final_fight: FinalFight
## The final approach's pylons, buildup and walls; null elsewhere.
var approach: FinalApproach
## The shared interactables (the pylons, the timed doors' switches) and the
## puzzles' calm rooms; empty in most worlds (hashed only when it holds one).
var interactables := Interactables.new()
## The footprints of props that look solid (Solids); empty unless the floor's rules ask for them.
var solids := Solids.new()
## The floor's timed door and its secret room; null on a floor without one.
var timed: TimedDoor
## The floor's rune puzzle and its hidden room; null without one.
var runes: RuneAlignment
## The cracked wall, the containers and the explosive barrels; null
## on a floor with none.
var breakables: Breakables
## The hidden room under the Hollow Crown's throne (its pedestal and its
## sealed door), on the final approach of a profile that learned all ten Runic Stone lines; null everywhere else.
var heart: HeartRoom
## The floor's purple-rune room (its dais awakens the Purple Portal); null without.
var purple: PurpleRunes
## The floor's Lockdowns in play; null on a floor without any.
var lockdown: LockdownState
## v0.9.0 SH, HF (owner Q29b, W36; Shrines): the floor's Blood or Chaos shrine and its healing fountain; null without
## either (a Fortune shrine is the gamble shrine below).
var shrine: ShrineState
## The floor's elites (its elite rooms, those alive); null on a floor that
## never had one. elite_rules: their numbers (content, like reward_table; not hashed, not snapshotted).
var elites: EliteState
var elite_rules: EliteRules
## AFFINITIES.md; Affinities: the run's rune affinity on this floor; null for None (no effect, not
## hashed: a run without one hashes as before RB).
var affinity: AffinityState
## COLLECTIBLES.md; Collectibles: the collectibles this floor can hold (armed at setup by the app); null on
## a floor that holds none (every world before CL, goldens, sims: hashed only when it exists).
var collect: CollectState
## Stress Mark; StressMarks: the weak sides on enemies; null until a hero first holds the card.
var stress: StressState
# --- end Bosses ---------------------------------------------------------------------------------------------
# --- Rewards (v0.3.0 E; Rewards) ----------------------------------------------------------------------------
## The floor's reward rules (part of the loadout, like item_tables; not hashed).
var reward_table := RewardTable.new()
## Shards held (hashed). The run flow carries it between floors.
var shards := 0
## The shards the portal left behind on the way to this floor (RunCarry; 0 on floor 1). Read
## by the arrival card only.
var shards_left_behind := 0
## The floor number, 1-based: chest prices and boss shards scale with it (the run flow sets it).
var floor_index := 1
## Altars and chests on the floor.
var rewards := RewardStore.new()
## The reward whose offer is open (its id), or -1. While >= 0 the world waits for the pick.
var choosing := -1
## The last refused open (a chest you can't afford, or an empty offer): the reward's id and the tick.
var reward_denied_id := -1
var reward_denied_tick := -1
# --- end Rewards --------------------------------------------------------------------------------------------
# --- Gamble shrine (v0.3.0 L19; Gamble) ---------------------------------------------------------------------
## The shrine's rules (part of the loadout, like reward_table; not hashed).
var gamble_table := GambleTable.new()
## The floor's shrine: its id (-1 = none on this floor) and where it stands.
var gamble_id := -1
var gamble_pos := Vector2.ZERO
## Wins per GambleTable.Stat this run (empty until the first). The run flow carries it between floors.
var gamble_stacks := PackedInt32Array()
## Uses on this floor (the price steps up with each; not carried), the last win (stat, tick) and the last refusal.
var gamble_uses := 0
var gamble_last_stat := -1
var gamble_tick := -1
var gamble_denied_tick := -1
## The shrine's wins on this floor (a failed use doesn't count; at GambleTable.max_wins it is
## spent) and the last failed use's tick (-1 = none). Not carried: each floor's shrine starts fresh.
var gamble_wins := 0
var gamble_fail_tick := -1
# --- end Gamble ---------------------------------------------------------------------------------------------
# Shop: the shop's rules (loadout, not hashed; null = no shops) and the floor's shop (hashed once placed).
var shop_table: ShopTable
var shop := ShopState.new()

# --- Engines and combos (v0.3.0 G; Engines). Hashed when the loadout has items (_hash_engines). --------------
## Compiled combos (part of the loadout, like item_tables); combos_owned holds indices into it, in unlock order.
var combo_tables: Array[ComboTable] = []
var combos_owned := PackedInt32Array()
## Bit (1 << ComboTable.Effect) per owned combo (derived from combos_owned, so not hashed).
var combo_mask := 0
## Bulwark: guard charges stored, and how many the current swing took.
var guard_charges := 0
var swing_charges := 0
## Landed player bolts counted by the bolt feeders (Cinder Shot, Static Chain, Barbed Bolts, Frost Core).
var engine_bolt_hits := 0
## Which effects already fired in which root chain.
var proc_ledger := ProcLedger.new()
## Twin Arc's pending echo comes from an Overcharge swing, and that swing's shockwave damage (Resonance).
var echo_overcharged := false
var echo_wave := 0
## Slipstream: the first tick it may refund the dash again.
var slipstream_next := 0
## The last of each payoff, for the views: shock discharge (tick, from, jump ends), Plasma Arc (tick, from, to),
## Shatter Dash, bleed burst, Wildfire and Blood Harvest (tick, where), Resonance, Shrapnel Storm, Spiked Phase,
## Slipstream and Frozen Bastion (tick).
var discharge_tick := -1
var discharge_from := Vector2.ZERO
var discharge_to := PackedVector2Array()
var plasma_tick := -1
var plasma_from := Vector2.ZERO
var plasma_to := Vector2.ZERO
var shatter_tick := -1
var shatter_pos := Vector2.ZERO
var burst_tick := -1
var burst_pos := Vector2.ZERO
var wildfire_tick := -1
var wildfire_pos := Vector2.ZERO
var harvest_tick := -1
var harvest_pos := Vector2.ZERO
var resonance_tick := -1
var shrapnel_tick := -1
var spiked_tick := -1
var slipstream_tick := -1
var bastion_tick := -1
## Transient within a tick (not hashed): the payoff effects running right now (the ancestry), and the event seq when
## this tick began (the watchdog's per-tick count).
var engine_chain := PackedStringArray()
var tick_seq0 := 0
# --- end Engines -------------------------------------------------------------------------------------------

# --- Run flow -----------------------------------------------------------------------------------
## The floor's boss room, door and portal (null in the arena and kernel scenarios) and the run's floor count
## (RunState sets it, and floor_index above). The boss itself is C's (boss_id, bosses).
var boss_flow: BossFlow
var floor_count := 1
## The Ascension loop; RunState.prepare sets them: the loop (1 outside a run), the run's floor counted
## across loops (0: floor_index, a world without a run; run_floor_index()), the threat T the loop adds
## (Curses.threat) and the per mille it adds to the hidden catch-up's caps (CatchUp).
var loop := 1
var run_floor := 0
var loop_threat := 0
var loop_cap_permille := 0
## The run's loop rules on this floor (indices into LoopRules.POOL; RunState.prepare
## sets them, so they are not saved apart from the snapshot) and SHIELDED's front multiplier and half-arc (1000 and 0:
## no guard).
var loop_rules := PackedInt32Array()
var loop_shield_permille := 1000
var loop_shield_half_arc := 0
## The max HP the floors cleared so far add before the max HP stat
## (Stats.max_hp_at). RunState.prepare sets it from the run's floor (RunState.floor_hp_bonus), so it is not saved: a
## resumed floor derives it again. 0 outside a run.
var floor_hp_bonus := 0
# --- end Run flow ------------------------------------------------------------------------------------------
var build_state := PlayerBuildState.new()  # Facing, damage remainders, combat and regen (PlayerBuild).
var regen_bonus_permille := 0  # v0.3.0 L25 hook: extra per mille of max HP a second out of combat (PlayerRegen).

var heat: HeatState  # Overclock heat (v0.3.0 L18; Heat): null unless the loadout has it (Heat.enable).
var kit := KitState.new()  # The Vent and Skill buttons (PlayerSkill), hashed once touched.
# --- Build (v0.4.0 BS; Abilities, Stats, Offers). Hashed once touched (Abilities.hash_into). ---------------------
## Compiled abilities and stat cards (part of the loadout, like item_tables; stat_tables indexed by Stats.Stat).
var ability_tables: Array[AbilityTable] = []
var stat_tables: Array[StatTable] = []
## Run-long (RunCarry): abilities in slot order (indices into ability_tables), their levels, and Stats values.
var ability_owned := PackedInt32Array()
var ability_levels := PackedInt32Array()
var stat_values := PackedInt32Array()
var stat_cards := PackedInt32Array()  # The stat cards taken (Offers codes), in order
var ab := AbilityState.new()  # per floor: cooldowns, drones, bombs, orbit, charges
## BuildSlots; owner B7: the modifier slots in pick order (the layer order), as Offers card codes (an item
## index, or ABILITY_BASE + an ability index), at most BuildSlots.SLOTS; run-long (RunCarry). A pending swap: the
## card waiting for a slot (-1 = none), where it came from (BuildSlots.Source) and its offer index there.
var mod_slots := PackedInt32Array()
var swap_code := -1
var swap_source := 0
var swap_ref := -1
## CardLevels; WAND.md rule 6: the level of each held wand card by item index (0 or absent = level 1;
## sized on the first level-up, so a world that never levels a card hashes as before); run-long (RunCarry).
var card_levels := PackedInt32Array()
## The spec of the player hit resolving now (Attacks, the projectile sweep; null between hits), which the
## engines read for its statuses. Transient within a tick (WorldSnapshot.WORLD_KEPT).
var hit_spec: AttackSpec = null
## Whether the last player hit Damage.hit resolved was a crit (the wand's On Crit reads it right after).
## Transient within a hit (WorldSnapshot.WORLD_KEPT).
var last_hit_crit := false
## The proc of the player hit resolving now, per mille (a secondary attack's:
## WandTable.secondary_proc_permille; 1000 otherwise), which the engines' status feeds read. Transient within a hit
## (WorldSnapshot.WORLD_KEPT): 1000 between hits.
var hit_proc_permille := 1000
## Matchups: the spec Attacks.launch is running (null outside a launch), and the matchup of the next
## Damage.hit, set by the direct-hit callers (Attacks._hit, the projectile sweep) and taken (reset) by that hit, so
## a hit nested in it is neutral. Transient within a hit (WorldSnapshot.WORLD_KEPT).
var strike_spec: AttackSpec = null
var matchup_permille := 1000
var matchup_tags := 0
## Wand: the wand's numbers, the slots per floor and the trigger's child spell (loadout, not hashed; null
## = a lab world: six slots, the class defaults for the child spell).
var wand_table: WandTable
var rng_crit: RngStream  # crit rolls (Stats.outgoing)
var rng_ability: RngStream  # auto-ability randomness (Abilities)
var overrun_table: OverrunTable  # The Overrun branch's numbers (null = off; not hashed)
var overrun := OverrunState.new()  # The floor's Overrun room in play (Overrun), hashed once touched
var arena_table: ArenaTable  # The sealed arenas' numbers (null = no regular arenas; not hashed)
var arenas := ArenaState.new()  # The arena sealed now and those cleared (Arenas), hashed once touched
## The boss-only legendary tier (null = none; not hashed) and the legendary altar the boss's
## death left (its reward id; -1 until then; it stays set after the pick so one boss pays once). BossReward.
var legendary_table: LegendaryTable
var legendary_id := -1
## The picks the floor's legendary altar still gives after the one open now (LegendaryTable.
## extra_picks for the loop, set when the boss dies; BossReward.another_pick). Hashed while above 0.
var legendary_picks := 0
## The floor's pacing table (loadout, not hashed; null = no pacing, the draws as
## before FL), the regular altars that used the floor's compatible-card guarantee (hashed once above 0) and the
## floor's jackpot cards as (reward id, card code) pairs (hashed once one exists; the pick card's "Jackpot").
var loot_pacing: LootPacingTable
var loot_guaranteed := 0
var loot_jackpots := PackedInt32Array()
## The floor's ice (Frozen Shore; IcePatches): loadout, null on every other biome (not hashed: laid from
## the floor seed like the layout; its slide shows in the hashed position and velocity). or Starfall's
## starglow pools (IceField.kind), the same way.
var ice: IceField
# --- end Build ----------------------------------------------------------------------------------------------
# Events, Curses: the floor's event rooms and cursed offers; the curses held and the threat peak (carried).
var ev := EventState.new()
## Every whole-value write (RunCarry.apply, WorldSnapshot.apply) drops Curses.total's cache; Curses.add and cleanse,
## which change it in place, drop it themselves.
var curses_owned := PackedInt32Array():
	set(v):
		curses_owned = v
		curse_totals = PackedInt32Array()
## v0.7.0 audit C-12: Curses.total's cache, one sum per Curses.Effect; empty = stale (rebuilt on the next read).
## Derived from curses_owned and World.ev.curses: not hashed, not snapshotted (WorldSnapshot.WORLD_KEPT).
var curse_totals := PackedInt32Array()
var threat_peak := 0
## The event indices (Events.draw_event) placed in common event rooms so far this run, this floor's included
## (carried; the run's cap and "never the same twice" read it). Not hashed.
var events_seen := PackedInt32Array()
## v0.5.0 RT + EV: Deep floors taken so far this run, this one included (RunState.prepare): +1 threat T each.
var deep_threat := 0
## The trade-off curses' state in play (Curses) and core theft (CoreTheft), per floor.
var cs := CurseState.new()
var cores := CoreState.new()
## The modifier engine's state in play (ModifierRuntime), per floor: queued launches, every-N counters,
## the moments' and body rules' marks. Hashed with the build's specs (Modifiers.hash_into).
var mx := ModifierState.new()
## The Blade pool's state in play (BladeForms), per floor: knocked enemies, orbiting blades, the last
## dash, what the view draws. Hashed once touched (ModifierRuntime.hash_into). The cards' levels are card_levels.
var blade := BladeState.new()
## The Blade pool's runner numbers (loadout, not hashed; null = a lab world: BladeTable's defaults).
var blade_table: BladeTable
## The wand's slot limits, projectile caps and form × card table (loadout,
## not hashed; null = a lab world: no limits, no table, no caps).
var slot_table: SlotTable
## The hidden catch-up's numbers (loadout, not hashed; null = off) and the floor's m (CatchUp),
## hashed only with the table. S5: the rooms of a Deep floor whose first pack already brought its elite (hashed once
## one did).
var catch_up_table: CatchUpTable
## The designer numbers once fixed in the sim's code (dev panel Step 6): shipped values unless Main sets them from
## data/tuning/sim.tres. Loadout, not state (not hashed).
var tuning := SimTuning.new()
var catch_up := CatchUpState.new()
## The intensity director's state (Intensity), hashed only when the spawner has its table.
var intensity := IntensityState.new()
var deep_elite_rooms := PackedInt32Array()
## The pairing rows (indices into SpawnTable.pairings) that fired on this floor, in first-seen order.
var pairs_seen := PackedInt32Array()
## The floor's horde critter (an ActorStore kind; FloorPlan sets it from the biome,
## -1: none, so no surges; loadout) and its surges (Surges): the floor ticks each begins at and its size (empty until
## planned), the next one to begin, the ticks into the one running (-1: none) and how many of it have arrived. Hashed
## once planned.
var critter_kind := -1
## The kinds only this floor's biome spawns (its signatures and variant, sorted; FloorPlan
## sets it from the biome, VariantCompiler.roster_kinds; empty: none, so no biome-only kind spawns; loadout), and what
## the variants left on the floor (VariantState: the trails, the rubble; hashed once touched).
var roster_kinds := PackedInt32Array()
var variants := VariantState.new()
## ENEMIES.md R1-R4: what the Ruins and Night Rocks signatures leave (RuinsRocksState: the Weavers'
## cables, the Throwers' rocks, the waiting Lurkers' boulders; hashed once touched).
var ruins_rocks := RuinsRocksState.new()
## ENEMIES.md R5-R8: what the Red Canyon's and the Frozen Shore's signature enemies left on the floor
## (CanyonShoreState: bursts, vents, blobs, chunks, shells; hashed once touched).
var canyon_shore := CanyonShoreState.new()
var surge_at := PackedInt32Array()
var surge_sizes := PackedInt32Array()
var surge_next := 0
var surge_t := -1
var surge_spawned := 0
## The perf probe's phase timer (scripts/checks/perf_probe.gd --phases); null in play. Told where each tick
## phase begins and ends (begin/end with the phase's name), it never reads or writes state: not hashed, not copied.
var phase_probe: Object = null
## The native side (NativeWorld), or null, and the kernels it runs (NativeWorld bits). Not hashed, not copied: a
## copy makes its own from the factory.
var native: Object = null
var native_on := 0
## Tests only: -1 off; 0 or more counts the aoe_candidates calls that left out an actor the full scan's
## distance test would take (it must stay 0: the candidates are a superset).
var debug_aoe_misses := -1
## Tests only: true keeps aoe_candidates on the full scan (the reference its grid must match exactly).
var debug_aoe_full := false
var _next_id := 1
var _event_seq := 0
var _events: Array[SimEvent] = []
var _wall_grid := DenseGrid.new()  # Dense grids (were UniformGrids)
var _actor_grid := DenseGrid.new()
## The area attacks' grid (aoe_candidates): built at most once in each _projectile_hits, from the positions
## then (nothing moves or adds a body inside it); _hit_grid_state 0: closed (full scans), 1: open, 2: open and built.
var _hit_grid := DenseGrid.new()
var _hit_grid_state := 0
## 1.. n - 1 for n actors (aoe_candidates' full scan; it depends on the count only).
var _every_index := PackedInt32Array()
## Bumped whenever the wall grid changes, so the native mover knows to take the walls again.
var _wall_rev := 0
## Run flow: a wall prepared for adding in play, and its flow field (prepare_wall).
var _wall_next: Obb
var _nav_next: NavField
## The flow field from before the prepared wall was added (add_wall_now), swapped back in when that wall
## is removed again (remove_wall_now: the boss door reopening after the boss), so reopening never rebuilds it.
var _nav_open: NavField
## A floor's build (FloorPlan, through defer_nav) builds its flow fields once, at its end (build_nav):
## meanwhile set_walls and prepare_wall keep a copy of the walls each field would be built from (null: none due).
var _nav_deferred := false
var _nav_due: Variant = null
var _nav_next_due: Variant = null
## Projectile spawns wait until phase 9 of the tick: [owner, team, pos, vel, damage, radius, life, tags, bounces].
var _pending_projectiles: Array[Array] = []
## Enemies a boss brings in (eggs, turrets) wait until phase 9 of the tick: [kind, pos].
var _pending_enemies: Array[Array] = []


func _init(p_seed: int, p_player: PlayerTable, player_pos: Vector2 = Vector2.ZERO) -> void:
	seed_value = p_seed
	rng_map = RngStream.derive(p_seed, "map")
	rng_loot = RngStream.derive(p_seed, "loot")
	rng_combat = RngStream.derive(p_seed, "combat")
	rng_ai = RngStream.derive(p_seed, "ai")
	rng_enemy = RngStream.derive(p_seed, "ai:enemy")
	rng_crit = RngStream.derive(p_seed, "crit")  # v0.4.0 BS
	rng_ability = RngStream.derive(p_seed, "ability")
	player = p_player
	if native_kernels != 0 and native_factory.is_valid():
		native = native_factory.call()
		if native != null:
			native_on = native_kernels
			NativeWorld.setup(self)
	var id := take_id()
	actors.add(
		id,
		ActorStore.Kind.PLAYER,
		ActorStore.TEAM_PLAYER,
		player_pos,
		player.radius_m,
		player.hp,
		0
	)


## Static walls; call before the first step.
func set_walls(p_walls: Array[Obb]) -> void:
	walls = p_walls
	if _nav_deferred:
		_nav_due = walls.duplicate()  # The field build_nav builds (as nav.build's own copy)
	else:
		nav.build(walls)
	rebuild_wall_grid()


## From now until build_nav, set_walls and prepare_wall leave their flow fields for build_nav, which
## builds each once from the walls of the last call (a floor rebuilds its walls up to five times while it is laid
## out: the shop, the room purposes, the curse room, the fountain). Only for a floor's build: none of its steps reads
## a flow field (the wall grid stays current); the first tick builds them if build_nav was not called.
func defer_nav() -> void:
	_nav_deferred = true


## Builds the flow fields defer_nav left: the same fields set_walls and prepare_wall would have built.
func build_nav() -> void:
	if not _nav_deferred:
		return
	_nav_deferred = false
	if _nav_due != null:
		nav.build(_nav_due)
		_nav_due = null
	if _nav_next_due != null:
		_nav_next = NavField.new()
		_nav_next.build(_nav_next_due)
		_nav_next_due = null


## Indices of the walls that may touch `rect` (ascending; a superset), for sweeps that would test every wall (SC).
func walls_near(rect: Rect2) -> PackedInt32Array:
	return _wall_grid.query_rect(rect)


## Indices of the walls that may touch a body of radius r moving from a to b (ascending; a superset): a line of sight
## or a run, walking only the grid cells along it. The reach is r × 1.5: Collide.sweep_vs_obb grows a
## turned wall by r along its own axes, which reaches up to r × 1.41 along the world's.
func walls_along(a: Vector2, b: Vector2, r: float) -> PackedInt32Array:
	return _wall_grid.query_segment(a, b, r * 1.5)


## No wall crosses the line from `a` to `b` (homing targets: the Laser's Homing, the Seekers).
func sees(a: Vector2, b: Vector2) -> bool:
	for k in walls_along(a, b, 0.0):
		if Collide.sweep_vs_obb(a, b, 0.0, walls[k]) >= 0.0:
			return false
	return true


## Indices of the actors whose bodies may touch `rect` (ascending; a superset) as of the last actor-grid build:
## tick phase 3 builds it before the enemies plan, each collision pass in phase 5 rebuilds it.
func actors_near(rect: Rect2) -> PackedInt32Array:
	return _actor_grid.query_rect(rect)


## Adds a dummy mover immediately (setup only; during a tick, spawns are queued).
func add_dummy(p: Vector2, radius_m: float, hp: int) -> int:
	var id := take_id()
	var first_shot := dummy_fire_period + (id % maxi(dummy_fire_period, 1))
	actors.add(id, ActorStore.Kind.DUMMY, ActorStore.TEAM_ENEMY, p, radius_m, hp, first_shot)
	emit_event(SimEvent.Kind.SPAWN, id, id, id, p)
	return id


## Queues a projectile for phase 9 of this tick. `bounces`: wall bounces (Ricochet Core).
func queue_projectile(
	owner_id: int,
	team: int,
	at: Vector2,
	vel: Vector2,
	damage: int,
	radius_m: float,
	life: int,
	tags: int,
	bounces: int = 0,
	spec_key: String = ""
) -> void:
	_pending_projectiles.append(
		[
			owner_id,
			team,
			at,
			vel,
			damage,
			radius_m,
			life,
			tags,
			bounces,
			spec_key,
			&"",
			-1,
			0,
			"",
			0,
			0
		]
	)


## The player bolt queued last is a secondary one (ProjectileStore.SECONDARY) or a repeat's
## (ProjectileStore.REPEAT; Attacks._bolts).
func set_pending_second(kind: int) -> void:
	_pending_projectiles[-1][12] = kind


## The player bolt queued last pierces this many more enemies than its spec (the Wisps' shots).
func set_pending_pierce(n: int) -> void:
	_pending_projectiles[-1][14] = n


## The Seekers dart queued last was dealt from this many thousandths of damage (SeekerMods.on_spawn).
func set_pending_milli(n: int) -> void:
	_pending_projectiles[-1][15] = n


## Remnants, Threadline: the player bolt queued last links to the one before it (its LINK hook's key).
func set_pending_link(key: String) -> void:
	_pending_projectiles[-1][13] = key


## The projectile queued last is a fireball of look `look` (BulletPatterns).
func set_pending_look(look: StringName) -> void:
	_pending_projectiles[-1][10] = look


## The last n projectiles queued take look `look` (the Wardens' twin's embers).
func relook_pending(n: int, look: StringName) -> void:
	for k in range(maxi(0, _pending_projectiles.size() - n), _pending_projectiles.size()):
		_pending_projectiles[k][10] = look


## The projectile queued last was fired by its boss's attack `attack` (the recap's cause, BulletPatterns).
func set_pending_cause(attack: int) -> void:
	_pending_projectiles[-1][11] = attack


## The last `n` projectiles queued bounce off walls `bounces` times (BossRicochet).
func set_pending_bounces(n: int, bounces: int) -> void:
	for k in range(maxi(0, _pending_projectiles.size() - n), _pending_projectiles.size()):
		_pending_projectiles[k][8] = bounces


## Projectiles queued this tick, not spawned yet (BulletPatterns' per-tick cap reads it).
func pending_projectiles() -> int:
	return _pending_projectiles.size()


## Projectiles actor `owner_id` queued this tick, not spawned yet (BossPrism.shots_alive).
func pending_projectiles_of(owner_id: int) -> int:
	var n := 0
	for q in _pending_projectiles:
		if int(q[0]) == owner_id:
			n += 1
	return n


## The player's projectiles alive and queued now (Attacks._shot_room's count).
func player_projectiles() -> int:
	var n := 0
	for t in projectiles.team:
		if t == ActorStore.TEAM_PLAYER:
			n += 1
	for s in _pending_projectiles:
		if s[1] == ActorStore.TEAM_PLAYER:
			n += 1
	return n


## The player's projectiles alive and queued now whose spec is attack `id` (any key of it: each combo
## step's Blade Storm is its own spec; Attacks._alive_room's count). Read on demand, never stored.
func player_projectiles_of(id: StringName) -> int:
	var book := Modifiers.book(self)
	var n := 0
	for key in projectiles.spec_key:
		if key != "":
			var s := book.find(key)
			if s != null and s.id == id:
				n += 1
	for p in _pending_projectiles:
		if p[1] == ActorStore.TEAM_PLAYER and p[9] != "":
			var s := book.find(p[9])
			if s != null and s.id == id:
				n += 1
	return n


## Advances exactly one tick. The phase order is part of the contract (SIM_CONTRACTS §2).
func step(frame: InputFrame) -> void:
	if _nav_deferred:  # A floor whose build left its flow fields (FloorPlan builds them first)
		build_nav()
	# 0. a wand reorder (InputFrame.pick = PICK_WAND_MOVE_BASE + from × 16 + to) is input, applied first
	# in any state (a choice open, the shop, hit-stop); the rest of the tick sees no pick.
	frame = Wand.take_move(self, frame)
	# 1. Freeze check: hit-stop holds everything except buffering new presses.
	if freeze_ticks > 0:
		freeze_ticks -= 1
		_buffer_presses(frame.pressed)
		tick += 1
		return
	tick_seq0 = _event_seq  # Engines: the watchdog counts this tick's events.
	# v0.8.0 N11 fix: while the hero arrives, phase 1c's hold comes before any choice: a swap opened meanwhile (the dev
	# panel's grant) waits for the landing, instead of freezing the arrival with the HUD hidden.
	var arriving := boss_flow != null and boss_flow.arrive_left > 0
	# 1b. Rewards: while a 3-card choice is open, only the pick runs; the tick still counts. a new
	# loop's Constellation pick (free, no skip) waits first.
	var granting := swap_code >= 0 and swap_source == BuildSlots.Source.GRANT
	var starry := not constellation_offer.is_empty()
	if (starry or granting or choosing >= 0) and not arriving:
		if starry:
			Constellations.choose(self, frame)
		elif granting:  # A swap with no panel of its own waits first
			BuildSlots.choose_grant(self, frame)
		else:
			Rewards.choose(self, frame)
		tick += 1
		return
	# The shop's panel is open, only its actions run; an event panel waits for its choice.
	# (v0.7.5 AP's Ascension choice waited here too; v0.8.0 P2 retired it: two devices, no panel.)
	if (shop.open or ev.open >= 0) and not arriving:
		if shop.open:
			Shop.choose(self, frame)
		else:
			Events.choose(self, frame)
		tick += 1
		return
	if boss_flow != null and boss_flow.holds_world():  # Run flow: the floor is over, or the portal transit (PT).
		boss_flow.advance_transit(self)
		tick += 1
		return
	# 2. Input (a dead player's input is ignored).
	_age_buffer()
	if player_dead():
		frame = InputFrame.new()
	_buffer_presses(frame.pressed)
	move_intent = frame.move
	aim_angle = frame.aim_angle
	aim_dist_cm = frame.aim_dist_cm
	held_buttons = frame.held
	actors.facing[0] = aim_angle
	PlayerBuild.note_facing(self)  # Builds: melee follows the facing.
	# 2b. Rewards: interact by an altar or chest opens its choice; the rest of this tick waits with it.
	if Rewards.interact(self) or Events.interact(self):  # 2c. an event pedestal opens its panel.
		tick += 1
		return
	if Shop.interact(self):  # Interact by the terminal opens the shop.
		tick += 1
		return
	Gamble.interact(self)  # Gamble shrine: the press goes to an altar or chest in reach first.
	if boss_flow != null:  # The press by the shut boss door opens it
		boss_flow.interact(self)
	# The shared interactables' slot (the FA pylons): the nearest enabled one in reach takes the press
	Interactables.interact(self)
	Solids.step(self)  # A prop's footprint joins the walls once the hero is clear of it
	# 3. AI (the flow field refreshes on fixed ticks).
	var pp := phase_probe  # The perf probe's phase timer (null in play)
	# The flood starts on those ticks and is built over NavField.SLICES ticks, then swapped in.
	if not enemy_tables.is_empty() and (tick % NavField.PERIOD == 0 or nav.building()):
		if pp != null:
			pp.begin(&"nav_flood")
		if tick % NavField.PERIOD == 0:
			_begin_nav_flood()  # Bounded; stops past the enemies
		nav.advance()
		if pp != null:
			pp.end(&"nav_flood")
	if pp != null:
		pp.begin(&"ai")
	_run_ai()
	if pp != null:
		pp.end(&"ai")
		pp.begin(&"actions")
	# 4. Action states.
	_advance_actions()
	if pp != null:
		pp.end(&"actions")
		pp.begin(&"move")
	# 5. Move and collide.
	var before_move := player_pos()  # Items: the Kinetic Dash sweep starts here.
	_move_and_collide()
	if pp != null:
		pp.end(&"move")
		pp.begin(&"resolve")
	# 6. Hits: enemy attacks, then projectile sweeps.
	var critter_rows := PackedInt32Array()  # The critters touch after the others (CritterAi)
	var roles := EnemyAi.roles  # One table read per actor (EnemyAi.role_of; a local: a static read costs more)
	for i in range(1, actors.size()):
		var kind := actors.kinds[i]
		var role := roles[kind] if (kind & -EnemyAi.KIND_SLOTS) == 0 else EnemyAi.role_of(kind)
		if role == EnemyAi.Role.CRITTER:
			critter_rows.append(i)
		elif role == EnemyAi.Role.BOSS and actors.dead[i] == 0:
			BossAi.resolve(self, i)  # Bosses.
		elif role == EnemyAi.Role.ENEMY and actors.dead[i] == 0:
			EnemyAi.resolve(self, i)
	if not critter_rows.is_empty():
		CritterAi.touch_all(self, critter_rows)
	Mines.advance(self)  # Mines arm and blow.
	Variants.advance(self)  # The variants' trails burn and melt (after the mines)
	RuinsRocks.advance(self)  # The cables drop or hurt, the rocks go, the Lurkers hold still
	if canyon_shore.touched:
		CanyonShore.advance(self)  # The bursts, the vents, the blobs land, the chunks slide
	if not boss_tables.is_empty():
		BossSignatures.advance(self)  # Pillars sink, javelins fly back
	if pp != null:
		pp.end(&"resolve")
		pp.begin(&"proj")
	_projectile_hits()
	if pp != null:
		pp.end(&"proj")
		pp.begin(&"dash_abilities")
	ItemEffects.dash_hits(self, before_move)  # Items: Kinetic Dash.
	if affinity != null:
		Affinities.dash_shock(self, before_move)  # A2 Storm's crackle
	if pp != null:
		pp.begin(&"da.abilities")
	Abilities.advance(self)  # Auto abilities, the blink shock, stat regen.
	if pp != null:
		pp.end(&"da.abilities")
		pp.begin(&"da.starfall_spells")
	Starfall.advance(self)  # The meteors due land
	if Spells.touched(self):
		Spells.advance(self)  # The spells cast by themselves, the Fireballs fly
	if pp != null:
		pp.end(&"da.starfall_spells")
		pp.end(&"dash_abilities")
		pp.begin(&"statuses")
	# 7. The effect queue arrives with the engine work. 8. Statuses: Ember Edge burns (Items).
	ItemEffects.tick_burns(self)
	ItemProcs.tick_slows(self)  # Items: Frost Core slows run down.
	Engines.tick_statuses(self)  # Engines: shock, bleed, frost, freezes.
	Venom.tick(self)  # Venom Core's poison
	PlayerRegen.advance(self)  # Builds: out-of-combat regen.
	if pp != null:
		pp.end(&"statuses")
		pp.begin(&"remove_dead")
	# 9. Deaths and spawns (the wave director adds enemies here).
	if approach != null:
		approach.advance(self)  # The buildup's end: the walls of light, the Colossus rises
	if timed != null:
		TimedDoor.advance(self)  # The slab, the timer, the shut once the hero is clear
	if runes != null:
		RuneAlignment.advance(self)  # The slab stands until the pillars are aligned
	if breakables != null:
		Breakables.advance(self)  # The cracked wall, shots through props, the barrels' blasts
	if final_fight != null:
		FinalBoss.advance(self)  # The shatter, the next body, the win (before the dead leave)
	_remove_dead()
	if pp != null:
		pp.end(&"remove_dead")
		pp.begin(&"after")
	StressMarks.advance(self)  # The weak sides on the enemies near the hero
	Events.advance(self)  # A defence held.
	CoreTheft.advance(self)  # The gone carriers, staggers and steal windows, drops taken
	Arenas.advance(self)  # Sealed arenas (the Overrun too): the seal, the waves, the clear
	if not starbound.is_empty():
		Starbound.advance(self)  # A cleared room resets Rising Edge and Fervour
	if lockdown != null:
		Lockdowns.advance(self)  # The seal, the formations, the safety, the cap, the open
	if shrine != null:
		Shrines.advance(self)  # A Chaos challenge cleared raises its altar
	if elites != null:
		Elites.advance(self)  # The elites gone, an elite room's elite arriving
	if collect != null:
		Collectibles.advance(self)  # A source gives its collectible; the hero takes those in reach
	ItemEffects.collect_pickups(self)  # Items: walking over a pickup takes it.
	HealOrbs.advance(self)  # Walking over a heal orb heals
	ShardDrops.advance(self)  # Walking near kill shards takes them
	WaveDirector.advance(self)
	if spawner != null:
		if Arenas.holds_spawns(self) or Lockdowns.holds_spawns(self):  # A Lockdown too
			Arenas.count_time(self)  # Sealed in an arena, the horde waits; the clock runs on
		elif boss_flow == null or boss_flow.spawns_open(self):
			SpawnDirector.advance(self)
		else:
			boss_flow.count_time(self)  # Run flow: the boss fight (and its room after, PB) stops spawns, not the clock.
	if boss_flow != null:
		boss_flow.advance(self)
	BossReward.advance(self)  # The boss's legendary altar
	_apply_spawns()
	if pp != null:
		pp.end(&"after")
	# 10. Cues are already in the event log. 11. Hashing is on demand (state_hash).
	tick += 1


func add_freeze(ticks: int) -> void:
	freeze_ticks = mini(freeze_ticks + ticks, SimTick.FREEZE_CAP_TICKS)


func player_pos() -> Vector2:
	return actors.pos(0)


## The run's floor counted across loops (FloorCadence's shop and curse floors, the wand's slots read it);
## floor_index for a world without a run.
func run_floor_index() -> int:
	return run_floor if run_floor > 0 else floor_index


func player_dead() -> bool:
	return actors.dead[0] == 1


## The player's guard is up: guard chosen, the utility button held, not dashing, alive.
func guarding() -> bool:
	return (
		Abilities.utility(self) == PlayerTable.Utility.GUARD  # the forced loadout's guard, or Aegis
		and (held_buttons & InputFrame.UTILITY) != 0
		and dash_ticks_left == 0
		and not player_dead()
	)


## Compiled numbers for an enemy kind; null for kinds without a table (the kernel's dummies).
func enemy_table(kind: int) -> EnemyTable:
	return enemy_tables.get(kind)


func set_enemy_tables(tables: Array[EnemyTable]) -> void:
	for t in tables:
		enemy_tables[t.kind] = t
	if native != null:
		NativeWorld.tables_changed(self)


## Adds an enemy now (setup, or the wave director in phase 9). It spawns in: no acting, no damage, for
## SPAWN_IN_TICKS.
func add_enemy(kind: int, p: Vector2) -> int:
	var t := enemy_table(kind)
	var id := take_id()
	var i := actors.add(id, kind, ActorStore.TEAM_ENEMY, p, t.radius_m, t.hp, 0)
	actors.invuln[i] = tuning.spawn_in_ticks
	actors.facing[i] = Kin.angle_of(player_pos() - p)
	actors.power[i] = 1000  # Full damage; the spawn director scales it by tier
	emit_event(SimEvent.Kind.SPAWN, id, id, id, p)
	return id


# --- Items ---------------------------------------------------------------------------------------
## The compiled items, in the order the indices in items_owned and pickups refer to.
func set_item_tables(tables: Array[ItemTable]) -> void:
	item_tables = tables
	_build_mods()


## Gives the player item `item_index`. Returns false (and changes nothing) if it is already owned.
func add_item(item_index: int) -> bool:
	if items_owned.has(item_index):
		return false
	items_owned.append(item_index)
	BuildSlots.sync(self)  # An attack item takes the next modifier slot
	_build_mods()
	_refresh_combos(true)
	return true


## The compiled combos, in the order combos_owned refers to. Combos already earned by the items owned
## are owned at once, without an event.
func set_combo_tables(tables: Array[ComboTable]) -> void:
	combo_tables = tables
	_refresh_combos(false)


## Sets the items owned (carrying a run's items to a new floor): modifiers and combos follow, no events.
func set_items_owned(owned: PackedInt32Array) -> void:
	items_owned = owned.duplicate()
	BuildSlots.sync(self)  # v0.6.0 MX2
	_build_mods()
	_refresh_combos(false)


## The item modifiers plus the engine numbers the owned abilities borrow (ElementAbilities).
func _build_mods() -> void:
	item_mods = ItemMods.build(item_tables, items_owned)
	ElementAbilities.fold_engines(self, item_mods)
	Modifiers.invalidate(self)  # The specs compile again on their next read


## After the abilities owned or their levels changed: the modifiers, then the combos (an ability pair at
## its level evolves; `announce` emits COMBO_UNLOCKED).
func refresh_build(announce: bool) -> void:
	_build_mods()
	_refresh_combos(announce)


## Owns every combo whose two items are owned (new ones appended in combo order); `announce` emits COMBO_UNLOCKED
## for each new one (amount = its combo index). a combo deleted since a save was written (a retired stub,
## CardOrder.RETIRED_COMBOS) leaves combos_owned here, the first time the tables meet the restored state.
func _refresh_combos(announce: bool) -> void:
	drop_retired_combos()
	var earned := Engines.combos_for(combo_tables, items_owned)
	for c in earned:
		if combos_owned.has(c):
			continue
		combos_owned.append(c)
		if announce:
			var pid := actors.ids[0]
			var e := emit_event(SimEvent.Kind.COMBO_UNLOCKED, pid, pid, pid, player_pos())
			e.amount = c
			e.effect_id = combo_tables[c].id
	combo_mask = 0
	for c in combos_owned:
		combo_mask |= 1 << combo_tables[c].effect


## A held combo that was deleted (its table a retired stub, CardOrder.RETIRED_COMBOS) or is past the
## tables goes (a carry or snapshot written before O1; WorldSnapshot.apply calls it too). No-op without tables.
func drop_retired_combos() -> void:
	if combo_tables.is_empty():
		return
	var kept := PackedInt32Array()
	for c in combos_owned:
		if c < combo_tables.size() and not combo_tables[c].retired:
			kept.append(c)
	if kept.size() == combos_owned.size():
		return
	combos_owned = kept
	combo_mask = 0
	for c in combos_owned:
		combo_mask |= 1 << combo_tables[c].effect


## Puts a pickup for item `item_index` on the floor at `pos` (setup, or a spawner in phase 9). Returns its id.
func add_pickup(item_index: int, pos: Vector2) -> int:
	var id := take_id()
	pickups.add(id, pos, item_index)
	emit_event(SimEvent.Kind.SPAWN, id, id, id, pos)
	return id


# --- end Items ---------------------------------------------------------------------------------------------


# --- Run flow -----------------------------------------------------------------------------------
## Whether a blink from `from` may land at `at`: the boss room's door rules (BossFlow.blink_may_land).
func blink_may_land(from: Vector2, at: Vector2) -> bool:
	if not Arenas.blink_may_land(self, at):  # Never out of a sealed arena
		return false
	if not Lockdowns.blink_may_land(self, at):  # Never out of a sealed Lockdown
		return false
	return boss_flow == null or boss_flow.blink_may_land(self, from, at)


## A sealed arena's doorway barrier joins the walls for collision, shots and sight only: the flow field is
## left as it is (a rebuild is ~0.1 s on a floor), so the enemies outside press against it and those inside chase you.
func add_barrier(o: Obb) -> void:
	walls.append(o)
	_wall_grid.add(o.bounds())
	_wall_rev += 1


## Removes barriers (each matched by its shape; a restored world holds copies), then rebuilds the wall
## grid once (an arena's doorways all open on the same tick).
func remove_barriers(list: Array[Obb]) -> void:
	var removed := false
	for o in list:
		var k := _find_wall(o)
		if k >= 0:
			walls.remove_at(k)
			removed = true
	if removed:
		rebuild_wall_grid()


## The last wall with o's shape (centre, half-extents and angle), or -1. Walls added in play are matched by shape,
## not identity: a restored world holds copies of them.
func _find_wall(o: Obb) -> int:
	for k in range(walls.size() - 1, -1, -1):
		var x := walls[k]
		if x.center == o.center and x.half == o.half and x.angle == o.angle:
			return k
	return -1


## Adds several walls during play at once (the final approach's walls of light): the grid and the flow
## field are rebuilt once, then flooded from the player.
func add_walls_now(list: Array[Obb]) -> void:
	if list.is_empty():
		return
	walls.append_array(list)
	rebuild_wall_grid()
	_wall_next = null
	_nav_next = null
	nav.build(walls)
	flood_nav()


## The wall grid from the walls as they stand (WorldSnapshot.apply after a barrier came back with a save).
func rebuild_wall_grid() -> void:
	var rects: Array[Rect2] = []
	for x in walls:
		rects.append(x.bounds())
	_wall_grid.build(rects)
	_wall_rev += 1


## Enemies queued for phase 9's arrival (Splitlings, boss adds) that aren't actors yet (Arenas waits for them).
func has_pending_enemies() -> bool:
	return not _pending_enemies.is_empty()


## Builds, at setup, the flow field for the walls plus `o`, so adding `o` in play (the boss door sealing) never
## rebuilds the whole field mid-fight (about 0.1 s on a floor).
func prepare_wall(o: Obb) -> void:
	var next: Array[Obb] = walls.duplicate()
	next.append(o)
	_wall_next = o
	if _nav_deferred:  # Built once, by build_nav
		_nav_next_due = next
		return
	_nav_next = NavField.new()
	_nav_next.build(next)


## The world's flood of the flow field from the player, bounded (WORLD_FLOOD_STEPS) and
## stopped a margin past the farthest live enemy (their cells are its targets), skipped while the player keeps its
## cell and every enemy is still in the field, and with no enemy alive.
## This floods at once (the walls or extra cells changed) and drops a build in progress.
func flood_nav() -> void:
	nav.cancel_build()
	var targets := _nav_targets()
	if targets.is_empty():
		return  # nobody reads the field; the first flood with enemies about runs (the key is the old one)
	nav.flood(player_pos(), NavField.WORLD_FLOOD_STEPS, targets)


## The periodic flood, from the player's cell and the enemies' cells of this tick,
## built over NavField.SLICES ticks (NavField.begin_build; World.step advances it) and swapped in when done, so the
## field enemies follow is up to that many ticks older. Skipped by flood's rules; a field not yet flooded since its
## build floods at once (the floor's first flood: enemies never walk an empty field).
func _begin_nav_flood() -> void:
	var targets := _nav_targets()
	if targets.is_empty():
		return
	if nav.never_flooded():
		nav.flood(player_pos(), NavField.WORLD_FLOOD_STEPS, targets)
	else:
		nav.begin_build(player_pos(), NavField.WORLD_FLOOD_STEPS, targets)


## The live enemies' cells (NavField.target_cell), the flood's targets.
func _nav_targets() -> PackedInt32Array:
	var targets := PackedInt32Array()
	for i in range(1, actors.size()):
		if actors.dead[i] == 0 and EnemyAi.is_enemy_kind(actors.kinds[i]):
			targets.append(nav.target_cell(actors.pos(i)))
	return targets


## Adds a wall during play. The flow field swaps to the one prepare_wall built (or is rebuilt if there is none) and
## floods from the player at once, so enemies path around the new wall from this tick.
func add_wall_now(o: Obb) -> void:
	walls.append(o)
	_wall_grid.add(o.bounds())
	_wall_rev += 1
	if o == _wall_next and _nav_next != null:
		_nav_open = nav
		nav = _nav_next
		_nav_open.cancel_build()  # The kept field holds no build; the flood's work carries over
		nav.last_work = _nav_open.last_work
	else:
		nav.build(walls)
	_wall_next = null
	_nav_next = null
	flood_nav()


## Removes a wall added in play (the boss door reopening once the boss is dead). The wall is
## matched by its shape (a restored world holds copies of the walls); the grid is rebuilt, and the flow field from
## before add_wall_now swaps back in (or is rebuilt if there is none) and floods from the player at once.
## `again` (the boss door's press opening it before the fight): the field with the wall is kept as the
## prepared one (prepare_wall), so the sealing that adds it back swaps it in instead of rebuilding.
func remove_wall_now(o: Obb, again: bool = false) -> void:
	var k := _find_wall(o)
	if k < 0:
		return
	walls.remove_at(k)
	rebuild_wall_grid()
	if _nav_open != null:
		if again and _wall_next == null:
			_wall_next = o
			_nav_next = nav
		nav.cancel_build()  # The field swapped out holds no build; the flood's work carries over
		_nav_open.last_work = nav.last_work
		nav = _nav_open
	else:
		nav.build(walls)
	_nav_open = null
	flood_nav()


# --- end Run flow ------------------------------------------------------------------------------------------


# --- Bosses --------------------------------------------------------------------------------------
## The compiled bosses, in the order spawn_boss's index refers to (ContentCompiler.compile_bosses).
func set_boss_tables(tables: Array[BossTable]) -> void:
	boss_tables = tables


## The first boss table of an actor kind, or null.
func boss_table_of_kind(kind: int) -> BossTable:
	for t in boss_tables:
		if t.kind == kind or (t.twin_kind >= 0 and t.twin_kind == kind):  # A twin's is its boss's
			return t
	return null


## Adds boss `boss_table_index` at `pos` now (setup, or tick phase 9 like the wave director) and returns its actor
## id. It rises for BossAi.INTRO_TICKS (invulnerable, not acting), then fights. Its death emits KILL (as any enemy,
## with its own kind) and then BOSS_DEFEATED once.
func spawn_boss(boss_table_index: int, pos: Vector2) -> int:
	var t := boss_tables[boss_table_index]
	var id := take_id()
	var i := actors.add(id, t.kind, ActorStore.TEAM_ENEMY, pos, t.radius_m, t.hp, 0)
	actors.invuln[i] = tuning.boss_intro_ticks
	actors.facing[i] = Kin.angle_of(player_pos() - pos)
	actors.freeze_immune[i] = 1  # Engines: frost only slows a boss, it never freezes it.
	bosses.add(id, boss_table_index)
	boss_id = id
	CoreTheft.on_boss(self, i)  # The boss's legendary core
	CatchUp.on_boss(self, i)  # The boss's own hidden catch-up, fixed for the fight
	BossTwin.on_spawn(self, i)  # The Twin Wardens' second body rises beside it, sharing its HP
	return id


# --- Rewards -------------------------------------------------------------------------------------
## Puts an altar (price 0) or a chest on the floor (setup). Returns its id.
func add_reward(kind: int, pos: Vector2, price: int) -> int:
	var id := take_id()
	rewards.add(id, pos, kind, price)
	if kind != RewardStore.Kind.DROP:  # An altar or chest is solid (a drop is a card, not a prop)
		solids.add_square(Solids.Kind.REWARD, id, pos)
	emit_event(SimEvent.Kind.SPAWN, id, id, id, pos)
	return id


## True while any boss is alive (not yet killed).
func boss_alive() -> bool:
	for id in bosses.ids:
		var i := actors.index_of(id)
		if i >= 0 and actors.dead[i] == 0:
			return true
	return false


## Drops the hostile shots queued this tick (FinalBoss.clear_shots: the shatter clears every one).
func drop_pending_hostile() -> void:
	var keep: Array[Array] = []
	for s in _pending_projectiles:
		if s[1] == ActorStore.TEAM_PLAYER:
			keep.append(s)
	_pending_projectiles = keep


## Queues an enemy for phase 9 of this tick (a boss's eggs and turrets).
func queue_enemy(kind: int, pos: Vector2) -> void:
	_pending_enemies.append([kind, pos])


## Queues an egg of `kind` for phase 9: `egg` is [its ticks, its HP at the kind's base HP, the boss
## attack that laid it] (BossSignatures.make_egg).
func queue_egg(kind: int, pos: Vector2, egg: Array) -> void:
	_pending_enemies.append([kind, pos, egg])


func pending_enemies_of(kind: int) -> int:
	var n := 0
	for s in _pending_enemies:
		if s[0] == kind:
			n += 1
	return n


# --- end Bosses ---------------------------------------------------------------------------------------------
## Any reward state away from its default (state_hash includes the rewards only then).
func _rewards_touched() -> bool:
	return (
		shards != 0
		or floor_index != 1
		or choosing != -1
		or reward_denied_tick != -1
		or reward_denied_id != -1
		or rewards.size() > 0
	)


## Living enemy indices whose body touches the disc (center, r), ascending. The uniform grid of this
## tick's bodies (the DenseGrid built in phase 5) does the broadphase, so call it from phase 6 on (auto-ability
## targeting).
## The actor indices an area check around `center` must look at, ascending, from 1: every index whose
## centre is within `reach` plus its own radius of `center` is in it (a superset; the caller's own test, live, decides).
## Inside _projectile_hits a grid narrows it; elsewhere it is every actor (the full scan it replaces).
func aoe_candidates(center: Vector2, reach: float) -> PackedInt32Array:
	var out: PackedInt32Array
	if _hit_grid_state == 0:
		var n := actors.size() - 1
		if _every_index.size() != maxi(n, 0):
			_every_index.resize(maxi(n, 0))
			for k in n:
				_every_index[k] = k + 1
		out = _every_index
	else:
		if _hit_grid_state == 1:
			_hit_grid.build_circles(actors.pos_x, actors.pos_y, actors.radius)
			_hit_grid_state = 2
		var m := reach + AOE_MARGIN_M
		out = _hit_grid.query_rect(Rect2(center.x - m, center.y - m, m * 2.0, m * 2.0))
		if not out.is_empty() and out[0] == 0:
			out.remove_at(0)
	if debug_aoe_misses >= 0:
		_check_aoe(center, reach, out)
	return out


## Tests: counts an actor the full scan's distance test would take that `got` left out.
func _check_aoe(center: Vector2, reach: float, got: PackedInt32Array) -> void:
	for j in range(1, actors.size()):
		if Kin.length(actors.pos(j) - center) <= reach + actors.radius[j] and not got.has(j):
			debug_aoe_misses += 1
	for k in range(1, got.size()):
		if got[k] <= got[k - 1]:
			debug_aoe_misses += 1


## The live non-player actors whose bodies reach within `r` of `center`, ascending. The hero's area attacks ask
## many times a tick, so the columns are read directly; the distance is Kin.length of actors.pos(i) - center, the
## same Vector2 difference and the same arithmetic.
func enemies_near(center: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var g := r + 1.0
	var n := actors.size()
	var teams := actors.teams
	var dead := actors.dead
	var px := actors.pos_x
	var py := actors.pos_y
	var rad := actors.radius
	for i in _actor_grid.query_rect(Rect2(center.x - g, center.y - g, g * 2.0, g * 2.0)):
		if i >= n or teams[i] == ActorStore.TEAM_PLAYER or dead[i] == 1:
			continue
		var d := Vector2(px[i], py[i]) - center
		if sqrt(float(d.x) * d.x + float(d.y) * d.y) <= r + rad[i]:
			out.append(i)
	return out


## Clears a buffered press of `bit` (it was used).
func consume_buffered(bit: int) -> void:
	input_buffer[BUTTON_BITS.find(bit)] = 0


# --- end Rewards --------------------------------------------------------------------------------------------


## Phase Dash's intangible dash keeps the i-frames for the whole dash.
func dash_iframes_active() -> bool:
	if dash_ticks_left <= 0:
		return false
	return (
		player.dash_ticks - dash_ticks_left < player.dash_iframe_ticks
		or ModifierRuntime.intangible(self)
	)


func is_dashing() -> bool:
	return dash_ticks_left > 0


func buffered(bit: int) -> int:
	return input_buffer[BUTTON_BITS.find(bit)]


func last_event_seq() -> int:
	return _event_seq


## Events with seq > after_seq, oldest first. The log keeps the most recent EVENT_LOG_CAP events.
## The log is ascending by seq (emit_event appends, the trim drops the oldest), so a binary search finds the first.
func events_since(after_seq: int) -> Array[SimEvent]:
	var lo := 0
	var hi := _events.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if _events[mid].seq > after_seq:
			hi = mid
		else:
			lo = mid + 1
	return _events.slice(lo)


func state_hash() -> String:
	var h := StateHasher.new()
	h.add_int(tick)
	h.add_int(freeze_ticks)
	h.add_int(seed_value)
	h.add_int(_next_id)
	h.add_int(_event_seq)
	for s in [rng_map, rng_loot, rng_combat, rng_ai]:
		h.add_int(s.state)
	h.add_int(aim_angle)
	h.add_int(aim_dist_cm)
	h.add_int(move_intent.x)
	h.add_int(move_intent.y)
	h.add_int(dash_ticks_left)
	h.add_int(dash_cooldown_left)
	h.add_f32(dash_dir.x)
	h.add_f32(dash_dir.y)
	h.add_f32(vel.x)
	h.add_f32(vel.y)
	h.add_ints(input_buffer)
	for v in [held_buttons, swing_t, swing_angle, swing_root, combo_step, combo_window, shot_cd]:
		h.add_int(v)
	if dmg_carry != 0 or dot_carry != 0 or shot_carry != 0:  # Only once a remainder was carried
		for v in [dmg_carry, dot_carry, shot_carry]:
			h.add_int(v)
	if starfall_crits != 0 or meteor_attacks != 0 or not meteors.is_empty():  # v0.10.5 W3-P10e
		h.add_int(starfall_crits)
		h.add_int(meteor_attacks)
		h.add_ints(meteors)
	for v in [wave_index, wave_timer, 1 if cleared else 0, killer_kind, killer_tags]:
		h.add_int(v)
	for v in [1 if spawner != null else 0, run_ticks, spawn_cd, kills]:
		h.add_int(v)
	h.add_int(blink_cd)
	h.add_int(blink_tick)
	h.add_f32(blink_from.x)
	h.add_f32(blink_from.y)
	# Items.
	h.add_ints(items_owned)
	pickups.hash_into(h)
	for v in [echo_t, echo_angle, echo_step, echo_root, echo_damage, echo_tick, swing_count]:
		h.add_int(v)
	h.add_int(1 if swing_overcharged else 0)
	for v in [overcharge_tick, dash_root, dash_hit_tick]:
		h.add_int(v)
	h.add_ints(dash_hit_ids)
	# Bosses: only in a world with boss tables, so worlds without bosses hash as before.
	if not boss_tables.is_empty():
		bosses.hash_into(h)
		h.add_int(killer_attack)
		h.add_int(boss_id)
	if not enemy_tables.is_empty():  # Enemy AI: only worlds with enemies, so the kernel golden holds.
		h.add_int(rng_enemy.state)
		actors.hash_ai(h)
	if variants.touched:  # Only once a variant left a trail or its crust
		variants.hash_into(h)
	if ruins_rocks.touched:  # Only once a signature left a cable, a rock or a boulder
		ruins_rocks.hash_into(h)
	if canyon_shore.touched:  # Only once a signature left something
		canyon_shore.hash_into(h)
	if mines.touched:  # Only once a Mine Layer dropped a mine.
		mines.hash_into(h)
	if orbs.touched:  # Only once a kill earned points or an orb lay.
		orbs.hash_into(h)
	if shard_drops.touched:  # Only once a kill laid shards on the floor.
		shard_drops.hash_into(h)
	if objectives.touched:  # Only once a boss pointed at something.
		objectives.hash_into(h)
	# Items, the second eight.
	for v in [heal_window_start, heal_window_used, heal_tick, chain_count, chain_root, chain_tick]:
		h.add_int(v)
	for v in [chain_from.x, chain_from.y, chain_to.x, chain_to.y]:
		h.add_f32(v)
	for v in [momentum_t, 1 if swing_momentum else 0, thorn_tick, phase_tick, phase_guard_next]:
		h.add_int(v)
	# Rewards: hashed once any reward state leaves its default, so worlds without rewards (the kernel
	# golden) keep their hash; any two states that differ in it still hash apart.
	if _rewards_touched():
		for v in [shards, floor_index, choosing, reward_denied_id, reward_denied_tick]:
			h.add_int(v)
		rewards.hash_into(h)
	if not item_tables.is_empty():
		_hash_engines(h)
	PlayerBuild.hash_into(self, h)  # Builds and regen, once touched.
	Heat.hash_into(self, h)  # Overclock heat: only worlds with heat.
	Abilities.hash_into(self, h)  # Only once a slot, a stat or crit is in play.
	BuildSlots.hash_into(self, h)  # Only once a modifier slot is filled or a swap waits.
	Modifiers.hash_into(self, h)  # The compiled specs, once the build has a modifier.
	if overrun.touched():  # Only once the player entered an Overrun room.
		overrun.hash_into(h)
	if arenas.touched():  # Only once an arena sealed.
		arenas.hash_into(h)
	if legendary_id != -1:  # Only once a boss left its legendary altar.
		h.add_int(legendary_id)
	if legendary_picks != 0:  # Only while a loop's boss altar gives more picks.
		h.add_int(legendary_picks)
	LootPacing.hash_into(self, h)  # Only once a guarantee or a jackpot was used.
	if kit.touched():  # Kit: only once Vent or Skill was pressed.
		kit.hash_into(h)
	if gamble_id >= 0 or not gamble_stacks.is_empty():  # Gamble shrine: only once there is one.
		h.add_ints(gamble_stacks)
		for v in [gamble_id, gamble_uses, gamble_last_stat, gamble_tick, gamble_denied_tick]:
			h.add_int(v)
		h.add_f32(gamble_pos.x)
		h.add_f32(gamble_pos.y)
		if gamble_wins != gamble_uses or gamble_fail_tick >= 0:  # Only once a use failed
			h.add_int(gamble_wins)
			h.add_int(gamble_fail_tick)
	if shop.present():  # Only floors with a shop.
		shop.hash_into(h)
	Events.hash_into(self, h)  # Only worlds with events or curses.
	if catch_up_table != null:  # Only worlds whose loadout has the hidden catch-up.
		catch_up.hash_into(h)
	if spawner != null and spawner.intensity != null:  # Only worlds whose spawner has the director
		intensity.hash_into(h)
	if not starbound.is_empty():  # Only once a Starbound card was taken (loop 2+)
		Starbound.hash_into(self, h)
	if Spells.touched(self):  # Only once a spell was taken
		Spells.hash_into(self, h)
	if not pairs_seen.is_empty():  # Only once a duo fired
		h.add_ints(pairs_seen)
	if not surge_at.is_empty():  # Only once a floor's surges were planned
		h.add_ints(surge_at)
		h.add_ints(surge_sizes)
		h.add_int(surge_next)
		h.add_int(surge_t)
		h.add_int(surge_spawned)
	if not deep_elite_rooms.is_empty():  # Only once a Deep room brought its elite.
		h.add_ints(deep_elite_rooms)
	if boss_flow != null:  # Run flow: only floors with a boss room carry it.
		boss_flow.hash_into(h)
		# v0.9.0 TD fix: FA's approach block had split these off the boss flow's (normal floors stopped hashing them)
		for v in [floor_index, floor_count]:
			h.add_int(v)
		if loop > 1:  # Only past the first loop, so every loop-1 floor hashes as before
			for v in [loop, run_floor, loop_threat, loop_cap_permille]:
				h.add_int(v)
			if not loop_rules.is_empty():  # Only once a loop drew a rule
				h.add_ints(loop_rules)
				h.add_int(loop_shield_permille)
				h.add_int(loop_shield_half_arc)
	Constellations.hash_into(self, h)  # Only once a Constellation is held or offered
	if approach != null:  # Only the final approach carries it
		approach.hash_into(h)
	if not interactables.is_empty():  # Only worlds holding an interactable or a calm room
		interactables.hash_into(h)
	if not solids.is_empty():  # Only floors holding a solid prop
		solids.hash_into(h)
	if timed != null:  # Only floors with a timed door
		timed.hash_into(h)
	if runes != null:  # Only floors with a rune puzzle
		runes.hash_into(h)
	if breakables != null:  # Only floors with destructibles
		breakables.hash_into(h)
	if heart != null:  # Only the final approach of a profile with all ten lines
		heart.hash_into(h)
	if not relics.is_empty():  # Only once a relic was taken
		Relics.hash_into(self, h)
	if purple != null:  # Only floors with a purple-rune room
		purple.hash_into(h)
	if lockdown != null:  # Only floors with a Lockdown
		lockdown.hash_into(h)
	if shrine != null:  # v0.9.0 SH, HF: only floors with a Blood or Chaos shrine or a fountain
		shrine.hash_into(h)
	if elites != null:  # Only floors that had an elite
		elites.hash_into(h)
	if affinity != null:  # Only runs with an affinity (None: null)
		affinity.hash_into(h)
	if not locked_items.is_empty():  # Only runs with a card still locked (none: hashed as before)
		h.add_ints(locked_items)
	if collect != null:  # Only floors armed with a collectible
		collect.hash_into(h)
	if stress != null:  # Only runs that held the Stress Mark
		stress.hash_into(h)
	if final_fight != null:  # Only the worlds that hold the final fight
		final_fight.hash_into(h)
	actors.hash_into(h)
	projectiles.hash_into(h)
	h.add_int(walls.size())
	for w in walls:
		h.add_f32(w.center.x)
		h.add_f32(w.center.y)
		h.add_f32(w.half.x)
		h.add_f32(w.half.y)
		h.add_int(w.angle)
	return h.finish_hex()


## Engines and combos, in a fixed order. Only worlds whose loadout has items hash them: their fields
## stay at their defaults otherwise, and leaving them out keeps the item-free goldens' hashes.
func _hash_engines(h: StateHasher) -> void:
	h.add_ints(combos_owned)
	for v in [
		guard_charges, swing_charges, engine_bolt_hits, 1 if echo_overcharged else 0, echo_wave
	]:
		h.add_int(v)
	h.add_int(slipstream_next)
	proc_ledger.hash_into(h)
	actors.hash_statuses(h)
	for v in [discharge_tick, plasma_tick, shatter_tick, burst_tick, wildfire_tick, harvest_tick]:
		h.add_int(v)
	for v in [resonance_tick, shrapnel_tick, spiked_tick, slipstream_tick, bastion_tick]:
		h.add_int(v)
	for p: Vector2 in [
		discharge_from, plasma_from, plasma_to, shatter_pos, burst_pos, wildfire_pos
	]:
		h.add_f32(p.x)
		h.add_f32(p.y)
	h.add_f32(harvest_pos.x)
	h.add_f32(harvest_pos.y)
	h.add_int(discharge_to.size())
	for p in discharge_to:
		h.add_f32(p.x)
		h.add_f32(p.y)


## The canonical snapshot of the whole world (WorldSnapshot), for saves; restore it with from_snapshot.
func to_snapshot() -> Dictionary:
	return WorldSnapshot.take(self)


## Writes `snap` into `base`, a world built from the same generation inputs (seed, floor, build, content); returns
## it, or null when the snapshot doesn't fit (WorldSnapshot.apply says why).
static func from_snapshot(snap: Dictionary, base: World) -> World:
	return base if WorldSnapshot.apply(base, snap) == "" else null


## Plain-data copy for inspectors and desync diffs; never used for gameplay.
func snapshot() -> Dictionary:
	return {
		"tick": tick,
		"freeze_ticks": freeze_ticks,
		"next_id": _next_id,
		"event_seq": _event_seq,
		"rng": [rng_map.state, rng_loot.state, rng_combat.state, rng_ai.state],
		"player":
		{"aim": aim_angle, "dash_ticks_left": dash_ticks_left, "dash_cd": dash_cooldown_left},
		"actors": {"ids": actors.ids, "x": actors.pos_x, "y": actors.pos_y, "hp": actors.hp},
		"projectiles": {"ids": projectiles.ids, "x": projectiles.pos_x, "y": projectiles.pos_y},
	}


## A fresh entity id (actors, projectiles, v0.4.0 TU: heal orbs). Entity ids and chain roots share one counter.
func take_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


## A fresh root id for a new chain (a player action or an enemy attack): an id from the same counter.
func take_root() -> int:
	return take_id()


func emit_event(kind: SimEvent.Kind, source: int, owner: int, target: int, at: Vector2) -> SimEvent:
	_event_seq += 1
	var e := SimEvent.new()
	e.seq = _event_seq
	e.tick = tick
	e.kind = kind
	e.root_id = source
	e.source_id = source
	e.owner_id = owner
	e.target_id = target
	e.pos = at
	_events.append(e)
	# Trimmed EVENT_LOG_TRIM at a time (was EVENT_LOG_CAP at once: freeing that many events in one
	# tick was a ~10 ms hitch in a horde).
	if _events.size() > EVENT_LOG_CAP + EVENT_LOG_TRIM:
		_events = _events.slice(_events.size() - EVENT_LOG_CAP)
	return e


func _age_buffer() -> void:
	for i in input_buffer.size():
		if input_buffer[i] > 0:
			input_buffer[i] -= 1
	PlayerSkill.age(self)  # Kit


func _buffer_presses(pressed: int) -> void:
	for i in BUTTON_BITS.size():
		if pressed & BUTTON_BITS[i]:
			input_buffer[i] = SimTick.INPUT_BUFFER_TICKS
	PlayerSkill.buffer(self, pressed)  # Kit


func _run_ai() -> void:
	var target := player_pos()
	var pp := phase_probe  # v0.8.0 HS
	if not enemy_tables.is_empty():  # The grid the enemies' staggered plans query (EnemyAi.plan)
		if pp != null:
			pp.begin(&"ai.grid")
		_actor_grid.build_circles(actors.pos_x, actors.pos_y, actors.radius)
		if pp != null:
			pp.end(&"ai.grid")
	if (native_on & NativeWorld.AI) != 0 and NativeAi.think(self):  # The table kinds think native
		return
	var critter_rows := PackedInt32Array()  # The critters think in one loop after the others (CritterAi)
	var roles := EnemyAi.roles  # One table read per actor (EnemyAi.role_of; a local: a static read costs more)
	for i in range(1, actors.size()):
		var kind := actors.kinds[i]
		var role := roles[kind] if (kind & -EnemyAi.KIND_SLOTS) == 0 else EnemyAi.role_of(kind)
		if role == EnemyAi.Role.CRITTER:
			critter_rows.append(i)
			continue
		if role == EnemyAi.Role.BOSS:
			BossAi.think(self, i)  # Bosses.
			continue
		if role == EnemyAi.Role.ENEMY:
			EnemyAi.think(self, i)  # (its plan is timed as ai.plan inside)
			continue
		if kind == ActorStore.Kind.DUMMY:
			dummy_think(i, target)
	if not critter_rows.is_empty():
		CritterAi.think_all(self, critter_rows)


## Phase 3 for dummy i (the kernel's movers): its jitter, and its shot at `target` on its fire period.
func dummy_think(i: int, target: Vector2) -> void:
	var id := actors.ids[i]
	if (tick + id) % SimTick.AI_HEAVY_PERIOD == 0:
		actors.jitter_x[i] = rng_ai.range_int(-300, 300) / 100.0
		actors.jitter_y[i] = rng_ai.range_int(-300, 300) / 100.0
	if dummy_fire_period <= 0:
		return
	actors.fire_cd[i] -= 1
	if actors.fire_cd[i] > 0:
		return
	actors.fire_cd[i] = dummy_fire_period
	var from := actors.pos(i)
	var shot_angle := Kin.angle_of(target - from)
	if dummy_aim_spread > 0:
		shot_angle += rng_ai.range_int(-dummy_aim_spread, dummy_aim_spread)
	var dir := Kin.dir(shot_angle)
	var muzzle := from + dir * (actors.radius[i] + projectile_radius + 0.05)
	queue_projectile(
		id,
		ActorStore.TEAM_ENEMY,
		muzzle,
		dir * projectile_speed,
		dummy_shot_damage,
		projectile_radius,
		projectile_life,
		SimEvent.TAG_PROJECTILE
	)


func _advance_actions() -> void:
	for i in actors.size():
		if actors.invuln[i] > 0:
			actors.invuln[i] -= 1
	if player_dead():
		dash_ticks_left = 0
		swing_t = 0
		shot_cd = 0
		return
	Curses.advance(self)  # Brittle's stun runs down
	PlayerKit.advance_utility(self)
	PlayerKit.advance(self)
	PlayerSkill.advance(self)  # Kit: Vent, and the build's skill.
	if dash_cooldown_left > 0:
		dash_cooldown_left -= 1
	if dash_ticks_left > 0:
		dash_ticks_left -= 1
		if dash_ticks_left == 0:
			ItemProcs.on_dash_end(self)  # Items: Momentum.
			ModifierRuntime.on_dash_end(self)  # The dash spec's ON_END hooks (Phase Dash)
		return
	if input_buffer[DASH_SLOT] > 0 and (Curses.no_dash(self) or Curses.stunned(self)):
		input_buffer[DASH_SLOT] = 0  # Rooted (no dash), Brittle (stunned)
	if input_buffer[DASH_SLOT] > 0 and dash_cooldown_left == 0 and not PlayerSkill.busy(self):
		input_buffer[DASH_SLOT] = 0
		PlayerKit.cancel_recovery(self)  # A dash ends the swing's recovery
		dash_dir = PlayerKit.move_or_aim(self)
		dash_root = 0  # Items: a new dash may hit every enemy once again.
		dash_hit_ids = PackedInt32Array()
		dash_ticks_left = player.dash_ticks
		dash_cooldown_left = ItemProcs.dash_cooldown_ticks(self)  # Items: Swift Feet.
		ModifierRuntime.on_dash_start(self)  # The dash spec's ON_LAUNCH hooks (Long Shadow)


func _move_and_collide() -> void:
	# Player.
	var p := player_pos()
	var hero_from := p  # Where the hero began the tick (RuinsRocks.block_hero)
	var kick := Lance.recoil(self)  # The Lance's push back, spent each tick (walls resolve it below)
	if player_dead():
		vel = Vector2.ZERO
	elif dash_ticks_left > 0:
		p += dash_dir * (player.dash_distance_m / player.dash_ticks)
	elif PlayerSkill.moving(self):  # Kit: the lunge, or the blast's step back
		vel = Vector2.ZERO
		p += PlayerSkill.move_step(self)
	else:
		var target := Vector2.ZERO
		if move_intent != Vector2i.ZERO:
			var mv := Vector2(move_intent.x, move_intent.y) / float(SimTick.MOVE_MAX)
			var len := Kin.length(mv)
			if len > 1.0:
				mv /= len
			var speed := ItemProcs.move_speed(self) * Heat.move_factor(self)  # Swift Feet; the overheat stall.
			speed *= Curses.move_factor(self)  # Brittle (the stun, + move speed)
			speed *= Laser.move_factor(self)  # 75 % while the beam fires
			speed *= BossHazard.move_factor(self)  # Venom and fallen rock drag at the hero
			if guarding():
				speed = speed * player.guard_move_permille / 1000.0
			target = mv * speed
		var on_patch := ice != null and ice.covers(p)
		if on_patch and ice.speed_permille != 1000:  # Starfall's starglow speeds the hero's step
			target = target * (ice.speed_permille / 1000.0)
		var k := (
			player.accel_permille if Kin.length(target) > Kin.length(vel) else player.decel_permille
		)
		if on_patch:  # On ice the hero speeds up and stops slowly (NB2: starglow drifts a little)
			k = ice.accel_permille if Kin.length(target) > Kin.length(vel) else ice.decel_permille
		if variants.trail_count() > 0:  # A Frost Charger's slick: the hero slides (keeps its speed)
			var slick := Variants.slick_at(self, p)
			if slick > 0:
				k = mini(k, slick)
			var rubble := Variants.rubble_at(self, p)  # the Rubble Warden's fallen crust: ×patch_slow_permille
			if rubble > 0:
				target = target * (rubble / 1000.0)
		vel += (target - vel) * (k / 1000.0)
		if Kin.length(vel - target) < 0.0001:
			vel = target
		p += vel + PlayerKit.lunge_offset(self)  # a combo step's forward step
		p += kick
	actors.set_pos(0, p)
	var pp := phase_probe  # v0.8.0 HS
	if pp != null:
		pp.begin(&"move.steer")
	if (native_on & NativeWorld.AI) == 0 or not NativeAi.move(self):  # The table kinds steer native
		_steer_actors(p)
	PlayerSkill.push(self)  # Kit: Scatter Blast knockback, before walls resolve it.
	if pp != null:
		pp.end(&"move.steer")
		pp.begin(&"move.walls")
	# Resolve: walls first, then actor pairs in ascending index order. A boss in the air or underground passes
	# through both; a boss on the ground isn't shoved: the other body takes the whole push.
	var through := PackedInt32Array()
	var heavy := PackedInt32Array()
	# A waiting Rock Lurker passes through its own boulder (a wall: RuinsRocks.hidden), and so is not shoved
	if not bosses.ids.is_empty() or ruins_rocks.hide_count() > 0:
		for i in actors.size():
			through.append(1 if BossAi.passes_through(self, i) or RuinsRocks.hidden(self, i) else 0)
			heavy.append(1 if BossAi.is_boss_kind(actors.kinds[i]) else 0)
	if (native_on & NativeWorld.MOVE) != 0:
		NativeMove.resolve(self, through, heavy)
	else:
		_resolve_bodies(through, heavy)
	if ruins_rocks.cable_count() > 0:  # A live cable is a wall to the hero alone
		RuinsRocks.block_hero(self, hero_from)
	if pp != null:
		pp.end(&"move.walls")


## Phase 5's steering in GDScript: every actor but the hero, toward the hero at `target`.
func _steer_actors(target: Vector2) -> void:
	var critter_rows := PackedInt32Array()  # The critters step in one loop after the others (CritterAi)
	var roles := EnemyAi.roles  # One table read per actor (EnemyAi.role_of; a local: a static read costs more)
	for i in range(1, actors.size()):
		var kind := actors.kinds[i]
		var role := roles[kind] if (kind & -EnemyAi.KIND_SLOTS) == 0 else EnemyAi.role_of(kind)
		if role == EnemyAi.Role.CRITTER:
			critter_rows.append(i)
			continue
		if role == EnemyAi.Role.BOSS:
			BossAi.move(self, i)  # Bosses.
			continue
		if role == EnemyAi.Role.ENEMY:
			EnemyAi.move(self, i)
			continue
		dummy_steer(i, target)
	if not critter_rows.is_empty():
		CritterAi.move_all(self, critter_rows)


## Phase 5 for dummy i: toward `target` plus its jitter (kept dummy_keep_distance off it), at most dummy_speed.
func dummy_steer(i: int, target: Vector2) -> void:
	var at := actors.pos(i)
	var goal := target + Vector2(actors.jitter_x[i], actors.jitter_y[i])
	if dummy_keep_distance > 0.0:
		var away := at - target
		var away_len := Kin.length(away)
		if away_len > 0.0:
			goal += away * (dummy_keep_distance / away_len)
	var to := goal - at
	var dist := Kin.length(to)
	if dist > dummy_speed:
		at += to * (dummy_speed / dist)
	actors.set_pos(i, at)


## The collision passes in GDScript (walls, grid and pairs; NativeMove runs the native ones instead).
func _resolve_bodies(through: PackedInt32Array, heavy: PackedInt32Array) -> void:
	var pp := phase_probe
	# A body with no wall within WALL_SKIP_M of it skips the wall checks while it stays within that of
	# where it was looked at (walls that far off give no push, so the result is the same).
	var open_x := PackedFloat32Array()
	var open_y := PackedFloat32Array()
	var n := actors.size()
	open_x.resize(n)
	open_y.resize(n)
	# The wall passes read and write local copies of the columns (handed back after each pass), as the pairs pass does.
	var px := actors.pos_x
	var py := actors.pos_y
	var rad := actors.radius
	var no_solids := solids.is_empty()
	for i in n:
		var r := rad[i] + WALL_SKIP_M
		open_x[i] = INF
		var box := Rect2(px[i] - r, py[i] - r, r * 2.0, r * 2.0)
		if not _wall_grid.any_in_rect(box) and (no_solids or not solids.any_near(box)):  # No list built
			open_x[i] = px[i]
			open_y[i] = py[i]
	for _iter in SimTick.COLLIDE_ITERS:
		px = actors.pos_x
		py = actors.pos_y
		for i in n:
			if not through.is_empty() and through[i] == 1:
				continue
			if absf(px[i] - open_x[i]) < WALL_SKIP_M and absf(py[i] - open_y[i]) < WALL_SKIP_M:
				continue
			var ap := Vector2(px[i], py[i])
			var r := rad[i]
			for w in _wall_grid.query_rect(Rect2(ap.x - r, ap.y - r, r * 2.0, r * 2.0)):
				ap += Collide.circle_vs_obb(ap, r, walls[w])
			if not no_solids:  # Solid props block bodies, not shots or sight
				ap += solids.push(ap, r)
			px[i] = ap.x
			py[i] = ap.y
		actors.pos_x = px
		actors.pos_y = py
		if pp != null:
			pp.end(&"move.walls")
			pp.begin(&"move.grid")
		_actor_grid.build_circles(actors.pos_x, actors.pos_y, actors.radius)
		if pp != null:
			pp.end(&"move.grid")
			pp.begin(&"move.pairs")
		var ghost := dash_ticks_left > 0 and ModifierRuntime.intangible(self)  # Phase Dash
		# The pass works on local copies of the position columns (one native copy on the first push,
		# handed back after; an actor-store lookup per read was most of its cost) and starts each body's candidates
		# past its own index (bsearch: the grid's list is ascending), with the same arithmetic in the same order.
		px = actors.pos_x
		py = actors.pos_y
		for a in n:
			if ghost and a == 0:
				continue
			var ra := rad[a]
			var near := _actor_grid.query_rect(Rect2(px[a] - ra, py[a] - ra, ra * 2.0, ra * 2.0))
			for q in range(near.bsearch(a + 1), near.size()):
				var b := near[q]
				# Bodies whose boxes are clearly apart get no push; skip the call (the margin covers
				# rounding, so the result is the same).
				var rb := rad[b]
				var reach := ra + rb + 0.001
				if absf(px[b] - px[a]) >= reach or absf(py[b] - py[a]) >= reach:
					continue
				# The circle-circle push, applied half to each (a gets it, b its negation; coincident centres part
				# along x). Inlined here for speed; test_collision drives it through this pass.
				var d := Vector2(px[a], py[a]) - Vector2(px[b], py[b])
				var rr := ra + rb
				var dist2 := float(d.x) * d.x + float(d.y) * d.y
				if dist2 >= rr * rr:
					continue
				var push := Vector2(rr * 0.5, 0.0)
				if dist2 != 0.0:
					var dist := sqrt(dist2)
					push = d * ((rr - dist) * 0.5 / dist)
				if not through.is_empty():
					if through[a] == 1 or through[b] == 1:
						continue
					if heavy[a] != heavy[b]:
						actors.pos_x = px  # _shove reads and writes the store: hand the columns back first
						actors.pos_y = py
						if heavy[a] == 1:
							_shove(b, -push * 2.0)
						else:
							_shove(a, push * 2.0)
						px = actors.pos_x
						py = actors.pos_y
						continue
				var na := Vector2(px[a], py[a]) + push
				px[a] = na.x
				py[a] = na.y
				var nb := Vector2(px[b], py[b]) - push
				px[b] = nb.x
				py[b] = nb.y
		actors.pos_x = px
		actors.pos_y = py
		if pp != null:
			pp.end(&"move.pairs")
			pp.begin(&"move.walls")


## A boss's shove moves body i by `delta` only as far as the first wall on the way (its radius swept), so a
## boss landing beside a body at a wall can't push it through the wall (the faster Colossus leap found it: a hero in
## the final ring was shoved out of it). The pass's other pushes are unchanged.
func _shove(i: int, delta: Vector2) -> void:
	var a := actors.pos(i)
	var b := a + delta
	var r := actors.radius[i]
	var t := 1.0
	for w in _wall_grid.query_rect(Rect2(a, Vector2.ZERO).expand(b).grow(r)):
		var hit := Collide.sweep_vs_obb(a, b, r, walls[w])
		if hit >= 0.0 and hit < t:
			t = hit
	actors.set_pos(i, a + delta * t)


func _projectile_hits() -> void:
	_hit_grid_state = 0 if debug_aoe_full else 1  # aoe_candidates may build its grid from here on
	if (native_on & NativeWorld.SHOTS) != 0:
		NativeShots.sweep(self)
		_hit_grid_state = 0
		return
	var dead := PackedInt32Array()
	var pp := phase_probe  # v0.8.0 HS
	var pull := StarfallKinds.nodes(self) if not enemy_tables.is_empty() else PackedFloat32Array()
	for i in projectiles.size():
		if pp != null:
			pp.begin(&"proj.sweep")
		var held := ProjectileMoves.steer(self, i)  # Orbit first, homing, the way back
		if not pull.is_empty() and not held:  # A Gravity Node bends it (after its form's steering)
			StarfallKinds.bend_projectile(self, i, pull)
		if GlaiveMods.hold(self, i):  # A Mine disc spins in place (no sweep), hitting
			if pp != null:
				pp.end(&"proj.sweep")
			continue
		var a := Vector2(projectiles.pos_x[i], projectiles.pos_y[i])
		var v := Vector2(projectiles.vel_x[i], projectiles.vel_y[i])
		var b := a + v
		var r := projectiles.radius[i]
		# Walls and actors are inserted with their full extent, so the segment only grows by its own radius.
		var span := Rect2(a, Vector2.ZERO).expand(b).grow(r)
		var best_t := 2.0
		var best_actor := -1
		var best_wall := -1
		for w in _wall_grid.query_rect(span):
			var t := Collide.sweep_vs_obb(a, b, r, walls[w])
			if t >= 0.0 and t < best_t:
				best_t = t
				best_wall = w
		# A Void shot passes through bodies (its aura hurts them, VoidShots); only walls end it.
		# So does a Wave shot (its band hits them, WaveShots).
		var bodies := (
			PackedInt32Array()
			if VoidShots.is_void_projectile(self, i) or WaveShots.is_wave_projectile(self, i)
			else _actor_grid.query_rect(span)
		)
		for k in bodies:
			if actors.teams[k] == projectiles.team[i] or actors.dead[k] == 1:
				continue
			# A body clearly outside the segment's box can't be hit; skip the sweep (same result).
			var reach := actors.radius[k] + 0.001
			if (
				actors.pos_x[k] + reach < span.position.x
				or actors.pos_x[k] - reach > span.end.x
				or actors.pos_y[k] + reach < span.position.y
				or actors.pos_y[k] - reach > span.end.y
			):
				continue
			var t := Collide.sweep_vs_circle(a, b, r, actors.pos(k), actors.radius[k])
			# A tie keeps the earlier find: the wall, else the lower actor index (the grid returns them ascending).
			if t >= 0.0 and t < best_t:
				best_t = t
				best_actor = k
		if pp != null:
			pp.end(&"proj.sweep")
		if ProjectileContacts.apply(self, i, a, v, best_t, best_actor, best_wall):
			dead.append(i)
	_hit_grid_state = 0
	if pp != null:
		pp.begin(&"proj.remove")
	projectiles.remove_sorted(dead)
	if pp != null:
		pp.end(&"proj.remove")


func _remove_dead() -> void:
	var gone := PackedInt32Array()
	for i in range(1, actors.size()):
		if actors.dead[i] == 1:
			gone.append(i)
			if (
				actors.state[i] == BossSignatures.EGG_GONE
				and EnemyAi.is_enemy_kind(actors.kinds[i])
			):
				continue  # An egg that burst or crumbled leaves without a kill
			if BossTwin.leaves(self, i):
				continue  # A Warden's twin goes with its boss: one defeat, one kill, one reward
			if RuinsRocks.leaves(self, i):
				continue  # A Wire Weaver's post breaks or drops: no kill, no shards
			if EnemyAi.is_enemy_kind(actors.kinds[i]):
				kills += 1
				EnemyAi.on_death(self, i)  # A Splitter splits.
				Intensity.on_death(self, i)  # A kill beside the hero raises intensity
			var b := bosses.index_of(actors.ids[i])
			if b >= 0:  # Bosses: defeated, once, as it leaves.
				var e := emit_event(
					SimEvent.Kind.BOSS_DEFEATED,
					actors.ids[i],
					actors.ids[i],
					actors.ids[i],
					actors.pos(i)
				)
				e.amount = bosses.table[b]
				bosses.remove(b)
				BossSignatures.on_boss_gone(self, actors.ids[i])  # Its pillars and javelins go
				if boss_id == actors.ids[i]:
					boss_id = -1
			Rewards.on_kill(self, i)  # Rewards: shards.
			CoreTheft.on_death(self, i)  # A boss's core stolen in its window
			if EliteAi.is_elite_kind(actors.kinds[i]):
				Elites.on_death(self, i)  # 30 % its core's card
	actors.remove_sorted(gone)


func _apply_spawns() -> void:
	for s in _pending_projectiles:
		var id := take_id()
		projectiles.add(id, s[0], s[1], s[2], s[3], s[5], s[6], s[4], s[7], s[8])
		projectiles.spec_key[projectiles.size() - 1] = s[9]  # v0.6.0 MX2
		if s[10] != &"":  # A fireball's look (BulletPatterns)
			projectiles.set_look(projectiles.size() - 1, s[10])
		if s[11] >= 0:  # The boss attack that fired it
			projectiles.set_cause(projectiles.size() - 1, s[11])
		if s[12] != 0:  # A secondary bolt or a repeat's
			projectiles.set_second(projectiles.size() - 1, s[12])
		ProjectileMoves.on_spawn(self, projectiles.size() - 1, s[14])  # v0.6.0 MX4
		VoidMods.on_spawn(self, projectiles.size() - 1)  # A void with cards gets its row
		LanceMods.on_spawn(self, projectiles.size() - 1)  # A lance with cards gets its row
		GlaiveMods.on_spawn(self, projectiles.size() - 1)  # A disc with cards gets its row
		WaveMods.on_spawn(self, projectiles.size() - 1)  # A wave with cards gets its row
		SeekerMods.on_spawn(self, projectiles.size() - 1, s[15])  # A dart with cards gets its row
		emit_event(SimEvent.Kind.SPAWN, id, s[0], id, s[2])
		if s[13] != "":  # Threadline links it to the bolt before
			Remnants.on_link(self, projectiles.size() - 1, s[13])
	_pending_projectiles.clear()
	VoidMods.cull(self)  # At most so many voids a hero
	GlaiveMods.cull(self)  # And so many discs
	WaveMods.cull(self)  # And so many waves
	SeekerMods.cull(self)  # And so many darts
	WispMods.cull(self)  # And so many wisp mines
	for s in _pending_enemies:  # Bosses: eggs and turrets.
		if enemy_table(s[0]) != null:
			add_enemy(s[0], s[1])
			SpawnDirector.scale_arrival(self, actors.size() - 1, run_ticks)  # Tier scaling too
			if s.size() > 2:  # An egg
				BossSignatures.make_egg(self, actors.size() - 1, s[2])
	_pending_enemies.clear()

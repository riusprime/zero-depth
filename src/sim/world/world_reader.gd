# gdlint: disable=max-public-methods, max-file-lines
class_name WorldReader
extends RefCounted
## The read-only face of World for presentation (EI-07). Presentation may name WorldReader, never World.
## It is a wide facade on purpose: one read method per thing a view needs.

const KIND_PLAYER := ActorStore.Kind.PLAYER
const KIND_CHARGER := ActorStore.Kind.CHARGER
const KIND_WARDEN := ActorStore.Kind.WARDEN
const KIND_NEEDLE := ActorStore.Kind.NEEDLE
## Bosses and the Brood Mother's hatchlings (v0.3.0 C).
const KIND_HATCHLING := ActorStore.Kind.HATCHLING
const KIND_GATEKEEPER := ActorStore.Kind.GATEKEEPER
const KIND_BROOD_MOTHER := ActorStore.Kind.BROOD_MOTHER
const KIND_SIEGE_ENGINE := ActorStore.Kind.SIEGE_ENGINE
## v0.3.5 AI: the Arc Caster and the Bomb Drone.
const KIND_ARC_CASTER := ActorStore.Kind.ARC_CASTER
const KIND_BOMB_DRONE := ActorStore.Kind.BOMB_DRONE
## v0.4.0 EN: the horde kinds (a Splitter splits into Splitlings).
const KIND_SWARMER := ActorStore.Kind.SWARMER
const KIND_SPLITTER := ActorStore.Kind.SPLITTER
const KIND_SPLITLING := ActorStore.Kind.SPLITLING
const KIND_SHIELD_BEARER := ActorStore.Kind.SHIELD_BEARER
const KIND_MENDER := ActorStore.Kind.MENDER
const KIND_MINE_LAYER := ActorStore.Kind.MINE_LAYER
const KIND_SNIPER := ActorStore.Kind.SNIPER
## v0.4.0 BO: the second boss of each pool, and the Hive Lens's drones.
const KIND_WARLORD := ActorStore.Kind.WARLORD
const KIND_HIVE_LENS := ActorStore.Kind.HIVE_LENS
const KIND_FOUNDRY := ActorStore.Kind.FOUNDRY
const KIND_LENS_DRONE := ActorStore.Kind.LENS_DRONE
## How a melee combo step moves the blade (SwingStep.Motion; swing_motion()).
const MOTION_SLASH_RIGHT_TO_LEFT := SwingStep.Motion.SLASH_RIGHT_TO_LEFT
const MOTION_SLASH_LEFT_TO_RIGHT := SwingStep.Motion.SLASH_LEFT_TO_RIGHT
const MOTION_THRUST := SwingStep.Motion.THRUST
const MOTION_SPIN := SwingStep.Motion.SPIN
## Item kinds, for views (presentation may not name ItemTable).
const ITEM_LONG_EDGE := ItemTable.Kind.LONG_EDGE
const ITEM_TWIN_ARC := ItemTable.Kind.TWIN_ARC
const ITEM_EMBER_EDGE := ItemTable.Kind.EMBER_EDGE
const ITEM_SPLINTER_SHOT := ItemTable.Kind.SPLINTER_SHOT
const ITEM_RAPID_COIL := ItemTable.Kind.RAPID_COIL
const ITEM_RICOCHET_CORE := ItemTable.Kind.RICOCHET_CORE
const ITEM_KINETIC_DASH := ItemTable.Kind.KINETIC_DASH
const ITEM_OVERCHARGE := ItemTable.Kind.OVERCHARGE
const ITEM_VAMPIRIC_CORE := ItemTable.Kind.VAMPIRIC_CORE
const ITEM_STATIC_CHAIN := ItemTable.Kind.STATIC_CHAIN
const ITEM_MOMENTUM := ItemTable.Kind.MOMENTUM
const ITEM_FROST_CORE := ItemTable.Kind.FROST_CORE
const ITEM_THORN_MANTLE := ItemTable.Kind.THORN_MANTLE
const ITEM_EXECUTIONER := ItemTable.Kind.EXECUTIONER
const ITEM_SWIFT_FEET := ItemTable.Kind.SWIFT_FEET
const ITEM_PHASE_STRIKE := ItemTable.Kind.PHASE_STRIKE
const ITEM_CINDER_SHOT := ItemTable.Kind.CINDER_SHOT
const ITEM_WILDFIRE := ItemTable.Kind.WILDFIRE
const ITEM_CONDUCTOR := ItemTable.Kind.CONDUCTOR
const ITEM_SERRATED_EDGE := ItemTable.Kind.SERRATED_EDGE
const ITEM_BARBED_BOLTS := ItemTable.Kind.BARBED_BOLTS
const ITEM_GLACIAL_EDGE := ItemTable.Kind.GLACIAL_EDGE
const ITEM_COLD_SNAP := ItemTable.Kind.COLD_SNAP
const ITEM_BULWARK := ItemTable.Kind.BULWARK
## Enemy AI states, for actor_state() (presentation animates from them; EnemyAi.State is the source).
const STATE_SPAWN := EnemyAi.State.SPAWN
const STATE_MOVE := EnemyAi.State.MOVE
const STATE_WINDUP := EnemyAi.State.WINDUP
const STATE_ACTIVE := EnemyAi.State.ACTIVE
const STATE_RECOVER := EnemyAi.State.RECOVER
## The Arc Caster's spells (v0.3.5 AI; EnemyAi.Spell), for actor_spell().
const SPELL_BOLT := EnemyAi.Spell.BOLT
const SPELL_SPREAD := EnemyAi.Spell.SPREAD
const SPELL_RUNE := EnemyAi.Spell.RUNE
## Run flow (v0.3.0 B): boss flow states, for views (BossFlow.State is the source).
const BOSS_WAITING := BossFlow.State.WAITING
const BOSS_FIGHT := BossFlow.State.FIGHT
const BOSS_OPEN := BossFlow.State.OPEN
const BOSS_EXITED := BossFlow.State.EXITED
const BOSS_ENTERING := BossFlow.State.ENTERING
## A boss knocked off balance by a full stagger meter (BossAi).
const STATE_STAGGERED := BossAi.STAGGERED
## Boss moves, for telegraph()["move"] and boss_move() (views pick an animation from them).
const MOVE_SLAM_RING := BossAttackTable.Move.SLAM_RING
const MOVE_LANES := BossAttackTable.Move.LANES
const MOVE_SWEEP := BossAttackTable.Move.SWEEP
const MOVE_CHARGE := BossAttackTable.Move.CHARGE
const MOVE_LEAP := BossAttackTable.Move.LEAP
const MOVE_BURROW := BossAttackTable.Move.BURROW
const MOVE_BROOD := BossAttackTable.Move.BROOD
const MOVE_BARRAGE := BossAttackTable.Move.BARRAGE
const MOVE_RAIL := BossAttackTable.Move.RAIL
const MOVE_BOLT_FAN := BossAttackTable.Move.BOLT_FAN
const MOVE_DEPLOY := BossAttackTable.Move.DEPLOY
## Boss challenge (v0.3.0 BX): the vortex that drags you in, then slams.
const MOVE_PULL := BossAttackTable.Move.PULL
## v0.4.0 BO: parallel lanes that stand while active (spears, molten floor).
const MOVE_FLOOD := BossAttackTable.Move.FLOOD
## Rewards (v0.3.0 E): reward kinds and item rarities, for views.
const REWARD_ALTAR := RewardStore.Kind.ALTAR
const REWARD_CHEST := RewardStore.Kind.CHEST
const RARITY_COMMON := ItemTable.COMMON
const RARITY_RARE := ItemTable.RARE
## Kit (v0.3.5 K): the build skills.
const SKILL_LUNGE_CLEAVE := SkillTable.Kind.LUNGE_CLEAVE
const SKILL_SCATTER_BLAST := SkillTable.Kind.SCATTER_BLAST
## Build (v0.4.0 BS): card types, ability kinds and buttons, slots and levels.
const CARD_MOD := Offers.MOD
const CARD_ABILITY := Offers.ABILITY
const CARD_STAT := Offers.STAT
const ABILITY_COMBO_SWORD := AbilityTable.Kind.COMBO_SWORD
const ABILITY_PULSE_GUN := AbilityTable.Kind.PULSE_GUN
const ABILITY_BOMB_LOBBER := AbilityTable.Kind.BOMB_LOBBER
const ABILITY_DRONE_BUDDY := AbilityTable.Kind.DRONE_BUDDY
const ABILITY_ORBIT_BLADES := AbilityTable.Kind.ORBIT_BLADES
const ABILITY_BLINK := AbilityTable.Kind.BLINK
const ABILITY_AEGIS := AbilityTable.Kind.AEGIS
const ABILITY_BUTTON_PRIMARY := AbilityTable.Binding.PRIMARY
const ABILITY_BUTTON_UTILITY := AbilityTable.Binding.UTILITY
const ABILITY_SLOTS := Abilities.SLOTS
const ABILITY_MAX_LEVEL := AbilityTable.MAX_LEVEL

var _w: World


func _init(world: World) -> void:
	_w = world


func tick() -> int:
	return _w.tick


func seed_value() -> int:
	return _w.seed_value


func player_pos() -> Vector2:
	return _w.player_pos()


func aim_angle() -> int:
	return _w.aim_angle


func is_dashing() -> bool:
	return _w.is_dashing()


func actor_count() -> int:
	return _w.actors.size()


func actor_pos(i: int) -> Vector2:
	return _w.actors.pos(i)


func actor_id(i: int) -> int:
	return _w.actors.ids[i]


func actor_team(i: int) -> int:
	return _w.actors.teams[i]


func actor_radius(i: int) -> float:
	return _w.actors.radius[i]


func actor_kind(i: int) -> int:
	return _w.actors.kinds[i]


func actor_hp(i: int) -> int:
	return _w.actors.hp[i]


func actor_max_hp(i: int) -> int:
	return _w.actors.max_hp[i]


func actor_dead(i: int) -> bool:
	return _w.actors.dead[i] == 1


func actor_facing(i: int) -> int:
	return _w.actors.facing[i]


func actor_invulnerable(i: int) -> bool:
	return _w.actors.invuln[i] > 0


func player_dead() -> bool:
	return _w.player_dead()


func swing_tick() -> int:
	return _w.swing_t


func swing_angle() -> int:
	return _w.swing_angle


func combo_step() -> int:
	return _w.combo_step


## The arc of combo step `step` (-1 = the current swing's), for drawing: [half_arc, reach_m, own_radius_m]. Same
## numbers PlayerKit hits with (EI-07).
func swing_shape(step: int = -1) -> Array:
	var s := _step_index(step)
	return [_w.player.combo[s].half_arc, swing_reach_m(s), _w.player.radius_m]


## The current swing's length in ticks (its step's).
func swing_ticks() -> int:
	return PlayerKit.current_step(_w).ticks


## The current swing's step: how the blade moves (SwingStep.Motion), how long it takes to cross the arc, the tick
## it hits on.
func swing_motion() -> int:
	return PlayerKit.current_step(_w).motion


func swing_sweep_ticks() -> int:
	return PlayerKit.current_step(_w).sweep_ticks


func swing_active_tick() -> int:
	return PlayerKit.current_step(_w).active_tick


## Steps in the melee combo, and whether step `step` (-1 = the current swing's) is its finisher.
func combo_length() -> int:
	return _w.player.combo.size()


func is_finisher(step: int = -1) -> bool:
	return PlayerKit.is_finisher(_w, _step_index(step))


func _step_index(step: int) -> int:
	return step if step >= 0 else _w.combo_step


func shooting() -> bool:
	return PlayerKit.shooting(_w)


func projectile_team(i: int) -> int:
	return _w.projectiles.team[i]


## v0.4.0 BS: the forced loadout's utility, or an owned Blink / Aegis ability (Abilities.utility).
func utility() -> int:
	return Abilities.utility(_w)


func has_guard() -> bool:
	return Abilities.utility(_w) == PlayerTable.Utility.GUARD


func has_blink() -> bool:
	return Abilities.utility(_w) == PlayerTable.Utility.BLINK


func guarding() -> bool:
	return _w.guarding()


## The guard's half arc, the same number Damage checks.
func guard_half_arc() -> int:
	return _w.player.guard_half_arc


func blink_cooldown() -> int:
	return _w.blink_cd


func blink_cooldown_total() -> int:
	return Abilities.blink_cooldown(_w)


func blink_tick() -> int:
	return _w.blink_tick


func blink_from() -> Vector2:
	return _w.blink_from


func dash_cooldown() -> int:
	return _w.dash_cooldown_left


## The dash cooldown's full length (Swift Feet applied: the same number the dash uses).
func dash_cooldown_total() -> int:
	return ItemProcs.dash_cooldown_ticks(_w)


func player_radius() -> float:
	return _w.player.radius_m


func actor_state(i: int) -> int:
	return _w.actors.state[i]


## True while the enemy is spawning in, dazed or recovering (presentation cues).
func actor_spawning(i: int) -> bool:
	return EnemyAi.is_enemy_kind(_w.actors.kinds[i]) and _w.actors.state[i] == EnemyAi.State.SPAWN


func actor_recovering(i: int) -> bool:
	return EnemyAi.is_enemy_kind(_w.actors.kinds[i]) and _w.actors.state[i] == EnemyAi.State.RECOVER


## The spell an Arc Caster is casting (v0.3.5 AI): SPELL_BOLT, SPELL_SPREAD or SPELL_RUNE (0 for other kinds).
func actor_spell(i: int) -> int:
	return _w.actors.pick[i]


## The enemy's telegraph, from the same function that resolves the attack (EI-07). {} when none.
func telegraph(i: int) -> Dictionary:
	return EnemyAi.telegraph(_w, i)


# --- Horde kinds (v0.4.0 EN) --------------------------------------------------------------------------------------
## The id of the ally a Mender is healing (its beam's far end), or -1.
func actor_heal_target(i: int) -> int:
	if _w.actors.kinds[i] != ActorStore.Kind.MENDER or _w.actors.pick[i] <= 0:
		return -1
	return _w.actors.pick[i]


## The actor index of an id, or -1 (a Mender's beam finds its patient with it).
func actor_index(id: int) -> int:
	return _w.actors.index_of(id)


## True for a priority target (the Mender): the view marks it.
func actor_priority(i: int) -> bool:
	return EnemyAi.is_priority(_w.actors.kinds[i])


## The line a Sniper shoots down (its telegraph's lane), for the shot's tracer.
func sniper_line(i: int) -> Obb:
	return EnemyAi.snipe_lane(_w, i)


func mine_count() -> int:
	return _w.mines.size()


func mine_id(k: int) -> int:
	return _w.mines.ids[k]


func mine_pos(k: int) -> Vector2:
	return _w.mines.pos(k)


func mine_radius(k: int) -> float:
	return _w.mines.radius[k]


## An armed mine's fuse, 0..1000 (the blast at 1000), or -1 while it lies idle.
func mine_fuse(k: int) -> int:
	var m := _w.mines
	return -1 if m.fuse[k] < 0 else clampi(m.fuse[k] * 1000 / maxi(1, m.fuse_total[k]), 0, 1000)


## A Warden's armour half-arcs (1/4096 turns either side of its facing): x = front, y = rear. (0, 0) for others.
func armour_half_arcs(i: int) -> Vector2i:
	if BossAi.is_boss_kind(_w.actors.kinds[i]):
		var bt := BossAi.table_of(_w, i)
		return Vector2i(bt.front_half_arc, bt.rear_half_arc)
	var t := _w.enemy_table(_w.actors.kinds[i])
	return Vector2i(t.front_half_arc, t.rear_half_arc) if t != null else Vector2i.ZERO


## 0 while fighting, 1 when the last wave is cleared (or the run's last portal taken), 2 when the player is dead,
## 3 when the portal of a floor before the last was taken (the app loads the next floor).
func outcome() -> int:
	if _w.boss_flow != null and _w.boss_flow.exited():
		return 1 if _w.floor_index >= _w.floor_count else 3
	if _w.player_dead():
		return 2
	return 1 if _w.cleared else 0


func wave_number() -> int:
	return _w.wave_index + 1


func wave_count() -> int:
	return _w.encounter.waves.size() if _w.encounter != null else 0


func enemies_alive() -> int:
	return WaveDirector.enemies_alive(_w)


## The kind that killed the player (-1 if unknown) and the hit's SimEvent tags.
func killer_kind() -> int:
	return _w.killer_kind


func killer_tags() -> int:
	return _w.killer_tags


func player_hp() -> int:
	return _w.actors.hp[0]


func player_max_hp() -> int:
	return _w.actors.max_hp[0]


func freeze_ticks() -> int:
	return _w.freeze_ticks


func projectile_count() -> int:
	return _w.projectiles.size()


func projectile_pos(i: int) -> Vector2:
	return Vector2(_w.projectiles.pos_x[i], _w.projectiles.pos_y[i])


func projectile_vel(i: int) -> Vector2:
	return Vector2(_w.projectiles.vel_x[i], _w.projectiles.vel_y[i])


func projectile_id(i: int) -> int:
	return _w.projectiles.ids[i]


func wall_count() -> int:
	return _w.walls.size()


func wall(i: int) -> Obb:
	return _w.walls[i]


func last_event_seq() -> int:
	return _w.last_event_seq()


func events_since(after_seq: int) -> Array[SimEvent]:
	return _w.events_since(after_seq)


func snapshot() -> Dictionary:
	return _w.snapshot()


func state_hash() -> String:
	return _w.state_hash()


## Run time in seconds (counts while the player lives; 0 without a spawn director).
func run_seconds() -> float:
	return float(_w.run_ticks) / SimTick.TICKS_PER_SECOND


## The spawn director's tier (0 without one).
func tier() -> int:
	return _w.spawner.tier_at(_w.run_ticks) if _w.spawner != null else 0


## Enemies killed this run.
func kills() -> int:
	return _w.kills


# --- Items (v0.2.0 E) ---------------------------------------------------------------------------------------
## Owned items in pickup order, as indices into the item tables (item_kind / item_name_key read them).
func items_owned() -> PackedInt32Array:
	return _w.items_owned


func item_count() -> int:
	return _w.items_owned.size()


func has_item_kind(kind: int) -> bool:
	return _w.item_mods.has(kind)


## Number of compiled items (valid item indices are 0..item_table_count() - 1).
func item_table_count() -> int:
	return _w.item_tables.size()


func item_kind(item_index: int) -> int:
	return _w.item_tables[item_index].kind


func item_id(item_index: int) -> StringName:
	return _w.item_tables[item_index].id


## Locale keys (tr() them in the view).
func item_name_key(item_index: int) -> StringName:
	return _w.item_tables[item_index].name_key


func item_desc_key(item_index: int) -> StringName:
	return _w.item_tables[item_index].desc_key


func pickup_count() -> int:
	return _w.pickups.size()


func pickup_pos(i: int) -> Vector2:
	return _w.pickups.pos(i)


## The item index a pickup holds.
func pickup_item(i: int) -> int:
	return _w.pickups.item[i]


func pickup_id(i: int) -> int:
	return _w.pickups.ids[i]


## Walking within this distance of a pickup takes it.
func pickup_radius_m() -> float:
	return ItemEffects.PICKUP_RADIUS_M


## Ember Edge burn stacks on actor i (0 = not burning).
func burn_stacks(actor_i: int) -> int:
	return _w.actors.burn_stacks[actor_i]


## The reach of combo step `step` (-1 = the current one) with Long Edge applied: the same number PlayerKit hits
## with (EI-07).
func swing_reach_m(step: int = -1) -> float:
	return ItemEffects.swing_reach_m(_w, _step_index(step))


## Overcharge: a press now would start the charged swing (the finisher, with the four-slash combo).
func overcharge_ready() -> bool:
	return ItemEffects.overcharge_ready(_w)


## Overcharge: the current swing is the charged one.
func swing_overcharged() -> bool:
	return _w.swing_t > 0 and _w.swing_overcharged


## The tick the last Overcharge shockwave fired (-1 = never), and its radius.
func overcharge_tick() -> int:
	return _w.overcharge_tick


func shockwave_radius_m() -> float:
	return _w.item_mods.shockwave_radius_m


## Twin Arc: an echo swing is pending, its angle and step, and the tick the last echo swung (-1 = never). The echo
## uses swing_shape(echo_step()) with this angle.
func echo_pending() -> bool:
	return _w.echo_t > 0


func echo_angle() -> int:
	return _w.echo_angle


func echo_step() -> int:
	return _w.echo_step


func echo_tick() -> int:
	return _w.echo_tick


## Kinetic Dash: the tick a dash last hit an enemy (-1 = never).
func dash_hit_tick() -> int:
	return _w.dash_hit_tick


## Ricochet Core: wall bounces a projectile has left, and the tick of its last bounce (-1 = none).
func projectile_bounces(i: int) -> int:
	return _w.projectiles.bounces[i]


func projectile_bounce_tick(i: int) -> int:
	return _w.projectiles.bounce_tick[i]


## Ticks between bolts while shooting (Rapid Coil applied).
func shot_period_ticks() -> int:
	return ItemEffects.shot_period_ticks(_w)


## The generated floor, for the stage and the gate (PLAN v0.2.0 F). False in the arena and kernel scenarios.
func has_floor() -> bool:
	return _w.floor_layout != null


func floor_bounds() -> Rect2:
	return _w.floor_layout.bounds if _w.floor_layout != null else Rect2()


## Room interiors of the generated floor (wall face to wall face), for the stage's ground.
func floor_room_count() -> int:
	return _w.floor_layout.rooms.size() if _w.floor_layout != null else 0


func floor_room(i: int) -> Rect2:
	return _w.floor_layout.rooms[i]


func portal_pos() -> Vector2:
	return _w.floor_layout.portal_pos if _w.floor_layout != null else Vector2.ZERO


func portal_angle() -> int:
	return _w.floor_layout.portal_angle if _w.floor_layout != null else 0


## True while the player stands in the clear square in front of the sealed gate.
func at_gate() -> bool:
	return _w.floor_layout != null and _w.floor_layout.portal_front().has_point(_w.player_pos())


## What a wall is, for drawing it: 0 a structural wall (the room edges and partitions), 1 a cover slab, 2 not drawn
## (the gate's footprint, which the gate itself shows). Without a floor: the first 4 walls are edges.
func wall_class(i: int) -> int:
	var f := _w.floor_layout
	if f == null:
		return 0 if i < 4 else 1
	if i < f.slab_first:
		return 0
	return 1 if i < f.walls.size() else 2


# --- Items, the second eight (v0.2.0 J) ---------------------------------------------------------------------
## Vampiric Core: the tick it last healed (-1 = never), and HP it can still heal in the current cap window.
func heal_tick() -> int:
	return _w.heal_tick


func heal_cap_left() -> int:
	return ItemProcs.heal_cap_left(_w)


## Static Chain: the tick of the last jump (-1 = never), its ends, and whether the next landed bolt chains.
func chain_tick() -> int:
	return _w.chain_tick


func chain_from() -> Vector2:
	return _w.chain_from


func chain_to() -> Vector2:
	return _w.chain_to


func chain_ready() -> bool:
	return ItemProcs.chain_ready(_w)


## Momentum: an empowered swing is waiting, and the current swing is empowered.
func momentum_ready() -> bool:
	return _w.momentum_t > 0


func swing_momentum() -> bool:
	return _w.swing_t > 0 and _w.swing_momentum


## Frost Core: actor i is slowed.
func actor_slowed(i: int) -> bool:
	return _w.actors.slow_t[i] > 0


## Thorn Mantle: the tick the last ring was released (-1 = never).
func thorn_tick() -> int:
	return _w.thorn_tick


## Executioner: actor i is below the threshold, so your hits on it deal extra (false without the item).
func in_execute_range(i: int) -> bool:
	return ItemProcs.in_execute_range(_w, i)


## Swift Feet: the player's top speed in metres per second.
func move_speed_mps() -> float:
	return ItemProcs.move_speed(_w) * SimTick.TICKS_PER_SECOND


## Phase Strike: the tick it last discharged (-1 = never), and its ring's radius.
func phase_tick() -> int:
	return _w.phase_tick


func phase_radius_m() -> float:
	return _w.item_mods.phase_radius_m


# --- Run flow (v0.3.0 B) -----------------------------------------------------------------------------------


## This floor's number in the run (1-based) and the run's floor count.
func floor_index() -> int:
	return _w.floor_index


func floor_count() -> int:
	return _w.floor_count


func has_boss_room() -> bool:
	return _w.floor_layout != null and _w.floor_layout.boss_room >= 0 and _w.boss_flow != null


func boss_room() -> int:
	return _w.floor_layout.boss_room if _w.floor_layout != null else -1


## The boss door: centre on the wall line, the direction into the boss room, the gap's width, and the half
## thickness of the wall it sits in.
func boss_door_center() -> Vector2:
	return _w.floor_layout.boss_door_center


func boss_door_angle() -> int:
	return _w.floor_layout.boss_door_angle


func boss_door_width() -> float:
	return _w.floor_layout.boss_door_width


func boss_door_half_thickness() -> float:
	var o := _w.floor_layout.boss_door_wall
	return minf(o.half.x, o.half.y) if o != null else 0.4


## The door has shut behind the player (the boss fight began).
func boss_door_sealed() -> bool:
	return _w.boss_flow != null and _w.boss_flow.door_sealed()


func boss_state() -> int:
	return _w.boss_flow.state if _w.boss_flow != null else BOSS_WAITING


## The gate's portal is active: the boss is dead, and walking in leaves the floor.
func portal_active() -> bool:
	return _w.boss_flow != null and _w.boss_flow.portal_active()


## The tick the portal opened (-1 = not yet).
func portal_opened_tick() -> int:
	return _w.boss_flow.opened_tick if _w.boss_flow != null else -1


## Portal transit (v0.3.5 PT): 0..1 through the hero's way into the portal and through the arrival on a new floor
## (-1 when that isn't playing), the portal's centre, and whether the world holds still (input is ignored).
func portal_enter_progress() -> float:
	return _w.boss_flow.enter_progress(_w.tick) if _w.boss_flow != null else -1.0


func arrival_progress() -> float:
	return _w.boss_flow.arrive_progress() if _w.boss_flow != null else -1.0


func transit_holds() -> bool:
	return _w.boss_flow != null and _w.boss_flow.holds_world()


# --- Bosses (v0.3.0 C) --------------------------------------------------------------------------------------
static func is_boss_kind(kind: int) -> bool:
	return BossAi.is_boss_kind(kind)


func boss_alive() -> bool:
	return _w.boss_alive()


## The boss's actor id (0 = none, or dead; the boss contract's stand-in tracks it in World.boss_id).
func boss_id() -> int:
	return _w.boss_id


## How far p is past the boss door's line, into the boss room (negative on the host side).
func boss_door_depth(p: Vector2) -> float:
	return _w.floor_layout.boss_door_depth(p) if _w.floor_layout != null else 0.0


## The actor index of the first live boss, or -1 (the boss bar shows it).
func boss_index() -> int:
	for i in range(1, _w.actors.size()):
		if BossAi.is_boss_kind(_w.actors.kinds[i]) and _w.actors.dead[i] == 0:
			return i
	return -1


## Locale key of boss i's name (tr() it in the view).
func boss_name_key(i: int) -> StringName:
	return BossAi.table_of(_w, i).name_key


## Boss i's stagger meter, 0..1000 of full (1000 while staggered).
func boss_stagger_permille(i: int) -> int:
	if _w.actors.state[i] == BossAi.STAGGERED:
		return 1000
	var b := BossAi.entry_of(_w, i)
	var t := BossAi.table_of(_w, i)
	return clampi(_w.bosses.meter[b] * 1000 / maxi(1, t.stagger_size_milli), 0, 1000)


func boss_staggered(i: int) -> bool:
	return _w.actors.state[i] == BossAi.STAGGERED


## Boss i's phase (0 = the first) and how many it has.
func boss_phase(i: int) -> int:
	return _w.bosses.phase[BossAi.entry_of(_w, i)]


func boss_phase_count(i: int) -> int:
	return BossAi.table_of(_w, i).phase_threshold.size()


## HP thresholds (per mille of max) where boss i's later phases start, for marks on the bar.
func boss_phase_thresholds(i: int) -> PackedInt32Array:
	return BossAi.table_of(_w, i).phase_threshold


## The move of boss i's attack in progress (a MOVE_* constant), or -1.
func boss_move(i: int) -> int:
	var atk := BossAi.attack_of(_w, i)
	return atk.move if atk != null else -1


## Ticks into boss i's current state, for its animation.
func actor_state_ticks(i: int) -> int:
	return _w.actors.state_t[i]


## Boss i is underground (a burrow): the view hides its body.
func boss_hidden(i: int) -> bool:
	return BossAi.hidden(_w, i)


## Boss i is mid-leap: [true, progress 0..1] while airborne, else [false, 0].
func boss_leap(i: int) -> Array:
	var atk := BossAi.attack_of(_w, i)
	if (
		atk == null
		or atk.move != BossAttackTable.Move.LEAP
		or _w.actors.state[i] != EnemyAi.State.ACTIVE
	):
		return [false, 0.0]
	return [true, clampf(float(_w.actors.state_t[i] + 1) / atk.active_ticks, 0.0, 1.0)]


## The death recap's cause key when a boss killed the player (its attack's line), else &"".
func killer_cause_key() -> StringName:
	return BossAi.cause_key(_w)


## Number of compiled bosses (indices for the dev panel's spawn), and boss k's name key.
func boss_table_count() -> int:
	return _w.boss_tables.size()


func boss_table_name_key(k: int) -> StringName:
	return _w.boss_tables[k].name_key


# --- Boss challenge (v0.3.0 BX) ----------------------------------------------------------------------------------
## How far boss i has risen, 0..1000: state ticks over BossAi.INTRO_TICKS while it rises, then 1000 (L22: the boss
## bar fills over exactly this).
func boss_intro_permille(i: int) -> int:
	if _w.actors.state[i] != EnemyAi.State.SPAWN:
		return 1000
	return clampi(_w.actors.state_t[i] * 1000 / BossAi.INTRO_TICKS, 0, 1000)


## Boss i's weak point: how much of its open time is left, 0..1000 (0 = closed).
func boss_weak_point_permille(i: int) -> int:
	var b := BossAi.entry_of(_w, i)
	var t := BossAi.table_of(_w, i)
	if b < 0 or t.weak_ticks <= 0:
		return 0
	return clampi(_w.bosses.exposed_t[b] * 1000 / t.weak_ticks, 0, 1000)


## How close (from boss i's edge) a hit must land to strike its open weak point.
func boss_weak_range_m(i: int) -> float:
	return BossAi.table_of(_w, i).weak_range_m


## The closing arena's band (BossChallenge.band): {} or "arena", "depth", "next", "warn" (-1 or 0..1000).
func boss_arena_band() -> Dictionary:
	return BossChallenge.band(_w)


## How long the player has stayed too far from boss i, 0..1000 of the time that starts its punish (0 = none).
func boss_punish_permille(i: int) -> int:
	var b := BossAi.entry_of(_w, i)
	var t := BossAi.table_of(_w, i)
	if b < 0 or t.punish_attack < 0 or t.punish_ticks <= 0:
		return 0
	return clampi(_w.bosses.far_t[b] * 1000 / t.punish_ticks, 0, 1000)


# --- Rewards (v0.3.0 E) -------------------------------------------------------------------------------------
func shards() -> int:
	return _w.shards


func item_rarity(item_index: int) -> int:
	return _w.item_tables[item_index].rarity


func reward_count() -> int:
	return _w.rewards.size()


func reward_id(i: int) -> int:
	return _w.rewards.ids[i]


func reward_pos(i: int) -> Vector2:
	return _w.rewards.pos(i)


## REWARD_ALTAR or REWARD_CHEST.
func reward_kind(i: int) -> int:
	return _w.rewards.kind[i]


## Shards to open (0 for an altar).
func reward_price(i: int) -> int:
	return _w.rewards.price[i]


## You hold enough shards to open it (the same check the sim makes).
func reward_affordable(i: int) -> bool:
	return Rewards.can_afford(_w, i)


## The reward the interact button would open now (the sim's own choice), or -1.
func reward_in_reach() -> int:
	return Rewards.nearest(_w)


func interact_radius_m() -> float:
	return _w.reward_table.interact_radius_m


## True while a 3-card choice is open (the world waits for the pick).
func choosing() -> bool:
	return _w.choosing >= 0


## The open choice's reward index (-1 when none).
func choice_reward() -> int:
	return _w.rewards.index_of(_w.choosing) if _w.choosing >= 0 else -1


## The open choice's cards, as item indices in card order (empty when none).
func choice_items() -> PackedInt32Array:
	var i := choice_reward()
	return _w.rewards.offer_of(i) if i >= 0 else PackedInt32Array()


## The last refused open: the reward's id and the tick (-1 when none yet).
func reward_denied_id() -> int:
	return _w.reward_denied_id


func reward_denied_tick() -> int:
	return _w.reward_denied_tick


# --- Walls with thickness (v0.3.0 A) ------------------------------------------------------------------------


## The generated floor's footprint, for the stage's ground: each room's cells (its thick walls and doorways
## included) and the outer half of each outer wall. Empty without a floor.
func floor_ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _w.floor_layout != null:
		out.append_array(_w.floor_layout.ground)
	return out


# --- Engines and combos (v0.3.0 G) --------------------------------------------------------------------------
## An item's tags (fire, shock, frost, bleed, blade, bolt, dash, guard).
func item_tags(item_index: int) -> PackedStringArray:
	return _w.item_tables[item_index].tags


## Shock, bleed and frost stacks on actor i, and whether it is frozen.
func shock_stacks(actor_i: int) -> int:
	return _w.actors.shock_stacks[actor_i]


func bleed_stacks(actor_i: int) -> int:
	return _w.actors.bleed_stacks[actor_i]


func frost_stacks(actor_i: int) -> int:
	return _w.actors.frost_stacks[actor_i]


func actor_frozen(actor_i: int) -> bool:
	return Engines.frozen(_w, actor_i)


## Stacks at which shock discharges and frost freezes (0 = that engine isn't owned).
func shock_threshold() -> int:
	return _w.item_mods.shock_threshold


func frost_threshold() -> int:
	return _w.item_mods.frost_threshold


## Bulwark: guard charges stored now, and the most it stores.
func guard_charges() -> int:
	return _w.guard_charges


func guard_charge_max() -> int:
	return Abilities.charge_max(_w)  # Bulwark's, or Aegis's (v0.4.0)


## Owned combos in unlock order, as indices into the combo tables.
func combos_owned() -> PackedInt32Array:
	return _w.combos_owned


func combo_table_count() -> int:
	return _w.combo_tables.size()


func combo_id(combo_index: int) -> StringName:
	return _w.combo_tables[combo_index].id


func combo_effect(combo_index: int) -> int:
	return _w.combo_tables[combo_index].effect


## Locale keys (tr() them in the view).
func combo_name_key(combo_index: int) -> StringName:
	return _w.combo_tables[combo_index].name_key


func combo_desc_key(combo_index: int) -> StringName:
	return _w.combo_tables[combo_index].desc_key


## The two item ids a combo needs.
func combo_item_ids(combo_index: int) -> Array[StringName]:
	var c := _w.combo_tables[combo_index]
	return [_w.item_tables[c.item_a].id, _w.item_tables[c.item_b].id]


## The last shock discharge: tick (-1 = never), where it went off, and where each jump landed.
func discharge_tick() -> int:
	return _w.discharge_tick


func discharge_from() -> Vector2:
	return _w.discharge_from


func discharge_to() -> PackedVector2Array:
	return _w.discharge_to


## The last Plasma Arc: tick (-1 = never), from, to.
func plasma_tick() -> int:
	return _w.plasma_tick


func plasma_from() -> Vector2:
	return _w.plasma_from


func plasma_to() -> Vector2:
	return _w.plasma_to


## The last payoff of each kind: [tick (-1 = never), where]. Kinds: &"shatter", &"burst", &"wildfire", &"harvest".
func payoff(kind: StringName) -> Array:
	match kind:
		&"shatter":
			return [_w.shatter_tick, _w.shatter_pos]
		&"burst":
			return [_w.burst_tick, _w.burst_pos]
		&"wildfire":
			return [_w.wildfire_tick, _w.wildfire_pos]
		&"harvest":
			return [_w.harvest_tick, _w.harvest_pos]
	return [-1, Vector2.ZERO]


## The tick of the last Resonance wave, Shrapnel Storm burst, Spiked Phase ring, Slipstream refund and Frozen
## Bastion chill (-1 = never).
func resonance_tick() -> int:
	return _w.resonance_tick


func shrapnel_tick() -> int:
	return _w.shrapnel_tick


func spiked_tick() -> int:
	return _w.spiked_tick


func slipstream_tick() -> int:
	return _w.slipstream_tick


func bastion_tick() -> int:
	return _w.bastion_tick


## Projectile i is a Shrapnel Storm shard.
func projectile_is_shard(i: int) -> bool:
	return (_w.projectiles.tags[i] & SimEvent.TAG_SHRAPNEL) != 0


func player_build() -> Dictionary:  # v0.3.0 P: PlayerBuild.read (has_blade, has_gun, facing, regenerating, ...).
	return PlayerBuild.read(_w)


func heat_state() -> Dictionary:
	return Heat.read(_w)  # Overclock heat (v0.3.0 L18): the meter's values (Heat.read); {} without heat.


# --- Gamble shrine (v0.3.0 L19) -----------------------------------------------------------------------------
## The floor has a gamble shrine.
func has_gamble() -> bool:
	return Gamble.present(_w)


func gamble_id() -> int:
	return _w.gamble_id


func gamble_pos() -> Vector2:
	return _w.gamble_pos


## Shards for the next use (the sim's own price).
func gamble_price() -> int:
	return Gamble.price(_w)


func gamble_affordable() -> bool:
	return Gamble.can_afford(_w)


## Every stat is at its cap.
func gamble_exhausted() -> bool:
	return Gamble.exhausted(_w)


## The interact button would use the shrine now: in its reach, and no altar or chest in reach (they go first).
func gamble_in_reach() -> bool:
	return Gamble.in_reach(_w) and Rewards.nearest(_w) < 0


func gamble_interact_radius_m() -> float:
	return _w.gamble_table.interact_radius_m


## The last win: its tick (-1 = none yet on this floor) and its stat (an index below gamble_stat_count()).
func gamble_tick() -> int:
	return _w.gamble_tick


func gamble_last_stat() -> int:
	return _w.gamble_last_stat


## The last refused use (too poor, or every stat capped): its tick, -1 when none.
func gamble_denied_tick() -> int:
	return _w.gamble_denied_tick


func gamble_uses() -> int:
	return _w.gamble_uses


func gamble_stat_count() -> int:
	return GambleTable.STAT_COUNT


## The stat's data name (max_hp, melee_damage ...), for icons and text.
func gamble_stat_id(stat: int) -> StringName:
	return GambleTable.STAT_IDS[stat]


## Wins of `stat` this run, and its cap.
func gamble_stacks(stat: int) -> int:
	return Gamble.stacks(_w, stat)


func gamble_cap(stat: int) -> int:
	return _w.gamble_table.cap[stat]


## What one win of `stat` adds: HP for max_hp, per mille otherwise (regen: per mille of max HP per second).
func gamble_amount(stat: int) -> int:
	return _w.gamble_table.amount[stat]


## What the wins of `stat` add so far, in the same unit.
func gamble_bonus(stat: int) -> int:
	return Gamble.bonus(_w, stat)


## The stats the shrine can still draw, in stat order (the view's spin shows these).
func gamble_candidates() -> PackedInt32Array:
	var out := PackedInt32Array()
	var weights := Gamble.weights(_w)
	for s in weights.size():
		if weights[s] > 0:
			out.append(s)
	return out


func tier_progress() -> float:  # v0.3.0 UI (L23): 0 .. <1 through the danger tier
	return _w.spawner.tier_progress(_w.run_ticks) if _w.spawner != null else 0.0


# --- Minimap (v0.3.0 MM) ------------------------------------------------------------------------------------
## The room whose interior holds p (-1 inside a wall, a doorway, or without a floor).
func floor_room_of(p: Vector2) -> int:
	return _w.floor_layout.room_of(p) if _w.floor_layout != null else -1


func floor_start_room() -> int:
	return _w.floor_layout.start_room if _w.floor_layout != null else -1


## The room the portal gate stands in (-1 without a floor).
func floor_portal_room() -> int:
	return _w.floor_layout.portal_room if _w.floor_layout != null else -1


## Doorways of the floor: door i joins rooms floor_door_rooms(i).x and .y; its passage through the wall; its index
## of the boss door (-1 when none).
func floor_door_count() -> int:
	return _w.floor_layout.door_rooms.size() if _w.floor_layout != null else 0


func floor_door_rooms(i: int) -> Vector2i:
	return _w.floor_layout.door_rooms[i]


func floor_door_rect(i: int) -> Rect2:
	return _w.floor_layout.door_rect(i)


## Direction from room .x to room .y through door i (1/4096 turns; a grid axis).
func floor_door_angle(i: int) -> int:
	return _w.floor_layout.door_angles[i]


func floor_boss_door() -> int:
	return _w.floor_layout.boss_door_index if _w.floor_layout != null else -1


# --- Kit: Vent and Skill (v0.3.5 K) ------------------------------------------------------------------------
## The build's skill for the views (PlayerSkill.read; {} without one): kind, cooldown and total, ready, running
## (its tick, 0 = none) and move_ticks, angle, start tick and point, the last cleave/blast (tick, where, pellet ends),
## and the shape numbers (half_arc, reach_m, half_cone, range_m, pellets, lunge_m).
func skill_state() -> Dictionary:
	return PlayerSkill.read(_w)


## True if the skill used from `center` toward `angle` would reach actor i: the forecast calls the hit's own shape
## function (PlayerSkill.would_hit, EI-07).
func skill_hits(i: int, center: Vector2, angle: int) -> bool:
	return PlayerSkill.would_hit(_w, i, center, angle)


## The skill's pellet angles for a blast toward `angle` (AttackShapes.pellet_angles, as the sim's).
func skill_pellet_angles(angle: int) -> PackedInt32Array:
	var t := _w.player.skill
	if t == null:
		return PackedInt32Array()
	return AttackShapes.pellet_angles(angle, t.half_cone, t.pellets)


## The melee facing now (the angle a Lunge Cleave would take).
func melee_facing() -> int:
	return PlayerBuild.melee_angle(_w)


## The last Vent press that found no heat to vent (the cold click), as a tick (-1 = never).
func vent_cold_tick() -> int:
	return _w.kit.cold_tick


# --- Build (v0.4.0 BS): the four ability slots, stat cards, crit and the card offers -----------------------------


## The owned abilities in slot order (Abilities.read: id, name_key, kind, auto, button, level, cooldown,
## cooldown_total, ready, charges).
func abilities() -> Array[Dictionary]:
	return Abilities.read(_w)


## What the ability views draw (Abilities.fx).
func ability_fx() -> Dictionary:
	return Abilities.fx(_w)


## A card code's face (Offers.info: type CARD_*, id, kind, name_key, desc_key, rarity 0..2, level, amount).
func card_info(code: int) -> Dictionary:
	return Offers.info(_w, code)


## Crit chance and multiplier now, per mille (Stats).
func crit_chance_permille() -> int:
	return Stats.crit_chance(_w)


func crit_mult_permille() -> int:
	return Stats.crit_mult(_w)


## A stat's raw value (Stats.value: per mille; base 1000 for multipliers, 0 for added points).
func stat_value(stat: int) -> int:
	return Stats.value(_w, stat)

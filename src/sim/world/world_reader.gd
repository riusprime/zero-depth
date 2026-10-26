# gdlint: disable=max-public-methods, max-file-lines
class_name WorldReader
extends RefCounted
## The read-only face of World for presentation (EI-07). Presentation may name WorldReader, never World.
## It is a wide facade on purpose: one read method per thing a view needs.

const KIND_PLAYER := ActorStore.Kind.PLAYER
## v0.9.0 FA: the final approach's states (approach_state).
const APPROACH_WALK := FinalApproach.State.WALK
const APPROACH_BUILDUP := FinalApproach.State.BUILDUP
const APPROACH_FIGHT := FinalApproach.State.FIGHT
## v0.9.0 IX: the shared interactables' kinds (interactable_kind).
const INTERACT_PYLON := Interactables.Kind.PYLON
const INTERACT_TIMED_SWITCH := Interactables.Kind.TIMED_SWITCH
const INTERACT_RUNE_PILLAR := Interactables.Kind.RUNE_PILLAR  # v0.9.0 RA
## v0.9.0 DX: the destructible props' kinds (breakable_kind).
const BREAKABLE_CRATE := Breakables.Kind.CRATE
const BREAKABLE_URN := Breakables.Kind.URN
const BREAKABLE_BARREL := Breakables.Kind.BARREL
const BREAKABLE_EXPLOSIVE := Breakables.Kind.EXPLOSIVE
## v0.9.0 TD: the timed door's states (timed_door_state).
const TIMED_SHUT := TimedDoor.State.SHUT
const TIMED_OPEN := TimedDoor.State.OPEN
const TIMED_HELD := TimedDoor.State.HELD
## v0.9.0 LK: the Lockdown kinds (lockdown()["kinds"], ["kind"]).
const LOCKDOWN_NORMAL := LockdownTable.Kind.NORMAL
const LOCKDOWN_HAZARD := LockdownTable.Kind.HAZARD
## v0.9.0 SH, HF: the shrine kinds (shrine_kind) and the interactables the shrines and the fountain use.
const SHRINE_FORTUNE := ShrineTable.Kind.FORTUNE
const SHRINE_BLOOD := ShrineTable.Kind.BLOOD
const SHRINE_CHAOS := ShrineTable.Kind.CHAOS
const INTERACT_SHRINE := Interactables.Kind.SHRINE
const INTERACT_FOUNTAIN := Interactables.Kind.FOUNTAIN
const LOCKDOWN_ELITE := LockdownTable.Kind.ELITE
## v0.8.0 RM: the remnant kinds, activations and Thermal Break's effect id, for the views (the layer rule).
const REMNANT_SEGMENT := RemnantRule.Kind.SEGMENT
const REMNANT_ANCHOR := RemnantRule.Kind.ANCHOR
const REMNANT_FRAGMENT := RemnantRule.Kind.FRAGMENT
const REMNANT_ATTACK_CROSS := RemnantRule.Activate.ATTACK_CROSS
const REMNANT_DELAY := RemnantRule.Activate.DELAY
const EFFECT_THERMAL_BREAK := Engines.EFFECT_THERMAL_BREAK
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
## v0.8.0 FB1: the final boss's bodies.
const KIND_COLOSSUS := ActorStore.Kind.COLOSSUS
const KIND_PRISM := ActorStore.Kind.PRISM
const KIND_NEMESIS := ActorStore.Kind.NEMESIS
## v0.9.0 NB1: floor 4's first new boss.
const KIND_TIDECALLER := ActorStore.Kind.TIDECALLER
## v0.9.0 EL: the elite archetypes, and their two attacks (elite_attack).
const KIND_BREAKER := ActorStore.Kind.BREAKER
const KIND_RIFT_HUNTER := ActorStore.Kind.RIFT_HUNTER
const KIND_CONDUIT := ActorStore.Kind.CONDUIT
const ELITE_BASIC := EliteAi.Attack.BASIC
const ELITE_ABILITY := EliteAi.Attack.ABILITY
## v0.9.0 NB2: floor 4's Twin Wardens, the amber body (the boss) and the violet one (its twin).
const KIND_TWIN_WARDEN := ActorStore.Kind.TWIN_WARDEN
const KIND_TWIN_WARDEN_VIOLET := ActorStore.Kind.TWIN_WARDEN_VIOLET
## v0.9.0 NB3: floor 5's Clockwork Judge, and boss_echo's "phase" (no echo, the path showing, the ghosts striking).
const KIND_CLOCKWORK_JUDGE := ActorStore.Kind.CLOCKWORK_JUDGE
## v0.9.0 NB4: floor 5's Lantern Shade (its light: boss_light).
const KIND_LANTERN_SHADE := ActorStore.Kind.LANTERN_SHADE
const ECHO_NONE := BossJudge.NONE
const ECHO_SHOW := BossJudge.SHOW
const ECHO_REPLAY := BossJudge.REPLAY
## v0.9.0 NB2: a Warden turning angry (STATUS_APPLY's effect) and the chain's burn (its DAMAGE's effect).
const EFFECT_TWIN_ANGER := BossTwin.EFFECT_ANGER
const EFFECT_TWIN_CHAIN := BossTwin.EFFECT_BURN
## v0.8.0 N2: The Fallen's mimic window states (final_pace "window", fallen_window), for the presentation.
const FALLEN_OFF := FinalPace.Mimic.OFF
const FALLEN_WARN := FinalPace.Mimic.WARN
const FALLEN_ON := FinalPace.Mimic.ON
## How a melee combo step moves the blade (SwingStep.Motion; swing_motion()).
const MOTION_SLASH_RIGHT_TO_LEFT := SwingStep.Motion.SLASH_RIGHT_TO_LEFT
const MOTION_SLASH_LEFT_TO_RIGHT := SwingStep.Motion.SLASH_LEFT_TO_RIGHT
const MOTION_THRUST := SwingStep.Motion.THRUST
const MOTION_SPIN := SwingStep.Motion.SPIN
## v0.6.5 WN4: the Blade pool's view marks (blade_forms()["fx"][k]["kind"]; BladeForms.FX_*).
const BLADE_FX_ARC := BladeForms.FX_ARC
const BLADE_FX_ARC_MIRROR := BladeForms.FX_ARC_MIRROR
const BLADE_FX_LINE := BladeForms.FX_LINE
const BLADE_FX_PARRY := BladeForms.FX_PARRY
const BLADE_FX_BURST := BladeForms.FX_BURST
const BLADE_FX_COUNTER := BladeForms.FX_COUNTER
## v0.6.0 MX1: attack spec forms (attack_spec()["form"]) and the weapon attacks' ids.
const FORM_ARC := AttackSpec.Form.ARC
const FORM_BOLT := AttackSpec.Form.BOLT
const FORM_RING := AttackSpec.Form.RING
const FORM_BEAM := AttackSpec.Form.BEAM
const FORM_ZONE := AttackSpec.Form.ZONE
const FORM_ORBITER := AttackSpec.Form.ORBITER
const FORM_LOB := AttackSpec.Form.LOB
const FORM_BURST := AttackSpec.Form.BURST
const ATTACK_BOLT := Modifiers.GUN_BOLT
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
## A boss knocked off balance by a full stagger meter (BossAi).
const STATE_STAGGERED := BossAi.STAGGERED
## v0.8.0 BA: a boss in its phase gate (BossGates; boss_gate_permille), for its roar.
const STATE_GATE := BossAi.GATE
## v0.8.0 BS1 (S3): an egg waiting, and bursting (BossSignatures).
const STATE_EGG := BossSignatures.EGG
## v0.8.0 BS2 (S5): the hostile team (a ricochet's sparks are drawn for its shots).
const TEAM_ENEMY := ActorStore.TEAM_ENEMY
const STATE_EGG_BURST := BossSignatures.EGG_BURST
## How far from a gated boss its adds rise (m).
const GATE_ADD_RING_M := BossGates.ADD_RING_M
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
## v0.7.5 BF1: a bullet pattern, tracked ground circles, tracked row-and-column lanes.
const MOVE_PATTERN := BossAttackTable.Move.PATTERN
const MOVE_MARKS := BossAttackTable.Move.MARKS
const MOVE_ROW_LANES := BossAttackTable.Move.ROW_LANES
const MOVE_GRID := BossAttackTable.Move.GRID  # v0.7.5 BF3
const MOVE_ROW_FLOOD := BossAttackTable.Move.ROW_FLOOD
const MOVE_GAZE := BossAttackTable.Move.GAZE  # v0.8.0 BS2 (S4)
const MOVE_MELT := BossAttackTable.Move.MELT  # v0.8.0 BS2 (S6)
const MOVE_COMBO := BossAttackTable.Move.COMBO  # v0.8.0 FB1 (the Colossus)
const MOVE_SPIKE_CHASE := BossAttackTable.Move.SPIKE_CHASE
const MOVE_SPIKE_BURST := BossAttackTable.Move.SPIKE_BURST
const MOVE_CROSS := BossAttackTable.Move.CROSS  # v0.8.0 FB2 (the Prism)
const MOVE_MIMIC_COMBO := BossAttackTable.Move.MIMIC_COMBO  # v0.8.0 FB3 (the Nemesis)
const MOVE_MIMIC_SHOTS := BossAttackTable.Move.MIMIC_SHOTS
const MOVE_CARD_CAST := BossAttackTable.Move.CARD_CAST
const MOVE_TIDE := BossAttackTable.Move.TIDE  # v0.9.0 NB1 (the Tidecaller's Pull)
const MOVE_CROSSFIRE := BossAttackTable.Move.CROSSFIRE  # v0.9.0 NB2 (the Twin Wardens)
const MOVE_CHAIN_SWEEP := BossAttackTable.Move.CHAIN_SWEEP
const MOVE_ECHO := BossAttackTable.Move.ECHO  # v0.9.0 NB3 (the Clockwork Judge)
const MOVE_VERDICT := BossAttackTable.Move.VERDICT
## v0.9.0 NB1: boss_tide's "phase".
const TIDE_NONE := BossTide.NONE
const TIDE_PULL := BossTide.PULL
const TIDE_PUSH := BossTide.PUSH
const TIDE_MAX_MPS := BossTide.MAX_MPS
## v0.8.0 FB3: the Nemesis's stances (BossTable.STANCE_*) and the effect ids of its dash and its card casts.
const STANCE_ECHO := BossTable.STANCE_ECHO
const STANCE_MIRROR := BossTable.STANCE_MIRROR
const STANCE_CLOSE := BossTable.STANCE_CLOSE
const STANCE_BACK := BossTable.STANCE_BACK
const EFFECT_NEMESIS_DASH := BossNemesis.EFFECT_DASH
const EFFECT_NEMESIS_CAST := BossNemesis.EFFECT_CAST
## v0.8.0 FB1: a final boss's body shattering (FinalBoss.SHATTER), and its views' events (STATUS_APPLY effect ids).
const STATE_SHATTER := FinalBoss.SHATTER
const EFFECT_FINAL_SHATTER := FinalBoss.EFFECT_SHATTER
const EFFECT_FINAL_RISE := FinalBoss.EFFECT_RISE
## v0.9.5 BH6: the Fallen's interphase (BossInterphase): the vanished body's state and its views' events.
const STATE_INTERPHASE := BossInterphase.STATE
const EFFECT_FALLEN_VANISH := BossInterphase.EFFECT_VANISH
const EFFECT_FALLEN_BEAMS := BossInterphase.EFFECT_BEAMS
const EFFECT_FALLEN_ERUPT := BossInterphase.EFFECT_ERUPT
const EFFECT_FALLEN_DARK := BossInterphase.EFFECT_DARK
const EFFECT_FALLEN_RAIN := BossInterphase.EFFECT_RAIN
const EFFECT_FALLEN_LINE := BossInterphase.EFFECT_LINE
const EFFECT_FALLEN_RETURN := BossInterphase.EFFECT_RETURN
## Rewards (v0.3.0 E): reward kinds and item rarities, for views.
const REWARD_ALTAR := RewardStore.Kind.ALTAR
const REWARD_CHEST := RewardStore.Kind.CHEST
## v0.8.0 N8: card_forecast's kinds: no number, a level, a value per mille, max HP. Literals equal to CardForecast's
## KIND_* (a const naming CardForecast here would close a load cycle; test_reward_cards.gd checks they match).
const GAIN_NONE := 0
const GAIN_LEVEL := 1
const GAIN_PERMILLE := 2
const GAIN_HP := 3
const REWARD_LEGENDARY := RewardStore.Kind.LEGENDARY  # v0.5.5 AR (X1b)
const REWARD_DROP := RewardStore.Kind.DROP  # v0.6.0 CU: a free one-card drop (a stolen core, Marked's card)
## v0.6.0 CU: a drop's kind (CoreState.Drop).
const DROP_CORE := CoreState.Drop.CORE
const DROP_BOSS_CORE := CoreState.Drop.BOSS_CORE
const DROP_ELITE_CARD := CoreState.Drop.ELITE_CARD
const RARITY_LEGENDARY := Offers.LEGENDARY
## v0.5.0 RT: the routes (Routes.Route).
const ROUTE_NORMAL := Routes.Route.NORMAL
const ROUTE_DEEP := Routes.Route.DEEP
## v0.7.5 AP: the device taken on the Ascension floor (ascension_choice); v0.8.0 P2 (O28): the Ascension portal or
## the Loop device (no picks: walking in is the choice).
const ASCEND_NONE := Ascension.Choice.NONE
const ASCEND_PORTAL := Ascension.Choice.ASCENSION
const ASCEND_LOOP := Ascension.Choice.LOOP
const RARITY_RARE := ItemTable.RARE
## Kit (v0.3.5 K): the build skills.
const SKILL_LUNGE_CLEAVE := SkillTable.Kind.LUNGE_CLEAVE
const SKILL_SCATTER_BLAST := SkillTable.Kind.SCATTER_BLAST
## Build (v0.4.0 BS): card types, ability kinds, slots and levels.
const CARD_MOD := Offers.MOD
const CARD_ABILITY := Offers.ABILITY
const CARD_STAT := Offers.STAT
const CARD_CURSE := Offers.CURSE  # v0.6.0 CU: a trade-off curse card
## v0.5.0 SH: a shop salvage entry's kind, and the shop's last action (ShopState.Action).
const SHOP_SELL_MOD := Shop.SELL_MOD
const SHOP_SELL_STAT := Shop.SELL_STAT
const SHOP_SELL_ABILITY := Shop.SELL_ABILITY
const SHOP_BUY := ShopState.Action.BUY
const SHOP_HEAL := ShopState.Action.HEAL
const SHOP_REROLL := ShopState.Action.REROLL
const SHOP_SELL := ShopState.Action.SELL
const SHOP_SALVAGE := ShopState.Action.SALVAGE_ABILITY
const ABILITY_COMBO_SWORD := AbilityTable.Kind.COMBO_SWORD
const ABILITY_PULSE_GUN := AbilityTable.Kind.PULSE_GUN
const ABILITY_BOMB_LOBBER := AbilityTable.Kind.BOMB_LOBBER
const ABILITY_DRONE_BUDDY := AbilityTable.Kind.DRONE_BUDDY
const ABILITY_ORBIT_BLADES := AbilityTable.Kind.ORBIT_BLADES
const ABILITY_BLINK := AbilityTable.Kind.BLINK
const ABILITY_AEGIS := AbilityTable.Kind.AEGIS
## v0.6.0 MX2: the weapon, the utility and the six modifier slots' abilities at most.
const ABILITY_SLOTS := 2 + BuildSlots.SLOTS
## v0.6.0 MX2 (BuildSlots): the modifier slots, and the swap answers' pick values. v0.6.5 WN1: the most slots the
## wand ever has (it grows 4 → 6 → 8; build()["max"] is the count now), and the reorder's pick values
## (PICK_WAND_MOVE_BASE + from × WAND_MOVE_STRIDE + to).
const MOD_SLOTS := Wand.MAX_SLOTS
## v0.9.0 AS (owner Q2–Q5, Q14; AttackSlots): a card's slot tag (card_info()["slot"], wand()["cards"][n]["slot"]; NONE
## for a card without one on this run) and each tag's translation key; the forms' name keys (wand()["form"]).
const SLOT_NONE := AttackSlots.FREE
const SLOT_FORM := AttackSlots.FORM
const SLOT_PATTERN := AttackSlots.PATTERN
const SLOT_SECONDARY := AttackSlots.SECONDARY
const SLOT_ELEMENT := AttackSlots.ELEMENT
const SLOT_TAG_KEYS := AttackSlots.TAG_KEYS
const PICK_WAND_MOVE_BASE := InputFrame.PICK_WAND_MOVE_BASE
const WAND_MOVE_STRIDE := InputFrame.WAND_MOVE_STRIDE
## v0.6.5 WN1: the triggers a wand card cuts on (wand()["cards"][n]["trigger"]; -1 for a card of rewrites).
const WAND_ON_HIT := AttackSpec.Trigger.ON_HIT
const WAND_ON_KILL := AttackSpec.Trigger.ON_KILL
const WAND_ON_END := AttackSpec.Trigger.ON_END
const WAND_ON_FINISHER := AttackSpec.Trigger.ON_FINISHER
const WAND_ON_CRIT := AttackSpec.Trigger.ON_CRIT
## v0.8.0 AO: what a wand card does to the cards to its left (wand()["cards"][n]["order"]; Wand.order_of).
const WAND_ORDER_SHAPE := ModifierTable.OrderKind.SHAPE
const WAND_ORDER_COUNT := ModifierTable.OrderKind.COUNT
const WAND_ORDER_MOTION := ModifierTable.OrderKind.MOTION
const PICK_SWAP_SKIP := InputFrame.PICK_SWAP_SKIP
const ABILITY_MAX_LEVEL := AbilityTable.MAX_LEVEL
## v0.5.0 EV: event pedestals, costs, rewards and refusals (Events).
const EVENT_READY := Events.State.READY
const EVENT_ACTIVE := Events.State.ACTIVE
const EVENT_DONE := Events.State.DONE
const EVENT_COST_HP := Events.Cost.HP
const EVENT_COST_MAX_HP := Events.Cost.MAX_HP
const EVENT_COST_SHARDS := Events.Cost.SHARDS
const EVENT_COST_OVERHEAT := Events.Cost.OVERHEAT
const EVENT_COST_FIGHT := Events.Cost.FIGHT
const EVENT_COST_DEFEND := Events.Cost.DEFEND
const EVENT_REWARD_OVERCLOCK := Events.Reward.OVERCLOCK
const EVENT_REWARD_SHARDS := Events.Reward.SHARDS
const EVENT_REWARD_CHEST := Events.Reward.CHEST
const EVENT_REWARD_CLEANSE := Events.Reward.CLEANSE
const EVENT_BLOCK_OK := Events.OK
const EVENT_BLOCK_SHARDS := Events.NEED_SHARDS
const EVENT_BLOCK_NOTHING := Events.NEED_NOTHING_TO_GAIN
const EVENT_BLOCK_BUSY := Events.NEED_BUSY
## v0.4.0 AB: a Napalm Drone fire patch (element_fx()["fire_kind"]).
const FIRE_NAPALM := ElementAbilities.FIRE_NAPALM
## v0.6.0 MX2: Arc Field's shock field, and any other spec's patch (a hook's zone).
const FIRE_FIELD := ElementAbilities.FIRE_FIELD
const FIRE_ZONE := ElementAbilities.FIRE_ZONE

var _w: World
## v0.8.0 RT: piece_key -> wall index of the floor's interior pieces (built on the first layout_prop ask).
var _layout_wall_index := {}


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
	return [Modifiers.step(_w, s).half_arc, swing_reach_m(s), _w.player.radius_m]


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


## Whether step `step` (-1 = the current swing's) is the melee combo's finisher.
func is_finisher(step: int = -1) -> bool:
	return PlayerKit.is_finisher(_w, _step_index(step))


func _step_index(step: int) -> int:
	return step if step >= 0 else _w.combo_step


func shooting() -> bool:
	return PlayerKit.shooting(_w)


## v0.9.0 LZ (owner Q8): the Laser's beams now, empty while it isn't firing: Laser.trace from the hero along the aim,
## the geometry the tick's hits use (EI-07). Each {from, to, hits (actor indices), at (their points), wall}.
func beams() -> Array[Dictionary]:
	if not Laser.firing(_w):
		return []
	return Laser.trace(_w, Modifiers.bolt(_w), _w.player_pos(), _w.aim_angle)


## v0.9.5 FC1: Echo's strikes still to come, for the view's pale ghost beams: {from, to, left (ticks), total}.
func laser_ghosts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := _w.mx
	var total := LaserMods.ticks(LaserMods.param(_w, "echo_delay_ms"))
	for k in s.lz_echo_due.size():
		(
			out
			. append(
				{
					"from": s.lz_echo_from[k],
					"to": s.lz_echo_to[k],
					"left": maxi(0, s.lz_echo_due[k] - _w.tick),
					"total": total,
				}
			)
		)
	return out


## v0.9.5 FC1: the Laser's mines alive: {pos, age (ticks)}.
func laser_mines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := _w.mx
	for k in s.lz_mine_at.size():
		out.append({"pos": s.lz_mine_at[k], "age": _w.tick - s.lz_mine_born[k]})
	return out


## v0.9.5 FC2: the Bomb cards' rows for the view: {kind (&"burst", &"drop", &"mine" or
## &"ring"), pos, r (m, a ring's largest), age, left (ticks), span (ticks, born to due), secondary}.
func bomb_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := _w.mx
	for k in s.bm_kind.size():
		(
			out
			. append(
				{
					"kind": BombMods.KIND_NAMES[s.bm_kind[k] & BombMods.KIND_MASK],
					"pos": s.bm_at[k],
					"r": s.bm_r[k] / 1000.0,
					"age": _w.tick - s.bm_born[k],
					"left": maxi(0, s.bm_due[k] - _w.tick),
					"span": maxi(1, s.bm_due[k] - s.bm_born[k]),
					"secondary": (s.bm_kind[k] & BombMods.SEC) != 0,
				}
			)
		)
	return out


## v0.9.5 FC3: the Void's lightning rings growing (VoidMods.read_rings): {pos, r (m, the largest), age, span (ticks)}.
func void_rings() -> Array[Dictionary]:
	return VoidMods.read_rings(_w)


## v0.9.5 FC4: the Lance's lightning rings growing (LanceMods.read_rings): {pos, r (m, the largest), age, span (ticks)}.
func lance_rings() -> Array[Dictionary]:
	return LanceMods.read_rings(_w)


## v0.9.5 FC6: the lightning rings round the Glaive's discs (GlaiveMods.read_rings): {pos, r (m)}.
func glaive_rings() -> Array[Dictionary]:
	return GlaiveMods.read_rings(_w)


## v0.9.5 FC7: the lightning rings Ring makes where a Seekers dart hit (SeekerMods.read_rings): {pos, r (m)}.
func seeker_rings() -> Array[Dictionary]:
	return SeekerMods.read_rings(_w)


## v0.9.5 FC4: the Lance's split shards in view (LanceMods.read_shards): {from, to, age, span (ticks)}.
func lance_shards() -> Array[Dictionary]:
	return LanceMods.read_shards(_w)


## v0.9.0 BM: player projectile `i` is a bomb (the Bomb form's shot; BombView draws it, not the pulses).
func projectile_is_bomb(i: int) -> bool:
	return Bomb.touches(_w, i)


## v0.9.0 BM: the run's Gun shot is the Bomb (its throw's sound).
func bomb_active() -> bool:
	return Bomb.active(_w)


## v0.9.0 AF1 (owner Q7, F5): the run's Gun shot is the Lance; how far it has charged (0..1). v0.9.0 AF1b: and the
## charging ball in front of the hero (Lance.orb: {pos, radius}, the ball a release now would launch: EI-07), empty
## while it isn't charging.
func lance_active() -> bool:
	return Lance.active(_w)


func lance_charge() -> float:
	return Lance.charge(_w)


func lance_orb() -> Dictionary:
	return Lance.orb(_w)


## v0.9.0 AF1 (owner Q7, F6): player projectile `i` is a Scatter pellet (ScatterView draws it, not the pulses), and the
## run's Gun shot is the Scatter (its blast's sound).
func projectile_is_pellet(i: int) -> bool:
	return Scatter.is_pellet(_w, i)


func scatter_active() -> bool:
	return Scatter.active(_w)


## v0.9.0 AF2 (owner Q7, F7): player projectile `i` is a Glaive disc (GlaiveView draws it, not the pulses), it is on
## its way back, and the run's Gun shot is the Glaive (its throw's sound).
func projectile_is_disc(i: int) -> bool:
	return Glaive.is_disc(_w, i)


func disc_coming_back(i: int) -> bool:
	return Glaive.coming_back(_w, i)


func glaive_active() -> bool:
	return Glaive.active(_w)


## v0.9.0 AF2 (owner Q7, F8): player projectile `i` is a Seekers dart (SeekersView draws it, not the pulses), and the
## run's Gun shot is the Seekers (its volley's sound).
func projectile_is_dart(i: int) -> bool:
	return Seekers.is_dart(_w, i)


func seekers_active() -> bool:
	return Seekers.active(_w)


## v0.9.0 VP: player projectile `i` is a Void shot (VoidView draws it, not the pulses), and the run's Gun shot is the
## Void (its hum).
func projectile_is_void(i: int) -> bool:
	return VoidShots.is_void_projectile(_w, i)


func void_active() -> bool:
	return VoidShots.active(_w)


## v0.9.0 AF3 (owner Q7, F9, F10): player projectile `i` is a Wave shot (WaveView draws it, not the pulses); the Wave
## shots in flight (WaveShots.read: id, pos, dir, half width, depth); the run's Gun shot is the Wave; the wisps round
## the hero (Wisps.read: pos, angle, wait, period; empty without the Wisps card).
func projectile_is_wave(i: int) -> bool:
	return WaveShots.is_wave_projectile(_w, i)


func wave_shots() -> Array[Dictionary]:
	return WaveShots.read(_w)


func wave_active() -> bool:
	return WaveShots.active(_w)


func wisps() -> Array[Dictionary]:
	return Wisps.read(_w)


## v0.9.5 FC0 (owner): the Rune Explosion's bursts now (RuneExplosion.read: uid, pos, radius, edge, age, grow, fade,
## the actors hit), and whether the run's Gun shot is the Rune Explosion.
func rune_bursts() -> Array[Dictionary]:
	return RuneExplosion.read(_w)


func rune_active() -> bool:
	return RuneExplosion.active(_w)


## v0.9.5 FC5: what the Rune Explosion cards leave on the floor (RuneMods.read: holds, shrinks, mines, shards, glyphs).
func rune_effects() -> Dictionary:
	return RuneMods.read(_w)


## v0.9.0 AF3: player projectile `i` is a wisp's orb (its own chirp).
func projectile_is_wisp(i: int) -> bool:
	return Wisps.is_wisp_shot(_w, i)


## v0.9.0 LZ: the Laser fires now (its hum, the view).
func beam_firing() -> bool:
	return Laser.firing(_w)


## v0.9.0 LZ: the Laser's elements (the Gun shot's, in the order the cards added them; empty: the default energy).
func beam_elements() -> PackedStringArray:
	return Modifiers.bolt(_w).elements.duplicate() if Laser.active(_w) else PackedStringArray()


## v0.8.0 GF1 (owner O19): whether the Gun fired a shot in the last tick (the cooldown was just set to the full
## period: PlayerKit and GunForms set it on every shot, and it only counts down after). The hero's cast flourish.
func shot_fired() -> bool:
	return _w.shot_cd > 0 and _w.shot_cd == ItemEffects.shot_period_ticks(_w)


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


## 0 while fighting, 1 when the last wave is cleared (or the run's last portal taken), 2 when the player is dead, 3 when
## the portal of a floor before the last was taken (the app loads the next floor). v0.8.0 FB1 (F1): the Ascension portal
## (P2) goes on to the final arena (3) when the run has a final boss; the final arena's outcome is 1 once its last body
## fell.
func outcome() -> int:
	if _w.final_fight != null and _w.final_fight.won and _w.boss_flow != null:
		return 1
	if _w.boss_flow != null and _w.boss_flow.exited():
		if _w.boss_flow.ascension:  # v0.8.0 P2: the Loop device or the final boss go on; no final boss: won
			return 3 if Ascension.looped(_w) or _w.boss_flow.final_next else 1
		return 1 if _w.floor_index >= _w.floor_count else 3
	if _w.player_dead():
		return 2
	return 1 if _w.cleared else 0


## v0.8.0 N3 (owner O45): the portal on this floor leads to another floor the app loads (outcome() turns 3 once the hero
## is through it), not to the run's end: the loading cover closes only then.
func portal_loads() -> bool:
	if _w.boss_flow == null:
		return false
	if _w.boss_flow.ascension:
		return Ascension.looped(_w) or _w.boss_flow.final_next
	return _w.floor_index < _w.floor_count


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


## v0.7.5 BF1: projectile i's fireball look key (BulletPatterns; "" = a plain shot, drawn by ActorViews).
func projectile_look(i: int) -> String:
	return _w.projectiles.look_of(i)


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


## The spawn director's danger tier (0 without one; v0.4.0 TU: the difficulty curve's when the floor has one).
func tier() -> int:
	return _w.spawner.danger_tier(_w.run_ticks) if _w.spawner != null else 0


# --- The intensity director (v0.8.0 N5, owner O58) ---------------------------------------------------------------
## True when the floor's ordinary spawning has the intensity director. The player is never shown it (owner: "for now
## nothing, quietness, the enemies are the real indicator"); the dev panel (F10's Tools page) reads it.
func has_intensity() -> bool:
	return Intensity.table(_w) != null


## The hidden intensity, 0..1000 (0 without the director).
func intensity() -> int:
	return _w.intensity.level / 1000 if has_intensity() else 0


## The director's state (IntensityState.Mode: BUILD_UP 0, PEAK 1, PULL_BACK 2, QUIET 3; BUILD_UP without it).
func intensity_mode() -> int:
	return _w.intensity.mode if has_intensity() else IntensityState.Mode.BUILD_UP


## Ticks left in the PEAK, PULL_BACK or QUIET timer (0 in BUILD_UP or without the director).
func intensity_timer() -> int:
	return maxi(0, _w.intensity.timer) if has_intensity() else 0


# --- Difficulty curve (v0.4.0 TU, owner D1–D3) ------------------------------------------------------------------
## True when the floor's spawning follows a difficulty curve.
func has_curve() -> bool:
	return _w.spawner != null and _w.spawner.curve != null


## The curve's phase now (0 = the calm minute; 0 without a curve).
func phase() -> int:
	return _w.spawner.curve.phase_at(_w.run_ticks) if has_curve() else 0


func phase_count() -> int:
	return _w.spawner.curve.phase_count() if has_curve() else 0


## The locale key naming the phase now (empty without a curve).
func phase_name_key() -> StringName:
	return _w.spawner.curve.name_keys[phase()] if has_curve() else &""


## Seconds until the next phase begins (0 at the peak or without a curve).
func phase_seconds_left() -> float:
	if not has_curve():
		return 0.0
	return float(_w.spawner.curve.ticks_to_next(_w.run_ticks)) / SimTick.TICKS_PER_SECOND


## Enemy kinds this floor shows for the first time in the run (ActorStore.Kind).
func new_kinds() -> PackedInt32Array:
	return _w.spawner.curve.new_kinds if has_curve() else PackedInt32Array()


## v0.4.0 TU (owner D8): where the heal orbs lie, in drop order, and their ids.
func heal_orbs() -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in _w.orbs.size():
		out.append(_w.orbs.pos(k))
	return out


func heal_orb_ids() -> PackedInt32Array:
	return _w.orbs.ids


## True while a living enemy of `kind` is on the floor.
func kind_alive(kind: int) -> bool:
	var a := _w.actors
	for i in range(1, a.size()):
		if a.kinds[i] == kind and a.dead[i] == 0:
			return true
	return false


## The locale key of enemy kind `kind`'s name (empty when it has no table).
func enemy_name_key(kind: int) -> StringName:
	var t := _w.enemy_table(kind)
	return t.name_key if t != null else &""


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
	return Offers.item_keys(_w, _w.item_tables[item_index])[0]  # v0.6.5 WN5a: T4's face per weapon


func item_desc_key(item_index: int) -> StringName:
	return Offers.item_keys(_w, _w.item_tables[item_index])[1]


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
	return _w.tuning.pickup_radius_m


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
	return Modifiers.nth_burst_radius_m(_w)


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


## Ricochet Core: the tick of a projectile's last wall bounce (-1 = none).
func projectile_bounce_tick(i: int) -> int:
	return _w.projectiles.bounce_tick[i]


## v0.6.0 MX1: the ids of the build's compiled attacks (the combo steps, the bolt, the Skill), and one attack's final
## spec as plain data (AttackSpec.read: form, tags, modifiers, sizes, damage, statuses, elements, behaviour, hooks
## with their children), {} for an unknown id. AttackView draws the weapon attacks from it.
func attack_ids() -> PackedStringArray:
	return Modifiers.book(_w).order.duplicate()


func attack_spec(id: StringName) -> Dictionary:
	var s := Modifiers.book(_w).spec(id)
	return s.read() if s != null else {}


## The spec id of combo step `step` (-1 = the current swing's).
func step_attack_id(step: int = -1) -> StringName:
	return Modifiers.step_id(_step_index(step))


## v0.6.0 MX4: what the M-list's modifiers do that no attack spec shows (ModifierOverlays draws it): Aether Shell's
## barrier is up ("shell"; "shell_tick" the last hit it absorbed, -1 = none), Ascension's next attack is charged
## ("charged"), the dash is intangible now ("phase", Phase Dash), the poisoned enemies' positions ("poisoned"), and
## where a queued launch waits ("queued": Long Shadow's afterimage, Twin Cast's repeat).
func modifier_marks() -> Dictionary:
	var poisoned := PackedVector2Array()
	var a := _w.actors
	for i in range(1, a.size()):
		if a.dead[i] == 0 and i < a.poison_stacks.size() and a.poison_stacks[i] > 0:
			poisoned.append(a.pos(i))
	return {
		"shell": ModifierRuntime.shell_up(_w),
		"shell_tick": _w.mx.shell_tick,
		"charged": ModifierRuntime.charged(_w),
		"phase": _w.is_dashing() and ModifierRuntime.intangible(_w),
		"poisoned": poisoned,
		"queued": _w.mx.q_pos.duplicate(),
	}


## v0.6.5 WN4: the Blade pool's marks for the views (BladeForms.read: ghost slashes, fissure cracks and eruptions,
## cut shots, a counter, the orbiting blades).
func blade_forms() -> Dictionary:
	return BladeForms.read(_w)


## v0.6.5 WN5a: the wand's small spells cast lately, oldest first (WandCasts.read: tick, key, pos, angle in 1/4096
## turns, cast: a trigger's child spell). AttackFormView draws each once.
func wand_casts() -> Array[Dictionary]:
	return WandCasts.read(_w)


## v0.6.5 WN4: how the current swing's cards change the swing itself, for the blade and the hero's pose
## (BladeForms.swing_read: weight, rate, lunge, knockback, parry).
func blade_swing() -> Dictionary:
	return BladeForms.swing_read(_w)


## The compiled build's digest (Modifiers: hashed once the build has a modifier); views key caches on it.
func attack_digest() -> String:
	return Modifiers.book(_w).digest


## v0.6.0 MX3: the final spec an AttackBook key names (a root's id, a hook child's "<parent key>/<n>"; MX2), as
## plain data ({} for "" or a key the current build doesn't have). AttackFormView draws the live attacks from it.
func attack_spec_at(key: String) -> Dictionary:
	if key == "":
		return {}
	var s := Modifiers.book(_w).find(key)
	return s.read() if s != null else {}


## v0.6.0 MX3: the spec key player projectile i runs ("" = none: an enemy's, or one from before MX2).
func projectile_spec_key(i: int) -> String:
	var keys := _w.projectiles.spec_key
	return keys[i] if i < keys.size() else ""


## v0.6.5 WN3: projectile `i`'s radius (a charged shot is bigger than its spec, G13), and how far the Gun's shot in
## the barrel has charged (0..1; 0 when the Gun doesn't charge: GunForms).
func projectile_radius(i: int) -> float:
	return _w.projectiles.radius[i]


func gun_charge() -> float:
	return GunForms.charge_fraction(_w)


## v0.6.0 MX3: the spec keys of the bombs in flight and of the patches, parallel to ability_fx()["bomb_pos"] and
## element_fx()["fire_pos"] ("" = one without a spec: Napalm Drone's patches).
func bomb_spec_keys() -> PackedStringArray:
	return _padded(_w.ab.bomb_spec, _w.ab.bomb_pos.size())


func fire_spec_keys() -> PackedStringArray:
	return _padded(_w.ab.fire_spec, _w.ab.fire_pos.size())


## v0.6.0 MX3: the RING form's live rings: {key, pos, radius (full), start, end} (the radius now grows linearly from
## start to end, ModifierAbilities.ring_radius). v0.8.0 N3: a travelling ring (pulses > 0) also gives where it left
## (from), its velocity per tick, its orbit and orbit angle, and "pos" is its centre this tick; ring_place puts it at
## any moment between ticks.
func rings_live() -> Array[Dictionary]:
	var st := _w.ab
	var out: Array[Dictionary] = []
	for k in st.ring_pos.size():
		var moving := k < st.ring_pulse.size() and st.ring_pulse[k] > 0
		(
			out
			. append(
				{
					"key": st.ring_spec[k] if k < st.ring_spec.size() else "",
					"pos": ModifierAbilities.ring_centre(_w, k, _w.tick),
					"from": st.ring_pos[k],
					"radius": st.ring_r[k],
					"start": st.ring_start[k],
					"end": st.ring_end[k],
					"pulses": st.ring_pulse[k] if moving else 0,
					"vel": st.ring_vel[k] if moving else Vector2.ZERO,
					"orb": st.ring_orb[k] if moving else 0.0,
					"orb_a": st.ring_orb_a[k] if moving else 0,
				}
			)
		)
	return out


## v0.8.0 N3: a travelling ring of rings_live() at moment `t` (ticks, fractional): [centre, radius], by the sim's own
## formulas (ModifierAbilities.travel_centre and travel_radius), so the ring drawn is the ring that hits.
static func ring_place(r: Dictionary, t: float) -> Array:
	var age := t - float(r["start"])
	var life := int(r["end"]) - int(r["start"])
	return [
		ModifierAbilities.travel_centre(r["from"], r["vel"], float(r["orb"]), int(r["orb_a"]), age),
		ModifierAbilities.travel_radius(float(r["radius"]), int(r["pulses"]), life, age),
	]


static func _padded(keys: PackedStringArray, n: int) -> PackedStringArray:
	var out := keys.duplicate()
	out.resize(n)
	return out


## Ticks between bolts while shooting (Rapid Coil applied).
func shot_period_ticks() -> int:
	return ItemEffects.shot_period_ticks(_w)


## The generated floor, for the stage and the gate (PLAN v0.2.0 F). False in the arena and kernel scenarios.
func has_floor() -> bool:
	return _w.floor_layout != null


## The floor has the run's gate (its boss flow; v0.7.5 PG: the Playground's room has a floor and no gate).
func has_gate() -> bool:
	return (
		_w.floor_layout != null
		and _w.boss_flow != null
		and _w.final_fight == null  # FB1: not the arena
		and _w.approach == null
	)  # v0.9.0 FA: nor its approach


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


## v0.5.9 L8: the kit piece a themed room's wall i is drawn with (&"" for any other wall). Presentation only.
func wall_piece(i: int) -> StringName:
	var f := _w.floor_layout
	if f == null or i < f.slab_first or i >= _w.walls.size():
		return &""
	return f.piece_tag(_w.walls[i])


## v0.8.0 RT: a designed room's blocker's drawn height (m; 0 = the kit's own), or -1.0 for any other wall (the biome's
## swap rules apply to a designed room's pieces). Presentation only.
func wall_layout_height(i: int) -> float:
	var f := _w.floor_layout
	if f == null or i < f.slab_first or i >= _w.walls.size():
		return -1.0
	return f.piece_height(_w.walls[i])


## v0.8.0 RT: the designed rooms' drawn-only pieces (presentation only).
func layout_prop_count() -> int:
	return _w.floor_layout.layout_props.size() if _w.floor_layout != null else 0


## Prop i: {"piece": StringName, "pos": Vector2, "angle": int (1/4096), "size": Vector2 (m), "height": float (m; 0 =
## the kit's own), "wall": the wall index it stands on (-1: decoration on open floor; -2: its blocker is gone, so it
## isn't drawn)}.
func layout_prop(i: int) -> Dictionary:
	var f := _w.floor_layout
	var p: Array = f.layout_props[i]
	var wall := -1
	var key: String = p[5]
	if not key.is_empty():
		if _layout_wall_index.is_empty():
			for k in range(f.slab_first, _w.walls.size()):
				_layout_wall_index[FloorLayout.piece_key(_w.walls[k])] = k
		wall = int(_layout_wall_index.get(key, -2))
	return {"piece": p[0], "pos": p[1], "angle": p[2], "size": p[3], "height": p[4], "wall": wall}


## The room's designed layout id (&"" for a rule-built room). For tools and shots.
func floor_room_layout(room: int) -> StringName:
	return _w.floor_layout.layout_of(room) if _w.floor_layout != null else &""


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


## v0.7.5 AP: the run's loop (1 until the first Ascend) and its floor counted across loops.
func loop() -> int:
	return _w.loop


func run_floor() -> int:
	return _w.run_floor_index()


## v0.7.5 AP: this floor's gate is the Ascension portal (the loop's last floor of a run).
func ascension_floor() -> bool:
	return _w.boss_flow != null and _w.boss_flow.ascension


## v0.7.5 AP: the device taken: ASCEND_NONE, ASCEND_PORTAL or ASCEND_LOOP (v0.8.0 P2).
func ascension_choice() -> int:
	return _w.boss_flow.ascend_choice if _w.boss_flow != null else ASCEND_NONE


## v0.8.0 P2 (owner O28): the Loop device beside the Ascension portal (a loop's last floor): whether it stands, its
## centre, the way it faces and the radius that takes the hero (it opens with the portal: portal_active).
func has_loop_device() -> bool:
	return ascension_floor() and _w.floor_layout != null and _w.floor_layout.has_loop_device


func loop_device_pos() -> Vector2:
	return _w.floor_layout.loop_pos if _w.floor_layout != null else Vector2.ZERO


func loop_device_angle() -> int:
	return _w.floor_layout.loop_angle if _w.floor_layout != null else 0


func loop_device_radius() -> float:
	return Ascension.LOOP_RADIUS_M


## v0.9.0 VP (owner Q10): the Void shots in flight (VoidShots.read: id, pos, dir, aura, pull radius, root), and the
## enemies their pull leans now (VoidShots.leans: actor id -> the way it is drawn, m a tick).
func void_shots() -> Array[Dictionary]:
	return VoidShots.read(_w)


func void_leans() -> Dictionary:
	return VoidShots.leans(_w)


## v0.8.0 RM (owner O91): the remnants alive and Dodge Imprint's standing point (Remnants.read: {remnants: [{uid,
## kind, card, activate, a, b, dir, age, life, count, target}], imprint, imprint_at}).
func remnants() -> Dictionary:
	return Remnants.read(_w)


## v0.8.0 RM: the radius (m) of the cast card `card`'s remnant releases (the view's flash; 0 without one).
func remnant_cast_radius(card: StringName) -> float:
	return Remnants.cast_radius(_w, card)


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


## v0.8.0 BD (owner O83): the door's slide before the fight from the sim, 0 (shut) .. 1 (open; BossFlow.door_progress),
## or -1 when the sim doesn't drive it (a floor before BD, or once the fight began).
func boss_door_progress() -> float:
	return _w.boss_flow.door_progress(_w.tick) if _w.boss_flow != null else -1.0


## v0.9.0 DS: how long the boss door takes to open, in ticks (the impact cue leads the touchdown).
func boss_door_open_ticks() -> int:
	return BossFlow.DOOR_OPEN_TICKS


## v0.8.0 BD (O83): the interact press would open the boss door now (the prompt).
func boss_door_in_reach() -> bool:
	return (
		_w.boss_flow != null
		and not _w.player_dead()
		and _w.boss_flow.door_in_reach(_w.floor_layout, player_pos())
	)


## The gate's portal is active: the boss is dead, and walking in leaves the floor.
func portal_active() -> bool:
	return _w.boss_flow != null and _w.boss_flow.portal_active()


## Portal transit (v0.3.5 PT): 0..1 through the hero's way into the portal and through the arrival on a new floor
## (-1 when that isn't playing), the portal's centre, and whether the world holds still (input is ignored).
func portal_enter_progress() -> float:
	return _w.boss_flow.enter_progress(_w.tick) if _w.boss_flow != null else -1.0


func arrival_progress() -> float:
	return _w.boss_flow.arrive_progress() if _w.boss_flow != null else -1.0


func transit_holds() -> bool:
	return _w.boss_flow != null and _w.boss_flow.holds_world()


## v0.8.0 N11 (owner O69): the floor has a receiver, the platform the hero arrives on in the middle of its first room
## (at floor_start_pos): every run floor, Deep floors too; not the final arena or the Playground (no gate there).
func floor_receiver() -> bool:
	return has_gate()


## v0.8.0 N11: the arrival playing now is floor 1 of a run's (the big landing; a later floor's is the step-out).
func arrival_first() -> bool:
	return _w.run_floor_index() == 1


## v0.9.0 SA (owner Q16: "only floor 1"): floor 1 of a run arrives on the altar (AltarStage) instead of the receiver,
## at floor_start_pos; the start hall keeps its cover and spawn spots FloorParams.start_clear_radius (3.5 m) away,
## outside the altar's 3.3 m.
func arrival_altar() -> bool:
	return floor_receiver() and arrival_first()


## v0.9.0 SA: the arrival's whole length in ticks (0 when the floor opens without one).
func arrival_ticks() -> int:
	return _w.boss_flow.arrive_ticks if _w.boss_flow != null else 0


## v0.8.0 N11: the hero is still arriving (the world holds; nothing spawns, nothing acts, the hero isn't there yet).
func arriving() -> bool:
	return _w.boss_flow != null and _w.boss_flow.arrive_left > 0


# --- Routes (v0.5.0 RT) ---------------------------------------------------------------------------------------
## This floor's boss room has the Deep gate (a run's floor before the last), where it stands and faces.
func has_deep_portal() -> bool:
	return _w.boss_flow != null and _w.boss_flow.routes


func deep_portal_pos() -> Vector2:
	return _w.floor_layout.deep_portal_pos if _w.floor_layout != null else Vector2.ZERO


func deep_portal_angle() -> int:
	return _w.floor_layout.deep_portal_angle if _w.floor_layout != null else 0


## Gate `route` (Routes.Route) is open: the boss is dead, and no route was taken or this one was.
func gate_open(route: int) -> bool:
	return _w.boss_flow != null and _w.boss_flow.gate_open(route)


## v0.9.0 PT (owner C4, Q15): 0..1 through gate `route`'s forming after the boss died (0 while it is closed: before
## the boss died, or once the other gate was taken); the hero can walk in once it is 1 (BossFlow.PORTAL_FORM_TICKS).
func portal_form_progress(route: int) -> float:
	if not gate_open(route):
		return 0.0
	return _w.boss_flow.portal_form_progress(_w.tick)


## The route walked into on this floor (Routes.Route; -1 = none yet).
func route_taken() -> int:
	return _w.boss_flow.route_taken if _w.boss_flow != null else -1


## This floor is a Deep floor (the Deep portal was taken on the floor before).
func floor_is_deep() -> bool:
	return Routes.is_deep(_w)


## Reward i is the Deep floor's epic altar.
func reward_is_epic(i: int) -> bool:
	return Routes.is_epic_altar(_w, i) or TimedDoor.is_epic(_w, i)  # v0.9.0 TD: the secret room's


## v0.5.5 AR (X1b): reward i is the boss's legendary altar.
func reward_is_legendary(i: int) -> bool:
	return BossReward.is_legendary(_w, i) or reward_drop_kind(i) == DROP_BOSS_CORE  # v0.6.0 CU


## v0.8.0 RR (owner O33): the picks the floor's boss altar still gives after the one open now (0 on loop 1).
func legendary_picks_left() -> int:
	return _w.legendary_picks


## v0.8.0 FL (owner O91; LootPacing.jackpot): card k of the open choice is a jackpot card (it says "Jackpot"). Replaces
## v0.6.5 WN5b's legendary_card_level: the boss's altar no longer takes a wand card to level 5.
func choice_jackpot(k: int) -> bool:
	var i := choice_reward()
	if i < 0:
		return false
	var offer := _w.rewards.offer_of(i)
	return k >= 0 and k < offer.size() and LootPacing.is_jackpot(_w, _w.rewards.ids[i], offer[k])


## v0.6.0 CU: reward i's drop kind (DROP_*), or -1 when it isn't a drop.
func reward_drop_kind(i: int) -> int:
	return CoreTheft.drop_kind(_w, _w.rewards.ids[i])


## v0.6.0 CU: the card a drop holds (an Offers code for card_info), or -1 when it holds none.
func reward_drop_card(i: int) -> int:
	var offer := _w.rewards.offer_of(i)
	return offer[0] if _w.rewards.kind[i] == REWARD_DROP and not offer.is_empty() else -1


## v0.5.5 AR: reward i stands in an arena that isn't cleared (it can't be opened yet).
func reward_locked(i: int) -> bool:
	return Arenas.locked(_w, i)


## v0.5.5 AR: the sealed arenas (Arenas.read: active, rooms, overrun, cleared, sealed, overrun_sealed, wave, waves,
## alive, next_wave_tick, sealed_tick, clear_tick, last_cleared).
func arenas() -> Dictionary:
	return Arenas.read(_w)


## v0.5.5 AR: the barriers of the sealed arena now (centre and half extents, axis-aligned), for the door views.
func arena_barriers() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for o in _w.arenas.barriers:
		out.append(Rect2(o.center - o.half, o.half * 2.0))
	return out


## The gate the hero went into (the Deep gate once it was taken, else the gate): its centre and facing.
## v0.8.0 P2: the Loop device once it was taken.
func entered_portal_pos() -> Vector2:
	if ascension_choice() == ASCEND_LOOP:
		return loop_device_pos()
	return deep_portal_pos() if route_taken() == Routes.Route.DEEP else portal_pos()


func entered_portal_angle() -> int:
	if ascension_choice() == ASCEND_LOOP:
		return loop_device_angle()
	return deep_portal_angle() if route_taken() == Routes.Route.DEEP else portal_angle()


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


## v0.5.5 DS (D7): 0..1000, how far boss i's phase gate has run (0 when it isn't in one; BossGates).
func boss_gate_permille(i: int) -> int:
	return BossGates.progress(_w, i)


func boss_in_gate(i: int) -> bool:
	return _w.actors.state[i] == BossAi.GATE


## Boss i's phase (0 = the first).
func boss_phase(i: int) -> int:
	return _w.bosses.phase[BossAi.entry_of(_w, i)]


## HP thresholds (per mille of max) where boss i's later phases start, for marks on the bar.
func boss_phase_thresholds(i: int) -> PackedInt32Array:
	return BossAi.table_of(_w, i).phase_threshold


## The move of boss i's attack in progress (a MOVE_* constant), or -1.
func boss_move(i: int) -> int:
	var atk := BossAi.attack_of(_w, i)
	return atk.move if atk != null else -1


## v0.8.0 BA: the timing of boss i's attack in progress, for its animation clip (the strike pose lands on the first
## active tick): Vector4i(windup ticks, active ticks, recover ticks, the ticks between strikes when it strikes more
## than once (a `marks` or `row_lanes` attack's later markers), else 0); Vector4i.ZERO with no attack.
func boss_attack_ticks(i: int) -> Vector4i:
	var atk := BossAi.attack_of(_w, i)
	if atk == null:
		return Vector4i.ZERO
	var gap := atk.mark_gap_ticks if atk.count > 1 and BossDodge.is_marker_move(atk.move) else 0
	if atk.move == MOVE_COMBO:  # v0.8.0 FB1: a swing per gap, then the slam
		gap = atk.mark_gap_ticks
	return Vector4i(atk.windup_ticks, atk.active_ticks, atk.recover_ticks, gap)


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


## v0.7.5 BF1 (owner N15, "Shielded during big patterns"): boss i is shielded now (its signature pattern runs): the
## player's hits spark off it. For the shell view and the avatars' shield pose.
func boss_shielded(i: int) -> bool:
	return BossDodge.shielded(_w, i)


## v0.8.0 N4 (owner O56: "if your boss has a shield you have to break before you can hurt it again, make the bar say
## so"): no hit can hurt boss i now: its invulnerable ticks run (the rise, a phase gate, a leap or burrow, a mimic's
## dash), its signature pattern's shield is up (boss_shielded), or it stands in a gate or a final shatter. The boss
## bar's invulnerable look. A read only (Damage decides; this mirrors its checks).
func boss_invulnerable(i: int) -> bool:
	var s := _w.actors.state[i]
	return (
		_w.actors.invuln[i] > 0
		or BossDodge.shielded(_w, i)
		or BossShade.unlit(_w, i)  # v0.9.0 NB4: a Lantern Shade in the dark
		or s == BossAi.GATE
		or s == FinalBoss.SHATTER
		or s == BossInterphase.STATE
	)  # v0.9.5 BH6: the Fallen, vanished


## v0.8.0 N4: the shields boss i still has to pass before it can fall, derived from sim state (no store counts
## shields): its phase gates still to come (each an invulnerable transition). 0 in its last phase. A final boss's
## body counts its own gates only (owner O59: nothing on the bar hints how many bodies remain).
func boss_shields_left(i: int) -> int:
	var t := BossAi.table_of(_w, i)
	return maxi(0, t.phase_threshold.size() - 1 - boss_phase(i))


## v0.8.0 N4 (owner O56: "The bosses should have one full bar and refill when changing phases"): boss i's HP within
## its current phase, 0..1000: full at the phase's start (its threshold of max HP), empty at the next phase's
## threshold (or 0 in the last phase). The boss bar shows one full bar per phase from it.
func boss_phase_permille(i: int) -> int:
	var t := BossAi.table_of(_w, i)
	var mx := _w.actors.max_hp[i]
	var p := boss_phase(i)
	var th := t.phase_threshold
	var hi := th[p] * mx / 1000 if p < th.size() else mx
	var lo := th[p + 1] * mx / 1000 if p + 1 < th.size() else 0
	return clampi((_w.actors.hp[i] - lo) * 1000 / maxi(1, hi - lo), 0, 1000)


## v0.7.5 BF1: the bullet pattern boss i is winding up or firing: {} or {"id", "kind" (BulletPatternTable.Kind),
## "look", "shielded", "winding", "progress" 0..1000} (BossAi.pattern_state), for the avatars' poses.
func boss_pattern(i: int) -> Dictionary:
	return BossDodge.pattern_state(_w, i)


## v0.7.5 BF3: the drops boss i's raining pattern (the Foundry's Slag Fountain) has in the air now, each [from, to
## (sim-plane points), progress 0..1, progress a tick]; they land as fireballs where `to` is (BossDodge.rain_drops).
func boss_rain(i: int) -> Array:
	return BossDodge.rain_drops(_w, i)


## v0.8.0 BS1 (owner O5, S1): the Gatekeeper's standing pillars (walls while they stand): [center, half side (m),
## the tick it rose, the tick it sinks] each, for StoneSpikeViews.
func boss_pillars() -> Array:
	var out := []
	var bs := _w.bosses
	for k in bs.pillar_x.size():
		out.append(
			[
				Vector2(bs.pillar_x[k], bs.pillar_y[k]),
				bs.pillar_h[k],
				bs.pillar_from[k],
				bs.pillar_until[k]
			]
		)
	return out


## v0.8.0 BS1 (S2): the javelins boss i has stuck in the floor: [at, angle out (1/4096 turns), the tick it stuck,
## the tick it flies back] each (BossSignatures.javelins_of).
func boss_javelins(i: int) -> Array:
	return BossSignatures.javelins_of(_w, i)


## v0.8.0 BS1 (S2): boss i's recall, for its pull: 0..1000 from its first javelin sticking to their flight back
## (1000 on that tick), or -1 with none stuck.
func boss_recall_permille(i: int) -> int:
	var from := 1 << 30
	var back := -1
	for j: Array in BossSignatures.javelins_of(_w, i):
		from = mini(from, int(j[2]))
		back = maxi(back, int(j[3]))
	if back < 0:
		return -1
	return clampi((_w.tick - from) * 1000 / maxi(1, back - from), 0, 1000)


## v0.8.0 BS1 (S3): actor i is a Brood Mother's egg: its time to hatch or burst 0..1000 (1000 bursting), else -1.
func actor_egg_permille(i: int) -> int:
	return BossSignatures.egg_permille(_w, i)


## v0.8.0 BS2 (owner O5, S4): boss i's Gaze: {} or {"winding", "progress", "from", "to", "angle", "half_width",
## "way", "hit"} (BossGaze.state): the eye brightening and its thin aim line in the windup, then the beam.
func boss_gaze(i: int) -> Dictionary:
	return BossGaze.state(_w, i)


## v0.9.0 NB1 (BOSSES_4_5.md N1): boss i's tide: {} or {"phase" (TIDE_NONE while its bell rings in the windup,
## TIDE_PULL, TIDE_PUSH), "windup", "progress" (0..1000 of that part), "speed" (m/s), "centre"} (BossTide.state).
func boss_tide(i: int) -> Dictionary:
	return BossTide.state(_w, i)


## v0.9.5 BH4 (BOSSES_HARD.md T3): the Tidecaller's crossing waves on the floor, each {"boss", "wall" (0 north .. 3
## west), "dir", "start", "pos", "length", "thick", "telegraph" (0..1000 as a foam line, -1 once it moves),
## "progress" (0..1000 of its run), "hit", "formed"} (BossStream.state).
func boss_waves() -> Array[Dictionary]:
	return BossStream.state(_w)


## v0.9.0 NB2 (BOSSES_4_5.md N2): Warden body i's pair: {} for any other actor; else "lead" (the boss's body),
## "partner" (the other's index), "angry", "anger" (0..1000 left), "chain" ([] or [from, to]), "hot" (it burns),
## "lifted" (the Chain Sweep has it), "burned" (ticks since it last burned the player, -1 none); in a Crossfire "safe",
## "gap" ([from, to]), "progress", "firing"; the boss's Chain Sweep "sweep" {from, to, half_width, locked, progress,
## struck} (BossTwin.state).
func boss_twin(i: int) -> Dictionary:
	if i <= 0 or i >= _w.actors.size():
		return {}
	return BossTwin.state(_w, i)


## v0.9.0 NB3 (BOSSES_4_5.md N3): the Clockwork Judge i's echo: {} for any other actor; else "recording" (0..1000),
## "trail" (the points recorded), "phase" (ECHO_NONE, ECHO_SHOW, ECHO_REPLAY), and while an echo runs "progress",
## "t", "windup", "gap", "radius", "path" ([{pos, k, at, struck}]); a Verdict winding up "verdict" {center, half,
## locked, progress} (BossJudge.state).
func boss_echo(i: int) -> Dictionary:
	if i <= 0 or i >= _w.actors.size() or _w.actors.kinds[i] != KIND_CLOCKWORK_JUDGE:
		return {}
	return BossJudge.state(_w, i)


## v0.9.0 NB4 (BOSSES_4_5.md N4): the Lantern Shade's light: {} with no Shade; else "dark", "falling" (0..1000 to
## the next Lights Out's dark, -1 none), "dark_left" (NB4b: ticks until the dark lifts, -1 none), "light_m" (the
## player's circle), "lamp_m", "lamp_ticks", "lamps" ([{pos, lit, left, frac}]), "boss" (its actor index) and
## "boss_lit" (hittable) (BossShade.state).
func boss_light() -> Dictionary:
	return BossShade.state(_w)


## v0.8.0 FB2 (FINAL_BOSS.md F5): boss i's Cross: {} or {"winding", "window", "progress", "arms" ([from, to, hit] per
## beam), "angle", "half_width", "way", "quarter", "speed", "bolt" ({} or {"from", "to", "angle", "progress",
## "shard"})} (BossPrism.state): the spin-up's aim lines, the turning beams, the window, the bolt's aim line.
## v0.8.0 PR (O84): no "orb_shard" (a Cross fires no orbs).
func boss_cross(i: int) -> Dictionary:
	return BossPrism.state(_w, i)


## v0.8.0 FB2: boss i's orbiting shards' places now (empty for a body without shards).
func boss_shards(i: int) -> PackedVector2Array:
	if i < 0 or i >= _w.actors.size() or not BossAi.is_boss_kind(_w.actors.kinds[i]):
		return PackedVector2Array()
	if BossAi.entry_of(_w, i) < 0:
		return PackedVector2Array()
	return BossPrism.shards(_w, i)


## v0.8.0 FB3 (FINAL_BOSS.md F6, F7): the Nemesis (boss i, a mimic body) for the views: {} or {"weapon", "stance",
## "dashing", "dash_dir", "echo", "mirror", "hit", "hit_cap", "cards" (each {"code", "level", "card_id", "arc",
## "arc_half", "arc_reach_m", "arc_strikes", "volley", "shots", "circle", "back", "split", "look", "blast", "blast_m"}),
## "casting" (the card index it casts now, -1 none), "cast_progress"} (BossNemesis.state).
func nemesis(i: int) -> Dictionary:
	if i < 0 or i >= _w.actors.size() or not BossAi.is_boss_kind(_w.actors.kinds[i]):
		return {}
	if BossAi.entry_of(_w, i) < 0:
		return {}
	return BossNemesis.state(_w, i)


## v0.8.0 FB2 (F7): the final fight's measured damage per second (the meter's last `seconds`, at most what it holds)
## in thousandths, and how many seconds that is: [dps × 1000, seconds] ([0, 0] outside the fight).
func final_dps(seconds: int = FinalFight.DPS_SECONDS) -> PackedInt32Array:
	if _w.final_fight == null:
		return PackedInt32Array([0, 0])
	var m := _w.final_fight.measured(seconds)
	return PackedInt32Array([m[0] * 1000 / maxi(1, m[1]) if m[1] > 0 else 0, m[1]])


## v0.8.0 BS2 (S6): the Foundry's molten floor down now: [rect (sim plane), the tick it was laid, the tick it cools]
## each.
func boss_lava() -> Array:
	var out := []
	var bs := _w.bosses
	for k in bs.lava_x.size():
		out.append([BossLava.lava_rect(bs, k), bs.lava_from[k], bs.lava_until[k]])
	return out


## v0.8.0 BS2 (S6): the meltdowns, each {"centre", "radius" (molten beyond it; INF while it only glows: the melt
## attack's windup), "next" (the radius it melts to next), "warn" (0..1000 while the next step glows, else -1),
## "bound" (the room, Rect2), "bridge" (bool), "exit" (the bridge's far end), "half" (its half width)}.
func boss_melts() -> Array:
	var out := []
	var shapes := BossLava.melt_shapes(_w)
	for k in shapes.size():
		var m: Array = shapes[k]
		var nx := BossLava.melt_warn(_w, k)
		(
			out
			. append(
				{
					"centre": m[BossLava.MELT_CENTRE],
					"radius": m[BossLava.MELT_R],
					"next": nx[0],
					"warn": nx[1],
					"bound": m[BossLava.MELT_BOUND],
					"bridge": m[BossLava.MELT_HAS_EXIT],
					"exit": m[BossLava.MELT_EXIT],
					"half": m[BossLava.MELT_HALF],
				}
			)
		)
	var i := boss_index()
	var atk := BossAi.attack_of(_w, i) if i >= 0 else null
	if atk != null and atk.move == MOVE_MELT and _w.actors.state[i] == EnemyAi.State.WINDUP:
		out.append(BossLava.melt_windup(_w, i, atk))
	return out


# --- The final boss (v0.8.0 FB1; FinalBoss) ---------------------------------------------------------------------
## The world holds the final boss's fight (the final arena, or the Playground's summon).
func final_fight() -> bool:
	return _w.final_fight != null


## The world is the final arena (the run's last world: the fight and its arrival; v0.9.0 FA: and its approach).
func final_arena() -> bool:
	return (_w.final_fight != null or _w.approach != null) and _w.boss_flow != null


## The fight's name key (the boss bar's title over its segments; RunTable.final_name_key), &"" without one.
func final_name_key() -> StringName:
	return _w.final_fight.name_key if _w.final_fight != null else &""


## The body fighting now (0 = the first), or -1 without a fight.
func final_phase() -> int:
	return _w.final_fight.phase if _w.final_fight != null else -1


## How many bodies the fight has (its boss bar's segments).
func final_phases() -> int:
	return _w.final_fight.tables.size() if _w.final_fight != null else 0


## Segment k's name key (its body's boss name).
func final_segment_name_key(k: int) -> StringName:
	var f := _w.final_fight
	if f == null or k < 0 or k >= f.tables.size():
		return &""
	return _w.boss_tables[f.tables[k]].name_key


## Segment k's fill, 0..1000 (FinalBoss.segment_permille).
func final_segment_permille(k: int) -> int:
	return FinalBoss.segment_permille(_w, k)


## 0..1000 through the shatter between two bodies (0 when none runs).
func final_shatter_permille() -> int:
	return FinalBoss.shatter_permille(_w)


func final_shattering() -> bool:
	return FinalBoss.shattering(_w)


## v0.9.5 BH6 (BOSSES_HARD.md HC4, HC5): the Fallen's interphase while it is vanished or returning, else {}: "stage"
## (2 vanished, 3 returning), "set" (0 rays, 1 rain, 2 lights out), "t", "ticks", "center", "radius", "beams", "erupts",
## "lines", "points", "ret" (BossInterphase.state).
func final_interphase() -> Dictionary:
	return BossInterphase.state(_w)


## The final fight's centre (where the first body rose; the Fallen slams back down here).
func final_home() -> Vector2:
	return _w.final_fight.home if _w.final_fight != null else Vector2.ZERO


## The Fallen's interphases that have begun (a bitmask: bit 0 the first) and the one running now (0 none).
func final_interphases_done() -> int:
	return _w.final_fight.ip_done if _w.final_fight != null else 0


## The last body fell (the fight is won).
func final_won() -> bool:
	return _w.final_fight != null and _w.final_fight.won


## The final arena's radius (m, the wall ring's inner face; 0 elsewhere).
func final_arena_radius() -> float:
	return FinalArena.radius_of(_w.floor_layout) if final_arena() else 0.0


# --- The final approach (v0.9.0 FA; FinalApproach) ---------------------------------------------------------------
## The world is the final approach (the stair causeway, the plateau, the pylons; the fight once the buildup ended).
func final_approach() -> bool:
	return _w.approach != null


## Its state (APPROACH_*; -1 without one).
func approach_state() -> int:
	return _w.approach.state if _w.approach != null else -1


func approach_pylon_count() -> int:
	return _w.floor_layout.pylons.size() if _w.approach != null else 0


func approach_pylon_pos(k: int) -> Vector2:
	return _w.floor_layout.pylons[k]


## Pylon k is switched on.
func approach_pylon_lit(k: int) -> bool:
	return _w.approach != null and _w.approach.lit[k] == 1


## How many pylons are on.
func approach_pylons_lit() -> int:
	return _w.approach.lit_count() if _w.approach != null else 0


## The tick pylon k was switched on (-1 not yet).
func approach_pylon_tick(k: int) -> int:
	return _w.approach.lit_tick[k] if _w.approach != null else -1


## The unlit pylon the interact press would switch on now, or -1 (the HUD's prompt).
func approach_pylon_in_reach() -> int:
	if _w.approach == null or _w.player_dead():
		return -1
	return _w.approach.in_reach(_w)


## 0..1 through the buildup (after the second pylon), -1 outside it.
func approach_buildup_progress() -> float:
	return _w.approach.buildup_progress(_w.tick) if _w.approach != null else -1.0


## The buildup's length in ticks.
func approach_buildup_ticks() -> int:
	return _w.approach.buildup_ticks if _w.approach != null else 0


## The walls of light stand (the buildup ended and the fight began).
func approach_walls_up() -> bool:
	return _w.approach != null and _w.approach.state == FinalApproach.State.FIGHT


## The tick the walls rose and the fight began (-1 not yet).
func approach_fight_tick() -> int:
	return _w.approach.fight_tick if _w.approach != null else -1


func approach_light_wall_count() -> int:
	return _w.floor_layout.light_walls.size() if _w.approach != null else 0


func approach_light_wall(k: int) -> Obb:
	return _w.floor_layout.light_walls[k]


## The altar at the plateau's centre (where the boss rises), the causeway's foot and top.
func approach_altar_pos() -> Vector2:
	return _w.floor_layout.altar_pos if _w.approach != null else Vector2.ZERO


func approach_causeway_foot() -> Vector2:
	return _w.floor_layout.causeway_foot if _w.approach != null else Vector2.ZERO


func approach_causeway_top() -> Vector2:
	return _w.floor_layout.causeway_top if _w.approach != null else Vector2.ZERO


## Half the causeway's width (m, wall face to wall face).
func approach_causeway_half_width() -> float:
	return _w.floor_layout.causeway_half_w if _w.approach != null else 0.0


## The tick the current body began (its rise).
func final_phase_tick() -> int:
	return _w.final_fight.phase_tick if _w.final_fight != null else -1


## v0.8.0 N2 (owner O41, O42, O52; FinalPace.state): the current body's pace and The Fallen's mimic window: {} outside a
## final fight, else {"paced" (its HP set from the meter), "dps" (the measured damage per second it was set from),
## "seconds" (how long it lasts at that rate), "budget" (the damage it may take now: the rate cap's bucket), "capped"
## (the bucket is empty: hits land for nothing until it refills), "window" (FinalPace.Mimic: OFF, WARN, ON),
## "window_left" and "window_len" (ticks of the window state now), "nerf" (your damage on it per mille, in a window),
## "copying" (the attack in progress copies your build)}.
func final_pace() -> Dictionary:
	if _w.final_fight == null:
		return {}
	var out := FinalPace.state(_w)
	if not out.is_empty():
		out["capped"] = FinalPace.table(_w).pace and _w.final_fight.pace_budget < 1000
	return out


## v0.8.0 N2: The Fallen's mimic window now (FinalPace.Mimic: 0 off, 1 the warning, 2 on).
func fallen_window() -> int:
	return FinalPace.window(_w) if _w.final_fight != null else FALLEN_OFF


## The death recap's cause key when a boss killed the player (its attack's line), else &"".
func killer_cause_key() -> StringName:
	return BossAi.cause_key(_w)


# --- Boss challenge (v0.3.0 BX) ----------------------------------------------------------------------------------
## How far boss i has risen, 0..1000: state ticks over BossAi.INTRO_TICKS while it rises, then 1000 (L22: the boss
## bar fills over exactly this).
func boss_intro_permille(i: int) -> int:
	if _w.actors.state[i] != EnemyAi.State.SPAWN:
		return 1000
	return clampi(_w.actors.state_t[i] * 1000 / maxi(1, _w.tuning.boss_intro_ticks), 0, 1000)


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


# --- Rewards (v0.3.0 E) -------------------------------------------------------------------------------------
func shards() -> int:
	return _w.shards


## v0.5.5 EC (owner Q-S4): shards the portal left behind on the way to this floor (half of the unspent ones).
func shards_left_behind() -> int:
	return _w.shards_left_behind


func item_rarity(item_index: int) -> int:
	return _w.item_tables[item_index].rarity


func reward_count() -> int:
	return _w.rewards.size()


func reward_id(i: int) -> int:
	return _w.rewards.ids[i]


func reward_pos(i: int) -> Vector2:
	return _w.rewards.pos(i)


## REWARD_ALTAR, REWARD_CHEST or (v0.5.5 AR) REWARD_LEGENDARY.
func reward_kind(i: int) -> int:
	return _w.rewards.kind[i]


## Shards to open (0 for an altar), under the prices curse (v0.5.0 EV).
func reward_price(i: int) -> int:
	return Rewards.price_of(_w, i)


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


## v0.8.0 N8 (owner O62): what taking card `code` changes, old → new (CardForecast: the take's own steps; on the
## open choice's reward).
func card_forecast(code: int) -> Dictionary:
	return CardForecast.of(_w, code, choice_reward())


## v0.8.0 N7 (owner O61): the open choice is a chest's dealt card (no choice: any answer takes it).
func choice_dealt() -> bool:
	var i := choice_reward()
	return i >= 0 and _w.rewards.rolled[i] == RewardStore.DEALT


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


# --- Ice (v0.7.5 NB1, Frozen Shore) ---------------------------------------------------------------------------
## The floor's ice patches (none on other biomes), for the stage, and whether the hero stands on one now.
func ice_patch_count() -> int:
	return _w.ice.rects.size() if _w.ice != null else 0


func ice_patch(i: int) -> Rect2:
	return _w.ice.rects[i]


func player_on_ice() -> bool:
	return IcePatches.on_ice(_w)


## v0.7.5 NB2: which surface the floor's patches are (&"ice", Starfall's &"starglow"; &"" for none): the stage draws
## each its own way. The patches themselves are ice_patch_count / ice_patch either way.
func surface_kind() -> StringName:
	return _w.ice.kind if _w.ice != null else &""


# --- Engines and combos (v0.3.0 G) --------------------------------------------------------------------------
## Shock, bleed and frost stacks on actor i, and whether it is frozen.
func shock_stacks(actor_i: int) -> int:
	return _w.actors.shock_stacks[actor_i]


func bleed_stacks(actor_i: int) -> int:
	return _w.actors.bleed_stacks[actor_i]


func frost_stacks(actor_i: int) -> int:
	return _w.actors.frost_stacks[actor_i]


## Venom poison stacks on actor i (0 = not poisoned).
func poison_stacks(actor_i: int) -> int:
	var a := _w.actors
	return a.poison_stacks[actor_i] if actor_i < a.poison_stacks.size() else 0


func actor_frozen(actor_i: int) -> bool:
	return Engines.frozen(_w, actor_i)


## v0.9.5 EE2: Fire's Heat sync (`fire`) or Frost's Shatter runs (the card is Lv 3): the status pip's "+" shows.
func element_plus(fire: bool) -> bool:
	return (
		ElementLevelsFsf.level(_w, ElementLevelsFsf.FIRE if fire else ElementLevelsFsf.FROST) >= 3
	)


## Stacks at which shock discharges and frost freezes (0 = that engine isn't owned).
func shock_threshold() -> int:
	return _w.item_mods.shock_threshold


func frost_threshold() -> int:
	return _w.item_mods.frost_threshold


## Bulwark: guard charges stored now.
func guard_charges() -> int:
	return _w.guard_charges


## Owned combos in unlock order, as indices into the combo tables.
func combos_owned() -> PackedInt32Array:
	return _w.combos_owned


func combo_table_count() -> int:
	return _w.combo_tables.size()


func combo_id(combo_index: int) -> StringName:
	return _w.combo_tables[combo_index].id


## Locale keys (tr() them in the view).
func combo_name_key(combo_index: int) -> StringName:
	return _w.combo_tables[combo_index].name_key


func combo_desc_key(combo_index: int) -> StringName:
	return _w.combo_tables[combo_index].desc_key


## The two item ids a combo needs.
func combo_item_ids(combo_index: int) -> Array[StringName]:
	var c := _w.combo_tables[combo_index]
	if c.ability_a >= 0:  # v0.4.0 AB: an ability combo's two abilities
		return [_w.ability_tables[c.ability_a].id, _w.ability_tables[c.ability_b].id]
	return [_w.item_tables[c.item_a].id, _w.item_tables[c.item_b].id]


## v0.9.5 EE3 (ElementPairs): a pair's id, text keys and its two element cards (the banner), the pairs on now (bit X
## each), and the Toxic Fumes clouds: their centres, the radius they share and the ticks each has left.
func pair_id(x: int) -> StringName:
	return ElementPairs.IDS[x]


func pair_name_key(x: int) -> StringName:
	return ElementPairs.name_key(x)


func pair_desc_key(x: int) -> StringName:
	return ElementPairs.desc_key(x)


func pair_card_ids(x: int) -> Array[StringName]:
	return ElementPairs.card_ids(x)


func pair_mask() -> int:
	return _w.pair_mask


func pair_clouds() -> Dictionary:
	var pos := PackedVector2Array()
	var left := PackedInt32Array()
	var c := _w.pair_clouds
	for k in range(0, c.size(), 3):
		pos.append(Vector2(c[k] / 1000.0, c[k + 1] / 1000.0))
		left.append(c[k + 2])
	var r := _w.pair_table.cloud_radius_m if _w.pair_table != null else 0.0
	var life := _w.pair_table.cloud_ticks if _w.pair_table != null else 1
	return {"pos": pos, "left": left, "radius": r, "life": life}


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


## The last win: its tick (-1 = none yet on this floor) and its stat (an index below gamble_stat_count()).
func gamble_tick() -> int:
	return _w.gamble_tick


func gamble_last_stat() -> int:
	return _w.gamble_last_stat


## The last refused use (too poor, spent, or every stat capped): its tick, -1 when none.
func gamble_denied_tick() -> int:
	return _w.gamble_denied_tick


func gamble_uses() -> int:
	return _w.gamble_uses


## v0.8.0 N14 (owner O72): the shrine's wins on this floor and how many it grants (the sim's own numbers), whether it
## is spent (blocked), the chance a use fails (per mille) and the last failed use's tick (-1 = none).
func gamble_wins() -> int:
	return Gamble.wins(_w)


func gamble_max_wins() -> int:
	return Gamble.max_wins(_w)


func gamble_spent() -> bool:
	return Gamble.spent(_w)


func gamble_fail_permille() -> int:
	return Gamble.fail_permille(_w)


func gamble_fail_tick() -> int:
	return _w.gamble_fail_tick


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


func tier_progress() -> float:  # v0.3.0 UI (L23): 0 .. <1 through the danger tier
	if _w.spawner == null:
		return 0.0
	return float(_w.spawner.danger_permille(_w.run_ticks) % 1000) / 1000.0  # v0.4.0 TU: the curve's


# --- Minimap (v0.3.0 MM) ------------------------------------------------------------------------------------
## The room whose interior holds p (-1 inside a wall, a doorway, or without a floor).
func floor_room_of(p: Vector2) -> int:
	return _w.floor_layout.room_of(p) if _w.floor_layout != null else -1


func floor_start_room() -> int:
	return _w.floor_layout.start_room if _w.floor_layout != null else -1


## The room the portal gate stands in (-1 without a floor).
func floor_portal_room() -> int:
	return _w.floor_layout.portal_room if _w.floor_layout != null else -1


## v0.6.1 SD: where the hero starts the floor (the player's position without a floor).
func floor_start_pos() -> Vector2:
	return _w.floor_layout.start_pos if _w.floor_layout != null else _w.player_pos()


## v0.6.1 SD: every open spot enemies may spawn on (the floor's per-room spots and the world's list), so the
## dressing keeps off them. Read only, for presentation.
func spawn_spots() -> PackedVector2Array:
	var out := PackedVector2Array(_w.spawn_points)
	if _w.floor_layout != null:
		for pts in _w.floor_layout.spawn_points:
			out.append_array(pts)
	return out


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


## v0.4.0 AB: Arc Field, Frost Nova, the fire patches and the ability combos' moments (ElementAbilities.fx).
## A fire patch's kind in element_fx()["fire_kind"]: FIRE_NAPALM is Napalm Drone's (else Flame Trail's).
func element_fx() -> Dictionary:
	return ElementAbilities.fx(_w)


## v0.4.0 AB: the Overrun room (Overrun.read: active, room, doors, inside, entered, kills, needed, cleared,
## clear_tick, bonus, reward_id, boosted).
func overrun() -> Dictionary:
	return Overrun.read(_w)


## v0.6.0 MX2: the build (BuildSlots.read): the modifier slots in pick order (code, id, name_key, type, level), the
## slot count (max), and the pending swap's card (swap_code, -1 for none) and source.
func build() -> Dictionary:
	return BuildSlots.read(_w)


## v0.6.5 WN1 (Wand.read): the wand in slot order: the weapon (&"gun" / &"blade"), the slot count, each card (code,
## id, name_key, type, level, trigger: -1 or the AttackSpec.Trigger it cuts on) and the cuts (the trigger slots).
func wand() -> Dictionary:
	return Wand.read(_w)


## v0.6.5 WN1 (Wand.describe): the wand's plain-words read-back as translation keys and their arguments (the Build
## page renders it, WN2).
func wand_read_back() -> Array[Dictionary]:
	return Wand.describe(Wand.read(_w))


## v0.6.5 WN2: a wand read (wand()) with the card in slot `from` moved to slot `to`: the rule the sim's reorder
## applies (Wand.moved_read), so the Build page's preview is the outcome it will get (EI-07).
static func wand_moved(wand_read: Dictionary, from: int, to: int) -> Dictionary:
	return Wand.moved_read(wand_read, from, to)


## v0.6.5 WN2: the plain-words read-back of any wand read (Wand.describe), e.g. a preview from wand_moved.
static func wand_describe(wand_read: Dictionary) -> Array[Dictionary]:
	return Wand.describe(wand_read)


## v0.8.0 MR (owner O91): per card of a wand read, why it can't act where it sits (Wand.flags: a translation key, or
## &""): the tiles dim such a card and show the reason.
static func wand_flags(wand_read: Dictionary) -> Array[StringName]:
	return Wand.flags(wand_read)


## v0.6.5 WN2: describe()'s lines in words (Wand.render; `translate` is the view's tr).
static func wand_render(lines: Array[Dictionary], translate: Callable) -> String:
	return Wand.render(lines, translate)


## v0.6.5 WN2: the wand moves (pick values) that turn the card order `from` into `to` (Wand.plan_moves).
static func wand_plan_moves(from: PackedInt32Array, to: PackedInt32Array) -> PackedInt32Array:
	return Wand.plan_moves(from, to)


## v0.6.5 WN2: a wand read with its incoming card swapped in for slot `leave` and moved to `at` (Wand.swapped_read:
## the rules the sim's swap answer and reorder apply), and the picks that do it (Wand.swap_picks).
static func wand_swapped(wand_read: Dictionary, leave: int, at: int) -> Dictionary:
	return Wand.swapped_read(wand_read, leave, at)


static func wand_swap_picks(leave: int, at: int) -> PackedInt32Array:
	return Wand.swap_picks(leave, at)


## v0.6.5 WN2: whether a move from slot `from` to slot `to` changes a wand of `n` cards (Wand.can_move).
static func wand_can_move(n: int, from: int, to: int) -> bool:
	return Wand.can_move(n, from, to)


## v0.6.0 MX2: a swap choice is open (a new modifier with the six slots full waits for its slot or a skip).
func swapping() -> bool:
	return BuildSlots.swapping(_w)


## v0.6.0 MX2: the build's weapon (the starting weapon ability's id, &"" outside a build) and the utility pick's id.
func weapon_id() -> StringName:
	for idx in _w.ability_owned:
		if _w.ability_tables[idx].start_weapon != 0:
			return _w.ability_tables[idx].id
	return &""


func utility_id() -> StringName:
	for idx in _w.ability_owned:
		if _w.ability_tables[idx].is_utility():
			return _w.ability_tables[idx].id
	return &""


## A card code's face (Offers.info: type CARD_*, id, kind, name_key, desc_key, rarity 0..2, level, amount).
func card_info(code: int) -> Dictionary:
	return Offers.info(_w, code)


## Crit chance and multiplier now, per mille (Stats).
func crit_chance_permille() -> int:
	return Stats.crit_chance(_w)


func crit_mult_permille() -> int:
	return Stats.crit_mult(_w)


# --- v0.5.0 EV: event rooms, curses and threat T (Events, Curses) ----------------------------------------------


func event_count() -> int:
	return _w.ev.size()


func event_pos(k: int) -> Vector2:
	return _w.ev.pos(k)


func event_room(k: int) -> int:
	return _w.ev.room[k]


## v0.8.0 N17 (owner O75): the curse room's altar (a pedestal index), or -1 on a floor without a curse room.
func event_curse_altar() -> int:
	return _w.ev.curse_k


## v0.8.0 N17: the curse room (a room index), or -1.
func event_curse_room() -> int:
	return _w.ev.room[_w.ev.curse_k] if _w.ev.curse_k >= 0 else -1


## v0.8.0 N19 (O80): whether the curse room is a room of its own (CurseRoom.furnish; false on a floor built under
## N17's rules, whose curse room kept its interior).
func curse_room_furnished() -> bool:
	return _w.floor_layout != null and _w.floor_layout.curse_room >= 0


## v0.8.0 N19: the curse room's crystal clusters as [centre: Vector2, half side (m)] (the altar's footprint left out).
func curse_room_crystals() -> Array:
	var out: Array = []
	if _w.floor_layout == null or _w.floor_layout.curse_room < 0:
		return out
	var solids := _w.floor_layout.curse_solids
	for i in range(1, solids.size()):
		out.append([solids[i].center, solids[i].half.x])
	return out


## EVENT_READY, EVENT_ACTIVE (a fight or a defence running) or EVENT_DONE.
func event_state(k: int) -> int:
	return _w.ev.state[k]


func event_name_key(k: int) -> StringName:
	return Events.table(_w, k).name_key


func event_desc_key(k: int) -> StringName:
	return Events.table(_w, k).desc_key


## The pedestal the interact button would open now (the sim's own choice), or -1.
func event_in_reach() -> int:
	return Events.nearest(_w) if not choosing() else -1


## True while an event panel is open (the world waits for the choice).
func event_open() -> bool:
	return _w.ev.open >= 0


func event_open_index() -> int:
	return _w.ev.open


func event_choice_count(k: int) -> int:
	return Events.table(_w, k).choice_count()


func event_choice_label(k: int, c: int) -> StringName:
	return Events.table(_w, k).labels[c]


## EVENT_COST_*.
func event_choice_cost(k: int, c: int) -> int:
	return Events.table(_w, k).cost[c]


## The cost's number as shown: percent of max HP (HP, MAX_HP), shards now (SHARDS), enemies (FIGHT), seconds
## (DEFEND); 0 otherwise.
func event_choice_cost_value(k: int, c: int) -> int:
	var t := Events.table(_w, k)
	match t.cost[c]:
		Events.Cost.HP, Events.Cost.MAX_HP:
			return t.cost_amount[c] / 10
		Events.Cost.SHARDS:
			return Events.shard_cost(_w, k, c)
		Events.Cost.DEFEND:
			return t.cost_amount[c] / SimTick.TICKS_PER_SECOND
	return t.cost_amount[c]


## Events.Reward: card rewards show their rolled card (event_choice_card); the rest are EVENT_REWARD_*.
func event_choice_reward(k: int, c: int) -> int:
	return Events.table(_w, k).reward[c]


## The reward's number as shown: percent of Overclock damage, or shards (x the floor).
func event_choice_reward_value(k: int, c: int) -> int:
	var t := Events.table(_w, k)
	if t.reward[c] == Events.Reward.OVERCLOCK:
		return t.reward_amount[c] / 10
	return t.reward_amount[c] * maxi(1, _w.floor_index)


## The card the choice gives (a card code for card_info), or -1 (not a card, or not rolled yet).
func event_choice_card(k: int, c: int) -> int:
	return _w.ev.roll_card[k * Events.MAX_CHOICES + c]


## The curse the choice carries (an index for curse_* reads), or -1.
func event_choice_curse(k: int, c: int) -> int:
	return _w.ev.roll_curse[k * Events.MAX_CHOICES + c]


## EVENT_BLOCK_OK, or why the sim would refuse the choice now.
func event_choice_block(k: int, c: int) -> int:
	return Events.block(_w, k, c)


## The tick a fight or defence last finished (-1 none).
func event_done_tick() -> int:
	return _w.ev.done_tick


## The pedestal being defended (-1 none), the share held (0..1) and the ring's radius.
func event_defend() -> int:
	return _w.ev.defend


func event_defend_progress() -> float:
	return float(_w.ev.defend_ticks) / maxf(1.0, _w.ev.defend_total)


func event_defend_radius_m() -> float:
	return _w.ev.rules.defend_radius_m


## Actor i is an elite (v0.9.0 EL: one of the three archetypes).
func actor_elite(i: int) -> bool:
	return EliteAi.is_elite_kind(_w.actors.kinds[i])


# --- v0.6.0 CU: core theft and the trade-off curses ---------------------------------------------------------------
## The card actor i's core holds (an Offers code for card_info), or -1 when it carries none.
func actor_core(i: int) -> int:
	var k := CoreTheft.entry_of(_w, _w.actors.ids[i])
	return _w.cores.card[k] if k >= 0 else -1


## Actor i carries a boss's (legendary) core.
func actor_core_boss(i: int) -> bool:
	var k := CoreTheft.entry_of(_w, _w.actors.ids[i])
	return k >= 0 and _w.cores.boss[k] == 1


## Actor i's steal window: ticks left (0 = shut), and its length.
func actor_steal_ticks(i: int) -> int:
	var k := CoreTheft.entry_of(_w, _w.actors.ids[i])
	return _w.cores.window_t[k] if k >= 0 else 0


func steal_window_ticks() -> int:
	return _w.ev.rules.core_window_ticks


## Elite actor i stands staggered (its own stagger; a boss's is boss_staggered).
func actor_core_staggered(i: int) -> bool:
	return CoreTheft.staggered(_w, i)


## The last steal (tick, card); -1 when none yet.
func steal_tick() -> int:
	return _w.cores.steal_tick


func steal_card() -> int:
	return _w.cores.steal_card


## Tunnel Vision: the minimap is off.
func minimap_blind() -> bool:
	return Curses.no_minimap(_w)


## Rooted's last dodge and Brittle's stun (ticks left; the tick it started); -1 when none yet.
func dodge_tick() -> int:
	return _w.cs.dodge_tick


func stun_ticks() -> int:
	return _w.cs.stun_t


func stun_tick() -> int:
	return _w.cs.stun_tick


## Curse c is a trade-off (it has an upside), and its upside's sentence key.
func curse_is_trade_off(c: int) -> bool:
	return c < _w.ev.curses.size() and _w.ev.curses[c].is_trade_off()


func curse_up_desc_key(c: int) -> StringName:
	return _w.ev.curses[c].up_desc_key if c < _w.ev.curses.size() else &""


## The numbers the curse sentences show (CurseLook): the drawback's and the upside's, as text (a percent, a count,
## or seconds for a stun).
func curse_value_text(c: int) -> String:
	if c >= _w.ev.curses.size():
		return ""
	var t := _w.ev.curses[c]
	return _effect_text(t.effect, t.amount)


func curse_up_value_text(c: int) -> String:
	if c >= _w.ev.curses.size() or not _w.ev.curses[c].is_trade_off():
		return ""
	var t := _w.ev.curses[c]
	return _effect_text(t.up_effect, t.up_amount)


static func _effect_text(effect: int, amount: int) -> String:
	match effect:
		Curses.Effect.EXTRA_ENEMY, Curses.Effect.NO_DASH, Curses.Effect.NO_MINIMAP:
			return str(amount)
		Curses.Effect.HIT_STUN:
			return str(snappedf(float(amount) / SimTick.TICKS_PER_SECOND, 0.01))
	return str(amount / 10)


## Threat T now (the curses held) and the run's peak so far (PD-05; M-THREAT).
func threat() -> int:
	return Curses.threat(_w)


func threat_peak() -> int:
	return maxi(_w.threat_peak, Curses.threat(_w))


## The curses held, in the order taken (curse indices).
func curses_owned() -> PackedInt32Array:
	return _w.curses_owned


func curse_name_key(c: int) -> StringName:
	return _w.ev.curses[c].name_key if c < _w.ev.curses.size() else &""


func curse_desc_key(c: int) -> StringName:
	return _w.ev.curses[c].desc_key if c < _w.ev.curses.size() else &""


## The last curse taken (tick, curse) and lifted (tick, curse); -1 when none yet.
func curse_tick() -> int:
	return _w.ev.curse_tick


func curse_last() -> int:
	return _w.ev.curse_last


func cleanse_tick() -> int:
	return _w.ev.cleanse_tick


func cleanse_last() -> int:
	return _w.ev.cleanse_last


## The curse on card k of the open 3-card choice (a cursed chest card), or -1.
func choice_curse(k: int) -> int:
	return Curses.offer_curse(_w, _w.choosing, k) if choosing() else -1


# --- Shop (v0.5.0 SH; Shop) --------------------------------------------------------------------------------------
## The floor has a shop terminal.
func has_shop() -> bool:
	return Shop.present(_w)


func shop_pos() -> Vector2:
	return _w.shop.pos


func shop_room() -> int:
	return _w.shop.room


## The terminal's facing (1/4096 turns; toward its room's first doorway).
func shop_angle() -> int:
	return _w.floor_layout.shop_angle if _w.floor_layout != null else 0


## v0.8.0 SR: the shop stands in its biome's shop room, a tent stall (false: the terminal).
func shop_stall() -> bool:
	return _w.floor_layout != null and _w.floor_layout.shop_layout != &"" and Shop.present(_w)


## Where you stand to use the shop (ShopPlacement.front: in front of the terminal's screen or the stall's counter).
func shop_front() -> Vector2:
	return ShopPlacement.front(_w.floor_layout) if _w.floor_layout != null else _w.shop.pos


## v0.8.0 SR: the shop room's layout id (&"" for the terminal).
func shop_layout() -> StringName:
	return _w.floor_layout.shop_layout if _w.floor_layout != null else &""


## v0.8.0 SR: the shop room's own pieces (the stall, its goods, sacks and lanterns) for ShopStallView.
func shop_piece_count() -> int:
	return _w.floor_layout.shop_props.size() if shop_stall() else 0


## Piece i: {"piece": StringName, "pos": Vector2, "angle": int (1/4096), "size": Vector2 (m: x along the angle's
## direction, y across it), "height": float (m; 0 = its own), "solid": bool, "on": the piece a drawn one stands on
## (&"" for none), "on_height": that piece's height (m; 0 = the kit's own, -1 for none)}.
func shop_piece(i: int) -> Dictionary:
	var p: Array = _w.floor_layout.shop_props[i]
	return {
		"piece": p[0],
		"pos": p[1],
		"angle": p[2],
		"size": p[3],
		"height": p[4],
		"solid": p[5],
		"on": p[6],
		"on_height": p[7],
	}


func shop_in_reach() -> bool:
	return Shop.in_reach(_w)


## The shop's panel is open (the world waits on it).
func shop_open() -> bool:
	return _w.shop.open


## The last refused shop action's tick (-1 when none).
func shop_denied_tick() -> int:
	return _w.shop.denied_tick


## Everything the shop panel shows (Shop.read): stock (code, sold, price, can_apply, affordable), heal (price,
## amount, used), reroll (price, rerolls), sell (kind SHOP_SELL_*, ref, code, refund) and the last action / refusal.
func shop() -> Dictionary:
	return Shop.read(_w)


# --- The shared interactables (v0.9.0 IX; Interactables) ---------------------------------------------------
## The registry's entry the interact press would go to now, or -1: none in reach, the hero dead, a choice open, or a
## system earlier in World.step's order (a reward, an event, the shop, the shrine, the boss door) takes the press.
func interactable_in_reach() -> int:
	if _w.player_dead() or choosing():
		return -1
	if reward_in_reach() >= 0 or event_in_reach() >= 0 or shop_in_reach() or gamble_in_reach():
		return -1
	if boss_door_in_reach():
		return -1
	return _w.interactables.in_reach(player_pos())


## The shared prompt's string key (&"" when the press would reach no interactable).
func interact_prompt_key() -> StringName:
	var i := interactable_in_reach()
	if i < 0:
		return &""
	return Interactables.prompt_key(_w, i)


## v0.9.0 SH, HF: the numbers formatted into the shared prompt (a shrine's cost, the fountain's heal); [] for none.
func interact_prompt_args() -> Array:
	var i := interactable_in_reach()
	if i < 0:
		return []
	return Interactables.prompt_args(_w, i)


func interactable_count() -> int:
	return _w.interactables.size()


func interactable_kind(i: int) -> int:
	return _w.interactables.kind[i]


func interactable_pos(i: int) -> Vector2:
	return _w.interactables.pos[i]


## Entry i's state (a switch: 0 off, 1 on).
func interactable_state(i: int) -> int:
	return _w.interactables.state[i]


func interactable_enabled(i: int) -> bool:
	return _w.interactables.enabled[i] == 1


## The tick entry i was last pressed (-1 never).
func interactable_press_tick(i: int) -> int:
	return _w.interactables.press_tick[i]


# --- The timed door (v0.9.0 TD; TimedDoor) -----------------------------------------------------------------
## The floor has a timed door to a secret room.
func has_timed_door() -> bool:
	return _w.timed != null


## Its state (TIMED_*; -1 without one).
func timed_door_state() -> int:
	return _w.timed.state if _w.timed != null else -1


## The doorway it shuts: its centre, the direction from the host into the secret room (1/4096 turns), its slab.
func timed_door_center() -> Vector2:
	return _w.floor_layout.door_centers[_w.floor_layout.timed_door]


func timed_door_angle() -> int:
	var f := _w.floor_layout
	var a := f.door_angles[f.timed_door]
	return a if f.door_rooms[f.timed_door].x == f.timed_host else (a + 2048) % 4096


func timed_door_slab() -> Obb:
	return _w.floor_layout.timed_door_wall


func timed_door_width() -> float:
	return _w.floor_layout.door_widths[_w.floor_layout.timed_door]


func timed_door_depth() -> float:
	return _w.floor_layout.door_depths[_w.floor_layout.timed_door]


## The ticks the door opened and shut last (-1 not yet), its timer and the ticks left on it (0 unless open).
func timed_open_tick() -> int:
	return _w.timed.open_tick if _w.timed != null else -1


func timed_shut_tick() -> int:
	return _w.timed.shut_tick if _w.timed != null else -1


func timed_timer_ticks() -> int:
	return _w.timed.open_ticks if _w.timed != null else 0


func timed_ticks_left() -> int:
	return _w.timed.ticks_left(_w.tick) if _w.timed != null else 0


## How many times the door has opened (0: never, the secret room still unseen).
func timed_opened() -> int:
	return _w.timed.opened if _w.timed != null else 0


## The door's switches: their count and each one's registry entry (interactable_pos, interactable_state).
func timed_switch_count() -> int:
	return _w.timed.switches.size() if _w.timed != null else 0


func timed_switch_entry(k: int) -> int:
	return _w.timed.switches[k]


## v0.9.5 TS: the lever inside the secret room (its registry entry, -1 without one).
func timed_lever_entry() -> int:
	return _w.timed.lever if _w.timed != null else -1


## The secret room and the room before it (the switches' room), -1 without a door.
func timed_room() -> int:
	return _w.floor_layout.timed_room if _w.timed != null else -1


func timed_host() -> int:
	return _w.floor_layout.timed_host if _w.timed != null else -1


## v0.9.0 TD (owner Q23: "hidden room should not appear or be visible until you open it"): the room not drawn, lit or
## shown on the minimap yet (-1 none): the secret room until its door first opens.
func hidden_room() -> int:
	if _w.timed == null or _w.timed.opened > 0:
		return -1
	return _w.floor_layout.timed_room


## The hidden room's cells in metres, grid line to grid line (Rect2() for none).
func hidden_room_cells() -> Rect2:
	return room_cells_rect(hidden_room())


## v0.9.0 RA (Q23; Secrets.hidden_rooms): every secret room not drawn, lit or shown on the minimap yet (the timed door's
## until it first opens, the rune puzzle's until it is solved), ascending by kind.
func hidden_rooms() -> PackedInt32Array:
	return Secrets.hidden_rooms(_w)


## Room `room`'s cells in metres, grid line to grid line (Rect2() for -1).
func room_cells_rect(room: int) -> Rect2:
	if room < 0:
		return Rect2()
	return _w.floor_layout.cell_rect(_w.floor_layout.room_cells[room])


## Reward i stands in a hidden room (not drawn yet).
func reward_hidden(i: int) -> bool:
	var rooms := hidden_rooms()
	return not rooms.is_empty() and rooms.has(_w.floor_layout.room_of(_w.rewards.pos(i)))


# --- The rune puzzle (v0.9.0 RA; RuneAlignment) ----------------------------------------------------------------
## The floor has a rune puzzle.
func has_rune_puzzle() -> bool:
	return _w.runes != null


## Its hidden room and the room before it (the pillars' room), -1 without one.
func rune_room() -> int:
	return _w.floor_layout.rune_room if _w.runes != null else -1


func rune_host() -> int:
	return _w.floor_layout.rune_host if _w.runes != null else -1


## The pillars: their count, each one's registry entry (interactable_pos, interactable_press_tick), the face it shows
## (0..3) and the face the carving asks of it.
func rune_pillar_count() -> int:
	return _w.runes.pillars.size() if _w.runes != null else 0


func rune_pillar_entry(k: int) -> int:
	return _w.runes.pillars[k]


func rune_face(k: int) -> int:
	return _w.interactables.state[_w.runes.pillars[k]]


func rune_target(k: int) -> int:
	return _w.runes.target[k]


## Solved (every pillar on its target), and the tick it was (-1 not yet).
func rune_solved() -> bool:
	return _w.runes != null and _w.runes.solved == 1


func rune_solve_tick() -> int:
	return _w.runes.solve_tick if _w.runes != null else -1


## The sealed doorway: its centre, the direction from the host into the hidden room (1/4096 turns), width, depth.
func rune_door_center() -> Vector2:
	return _w.floor_layout.door_centers[_w.floor_layout.rune_door]


func rune_door_angle() -> int:
	var f := _w.floor_layout
	var a := f.door_angles[f.rune_door]
	return a if f.door_rooms[f.rune_door].x == f.rune_host else (a + 2048) % 4096


func rune_door_width() -> float:
	return _w.floor_layout.door_widths[_w.floor_layout.rune_door]


func rune_door_depth() -> float:
	return _w.floor_layout.door_depths[_w.floor_layout.rune_door]


# --- The purple runes (v0.9.0 DP; PurpleRunes) ----------------------------------------------------------------
## The floor has a purple-rune room: its room, its dais's spot and registry entry, whether awakened and when.
func has_purple_runes() -> bool:
	return _w.purple != null


func purple_room() -> int:
	return _w.floor_layout.purple_room if _w.purple != null else -1


func purple_dais_pos() -> Vector2:
	return _w.floor_layout.purple_pos if _w.purple != null else Vector2.ZERO


func purple_dais_entry() -> int:
	return _w.purple.entry if _w.purple != null else -1


func purple_lit() -> bool:
	return _w.purple != null and _w.purple.lit == 1


func purple_lit_tick() -> int:
	return _w.purple.lit_tick if _w.purple != null else -1


## The boss room may show the Deep gate on this floor: it has it now (has_deep_portal), or its purple runes may still
## earn it (its spot is placed). The views build the gate up front; it stands sealed (unseen) until it opens.
func deep_portal_site() -> bool:
	if has_deep_portal():
		return true
	return _w.purple != null and _w.floor_layout != null and _w.floor_layout.has_deep_portal


# --- The destructibles (v0.9.0 DX; Breakables) -----------------------------------------------------------------
## The floor has a cracked wall before a dead end.
func has_cracked_wall() -> bool:
	return _w.breakables != null and _w.breakables.has_crack()


## Its hidden room and the room before it (-1 without one).
func crack_room() -> int:
	return _w.floor_layout.crack_room if has_cracked_wall() else -1


func crack_host() -> int:
	return _w.floor_layout.crack_host if has_cracked_wall() else -1


## The doorway the wall fills: its centre, the direction from the host into the hidden room, width, depth.
func crack_door_center() -> Vector2:
	return _w.floor_layout.door_centers[_w.floor_layout.crack_door]


func crack_door_angle() -> int:
	var f := _w.floor_layout
	var a := f.door_angles[f.crack_door]
	return a if f.door_rooms[f.crack_door].x == f.crack_host else (a + 2048) % 4096


func crack_door_width() -> float:
	return _w.floor_layout.door_widths[_w.floor_layout.crack_door]


func crack_door_depth() -> float:
	return _w.floor_layout.door_depths[_w.floor_layout.crack_door]


## The Skill hits it has left and takes in all, whether it broke, its last hit's and its break's ticks (-1 not yet).
func crack_hp() -> int:
	return _w.breakables.crack_hp if has_cracked_wall() else 0


func crack_max() -> int:
	return _w.breakables.crack_max if has_cracked_wall() else 0


func crack_broken() -> bool:
	return has_cracked_wall() and _w.breakables.crack_broken == 1


func crack_hit_tick() -> int:
	return _w.breakables.crack_hit_tick if has_cracked_wall() else -1


func crack_break_tick() -> int:
	return _w.breakables.crack_break_tick if has_cracked_wall() else -1


## The props (containers and explosive barrels): their count, where each stands, its kind (BREAKABLE_*), whether it
## broke (or blew) and when, and a barrel's fuse (lit tick, -1 not; burning now).
func breakable_count() -> int:
	return _w.breakables.pos.size() if _w.breakables != null else 0


func breakable_pos(i: int) -> Vector2:
	return _w.breakables.pos[i]


func breakable_kind(i: int) -> int:
	return _w.breakables.kind[i]


func breakable_broken(i: int) -> bool:
	return _w.breakables.broken[i] == 1


func breakable_break_tick(i: int) -> int:
	return _w.breakables.break_tick[i]


func breakable_fuse_tick(i: int) -> int:
	return _w.breakables.fuse_tick[i]


func breakable_fusing(i: int) -> bool:
	return _w.breakables.fusing(i)


## The barrels' fuse (ticks) and blast radius (m).
func barrel_fuse_ticks() -> int:
	return _w.breakables.fuse_ticks if _w.breakables != null else 0


func barrel_radius() -> float:
	return _w.breakables.radius_m if _w.breakables != null else 0.0


## v0.9.0 DX (Q29b, hidden rune markings): every secret's doorway (the timed door's, the rune puzzle's, the cracked
## wall's), each {center, angle (from the room before it into the secret room), width, depth}.
func secret_doors() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if has_timed_door():
		out.append(_door_of(_w.floor_layout.timed_door, timed_door_angle()))
	if has_rune_puzzle():
		out.append(_door_of(_w.floor_layout.rune_door, rune_door_angle()))
	if has_cracked_wall():
		out.append(_door_of(_w.floor_layout.crack_door, crack_door_angle()))
	return out


func _door_of(d: int, angle: int) -> Dictionary:
	var f := _w.floor_layout
	return {
		"center": f.door_centers[d],
		"angle": angle,
		"width": f.door_widths[d],
		"depth": f.door_depths[d]
	}


# --- The rune affinity (v0.9.0 RB; Affinities) ------------------------------------------------------------------
## The run's rune affinity's id (&"" for None).
func affinity_id() -> StringName:
	return _w.affinity.table.id if _w.affinity != null else &""


## A5 Guardian: the wards a floor starts with (0: the affinity has none), those still up, and the tick the last one
## broke (-1: none yet).
func affinity_ward_charges() -> int:
	return _w.affinity.table.ward_charges if _w.affinity != null else 0


func affinity_ward() -> int:
	return _w.affinity.ward if _w.affinity != null else 0


func affinity_ward_tick() -> int:
	return _w.affinity.ward_tick if _w.affinity != null else -1


## A2 Storm and A3 Venom: the dash shocks given and the poison jumps made on this floor.
func affinity_shocks() -> int:
	return _w.affinity.shocks if _w.affinity != null else 0


func affinity_jumps() -> int:
	return _w.affinity.jumps if _w.affinity != null else 0


## A4 Astral: how near (m) a secret pulses (0: off), and whether the minimap marks a secret's room once entered.
func affinity_sense_m() -> float:
	return _w.affinity.table.secret_sense_m if _w.affinity != null else 0.0


func affinity_maps_secrets() -> bool:
	return _w.affinity != null and _w.affinity.table.map_secrets


## A4 Astral: every secret on the floor as {pos (its doorway's centre), room (the room that holds its way in), found
## (opened, solved or broken)}: the timed door's, the rune puzzle's, the cracked wall's.
func secret_spots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := _w.floor_layout
	if has_timed_door():
		out.append(
			{"pos": f.door_centers[f.timed_door], "room": timed_host(), "found": timed_opened() > 0}
		)
	if has_rune_puzzle():
		out.append(
			{"pos": f.door_centers[f.rune_door], "room": rune_host(), "found": rune_solved()}
		)
	if has_cracked_wall():
		out.append(
			{"pos": f.door_centers[f.crack_door], "room": crack_host(), "found": crack_broken()}
		)
	return out


# --- The Lockdowns (v0.9.0 LK; Lockdowns) --------------------------------------------------------------------
## The floor has Lockdown rooms.
func has_lockdowns() -> bool:
	return _w.lockdown != null


# --- Shrines and the healing fountain (v0.9.0 SH, HF; Shrines) ------------------------------------------------
## The floor has a shrine of any kind (Fortune is the gamble shrine; Blood and Chaos stand on its site).
func has_shrine_site() -> bool:
	return _w.gamble_id >= 0


## The floor has a Blood or Chaos shrine or a healing fountain (World.shrine).
func has_shrines() -> bool:
	return _w.shrine != null


## The floor's shrine kind (SHRINE_FORTUNE, SHRINE_BLOOD, SHRINE_CHAOS; Fortune also when there is none).
func shrine_kind() -> int:
	return Shrines.kind_of(_w)


## The Blood or Chaos shrine and the fountain now (Shrines.read); {} without either.
func shrine() -> Dictionary:
	return Shrines.read(_w) if _w.shrine != null else {}


## The Lockdowns now (Lockdowns.read: rooms, kinds, the sealed one, its formations, the strikes, those opened).
func lockdown() -> Dictionary:
	return Lockdowns.read(_w)


## Room `room`'s doorways (each {center, angle, width, depth}), for the bars.
func lockdown_doors(room: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _w.floor_layout == null:
		return out
	for d in ArenaRooms.doors_of(_w.floor_layout, room):
		out.append(_door_of(d, _w.floor_layout.door_angles[d]))
	return out


## Puzzle calm (Q22): the hero stands in an unsolved puzzle's room (new packs at a quarter of the rate).
func puzzle_calm() -> bool:
	return Interactables.calm_now(_w)


# --- The elites (v0.9.0 EL; Elites, EliteAi) ----------------------------------------------------------------------
## Actor `kind` is an elite archetype (the Breaker, the Rift Hunter, the Conduit).
static func is_elite_kind(kind: int) -> bool:
	return EliteAi.is_elite_kind(kind)


## The elite actor i's name (a locale key: its bar's label), else &"".
func elite_name_key(i: int) -> StringName:
	var t := _w.enemy_table(_w.actors.kinds[i])
	return t.name_key if t != null and t.elite != null else &""


## Which attack elite actor i is making or last made: ELITE_ABILITY or ELITE_BASIC.
func elite_attack(i: int) -> int:
	return _w.actors.pick[i]


## The Rift Hunter i has vanished (no body until it reappears on its mark).
func elite_vanished(i: int) -> bool:
	return EliteAi.vanished(_w, i)


## Elite actor i is in its punish window (stuck, overloaded): its hits take more.
func elite_vulnerable(i: int) -> bool:
	return EliteAi.vulnerable(_w, i)


## The Conduit i's beam while it fires (and a moment after), else null.
func elite_beam(i: int) -> Obb:
	return EliteAi.beam_now(_w, i)


## The floor's elites now: {"active": false} on a floor that never had one, else the elite rooms (and which arrived),
## the elites alive, the last arrival (tick, id, pos) and the last kill (tick, pos, whether its card dropped).
func elites() -> Dictionary:
	var s := _w.elites
	if s == null:
		return {"active": false}
	return {
		"active": true,
		"rooms": s.rooms.duplicate(),
		"spawned": s.room_spawned.duplicate(),
		"ids": s.ids.duplicate(),
		"alive": s.size(),
		"arrive_tick": s.arrive_tick,
		"arrive_id": s.arrive_id,
		"arrive_pos": s.arrive_pos,
		"kill_tick": s.kill_tick,
		"kill_pos": s.kill_pos,
		"kill_dropped": s.kill_dropped,
	}


## v0.9.0 CL: the floor holds collectibles (armed at setup; Collectibles).
func has_collectibles() -> bool:
	return _w.collect != null


## v0.9.0 CL: the floor's collectibles, one per entry: {id, source (Collectibles.Source), pos, shown_tick, taken_tick}
## (shown_tick -1: its source hasn't given it yet; taken_tick -1: not taken). Empty without any.
func collectibles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c := _w.collect
	if c == null:
		return out
	for k in c.size():
		(
			out
			. append(
				{
					"id": StringName(c.ids[k]),
					"source": c.source[k],
					"pos": c.pos[k],
					"shown_tick": c.shown_tick[k],
					"taken_tick": c.taken_tick[k],
				}
			)
		)
	return out


## v0.9.0 CL: the collectibles the hero took on this floor (their ids).
func collectibles_taken() -> PackedStringArray:
	return _w.collect.taken_ids() if _w.collect != null else PackedStringArray()


## v0.9.5 SM (Stress Mark): the sides marked on actor `i` (bits 0 up, 1 right, 2 down, 3 left on the screen).
func stress_mask(i: int) -> int:
	return StressMarks.mask_of(_w, i)


## v0.9.5 SM: the radius (m) within which marks are shown, 0 without the card.
func stress_radius_m() -> float:
	var idx := StressMarks.card(_w)
	return 0.0 if idx < 0 else _w.item_tables[idx].mark_radius_m


## v0.9.5 SM: the unit vector from an enemy out to screen side `side` (0 up, 1 right, 2 down, 3 left).
static func stress_side_dir(side: int) -> Vector2:
	return StressMarks.side_dir(side)


## v0.9.5 SM: the side's angle on the sim plane (1/4096 turn).
static func stress_side_angle(side: int) -> int:
	return StressMarks.SIDE_ANGLES[side]

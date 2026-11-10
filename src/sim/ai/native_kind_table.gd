class_name NativeKindTable
extends RefCounted
## The per-kind table the native enemy kernels read (NATIVE_CORE.md §4.2): one row per ActorStore.Kind, KI ints and
## KF floats, built from a world's compiled EnemyTables and from EnemyAi's own per-kind lookups, plus the tuning
## beside it. It is content, not state: built from the world's loadout, sent by NativeWorld.send_kinds, never hashed.
## A kind runs from the table alone (NATIVE), from the table with GDScript hooks on its intents (HOOKED), or stays
## all GDScript (SCRIPT: bosses, elites, the Ruins and Night Rocks signatures, the Cinder Priest, the player, the
## dummy, and any kind without an EnemyTable in this world).

enum Mode { NATIVE, HOOKED, SCRIPT }
## How a kind's attack lands (EnemyAi.resolve's branches).
enum Shape { NONE, CONTACT, LOCKED_DISC, BASH_LANE, SNIPE_LANE, RUNE_DISC, BURST, PATTERN, HOOK }

const K := ActorStore.Kind
const MODE_SCRIPT := Mode.SCRIPT

## K_FLAGS bits, each a test EnemyAi makes on the kind.
const CHARGES := 1  # EnemyAi._charges
const KEEPS_AWAY := 2  # EnemyAi._keeps_away
const TURNS_SLOWLY := 4  # EnemyAi._turns_slowly: turns at turn_rate every tick, its facing its armour
const CRITTER := 8  # EnemyAi.is_critter
const FLEES_THEN_STRAFES := 16  # a Needle's behaviour: backs off inside flee_distance_m, strafes in its band
const STATIONARY := 32  # the Gravity Node holds its spot and never attacks
const RELOCATES := 64  # a Sniper's behaviour: walks to a new spot after each shot, commits by the snipe ticks
const TRACKS := 128  # EnemyAi.tracking: the windup's aim follows the hero until the commit
const AIM_NO_LEAD := 256  # aimed at where the hero stands, no lead (the Bomb Drone, the Frost Spitter)
const FACES_ON_PLAN := 512  # faces the hero on its plan ticks and as it attacks (every kind not TURNS_SLOWLY)
const AIM_AT_START := 1024  # _start_windup aims it (_aim)
const SPELLS := 2048  # the Arc Caster: a spell drawn at the windup's start; its rune neither tracks nor aims
const HOVERS := 4096  # the Bomb Drone keeps walking through its windup
const NEEDS_MAY := 8192  # its attack start needs a GDScript test (the Mine Layer's mine count: the `may` mask)
const GUARDS_FRONT := 16384  # attacks only a hero within front_half_arc of its facing (the Shield Bearer)
const LOCKS_AHEAD := 32768  # its disc locks reach_m ahead along the aim (the Splitter, the Splitling)
const LOCKS_FACING := 65536  # its lane runs along its facing, not the aim (the Shield Bearer)
const MELEE_STOP := 131072  # stops walking the tick it touches the hero (not a Needle, not a keep-away kind)

## K_HOOKS bits: the intents GDScript answers for the kind beyond the uniform ones.
const HOOK_THINK_TICK := 1  # every think tick, before the frozen check: Variants.on_think (the Rubble Warden)
const HOOK_MOVE_TICK := 2  # while walking, instead of attacking: the Mender's _mend
const HOOK_WINDUP_START := 4  # at the windup's start: the Star Warper's mark_spot
const HOOK_WINDUP_END := 8  # as the windup ends: the Star Warper's cancel
const HOOK_CHARGE_STEP := 16  # each charge step: Variants.on_charge_step (a trail)
const HOOK_BOLT := 32  # each bolt: the Dim Needle's look
const HOOK_ACTIVE := 64  # its active tick: Mines.drop, CanyonShore.throw_blob, StarfallKinds.blink, split lanes

## The ints of a row.
const K_MODE := 0
const K_BEHAVIOUR := 1  # EnemyAi.behaviour_of
const K_FLAGS := 2
const K_HOOKS := 3
const K_ROLE := 4  # EnemyAi.role_of
const K_AI_FLAGS := 5  # EnemyAi.flags_of
const K_COOLDOWN := 6
const K_WINDUP := 7
const K_WINDUP_MAX := 8
const K_ACTIVE := 9
const K_RECOVER := 10
const K_TURN_RATE := 11
const K_CHARGE_TURN := 12
const K_FRONT_HALF_ARC := 13
const K_LEAD_MAX := 14
const K_BURST_COUNT := 15
const K_BURST_GAP := 16
const K_BURST_SPREAD := 17
const K_SHAPE := 18
const K_DAMAGE := 19
const K_TAGS := 20  # the SimEvent tag of the kind's own hit
const K_CONTACT_CD := 21
const K_MAX_MINES := 22
const K_RUNE_WINDUP := 23
const K_BOLT_LIFE := 24
const K_HEAL_AMOUNT := 25
const K_HEAL_PERIOD := 26
const K_TRAIL_STEP := 27
const K_PATTERNS := 28  # EnemyTable.patterns.size()
## Then MAX_PATTERNS slots of PATTERN_KI ints, one per attack index (EnemyAi.pattern_of): present (0 or 1),
## lob_ticks, wave_gap_ticks, waves, duration_ticks, burst (a lobbed BURST: 1).
const K_PATTERN := 29
const PATTERN_KI := 6
const P_HAS := 0
const P_LOB := 1
const P_GAP := 2
const P_WAVES := 3
const P_DURATION := 4
const P_BURST := 5
const MAX_PATTERNS := 3
const KI := K_PATTERN + PATTERN_KI * MAX_PATTERNS

## The floats of a row.
const KF_RADIUS := 0
const KF_SPEED := 1
const KF_ATTACK_RANGE := 2
const KF_FLEE := 3
const KF_KEEP_DISTANCE := 4
const KF_KEEP_MIN := 5
const KF_CHARGE_SPEED := 6
const KF_CHARGE_DISTANCE := 7
const KF_REACH := 8  # also the Sniper's line length
const KF_SLAM_RADIUS := 9
const KF_LANE_HALF := 10
const KF_RUNE_RADIUS := 11
const KF_BOLT_SPEED := 12
const KF_BOLT_RADIUS := 13
const KF_SPREAD_SPEED := 14
const KF_HEAL_RANGE := 15
const KF_STRIKE_RADIUS := 16
## Then MAX_PATTERNS slots of PATTERN_KF floats: speed, radius_m, land_radius_m.
const KF_PATTERN := 17
const PATTERN_KF := 3
const PF_SPEED := 0
const PF_RADIUS := 1
const PF_LAND := 2
const KF := KF_PATTERN + PATTERN_KF * MAX_PATTERNS

## The tuning (floats; the tick counts and permilles are whole numbers, exact in a float).
const T_SPAWN_IN := 0
const T_COMMIT := 1
const T_SNIPE_COMMIT := 2
const T_STRAFE_PERMILLE := 3
const T_FLANK_MIN := 4
const T_FLANK_RANGE := 5
const T_FLANK_PERMILLE := 6
const T_SPREAD_RADIUS := 7
const T_SPREAD_WEIGHT := 8
const T_RELOCATE_SPEED_PERMILLE := 9
const T_RELOCATE_MAX := 10
const T_MEND_SCAN := 11
const T_PLAN_PERIOD := 12
const T_EGG_STATE := 13  # a row in this state or past it is GDScript's (BossSignatures.EGG)
const T_CONTACT_SLOP := 14
const T_CRITTER_TOUCH := 15
const T_RELOCATE_DONE := 16
const T_SIGHT_R := 17
const TUNING := 18


## One row per ActorStore.Kind.
static func kind_count() -> int:
	return K.size()


## [ints, floats, tuning] for world w: its enemy tables, its tuning.
static func build(w: World) -> Array:
	var n := kind_count()
	var ints := PackedInt32Array()
	ints.resize(n * KI)
	var floats := PackedFloat32Array()
	floats.resize(n * KF)
	for kind in n:
		_fill(kind, w.enemy_table(kind), ints, floats)
	return [ints, floats, tuning_of(w.tuning)]


static func tuning_of(s: SimTuning) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(TUNING)
	t[T_SPAWN_IN] = s.spawn_in_ticks
	t[T_COMMIT] = s.ai_commit_ticks
	t[T_SNIPE_COMMIT] = s.ai_snipe_commit_ticks
	t[T_STRAFE_PERMILLE] = s.ai_strafe_permille
	t[T_FLANK_MIN] = s.ai_flank_min_m
	t[T_FLANK_RANGE] = s.ai_flank_range_m
	t[T_FLANK_PERMILLE] = s.ai_flank_permille
	t[T_SPREAD_RADIUS] = s.ai_spread_radius_m
	t[T_SPREAD_WEIGHT] = s.ai_spread_weight
	t[T_RELOCATE_SPEED_PERMILLE] = s.ai_relocate_speed_permille
	t[T_RELOCATE_MAX] = s.ai_relocate_max_ticks
	t[T_MEND_SCAN] = s.ai_mend_scan_ticks
	t[T_PLAN_PERIOD] = EnemyAi.PLAN_PERIOD
	t[T_EGG_STATE] = BossSignatures.EGG
	t[T_CONTACT_SLOP] = EnemyAi.CONTACT_SLOP_M
	t[T_CRITTER_TOUCH] = EnemyAi.CRITTER_TOUCH_M
	t[T_RELOCATE_DONE] = EnemyAi.RELOCATE_DONE_M
	t[T_SIGHT_R] = EnemyAi.SIGHT_R_M
	return t


## The mode of a kind with table t (null: none in this world).
static func mode_of(kind: int, t: EnemyTable) -> int:
	var f := EnemyAi.flags_of(kind)
	if t == null or not EnemyAi.is_enemy_kind(kind) or EnemyAi.role_of(kind) == EnemyAi.Role.BOSS:
		return Mode.SCRIPT
	if (f & (EnemyAi.F_ELITE | EnemyAi.F_RUINS)) != 0 or kind == K.CINDER_PRIEST:
		return Mode.SCRIPT
	if hooks_of(kind, t) != 0 or (flags_for(kind) & NEEDS_MAY) != 0:
		return Mode.HOOKED
	return Mode.NATIVE


static func flags_for(kind: int) -> int:
	var f := EnemyAi.flags_of(kind)
	var beh := EnemyAi.behaviour_of(kind)
	var out := 0
	out |= CHARGES if (f & EnemyAi.F_CHARGES) != 0 else 0
	out |= KEEPS_AWAY if (f & EnemyAi.F_KEEPS_AWAY) != 0 else 0
	out |= TURNS_SLOWLY if (f & EnemyAi.F_TURNS_SLOWLY) != 0 else 0
	out |= CRITTER if (f & EnemyAi.F_CRITTER) != 0 else 0
	out |= FLEES_THEN_STRAFES if beh == K.NEEDLE else 0
	out |= STATIONARY if StarfallKinds.is_node(kind) else 0
	out |= RELOCATES if beh == K.SNIPER else 0
	var tracks := beh == K.SNIPER or beh == K.NEEDLE or kind == K.ARC_CASTER or kind == K.BOMB_DRONE
	out |= TRACKS if tracks else 0
	out |= AIM_NO_LEAD if kind == K.BOMB_DRONE or kind == K.FROST_SPITTER else 0
	out |= FACES_ON_PLAN if (f & EnemyAi.F_TURNS_SLOWLY) == 0 else 0
	var aims := beh == K.NEEDLE or beh == K.SNIPER or beh == K.BOMB_DRONE or beh == K.FROST_SPITTER
	out |= AIM_AT_START if aims else 0
	out |= SPELLS if beh == K.ARC_CASTER else 0
	out |= HOVERS if kind == K.BOMB_DRONE else 0
	out |= NEEDS_MAY if beh == K.MINE_LAYER else 0
	out |= GUARDS_FRONT | LOCKS_FACING if beh == K.SHIELD_BEARER else 0
	out |= LOCKS_AHEAD if beh == K.SPLITTER or beh == K.SPLITLING else 0
	out |= MELEE_STOP if beh != K.NEEDLE and (f & EnemyAi.F_KEEPS_AWAY) == 0 else 0
	return out


static func hooks_of(kind: int, t: EnemyTable) -> int:
	var beh := EnemyAi.behaviour_of(kind)
	var out := 0
	out |= HOOK_THINK_TICK if kind == K.RUBBLE_WARDEN else 0
	out |= HOOK_MOVE_TICK if kind == K.MENDER else 0
	out |= HOOK_WINDUP_START | HOOK_WINDUP_END if StarfallKinds.is_warper(kind) else 0
	var trail := t != null and t.trail != Variants.TRAIL_NONE
	out |= HOOK_CHARGE_STEP if trail and (EnemyAi.flags_of(kind) & EnemyAi.F_CHARGES) != 0 else 0
	out |= HOOK_BOLT if kind == K.DIM_NEEDLE else 0
	var active := (
		beh == K.MINE_LAYER
		or beh == K.FROST_SPITTER
		or beh == K.STAR_WARPER
		or kind == K.SPLIT_SNIPER
	)
	out |= HOOK_ACTIVE if active else 0
	return out


## The shape of the kind's hit and its SimEvent tag: [shape, tag].
static func shape_of(kind: int, t: EnemyTable) -> PackedInt32Array:
	var beh := EnemyAi.behaviour_of(kind)
	if (EnemyAi.flags_of(kind) & EnemyAi.F_CRITTER) != 0:
		return PackedInt32Array([Shape.CONTACT, SimEvent.TAG_MELEE])
	if t != null and not t.patterns.is_empty() and t.patterns[0] != null:
		return PackedInt32Array([Shape.PATTERN, SimEvent.TAG_AREA])  # The lobbed BURST's landing
	match beh:
		K.CHARGER, K.HATCHLING, K.SWARMER:
			return PackedInt32Array([Shape.CONTACT, SimEvent.TAG_MELEE])
		K.WARDEN:
			return PackedInt32Array([Shape.LOCKED_DISC, SimEvent.TAG_AREA])
		K.NEEDLE:
			return PackedInt32Array([Shape.BURST, SimEvent.TAG_PROJECTILE])
		K.ARC_CASTER:
			return PackedInt32Array([Shape.RUNE_DISC, SimEvent.TAG_AREA])
		K.SPLITTER, K.SPLITLING:
			return PackedInt32Array([Shape.LOCKED_DISC, SimEvent.TAG_MELEE])
		K.SHIELD_BEARER:
			return PackedInt32Array([Shape.BASH_LANE, SimEvent.TAG_MELEE])
		K.SNIPER:
			return PackedInt32Array([Shape.SNIPE_LANE, SimEvent.TAG_PROJECTILE])
		K.MINE_LAYER, K.FROST_SPITTER:
			return PackedInt32Array([Shape.HOOK, 0])
		K.STAR_WARPER:
			return PackedInt32Array([Shape.HOOK, SimEvent.TAG_MELEE])
	return PackedInt32Array([Shape.NONE, 0])


static func _fill(
	kind: int, t: EnemyTable, ints: PackedInt32Array, floats: PackedFloat32Array
) -> void:
	var i := kind * KI
	var f := kind * KF
	ints[i + K_MODE] = mode_of(kind, t)
	ints[i + K_BEHAVIOUR] = EnemyAi.behaviour_of(kind)
	ints[i + K_FLAGS] = flags_for(kind)
	ints[i + K_HOOKS] = hooks_of(kind, t)
	ints[i + K_ROLE] = EnemyAi.role_of(kind)
	ints[i + K_AI_FLAGS] = EnemyAi.flags_of(kind)
	var shape := shape_of(kind, t)
	ints[i + K_SHAPE] = shape[0]
	ints[i + K_TAGS] = shape[1]
	if t == null:
		return
	ints[i + K_COOLDOWN] = t.cooldown_ticks
	ints[i + K_WINDUP] = t.windup_ticks
	ints[i + K_WINDUP_MAX] = t.windup_max_ticks
	ints[i + K_ACTIVE] = t.active_ticks
	ints[i + K_RECOVER] = t.recover_ticks
	ints[i + K_TURN_RATE] = t.turn_rate
	ints[i + K_CHARGE_TURN] = t.charge_turn
	ints[i + K_FRONT_HALF_ARC] = t.front_half_arc
	ints[i + K_LEAD_MAX] = t.lead_max_ticks
	ints[i + K_BURST_COUNT] = t.burst_count
	ints[i + K_BURST_GAP] = t.burst_gap_ticks
	ints[i + K_BURST_SPREAD] = t.burst_spread
	ints[i + K_DAMAGE] = t.damage
	ints[i + K_CONTACT_CD] = t.contact_cd_ticks
	ints[i + K_MAX_MINES] = t.max_mines
	ints[i + K_RUNE_WINDUP] = t.rune_windup_ticks
	ints[i + K_BOLT_LIFE] = t.bolt_life_ticks
	ints[i + K_HEAL_AMOUNT] = t.heal_amount
	ints[i + K_HEAL_PERIOD] = t.heal_period_ticks
	ints[i + K_TRAIL_STEP] = t.trail_step_ticks
	ints[i + K_PATTERNS] = t.patterns.size()
	floats[f + KF_RADIUS] = t.radius_m
	floats[f + KF_SPEED] = t.speed
	floats[f + KF_ATTACK_RANGE] = t.attack_range_m
	floats[f + KF_FLEE] = t.flee_distance_m
	floats[f + KF_KEEP_DISTANCE] = t.keep_distance_m
	floats[f + KF_KEEP_MIN] = t.keep_min_m
	floats[f + KF_CHARGE_SPEED] = t.charge_speed
	floats[f + KF_CHARGE_DISTANCE] = t.charge_distance_m
	floats[f + KF_REACH] = t.reach_m
	floats[f + KF_SLAM_RADIUS] = t.slam_radius_m
	floats[f + KF_LANE_HALF] = t.lane_half_m
	floats[f + KF_RUNE_RADIUS] = t.rune_radius_m
	floats[f + KF_BOLT_SPEED] = t.bolt_speed
	floats[f + KF_BOLT_RADIUS] = t.bolt_radius_m
	floats[f + KF_SPREAD_SPEED] = t.spread_speed
	floats[f + KF_HEAL_RANGE] = t.heal_range_m
	floats[f + KF_STRIKE_RADIUS] = t.strike_radius_m
	for k in mini(t.patterns.size(), MAX_PATTERNS):
		var p: BulletPatternTable = t.patterns[k]
		if p == null:
			continue
		var pi := i + K_PATTERN + k * PATTERN_KI
		ints[pi + P_HAS] = 1
		ints[pi + P_LOB] = p.lob_ticks
		ints[pi + P_GAP] = p.wave_gap_ticks
		ints[pi + P_WAVES] = p.waves
		ints[pi + P_DURATION] = p.duration_ticks()
		ints[pi + P_BURST] = 1 if p.kind == BulletPatternTable.Kind.BURST else 0
		var pf := f + KF_PATTERN + k * PATTERN_KF
		floats[pf + PF_SPEED] = p.speed
		floats[pf + PF_RADIUS] = p.radius_m
		floats[pf + PF_LAND] = p.land_radius_m

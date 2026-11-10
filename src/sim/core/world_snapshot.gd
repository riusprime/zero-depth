class_name WorldSnapshot
extends RefCounted
## The canonical snapshot of a whole World as plain data (SIM_CONTRACTS §10b), and its restore. Pure: no
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
	&"strike_spec": "transient within a launch (v0.10.5 O10): null between ticks",
	&"matchup_permille": "transient within a hit (v0.10.5 O10): 1000 between hits",
	&"matchup_tags": "transient within a hit (v0.10.5 O10): 0 between hits",
	&"wand_table": "loadout",  # v0.6.5 WN1
	&"blade_table": "loadout",  # v0.6.5 WN4
	&"slot_table": "loadout",  # v0.9.0 AS
	&"pair_table": "loadout",  # v0.9.5 EE3
	&"elite_rules": "loadout",  # v0.9.0 EL
	&"ice": "loadout (v0.7.5 NB1: IcePatches lays it from the floor seed)",
	&"critter_kind": "loadout (v0.11.0 O9: FloorPlan sets it from the floor's biome)",
	&"roster_kinds": "loadout (v0.11.0 O13a: FloorPlan sets it from the floor's biome)",
	&"_events": "the presentation's event log, not state (its counter _event_seq is copied)",
	&"_wall_grid": "rebuilt: derived from walls",
	&"_wall_next": "setup (prepare_wall): only whether it is still pending is copied",
	&"_nav_next": "setup (prepare_wall): only whether it is still pending is copied",
	&"nav": "rebuilt from walls; its last flood and a build in progress (NF) are copied",
	&"_nav_open": "rebuilt: the field before the door sealed (apply's add_wall_now keeps it)",
	&"_nav_deferred": "setup (v0.11.1 S45): false once the floor's build ends (World.build_nav)",
	&"_nav_due": "setup (v0.11.1 S45): null once the floor's build ends (World.build_nav)",
	&"_nav_next_due": "setup (v0.11.1 S45): null once the floor's build ends (World.build_nav)",
	&"curse_totals": "rebuilt: Curses.total's cache, summed from curses_owned (v0.7.0 audit C-12)",
	&"phase_probe": "debug (v0.8.0 HS): the perf probe's phase timer, null in play, not state",
	&"native_mover": "setup: the optional native collision passes (World.mover_factory), not state",
	&"_wall_rev":
	"derived: counts the wall grid's changes (the native mover's cue to take the walls again)",
	&"debug_aoe_misses": "debug (v0.8.0 HS): a test's superset check, off in play",
	&"debug_aoe_full": "debug (v0.8.0 HS): a test's reference run, off in play",
	&"_hit_grid": "transient within a tick (v0.8.0 HS): built inside _projectile_hits only",
	&"_hit_grid_state": "transient within a tick (v0.8.0 HS): 0 between ticks",
	&"_every_index": "derived (v0.8.0 HS): 1 .. n - 1, rebuilt from the actor count",
	&"floor_hp_bonus": "rebuilt (v0.9.0 SV): RunState.prepare derives it from the run's floor",
	&"starbound_tables": "loadout",  # v0.10.5 W3-P10b
	&"spell_tables": "loadout",  # v0.11.0 O10
	&"spell_rules": "loadout",
	&"relic_tables": "loadout",  # v0.11.0 O14b
	&"sb_burst_pos":
	"transient within a hit (v0.10.5 W3-P10b): Detonation's chain, empty between hits",
	&"sb_burst_dmg": "transient within a hit (v0.10.5 W3-P10b)",
	&"sb_burst_root": "transient within a hit (v0.10.5 W3-P10b)",
	&"sb_draining": "transient within a hit (v0.10.5 W3-P10b): false between hits",
}
## Content tables: compiled from content at setup, read-only in play (the guard test checks they don't change).
const LOADOUT_CLASSES: Array[StringName] = [
	&"StarboundTable",  # The Starbound cards (content, compiled at setup)
	&"SpellTable",  # The spells and their rules (content, compiled at setup)
	&"SpellRules",
	&"RelicTable",  # The relics (content, compiled at setup)
	&"PlayerTable",
	&"EnemyTable",
	&"EncounterTable",
	&"SpawnTable",
	&"FloorLayout",
	&"ShopRoomTable",  # The shop rooms (content, read when a floor is built)
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
	&"QuakeTable",  # The Gatekeeper's quake pillars (BossTable.quake, content)
	&"HazardTable",  # A boss's arena hazards (BossTable.hazard, content)
	&"SwingStep",
	&"SkillTable",
	&"OverrunTable",  # v0.4.0 AB
	&"ShopTable",  # v0.5.0 SH
	&"ArenaTable",  # v0.5.5 AR
	&"LockdownTable",  # The Lockdowns' numbers (LockdownState.table)
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
	&"RemnantRule",  # A REMNANT op's rule (content)
	&"WandTable",  # v0.6.5 WN1
	&"BladeTable",  # v0.6.5 WN4
	&"SimTuning",  # the dev panel's Step 6: the sim's designer numbers
	&"IceField",  # A floor's ice, laid from the floor seed at setup and never written in play
	&"PairingTable",  # The enemy duos (SpawnTable.pairings)
	&"SurgeTable",  # The horde surges' numbers (SpawnTable.surge)
	&"IntensityTable",  # The intensity director's numbers (SpawnTable.intensity)
	&"BulletPatternTable",  # A boss attack's bullet pattern (BossAttackTable.pattern)
	&"SlotTable",  # The wand's slot limits, caps and form × card table (content, read in play)
	&"ElementPairTable",  # v0.9.5 EE3 (World.pair_table; SaveLab worlds hold it now, as Main)
	&"EliteTable",  # An elite archetype's ability and plain attack (EnemyTable.elite)
	&"EliteRules",  # Where elites appear and the core drop (EliteState.rules)
	&"AffinityTable",  # The run's rune affinity's numbers (AffinityState.table)
]
## State objects: every script variable is copied.
const STATE_CLASSES: Array[StringName] = [
	&"RngStream",
	&"ActorStore",
	&"ProjectileStore",
	&"PickupStore",
	&"MineStore",
	&"VariantState",  # The variants' trails and rubble
	&"RuinsRocksState",  # The signatures' cables, rocks and boulders
	&"CanyonShoreState",  # R5-R8's bursts, vents, blobs, chunks and shells
	&"HealOrbStore",  # v0.4.0 TU
	&"ShardDropStore",  # v0.10.5 O7b
	&"ObjectiveMarkers",  # The hint arrow's markers
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
	&"EventState",  # Pedestals, rolls, defence, cursed offers (its tables are loadout)
	&"CatchUpState",  # The floor's hidden catch-up
	&"ArenaState",  # The sealed arena, its waves, streams and barriers; the arenas cleared
	# The compiled specs (World.attack_book is kept out and compiled again on restore; listed so the
	# guard knows them).
	&"AttackBook",
	&"AttackSpec",
	&"AttackHook",
	&"CurseState",  # The trade-off curses in play (stun, dodges, shots counted)
	&"CoreState",  # Core carriers, staggers, steal windows, the drops on the floor
	&"ModifierState",  # Queued launches, every-N counters, the moments' and body rules' marks
	&"FinalFight",  # The final boss's fight (its bodies, the phase, the shatter)
	&"NemesisCast",  # The Nemesis's hostile copies of the player's shot and cards (FinalFight)
	&"IntensityState",  # The intensity director's state
	&"FinalApproach",  # The final approach (the pylons, the buildup, the walls of light)
	&"Solids",  # The props' footprints (standing, or waiting for the hero to clear)
	&"Interactables",  # The shared interactables and the puzzles' calm rooms
	&"TimedDoor",  # The timed door (its state, timer and reward)
	&"RuneAlignment",  # The rune puzzle (its pillars, solved, slab and reward)
	&"Breakables",  # The cracked wall, the containers and the explosive barrels
	&"PurpleRunes",  # The purple-rune dais (awakened, the Deep gate's footprint)
	&"LockdownState",  # The Lockdown sealed, its formations, the safety, the strikes; those opened
	&"ShrineState",  # v0.9.0 SH, HF: the Blood or Chaos shrine (used, the challenge, its altars) and the fountain
	&"EliteState",  # The floor's elite rooms, the elites alive, their contact clocks, the escort
	&"AffinityState",  # The rune affinity's ward and dash crackle on this floor
	&"CollectState",  # The floor's collectibles (armed, shown, taken)
	&"StressState",  # The Stress Mark's weak sides
	&"HeartRoom",  # The hidden room under the throne (its pedestal, its sealed door)
]

## script_fields' cache (Script -> Array[StringName]); derived from the class declarations only.
static var _fields := {}


## The snapshot of `w` between ticks. `errors` (optional) collects every unclassified object found.
static func take(w: World, errors: PackedStringArray = PackedStringArray()) -> Dictionary:
	var data := _encode_object(w, WORLD_KEPT, "World", errors)
	data[&"nav"] = {
		"size": w.nav.size,
		"dist": w.nav.dist.duplicate(),
		"flooded": w.nav.get(&"_flooded"),
		"work": w.nav.last_work,  # The next build's budget
		"build": w.nav.build_state(),  # The flood being built ({} none), run again on restore
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
	# The Gatekeeper's standing pillars are walls added in play too (barriers, never in the flow field).
	var pillars := _saved_pillars(data)
	# The timed door's slab is a barrier added in play (before or after the boss door): left out here;
	# The rune puzzle's slab too (Secrets.slabs); the Deep gate's footprint once earned.
	var plain := _without_slab(base, saved_c, walls_before)
	# The boss door sealed in play: add it the way play did (its prepared flow field swaps in, no rebuild).
	# Found among every wall play added, so a sealed arena's barriers (added on the same tick, before or
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
	Modifiers.invalidate(base)  # The restored build's specs compile on their next read
	base.drop_retired_combos()  # A held combo deleted since the save (CardOrder.RETIRED_COMBOS) goes
	Curses.invalidate(base)  # The curse sums are summed again from what was restored
	# A sealed arena's barriers came back with the walls: they never enter the flow field (World.add_barrier),
	# so only the wall grid is rebuilt for them.
	var barriers := base.arenas.barriers.size() + base.bosses.pillar_x.size()  # Pillars too
	barriers += Secrets.slabs_up(base)  # v0.9.0 TD, RA: the secret rooms' slabs while they stand
	barriers += base.ruins_rocks.rock_count() + base.ruins_rocks.hide_count()  # Rocks, boulders
	if base.lockdown != null:  # A sealed Lockdown's bars, as an arena's
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
	base.nav.last_work = int(nav["work"])
	base.nav.restore_build(nav["build"])
	for f: StringName in [&"_wall_next", &"_nav_next"]:
		if not bool(data.get(f, false)):
			base.set(f, null)
		elif base.get(f) == null:
			return "World.%s: pending in the snapshot, missing in the base" % f
	return ""


## The saved walls' centres without the secret rooms' slabs (barriers past the floor's walls;
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


## How many of the Gatekeeper's pillars stood in the snapshot (0 when the snapshot names none).
static func _saved_pillars(data: Dictionary) -> int:
	var bosses: Variant = data.get(&"bosses", {})
	if typeof(bosses) != TYPE_DICTIONARY:
		return 0
	var xs: Variant = (bosses as Dictionary).get(&"pillar_x", PackedFloat32Array())
	return (xs as PackedFloat32Array).size() if xs is PackedFloat32Array else 0


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
		var old := arr.duplicate()  # An array of content tables (World.ev.events) keeps its tables
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
		&"EliteState":  # A base whose floor had no elite before play brought one
			return EliteState.new()
		&"StressState":  # v0.9.5 SM
			return StressState.new()
		&"CollectState":  # A base built without the collectibles armed (a lab)
			return CollectState.new()
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
		&"VariantState":
			return VariantState.new()
		&"RuinsRocksState":
			return RuinsRocksState.new()
		&"CanyonShoreState":
			return CanyonShoreState.new()
		&"HealOrbStore":
			return HealOrbStore.new()
		&"ShardDropStore":
			return ShardDropStore.new()
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

# gdlint: disable=max-public-methods
class_name Spells
extends RefCounted
## The
## elemental spells, a card family in 4 spell slots separate from the wand. Each spell casts by itself on its own
## cooldown; nothing is aimed (the sim picks the target).
## - The offer: holding an element card (World.items_owned has the spell's element item) puts its element's
##   spells in this run's pool. A regular altar's offer gets one spell card from the pool (SpellRules.offer_permille),
##   drawn by weight (SpellTable.weight; × SpellRules.affinity_permille when the spell's affinity is the run's rune
##   affinity), from a named stream of its own per altar ("loot:spell:<loop>:<floor>:<reward id>", derived from the
##   floor's seed), so the loot stream and every other offer stay as they were. It takes the place of one card (the last
##   that is neither the leading fresh ability, a Starbound card, the only compatible card nor a jackpot), or appended
##   to a short offer. A held spell stays in the pool below its level cap.
## - The slots: World.spell_slots (spell indices, pick order), spell_levels and spell_cd (ticks left) side by side;
##   run-long (RunCarry; the cooldowns start ready on a new floor). Taking a held spell levels it (Q18: Lv 1-3, Lv 4-5
##   from loop 2: cap()); a new one goes in the next free slot; with every slot full it replaces the held spell of the
##   lowest level (the leftmost of those), and its card says so before it is taken (Offers.info "replaces", the attack
##   slots' Replace rule). Skipping the card keeps the slots.
## - The runner (tick phase 6, after Abilities): a slot's cooldown counts down; at 0 it casts as soon as it has a target
##   (then the cooldown starts again), else it waits ready. Every hit is the player's (Damage.hit: the damage stat and
##   crit apply), tagged TAG_ABILITY with the spell's id as its effect, and each enemy hit gets the element's status the
##   way the element card gives it (Engines.add_burn / add_frost / add_bleed, Venom.add; Lightning's, which leaves no
##   stack, charges the enemy: ElementStack.on_hit): the same stacks, caps and thresholds; a status the build has no
##   card for does nothing. A spell's damage is not an element's own (no ElementStack falloff or level share: O12).
## - "The densest pack" (densest_pack): among the living enemies within reach of the hero, the one whose
##   SpellRules.pack_radius_m circle holds the most enemies (ties: the nearest to the hero, then the lower index). One
##   function for the cast and any forecast (EI-07).
## - F2 Frost Nova: every enemy within radius of the hero takes damage, freezes its seconds (a freeze-immune actor,
##   a boss, gets a frost stack instead: the element card's rule), and is pushed push_m away over PUSH_TICKS (an elite
##   half, a boss never).
## - B1 Fireball: count balls fly at speed toward the densest pack (the next one at the densest pack outside the
##   earlier balls' bursts, else the same), locked when cast; each bursts radius at its point: damage and burn.
## - L1 Sky Strike: count bolts each strike an enemy within reach not yet struck by this cast (uniform, one draw each
##   on "combat:spell_sky:<tick>:<slot>"; every enemy struck: any of them), damage and shock; each then jumps to the
##   nearest living enemy within jump_m of it that this bolt hasn't hit (damage and shock).
## The view reads the slots (read) and the casts (World.spell_fx_*, never hashed; the balls in flight). Integer damage,
## metres as floats; no randomness but the named streams above (EI-05).

## The rest of the roster and the Lv 5 extras (SpellRoster casts them, SpellZones runs what lasts):
## - Frost Nova Lv 5: a frozen enemy you hit (any hit of yours but its own shatter) shatters: its freeze ends and it
##   takes bonus_damage (on_frozen_hit, from Damage.hit).
## - Fireball Lv 5: each burst leaves a burning ground (SpellZones.FIRE) of bonus_radius_m for bonus_ticks.
## - Sky Strike Lv 5: each enemy a bolt or its jump strikes is stunned bonus_ticks (a hold).
## - The holds (World.spell_hold_*: Sky Strike's stun, Meteor's knock-down, Toxic Cloud's slow): an enemy held at
##   0 per mille stands still and acts not (EnemyAi, EliteAi: as frozen, without being frozen); a slow scales its speed
##   (ItemProcs.slow_factor). Never on a freeze-immune actor (a boss: the element cards' rule). They run down here.
const BLIZZARD := 0
const FROST_NOVA := 1
const ICE_LANCES := 2
const FIREBALL := 3
const BURNING_GROUND := 4
const METEOR := 5
const SKY_STRIKE := 6
const BALL_LIGHTNING := 7
const STATIC_FIELD := 8
const VENOM_ORB := 9
const TOXIC_CLOUD := 10
const SPITTER_VINE := 11
const BLOOD_THORNS := 12
const HEMORRHAGE := 13
const LEECH := 14
const EFFECT_SHATTER := &"spell_frost_nova_shatter"
const EFFECT_HEMORRHAGE := &"spell_hemorrhage_burst"
## The most holds at once (a new one past it is not made).
const HOLDS_MAX := 128
## A line spell's half width (m) beside an enemy's own radius.
const LINE_HALF_M := 0.35
const ELEMENT_FROST := 0
const ELEMENT_FIRE := 1
const ELEMENT_LIGHTNING := 2
const ELEMENT_VENOM := 3
const ELEMENT_BLEED := 4
const LEVELS := 5
const STREAM_OFFER := "loot:spell"
const STREAM_SKY := "combat:spell_sky"
## Frost Nova's push runs over this many ticks.
const PUSH_TICKS := 6
## The view's log (World.spell_fx_*): a nova, a ball's burst, a bolt from the sky, a bolt's jump, a cast (slot flash).
const FX_NOVA := 0
const FX_BURST := 1
const FX_BOLT := 2
const FX_JUMP := 3
## A shard's line, a shatter, a ring of thorns, a spit, a zap, Meteor's strike, a discharge (Static Field,
## Ball Lightning's end), Hemorrhage's burst, a drain line.
const FX_LANCE := 4
const FX_SHATTER := 5
const FX_THORNS := 6
const FX_SPIT := 7
const FX_ZAP := 8
const FX_STRIKE := 9
const FX_DISCHARGE := 10
const FX_HEMO := 11
const FX_DRAIN := 12
const FX_MAX := 64


static func enabled(w: World) -> bool:
	return w.spell_rules != null and not w.spell_tables.is_empty()


## Spell k's table (null: not in this world's content).
static func table(w: World, k: int) -> SpellTable:
	for t in w.spell_tables:
		if t.spell == k:
			return t
	return null


static func slot_of(w: World, k: int) -> int:
	return w.spell_slots.find(k)


static func held(w: World, k: int) -> bool:
	return w.spell_slots.has(k)


## Spell k's level (0: not held).
static func level(w: World, k: int) -> int:
	var s := slot_of(w, k)
	return w.spell_levels[s] if s >= 0 and s < w.spell_levels.size() else 0


## The highest level now: SpellRules.loop1_max_level in loop 1, LEVELS from loop 2.
static func cap(w: World) -> int:
	if w.loop >= 2 or w.spell_rules == null:
		return LEVELS
	return w.spell_rules.loop1_max_level


static func level_after(w: World, k: int) -> int:
	return mini(level(w, k) + 1, cap(w))


static func slots(w: World) -> int:
	return w.spell_rules.slots if w.spell_rules != null else 0


static func full(w: World) -> bool:
	return w.spell_slots.size() >= slots(w)


## Spell k's element card is held.
static func unlocked(w: World, t: SpellTable) -> bool:
	return t != null and t.element_item >= 0 and w.items_owned.has(t.element_item)


## Spell k can be offered now: unlocked, and below the cap when held.
static func can_offer(w: World, k: int) -> bool:
	var t := table(w, k)
	if not unlocked(w, t):
		return false
	return not held(w, k) or level(w, k) < cap(w)


## Spell k's draw weight now: its weight, × affinity_permille when its affinity is the run's rune affinity.
static func weight_of(w: World, t: SpellTable) -> int:
	var wt := t.weight
	if t.affinity != &"" and w.affinity != null and w.affinity.table.id == t.affinity:
		wt = wt * w.spell_rules.affinity_permille / 1000
	return wt


## The spells the run's pool holds now (ascending index).
static func pool(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not enabled(w):
		return out
	for t in w.spell_tables:
		if can_offer(w, t.spell):
			out.append(t.spell)
	out.sort()
	return out


## The pool's draw weights (pool() order).
static func pool_weights(w: World, ks: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in ks:
		out.append(weight_of(w, table(w, k)))
	return out


# --- The offer --------------------------------------------------------------------------------------------------
## The spell reward i's offer gets, or -1. Pure: its own named stream for this altar, drawn the same however often it is
## asked (the e2e reads it before opening the altar).
static func offer_card(w: World, i: int) -> int:
	if not enabled(w) or i < 0 or i >= w.rewards.size():
		return -1
	var ks := pool(w)
	if ks.is_empty():
		return -1
	var stream := "%s:%d:%d:%d" % [STREAM_OFFER, w.loop, w.floor_index, w.rewards.ids[i]]
	var rng := RngStream.derive(w.seed_value, stream)
	if rng.range_int(0, 999) >= w.spell_rules.offer_permille:
		return -1
	var k := Offers.pick(rng, pool_weights(w, ks))
	return ks[k] if k >= 0 else -1


## Offers.roll, regular altar i's fresh offer `out` (after Starbound's): its spell card (offer_card) for one card.
static func into_offer(w: World, i: int, out: PackedInt32Array) -> PackedInt32Array:
	var k := offer_card(w, i)
	if k < 0 or out.is_empty():
		return out
	var code := Offers.spell_code(k)
	if out.size() < w.reward_table.offer_size:
		out.append(code)
		return out
	var s := _slot(w, i, out)
	if s >= 0:
		out[s] = code
	return out


static func _slot(w: World, i: int, out: PackedInt32Array) -> int:
	var first := 1 if out.size() > 1 and Offers.type_of(out[0]) == Offers.ABILITY else 0
	var fits := 0
	for c in out:
		if LootPacing.compatible(w, c):
			fits += 1
	for k in range(out.size() - 1, first - 1, -1):
		if Offers.type_of(out[k]) == Offers.STARBOUND:
			continue
		if LootPacing.is_jackpot(w, w.rewards.ids[i], out[k]):
			continue
		if fits != 1 or not LootPacing.compatible(w, out[k]):
			return k
	return -1


# --- The slots --------------------------------------------------------------------------------------------------
## The slot taking spell k would replace (-1: none): k not held with every slot full: the held spell of the lowest
## level, the leftmost of those.
static func replaces(w: World, k: int) -> int:
	if held(w, k) or not full(w):
		return -1
	var best := -1
	for s in w.spell_slots.size():
		if best < 0 or w.spell_levels[s] < w.spell_levels[best]:
			best = s
	return best


## Spell k is taken (BuildSlots, the pick): held, one level up (to the cap); new, the next free slot at Lv 1, ready;
## every slot full, it replaces the slot replaces() names.
static func take(w: World, k: int) -> void:
	if table(w, k) == null:
		return
	pad(w)
	var s := slot_of(w, k)
	if s >= 0:
		w.spell_levels[s] = mini(w.spell_levels[s] + 1, cap(w))
		return
	var r := replaces(w, k)
	if r >= 0:
		w.spell_slots[r] = k
		w.spell_levels[r] = 1
		w.spell_cd[r] = 0
		w.spell_cast_tick[r] = -1
		return
	if full(w):
		return
	w.spell_slots.append(k)
	w.spell_levels.append(1)
	w.spell_cd.append(0)
	w.spell_cast_tick.append(-1)


## The per-slot lists as long as the slots (a new floor's carry brings the slots and levels; the cooldowns start ready).
static func pad(w: World) -> void:
	var n := w.spell_slots.size()
	if w.spell_levels.size() != n:
		var old := w.spell_levels.size()
		w.spell_levels.resize(n)
		for s in range(old, n):
			w.spell_levels[s] = 1
	for list: String in ["spell_cd", "spell_cast_tick"]:
		var arr: PackedInt32Array = w.get(list)
		if arr.size() != n:
			var old := arr.size()
			arr.resize(n)
			for s in range(old, n):
				arr[s] = 0 if list == "spell_cd" else -1
			w.set(list, arr)


# --- The runner -------------------------------------------------------------------------------------------------
## Tick phase 6 (World.step, after Abilities.advance): the balls fly, the pushes slide, each slot counts down and casts.
static func advance(w: World) -> void:
	_advance_balls(w)
	_advance_pushes(w)
	_cast_slots(w)
	SpellZones.advance(w)  # What lasts pulses (a new one the tick it is cast) and ends
	_tick_holds(w)


## Each slot counts down and casts when ready and it has a target.
static func _cast_slots(w: World) -> void:
	if w.spell_slots.is_empty() or w.player_dead():
		return
	pad(w)
	for s in w.spell_slots.size():
		if w.spell_cd[s] > 0:
			w.spell_cd[s] -= 1
			if w.spell_cd[s] > 0:
				continue
		var t := table(w, w.spell_slots[s])
		if t == null:
			continue
		if cast(w, s, t):
			w.spell_cd[s] = t.cooldown_ticks
			w.spell_cast_tick[s] = w.tick


## Slot s's spell casts now if it has a target; true when it did.
static func cast(w: World, s: int, t: SpellTable) -> bool:
	var lv := w.spell_levels[s]
	match t.spell:
		FROST_NOVA:
			return _frost_nova(w, t, lv)
		FIREBALL:
			return _fireball(w, t, lv)
		SKY_STRIKE:
			return _sky_strike(w, t, lv, s)
	return SpellRoster.cast(w, t, lv)  # The other twelve


## Enemy i can be a spell's target: a living actor of the enemy team.
static func target(w: World, i: int) -> bool:
	return (
		i > 0
		and i < w.actors.size()
		and w.actors.teams[i] != ActorStore.TEAM_PLAYER
		and w.actors.dead[i] == 0
	)


## The living enemies within `reach` of `at`, ascending.
static func enemies_within(w: World, at: Vector2, reach: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r2 := reach * reach
	for j in w.aoe_candidates(at, reach):
		if target(w, j) and (w.actors.pos(j) - at).length_squared() <= r2:
			out.append(j)
	return out


## "The densest pack" (class doc): the enemy index at its centre, or -1 (no enemy within reach). `avoid`: centres of
## earlier bursts; an enemy within `avoid_r` of one isn't a centre nor counted (a second ball's own pack).
static func densest_pack(
	w: World, from: Vector2, reach: float, avoid := PackedVector2Array(), avoid_r := 0.0
) -> int:
	var radius := w.spell_rules.pack_radius_m if w.spell_rules != null else 3.0
	var cands := PackedInt32Array()
	for j in enemies_within(w, from, reach):
		if not _avoided(w.actors.pos(j), avoid, avoid_r):
			cands.append(j)
	var best := -1
	var best_n := 0
	var best_d := 0.0
	var r2 := radius * radius
	for c in cands:
		var at := w.actors.pos(c)
		var n := 0
		for j in cands:
			if (w.actors.pos(j) - at).length_squared() <= r2:
				n += 1
		var d := (at - from).length_squared()
		if best < 0 or n > best_n or (n == best_n and d < best_d):
			best = c
			best_n = n
			best_d = d
	return best


static func _avoided(p: Vector2, avoid: PackedVector2Array, r: float) -> bool:
	for c in avoid:
		if (p - c).length_squared() <= r * r:
			return true
	return false


## The element's status on enemy i, as the element card gives it (class doc).
static func status(w: World, i: int, t: SpellTable, root: int) -> void:
	if t.stacks <= 0 or w.actors.dead[i] == 1:
		return
	match t.element:
		ELEMENT_FIRE:
			Engines.add_burn(w, i, t.stacks, root, t.id)
		ELEMENT_FROST:
			Engines.add_frost(w, i, t.stacks, root, Engines.EFFECT_FROST)
		ELEMENT_LIGHTNING:
			ElementStack.on_hit(w, i, ElementStack.STORM)  # the Storm card leaves no stack: its hit charges
		ELEMENT_VENOM:
			Venom.add(w, i, t.stacks, root)
		ELEMENT_BLEED:
			Engines.add_bleed(w, i, t.stacks, root)


## The spell's hit on enemy i (the player's, TAG_ABILITY; `effect` overrides the spell's id): the HP removed.
static func hit(
	w: World, i: int, dmg: int, root: int, from: Vector2, t: SpellTable, effect := &""
) -> int:
	var pid := w.actors.ids[0]
	var id := effect if effect != &"" else t.id
	return Damage.hit(w, i, dmg, pid, pid, root, SimEvent.TAG_ABILITY, from, w.actors.pos(i), id)


## Freezes enemy i for `ticks` (a freeze-immune one, a boss, gets a frost stack instead: the element card's rule).
static func freeze(w: World, i: int, ticks: int, root: int, t: SpellTable) -> void:
	var a := w.actors
	if a.dead[i] == 1:
		return
	if Engines.freeze_immune(w, i):
		Engines.add_frost(w, i, maxi(1, t.stacks), root, Engines.EFFECT_FROST)
		return
	a.frozen_t[i] = maxi(a.frozen_t[i], ticks)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[i], a.pos(i))
	e.root_id = root
	e.amount = ticks
	e.effect_id = Engines.EFFECT_FREEZE
	Engines.thermal_break(w, i, root)  # fire and frost react from any source (Engines)


## F2: freeze, damage and push every enemy within radius of the hero.
static func _frost_nova(w: World, t: SpellTable, lv: int) -> bool:
	var at := w.player_pos()
	var r := SpellTable.at_f(t.radius_m, lv, 3.5)
	var near := enemies_within(w, at, r)
	if near.is_empty():
		return false
	var root := w.take_root()
	var dmg := SpellTable.at_i(t.damage, lv)
	var ticks := SpellTable.at_i(t.ticks, lv, 60)
	fx(w, FX_NOVA, at, at, r, t.spell)
	var a := w.actors
	var ids := PackedInt32Array()
	for i in near:
		ids.append(a.ids[i])
	for id in ids:
		var i := a.index_of(id)
		if i < 0 or a.dead[i] == 1:
			continue
		hit(w, i, dmg, root, at, t)
		if a.dead[i] == 1:
			continue
		freeze(w, i, ticks, root, t)
		_push(w, i, at, t.push_m)
	return true


## v0.11.0 O11, Frost Nova Lv 5 (Damage.hit: your hit landed on enemy i, frozen before it): it shatters.
static func on_frozen_hit(w: World, i: int, root: int, effect_id: StringName) -> void:
	var a := w.actors
	if effect_id == EFFECT_SHATTER or a.dead[i] == 1 or level(w, FROST_NOVA) < LEVELS:
		return
	var t := table(w, FROST_NOVA)
	if t == null or t.bonus_damage <= 0:
		return
	a.frozen_t[i] = 0
	var at := a.pos(i)
	fx(w, FX_SHATTER, at, at, 1.0, FROST_NOVA)
	hit(w, i, t.bonus_damage, root, at, t, EFFECT_SHATTER)


static func _push(w: World, i: int, from: Vector2, metres: float) -> void:
	var a := w.actors
	if (
		metres <= 0.0
		or a.dead[i] == 1
		or BossAi.is_boss_kind(a.kinds[i])
		or w.spell_push_id.has(a.ids[i])
	):
		return
	if EliteAi.is_elite_kind(a.kinds[i]):
		metres *= 0.5
	var away := a.pos(i) - from
	var len := Kin.length(away)
	w.spell_push_id.append(a.ids[i])
	w.spell_push_dir.append(away / len if len > 0.0 else Vector2.RIGHT)
	w.spell_push_step.append(metres / PUSH_TICKS)
	w.spell_push_left.append(PUSH_TICKS)


static func _advance_pushes(w: World) -> void:
	for j in range(w.spell_push_id.size() - 1, -1, -1):
		var i := w.actors.index_of(w.spell_push_id[j])
		if i > 0 and w.actors.dead[i] == 0:
			w.actors.set_pos(i, w.actors.pos(i) + w.spell_push_dir[j] * w.spell_push_step[j])
			w.spell_push_left[j] -= 1
		else:
			w.spell_push_left[j] = 0
		if w.spell_push_left[j] <= 0:
			w.spell_push_id.remove_at(j)
			w.spell_push_dir.remove_at(j)
			w.spell_push_step.remove_at(j)
			w.spell_push_left.remove_at(j)


## Count balls at the densest packs (class doc), locked now.
static func _fireball(w: World, t: SpellTable, lv: int) -> bool:
	var from := w.player_pos()
	var r := SpellTable.at_f(t.radius_m, lv, 3.0)
	var avoid := PackedVector2Array()
	var first := -1
	for n in SpellTable.at_i(t.count, lv, 1):
		var c := densest_pack(w, from, t.reach_m, avoid, r)
		if c < 0:
			c = first
		if c < 0:
			return false
		if first < 0:
			first = c
		var to := w.actors.pos(c)
		avoid.append(to)
		throw_ball(w, t, lv, from, to)
	return true


## A ball of spell t in flight from `from` to `to`, locked now (a Fireball, v0.11.0 O11 a Venom Orb).
static func throw_ball(w: World, t: SpellTable, lv: int, from: Vector2, to: Vector2) -> void:
	w.spell_ball_pos.append(from)
	w.spell_ball_to.append(to)
	w.spell_ball_spell.append(t.spell)
	w.spell_ball_level.append(lv)
	w.spell_ball_root.append(w.take_root())


static func _advance_balls(w: World) -> void:
	for b in range(w.spell_ball_pos.size() - 1, -1, -1):
		var t := table(w, w.spell_ball_spell[b])
		var p := w.spell_ball_pos[b]
		var to := w.spell_ball_to[b]
		var left := Kin.length(to - p)
		var step := t.speed_m_tick if t != null else 0.15
		if left > step and t != null:
			w.spell_ball_pos[b] = p + (to - p) / left * step
			continue
		var lv := w.spell_ball_level[b]
		var root := w.spell_ball_root[b]
		w.spell_ball_pos.remove_at(b)
		w.spell_ball_to.remove_at(b)
		w.spell_ball_spell.remove_at(b)
		w.spell_ball_level.remove_at(b)
		w.spell_ball_root.remove_at(b)
		if t != null:
			_land(w, t, lv, to, root)


## A ball came down at `at`: a Fireball bursts, a Venom Orb leaves its pool.
static func _land(w: World, t: SpellTable, lv: int, at: Vector2, root: int) -> void:
	if t.spell == VENOM_ORB:
		SpellRoster.pool(w, t, lv, at)
		return
	_burst(w, t, lv, at, root)
	if lv >= LEVELS and t.bonus_ticks > 0:  # v0.11.0 O11, Fireball Lv 5: the burst leaves burning ground
		SpellZones.add(
			w, SpellZones.FIRE, t, lv, at, t.bonus_radius_m, t.bonus_ticks, t.bonus_damage, 30
		)


static func _burst(w: World, t: SpellTable, lv: int, at: Vector2, root: int) -> void:
	var r := SpellTable.at_f(t.radius_m, lv, 3.0)
	fx(w, FX_BURST, at, at, r, t.spell)
	var dmg := SpellTable.at_i(t.damage, lv)
	var a := w.actors
	var ids := PackedInt32Array()
	for i in enemies_within(w, at, r):
		ids.append(a.ids[i])
	for id in ids:
		var i := a.index_of(id)
		if i < 0 or a.dead[i] == 1:
			continue
		hit(w, i, dmg, root, at, t)
		status(w, i, t, root)


## L1: count bolts from the sky, each jumping once (class doc).
static func _sky_strike(w: World, t: SpellTable, lv: int, s: int) -> bool:
	var from := w.player_pos()
	var cands := enemies_within(w, from, t.reach_m)
	if cands.is_empty():
		return false
	var a := w.actors
	var ids := PackedInt32Array()
	for i in cands:
		ids.append(a.ids[i])
	var rng := RngStream.derive(w.seed_value, "%s:%d:%d" % [STREAM_SKY, w.tick, s])
	var struck := PackedInt32Array()
	var dmg := SpellTable.at_i(t.damage, lv)
	var pid := a.ids[0]
	for n in SpellTable.at_i(t.count, lv, 3):
		var left := PackedInt32Array()
		for id in ids:
			var j := a.index_of(id)
			if j >= 0 and a.dead[j] == 0 and not struck.has(id):
				left.append(id)
		if left.is_empty():
			for id in ids:
				var j := a.index_of(id)
				if j >= 0 and a.dead[j] == 0:
					left.append(id)
		if left.is_empty():
			break
		var id := left[rng.range_int(0, left.size() - 1)]
		struck.append(id)
		var root := w.take_root()
		var i := a.index_of(id)
		var at := a.pos(i)
		fx(w, FX_BOLT, at, at, 0.0, t.spell)
		hit(w, i, dmg, root, at, t)
		status(w, i, t, root)
		if lv >= LEVELS:
			hold(w, i, t.bonus_ticks, 0)  # v0.11.0 O11, Lv 5: each bolt stuns
		var next := nearest(w, at, t.jump_m, PackedInt32Array([id]))
		if next < 0:
			continue
		var to := a.pos(next)
		fx(w, FX_JUMP, at, to, 0.0, t.spell)
		Damage.hit(w, next, dmg, pid, pid, root, SimEvent.TAG_ABILITY, at, to, t.id)
		status(w, next, t, root)
		if lv >= LEVELS:
			hold(w, next, t.bonus_ticks, 0)
	return true


## The nearest living enemy within reach of `at` whose id isn't in `skip` (ties: the lower index), or -1.
static func nearest(w: World, at: Vector2, reach: float, skip: PackedInt32Array) -> int:
	var best := -1
	var best_d := 0.0
	for j in enemies_within(w, at, reach):
		if skip.has(w.actors.ids[j]):
			continue
		var d := (w.actors.pos(j) - at).length_squared()
		if best < 0 or d < best_d:
			best = j
			best_d = d
	return best


## Up to `n` living enemies within `reach` of `at`, nearest first (ties: the lower index).
static func nearest_n(w: World, at: Vector2, reach: float, n: int) -> PackedInt32Array:
	var picked := PackedInt32Array()
	var dists := PackedFloat32Array()
	for j in enemies_within(w, at, reach):
		var d := (w.actors.pos(j) - at).length_squared()
		var k := 0
		while k < picked.size() and dists[k] <= d:
			k += 1
		picked.insert(k, j)
		dists.insert(k, d)
	return picked.slice(0, n)


## The ids of the first `n` living enemies a line from `from` through `to` meets within `reach` of
## `from` (nearest along it first; an enemy counts when its body is within LINE_HALF_M of the line). `first`, the aimed
## enemy, is always on it.
static func line(
	w: World, from: Vector2, to: Vector2, reach: float, n: int, first: int
) -> PackedInt32Array:
	var a := w.actors
	var d := to - from
	var len := Kin.length(d)
	var dir := d / len if len > 0.0 else Vector2.RIGHT
	var ids := PackedInt32Array()
	var along := PackedFloat32Array()
	for j in enemies_within(w, from, reach):
		var v := a.pos(j) - from
		var u := v.dot(dir)
		var side := absf(v.x * dir.y - v.y * dir.x)
		if a.ids[j] != first and (u < 0.0 or side > LINE_HALF_M + a.radius[j]):
			continue
		var k := 0
		while k < ids.size() and along[k] <= u:
			k += 1
		ids.insert(k, a.ids[j])
		along.insert(k, u)
	var out := ids.slice(0, n)
	if not out.has(first) and ids.has(first):
		out[out.size() - 1] = first
	return out


## The view's log (World.spell_fx_*): a cast of `kind` by spell `spell` (-1: none).
static func fx(w: World, kind: int, from: Vector2, to: Vector2, size: float, spell := -1) -> void:
	if w.spell_fx_kind.size() >= FX_MAX:
		w.spell_fx_kind.remove_at(0)
		w.spell_fx_tick.remove_at(0)
		w.spell_fx_from.remove_at(0)
		w.spell_fx_to.remove_at(0)
		w.spell_fx_size.remove_at(0)
		if not w.spell_fx_spell.is_empty():
			w.spell_fx_spell.remove_at(0)
	w.spell_fx_kind.append(kind)
	w.spell_fx_tick.append(w.tick)
	w.spell_fx_from.append(from)
	w.spell_fx_to.append(to)
	w.spell_fx_size.append(size)
	w.spell_fx_spell.append(spell)


# --- The holds ------------------------------------------------------------------------------------
## Holds enemy i `ticks` at `permille` of its speed (0: it stands still and acts not). One hold an enemy: the longer
## and the stronger win. Never a freeze-immune actor (a boss).
static func hold(w: World, i: int, ticks: int, permille: int) -> void:
	var a := w.actors
	if ticks <= 0 or i <= 0 or a.dead[i] == 1 or Engines.freeze_immune(w, i):
		return
	var k := w.spell_hold_id.find(a.ids[i])
	if k >= 0:
		w.spell_hold_t[k] = maxi(w.spell_hold_t[k], ticks)
		w.spell_hold_permille[k] = mini(w.spell_hold_permille[k], permille)
		return
	if w.spell_hold_id.size() >= HOLDS_MAX:
		return
	w.spell_hold_id.append(a.ids[i])
	w.spell_hold_t.append(ticks)
	w.spell_hold_permille.append(permille)


## The speed enemy i keeps under a spell's hold (per mille; 1000: none).
static func hold_permille(w: World, i: int) -> int:
	if w.spell_hold_id.is_empty():
		return 1000
	var k := w.spell_hold_id.find(w.actors.ids[i])
	return w.spell_hold_permille[k] if k >= 0 else 1000


## Enemy i is stunned or knocked down by a spell (EnemyAi and EliteAi hold it as if frozen).
static func held_still(w: World, i: int) -> bool:
	return not w.spell_hold_id.is_empty() and hold_permille(w, i) == 0


static func _tick_holds(w: World) -> void:
	for k in range(w.spell_hold_id.size() - 1, -1, -1):
		w.spell_hold_t[k] -= 1
		var i := w.actors.index_of(w.spell_hold_id[k])
		if w.spell_hold_t[k] <= 0 or i < 0 or w.actors.dead[i] == 1:
			w.spell_hold_id.remove_at(k)
			w.spell_hold_t.remove_at(k)
			w.spell_hold_permille.remove_at(k)


# --- Hash and reads ---------------------------------------------------------------------------------------------
static func touched(w: World) -> bool:
	return (
		not w.spell_slots.is_empty()
		or not w.spell_ball_pos.is_empty()
		or not w.spell_push_id.is_empty()
		or not w.spell_zone_kind.is_empty()
		or not w.spell_hold_id.is_empty()
	)


static func hash_into(w: World, h: StateHasher) -> void:
	h.add_ints(w.spell_slots)
	h.add_ints(w.spell_levels)
	h.add_ints(w.spell_cd)
	h.add_ints(w.spell_cast_tick)
	h.add_ints(w.spell_ball_spell)
	h.add_ints(w.spell_ball_level)
	h.add_ints(w.spell_ball_root)
	for p in w.spell_ball_pos:
		h.add_f32(p.x)
		h.add_f32(p.y)
	for p in w.spell_ball_to:
		h.add_f32(p.x)
		h.add_f32(p.y)
	h.add_ints(w.spell_push_id)
	h.add_ints(w.spell_push_left)
	SpellZones.hash_into(w, h)  # The lasting spells and the holds


## For the HUD and the pick (WorldReader.spells): the slot count and each held slot's spell, id, name key, element,
## level, cooldown left and total (ticks) and the tick it last cast (-1: not yet).
static func read(w: World) -> Dictionary:
	var out: Array[Dictionary] = []
	for s in w.spell_slots.size():
		var t := table(w, w.spell_slots[s])
		(
			out
			. append(
				{
					"spell": w.spell_slots[s],
					"id": t.id if t != null else &"",
					"name_key": t.name_key if t != null else &"",
					"element": t.element if t != null else 0,
					"level": w.spell_levels[s] if s < w.spell_levels.size() else 1,
					"cooldown": w.spell_cd[s] if s < w.spell_cd.size() else 0,
					"cooldown_total": t.cooldown_ticks if t != null else 1,
					"cast_tick": w.spell_cast_tick[s] if s < w.spell_cast_tick.size() else -1,
				}
			)
		)
	return {"slots": out, "max": slots(w), "tick": w.tick}

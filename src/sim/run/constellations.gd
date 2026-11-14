class_name Constellations
extends RefCounted
## The Constellations a run holds. A loop's
## arrival offers 1 of 3, free and permanent (never rerolled); a run never holds one twice, except Prism (twice at
## most: a Gun's third and fourth Element slot). World.constellations lists the held ids in pick order.
## This file is the shared contract the W3-P10 steps code against: the ids and the reads. The pick, its offer, the
## save and the hash belong to the Constellation step (W3-P10c).
## The pick. When the run enters a new loop (RunState.finish_floor,
## the Loop device), offer() draws up to OFFER_SIZE ids the run may still take on the named stream
## `constellation_<loop>` of the run seed; the carry hands them to the loop's floor 1 (World.constellation_offer).
## While an offer is open (and the hero has landed) the world runs only the pick (choose): a pick 1..n takes that
## Constellation, anything else (a cancel included: no skip, owner Q3) waits. Held and offered ids are hashed once
## either exists, so a loop-1 world hashes as before. The effects this step owns:
## - C1 Prism: a Gun run's Element slots + 1 per Prism (AttackSlots.limit); a Blade run (no Element limit) takes the
##   element falloff ElementPairTable.prism_falloff_steps steps softer per Prism (ElementStack.falloff_permille);
## - C2 Twin Star: each overlevel's step × TWIN_STAR_OVERLEVEL_MULT (CardLevels.overlevel_permille, which the
##   compile and the pick card's forecast both read);
## - C3 Glass Sky: the hero's damage × GLASS_SKY_DAMAGE_PERMILLE (Stats.damage_at) and max HP × GLASS_SKY_HP_PERMILLE
##   (Stats.max_hp_at, from the pick on; the pick lowers the max at once and clamps HP into 1..max);
## - C8 Hunter's Sky: the hero's hits and damage-over-time ticks on elites and bosses × HUNTERS_SKY_PERMILLE
##   (Damage.hit, Damage.tick_dot).
## Starfall, Meteor, Deep Wounds and Supernova are offered here; their effects are their own steps'.
## Pure: integers and a named stream.

const PRISM := 1
const TWIN_STAR := 2
const GLASS_SKY := 3
const STARFALL := 4
const DEEP_WOUNDS := 5
const SUPERNOVA := 6
const HUNTERS_SKY := 8
## Gravity Well (7) was dropped (owner Q4: "no"); the id stays unused.
const ALL: Array[int] = [PRISM, TWIN_STAR, GLASS_SKY, STARFALL, DEEP_WOUNDS, SUPERNOVA, HUNTERS_SKY]
const PRISM_MAX := 2
## W3-P10c: the cards a loop's pick offers at most.
const OFFER_SIZE := 3
## W3-P10c: the effects' starting values (G1 §C, "Starting value").
const TWIN_STAR_OVERLEVEL_MULT := 2  # + 15 % an overlevel -> + 30 %
const GLASS_SKY_DAMAGE_PERMILLE := 2000
const GLASS_SKY_HP_PERMILLE := 500
const HUNTERS_SKY_PERMILLE := 1500
## W3-P10c: the names by id: the locale keys CONST_<NAME>, CONST_<NAME>_DESC (upper case) and the card ids const_<name>
## (the art: icon_const_<name>.png).
const NAMES := {
	PRISM: "prism",
	TWIN_STAR: "twin_star",
	GLASS_SKY: "glass_sky",
	STARFALL: "starfall",
	DEEP_WOUNDS: "deep_wounds",
	SUPERNOVA: "supernova",
	HUNTERS_SKY: "hunters_sky",
}


## Whether the run holds Constellation `id`.
static func has(w: World, id: int) -> bool:
	return w.constellations.has(id)


## How many times the run holds `id` (Prism: 0..2, the others 0 or 1).
static func count(w: World, id: int) -> int:
	return w.constellations.count(id)


## W3-P10c: the most times a run may hold `id` (PRISM_MAX for Prism, else 1).
static func max_held(id: int) -> int:
	return PRISM_MAX if id == PRISM else 1


## W3-P10c: the ids a run holding `held` may still be offered, in ALL's order.
static func offerable(held: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in ALL:
		if held.count(id) < max_held(id):
			out.append(id)
	return out


## W3-P10c: loop `loop`'s offer for a run holding `held`: OFFER_SIZE distinct ids of offerable(held) (all of them
## when fewer are left; none when none are), drawn without repeats on the stream `constellation_<loop>`.
static func offer(run_seed: int, loop: int, held: PackedInt32Array) -> PackedInt32Array:
	var left := offerable(held)
	var out := PackedInt32Array()
	if left.is_empty():
		return out
	var rng := RngStream.derive(run_seed, "constellation_%d" % loop)
	while out.size() < OFFER_SIZE and not left.is_empty():
		var k := rng.range_int(0, left.size() - 1)
		out.append(left[k])
		left.remove_at(k)
	return out


## W3-P10c: a Constellation offer is open (the world waits for the pick).
static func open(w: World) -> bool:
	return not w.constellation_offer.is_empty()


## W3-P10c: the pick's tick (World.step phase 1a): a pick 1..n takes that card; anything else waits.
static func choose(w: World, frame: InputFrame) -> void:
	var c := frame.pick - 1
	if c < 0 or c >= w.constellation_offer.size():
		return
	take(w, c)


## W3-P10c: takes card `c` of the open offer (choose, after its check; tests call it directly): the id joins the
## held ones, the offer closes, and Glass Sky lowers the max HP at once.
static func take(w: World, c: int) -> void:
	var id := w.constellation_offer[c]
	var before := Stats.max_hp(w)
	w.constellations.append(id)
	w.constellation_offer = PackedInt32Array()
	if id == GLASS_SKY:
		var a := w.actors
		a.max_hp[0] = maxi(1, a.max_hp[0] + Stats.max_hp(w) - before)
		a.hp[0] = clampi(a.hp[0], 1, a.max_hp[0])
	Modifiers.invalidate(w)  # Twin Star's overlevels and Prism's slot reach the compile


## W3-P10c: `permille` when the run holds `id`, else 1000.
static func mult(w: World, id: int, permille: int) -> int:
	return permille if has(w, id) else 1000


## W3-P10c: Hunter's Sky's multiplier on the hero's hit or tick on actor `target`, per mille.
static func hunt_permille(w: World, target: int) -> int:
	if target <= 0 or not has(w, HUNTERS_SKY):
		return 1000
	var k := w.actors.kinds[target]
	if BossAi.is_boss_kind(k) or EliteAi.is_elite_kind(k):
		return HUNTERS_SKY_PERMILLE
	return 1000


## W3-P10c: `amount` × `permille`, rounded to nearest (unchanged at 1000).
static func scale(amount: int, permille: int) -> int:
	if permille == 1000 or amount <= 0:
		return amount
	return (amount * permille + 500) / 1000


## W3-P10c: the held and offered ids, once either exists (a loop-1 world hashes as before).
static func hash_into(w: World, h: StateHasher) -> void:
	if w.constellations.is_empty() and w.constellation_offer.is_empty():
		return
	h.add_int(w.constellations.size())
	h.add_ints(w.constellations)
	h.add_int(w.constellation_offer.size())
	h.add_ints(w.constellation_offer)


## W3-P10c: id's locale name and sentence keys, and its card id (the art: icon_<card id>.png, the violet frame).
static func name_key(id: int) -> String:
	return "CONST_%s" % String(NAMES.get(id, "unknown")).to_upper()


static func desc_key(id: int) -> String:
	return "CONST_%s_DESC" % String(NAMES.get(id, "unknown")).to_upper()


static func card_id(id: int) -> StringName:
	return StringName("const_%s" % NAMES.get(id, "unknown"))

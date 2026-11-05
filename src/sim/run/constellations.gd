class_name Constellations
extends RefCounted
## v0.10.5 W3-P10 (owner W7, docs/roadmap/v0.10.5/W3_W7_LOOP_POWER_G1.md §C): the Constellations a run holds. A loop's
## arrival offers 1 of 3, free and permanent (never rerolled); a run never holds one twice, except Prism (twice at
## most: a Gun's third and fourth Element slot). World.constellations lists the held ids in pick order.
## This file is the shared contract the W3-P10 steps code against: the ids and the reads. The pick, its offer, the
## save and the hash belong to the Constellation step (W3-P10c).

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


## Whether the run holds Constellation `id`.
static func has(w: World, id: int) -> bool:
	return w.constellations.has(id)


## How many times the run holds `id` (Prism: 0..2, the others 0 or 1).
static func count(w: World, id: int) -> int:
	return w.constellations.count(id)

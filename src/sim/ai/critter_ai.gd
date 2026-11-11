class_name CritterAi
extends RefCounted
## The horde critters (the five kinds FIRST..LAST, one per biome): which kinds they are. Their thinking, walking and
## touch run in the native library with the other table kinds (NativeAi, NativeStrike; native/src/zd_ai.cpp,
## zd_strike.cpp): the rise-in, the straight plan at the hero pushed off its neighbours, the step, and contact_damage
## at most every contact_cd_ticks within EnemyAi.CRITTER_TOUCH_M of contact.

const FIRST := ActorStore.Kind.DUST_MITE
const LAST := ActorStore.Kind.STAR_MOTE


static func takes(kind: int) -> bool:
	return kind >= FIRST and kind <= LAST

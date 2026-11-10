extends GutTest
## EnemyAi's per-kind lookup tables against the kind tests they stand for.

const K := ActorStore.Kind


## The per-kind lookups give what the kind tests they replace gave, for every kind (and past the table).
func test_the_kind_lookups_equal_the_kind_tests() -> void:
	var bad := 0
	for kind in range(-3, EnemyAi.KIND_SLOTS + 3):
		var base: int = EnemyAi.VARIANT_BASE.get(kind, CanyonShore.BASE.get(kind, kind))
		if kind == K.LENS_DRONE:
			base = K.NEEDLE
		var role := EnemyAi.Role.OTHER
		if CritterAi.takes(kind):
			role = EnemyAi.Role.CRITTER
		elif BossAi.is_boss_kind(kind):
			role = EnemyAi.Role.BOSS
		elif EnemyAi.is_enemy_kind(kind):
			role = EnemyAi.Role.ENEMY
		var f := EnemyAi.flags_of(kind)
		var ok := (
			EnemyAi.behaviour_of(kind) == base
			and EnemyAi.role_of(kind) == role
			and EnemyAi.is_critter(kind) == (kind in EnemyAi.CRITTERS)
			and EnemyAi._keeps_away(kind) == (base in EnemyAi.KEEP_AWAY)
			and EnemyAi._turns_slowly(kind) == (base == K.WARDEN or kind == K.SHIELD_BEARER)
			and EnemyAi.armoured(kind) == (base == K.WARDEN or kind == K.SHIELD_BEARER)
			and EnemyAi._charges(kind) == (base in [K.CHARGER, K.HATCHLING, K.SWARMER])
			and ((f & EnemyAi.F_ELITE) != 0) == EliteAi.is_elite_kind(kind)
			and ((f & EnemyAi.F_VARIANT) != 0) == Variants.is_variant(kind)
			and ((f & EnemyAi.F_CANYON) != 0) == CanyonShore.owns(kind)
			and ((f & EnemyAi.F_RUINS) != 0) == RuinsRocks.takes(kind)
		)
		if not ok:
			bad += 1
	assert_eq(bad, 0, "kinds whose lookups differ from their tests")

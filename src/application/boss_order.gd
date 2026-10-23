class_name BossOrder
extends RefCounted
## v0.9.0 NB1: the order the floor bosses compile in (World.boss_tables), which a save stores indices into
## (BossStore.table, the floor's boss, the pools). The six bosses before v0.9.0 keep their indices (by id, as
## ContentRepository.all_of gave them); a boss added later (BossDefinition.save_order > 0) comes after them, by
## save_order then id, so adding one never moves a saved index.


static func defs(repo: ContentRepository) -> Array:
	var out := repo.all_of(&"bosses").duplicate()
	out.sort_custom(
		func(a: BossDefinition, b: BossDefinition) -> bool:
			if a.save_order != b.save_order:
				return a.save_order < b.save_order
			return String(a.id) < String(b.id)
	)
	return out

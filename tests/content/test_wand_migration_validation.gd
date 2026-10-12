extends GutTest
## v0.6.5 WN5b (docs/design/WAND.md "What happens to the v0.6 cards"; CONTENT_SCHEMA "The wand"): the one table that
## retires the v0.6 cards (data/wand/migration.tres). Every v0.6 slot card and the six old ability modifiers either
## kept its id as a wand card (WN3/WN4) or has a row; every target is a card in the data or a pending shared-pool id;
## a bad table is reported.

## WAND.md's "map directly" cards that kept their ids as wand cards (WN3, WN4): never in the table.
const KEPT: Array[StringName] = [
	&"echo_slash",
	&"halo_shot",
	&"boomerang",
	&"orbit_rounds",
	&"split_shot",
	&"wide_arc",
	&"long_shadow",
	&"blade_orbit",
]
## The v0.6 cards WN5a kept as the shared pool's S cards (S1 Fire, S2 Lightning, S3 Frost, S4 Venom, S6 Void; lead,
## 2026-10-12): never retired, and targets of the table. They become wand cards with WN5a's merge.
const KEPT_AS_SHARED: Array[StringName] = [
	&"ember_core", &"storm_core", &"frost_core", &"venom_core", &"gravity_well"
]
const SIX: Array[StringName] = [
	&"bomb_lobber", &"drone_buddy", &"orbit_blades", &"arc_field", &"frost_nova", &"flame_trail"
]

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _table() -> WandMigrationDefinition:
	return _repo.get_def(&"wand", &"migration") as WandMigrationDefinition


func test_the_shipped_table_is_discovered_and_valid() -> void:
	var m := _table()
	assert_not_null(m, "data/wand/migration.tres")
	assert_eq(m.validate(), [])
	var defs: Array[ContentDef] = []
	defs.assign(_repo.all_of(&"wand") + _all())
	assert_eq(WandMigrationDefinition.cross_check(defs), [])
	assert_eq(
		m.old_ids.size(), 43, "the v0.6 cards it retires: 13 + 4 + 17 + 3 + 6 (WAND.md table)"
	)


## Every v0.6 slot card (an item that names modifiers or needs an ability, not a wand or trigger card) is in the
## table unless it kept its id as a wand card; the six old abilities too.
func test_every_v0_6_card_has_a_row_or_kept_its_id() -> void:
	var m := _table()
	for def: ItemDefinition in _repo.all_of(&"items"):
		if def.kind in [ItemDefinition.Kind.WAND, ItemDefinition.Kind.TRIGGER]:
			continue
		var slot := not def.modifiers.is_empty() or not String(def.requires_ability).is_empty()
		if not slot:
			assert_false(m.old_ids.has(def.id), "%s takes no slot: not a wand card, kept" % def.id)
			continue
		if KEPT_AS_SHARED.has(def.id):
			assert_false(m.old_ids.has(def.id), "%s is a shared-pool card (WN5a)" % def.id)
		elif KEPT.has(def.id):
			assert_true(def.tags.has("wand"), "%s kept its id as a wand card" % def.id)
			assert_false(m.old_ids.has(def.id))
		else:
			assert_true(m.old_ids.has(def.id), "%s has a row" % def.id)
	for id in SIX:
		assert_true(m.old_ids.has(id), "the old ability %s has a row" % id)


## A target is a wand card of the run's pool (a Blade target is never a Gun-only card, and the other way) or pending.
func test_every_target_fits_its_weapon() -> void:
	var m := _table()
	for k in m.old_ids.size():
		for pair: Array in [[m.blade_into[k], &"gun"], [m.gun_into[k], &"blade"]]:
			var id: StringName = pair[0]
			if String(id).is_empty() or m.pending.has(id):
				continue
			var d := _repo.get_def(&"items", id) as ItemDefinition
			assert_not_null(d, "%s → %s" % [m.old_ids[k], id])
			if d != null:
				assert_true(
					d.tags.has("wand") or KEPT_AS_SHARED.has(id), "%s is a wand or shared card" % id
				)
				assert_ne(
					d.requires_weapon, pair[1], "%s → %s fits the weapon" % [m.old_ids[k], id]
				)


func test_a_bad_table_is_reported() -> void:
	var m := WandMigrationDefinition.new()
	m.id = &"migration"
	m.old_ids = [&"storm_core", &"storm_core", &"ember_core"]
	m.blade_into = [&"", &""]
	m.gun_into = [&"", &"", &"ember_core"]
	var codes := m.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	assert_has(codes, &"table_size")
	assert_has(codes, &"duplicate_id")
	m.blade_into = [&"", &"", &""]
	codes = m.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	assert_has(codes, &"retired_target", "a card never maps onto a retired one")
	var bad := WandMigrationDefinition.new()
	bad.id = &"migration"
	bad.old_ids = [&"no_such_card"]
	bad.blade_into = [&"no_such_target"]
	bad.gun_into = [&"shared_x"]
	bad.pending = [&"shared_x"]
	var defs: Array[ContentDef] = [bad]
	var issues := WandMigrationDefinition.cross_check(defs)
	assert_eq(issues.size(), 2, "the unknown card and the unknown target; a pending target is fine")


func _all() -> Array:
	return _repo.all_of(&"items") + _repo.all_of(&"ability")

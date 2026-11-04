extends GutTest
## v0.10.5 W3-O12 (docs/roadmap/v0.10.5/W3_O12_VFX_GALLERY.md): the Effects gallery's lists. Every effect scene under
## the pack folders is either used (a PackFx row, a file that names it, or part of a used scene) or in the unused
## group, never both; every PackFx row has an entry; the sim groups hold the hero's, the enemies' and the bosses'.

const TINTED := "res://assets/vfx_zd/tinted_fire/tinted_fire_ball.tscn"
const SPARKS := "res://assets/BinbunVFX/fire_effects/src/prefs/fire/sparks.tscn"
const OTHER := "res://assets/BinbunVFX/smoke_effects/effects/smoke/smoke_vfx_01.tscn"


func test_every_pack_scene_is_used_or_listed_unused() -> void:
	var c := EffectsCatalog.build(null, false)
	var all := EffectsCatalog.scan_scenes()
	assert_gt(all.size(), 200, "the scan finds the installed packs' scenes")
	assert_eq(c.scenes, all)
	var listed := {}
	for e in c.in_group(&"pack_unused"):
		listed["res://" + String(e["source"])] = true
	for path in all:
		var u := c.used.has(path)
		var l := listed.has(path)
		assert_true(u != l, "%s: used (%s) or listed unused (%s), one of them" % [path, u, l])
	assert_eq(c.used.size() + c.unused.size(), all.size())
	assert_eq(listed.size(), c.unused.size())
	var per := 0
	for pack: String in c.per_pack:
		per += int(c.per_pack[pack][0]) + int(c.per_pack[pack][1])
	assert_eq(per, all.size(), "the per-pack counts cover every scene")


func test_every_pack_row_is_an_entry_and_its_scene_is_used() -> void:
	var c := EffectsCatalog.build(null, false)
	var def := PackFx.shared_def()
	assert_eq(c.in_group(&"pack_used").size(), def.count(), "one entry per PackFx row")
	for k in def.count():
		assert_true(c.used.has(def.scenes[k]), "%s's scene counts as used" % def.ids[k])
		assert_false(c.unused.has(def.scenes[k]))


func test_a_scene_is_used_by_a_file_and_its_parts_by_it() -> void:
	var all := PackedStringArray([TINTED, SPARKS, OTHER])
	var texts := {"res://src/x.gd": 'const LOOK := "%s"' % TINTED}
	var used := EffectsCatalog.referenced(all, null, texts)
	assert_eq(used.get(TINTED, ""), "x.gd", "named by a script")
	assert_true(String(used.get(SPARKS, "")).begins_with("part of"), "a sub-scene of a used scene")
	assert_false(used.has(OTHER), "named by nothing")


func test_code_uses_finds_the_scripts_of_an_id() -> void:
	assert_true(EffectsCatalog.code_uses(&"vx1_hit_ember").has("hit_pack.gd"))
	assert_eq(EffectsCatalog.code_uses(&"no_such_effect_id_at_all").size(), 0)


func test_the_sim_groups_hold_the_builds_cards_enemies_and_bosses() -> void:
	var c := EffectsCatalog.build()
	var hero := c.in_group(&"hero")
	var items := c.repo.all_of(&"items").size()
	var abilities := 0
	for a: Resource in c.repo.all_of(&"ability"):
		if (a as AbilityDefinition).start_weapon == &"":
			abilities += 1
	assert_eq(
		hero.size(),
		2 * EffectsCatalog.BASE_MOVES.size() + items + abilities,
		"each build's moves, every card, the abilities that are not a start weapon"
	)
	assert_gt(c.in_group(&"enemies").size(), 10)
	assert_gt(c.in_group(&"bosses").size(), 10)
	for g: StringName in [&"hero", &"enemies", &"bosses"]:
		for e in c.in_group(g):
			assert_eq(e["kind"], &"sim")
			assert_true(e.has("recipe") and String(e["title"]) != "", "%s: a recipe and a name" % g)

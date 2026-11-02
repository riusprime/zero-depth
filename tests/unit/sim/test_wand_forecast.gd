extends GutTest
## v0.10.5 O13 (owner P10; evidence/O13_WAND_FORECAST.md): the wand forecast (WandForecast) reads the attack spec the
## sim's own compiler makes for that wand, so it never disagrees with the outcome (EI-07). For six representative
## wands (both orders of an order-dependent pair among them) the forecast of an order the world doesn't hold yet equals
## the numbers the world gives once it holds that order (the cached book, ItemEffects.shot_period_ticks, the blade's
## steps); the order-dependent pairs read differently; the forecast writes nothing; every phrase has en and es.

const W := preload("res://tests/support/mx4_world.gd")
## [weapon, card ids in slot order]. Big·Split vs Split·Big and Ember·Twin vs Twin·Ember are order-dependent pairs.
const WANDS := [
	[&"gun", []],
	[&"gun", [&"gun_big_shot", &"split_shot"]],
	[&"gun", [&"split_shot", &"gun_big_shot"]],
	[&"gun", [&"gun_twin", &"ember_core", &"gun_rapid_fire", &"gun_echo"]],
	[&"gun", [&"halo_shot", &"gun_pierce", &"gun_ricochet", &"frost_core"]],
	[&"blade", [&"heavy", &"whirl", &"frost_core", &"echo_slash"]],
]


func _codes(w: World, ids: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id: StringName in ids:
		out.append(W.item(w, id))
	return out


## A world holding `ids` reversed (so the forecast's order is one it doesn't hold yet).
func _world(weapon: StringName, ids: Array) -> World:
	var rev := ids.duplicate()
	rev.reverse()
	return W.world(weapon, rev)


## Holds `codes` in that order through the sim's own reorder (Wand.move), as the Build page's moves would.
func _hold(w: World, codes: PackedInt32Array) -> void:
	for k in codes.size():
		var at := w.mod_slots.find(codes[k])
		if at != k:
			assert_true(Wand.move(w, at, k))
	assert_eq(w.mod_slots, codes)


## The numbers the world gives for the wand it holds (the outcome).
func _outcome(w: World) -> Dictionary:
	var gun := PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w)
	if gun:
		var s := Modifiers.bolt(w)
		var d := Attacks.bolt_base_damage(s) * PlayerBuild.bolt_permille(w) / 1000
		if s.share_permille > 0:
			d = Attacks.share_of(d, s.share_permille)
		return {
			"shots": WandForecast.shots(w, s),
			"damage": d,
			"period_ticks": ItemEffects.shot_period_ticks(w),
			"area_mm": int(round(s.radius_m * 1000.0)),
		}
	var ticks := 0
	var sum := 0
	for k in w.player.combo.size():
		ticks += BladeForms.step(w, k).ticks
		sum += Modifiers.step(w, k).damage * PlayerBuild.melee_permille(w) / 1000
	return {
		"damage": sum / w.player.combo.size(),
		"period_ticks": ticks,
		"area_mm": int(round(Attacks.arc_reach_m(w, Modifiers.step(w, 0)) * 1000.0)),
	}


func test_the_forecast_numbers_are_the_outcome_numbers_for_six_wands() -> void:
	for row: Array in WANDS:
		var w := _world(row[0], row[1])
		var codes := _codes(w, row[1])
		var f := WandForecast.of(w, codes)
		_hold(w, codes)
		var got: Dictionary = f["numbers"]
		var want := _outcome(w)
		for key: String in want:
			assert_eq(got[key], want[key], "%s %s: %s" % [row[0], str(row[1]), key])
		assert_gt(int(got["per_second_x10"]), 0, "%s: a damage per second" % str(row[1]))
		gut.p("%s %s: %s | %s" % [row[0], str(row[1]), _text(f)[0], _text(f)[1]])


func test_the_held_wand_forecast_is_the_cached_book_spec() -> void:
	var w := W.world(&"gun", [&"split_shot", &"gun_big_shot"])
	var f := WandForecast.of(w, w.mod_slots)
	var s := Modifiers.bolt(w)
	assert_eq(int(f["numbers"]["area_mm"]), int(round(s.radius_m * 1000.0)))
	assert_eq(
		f["numbers"]["period_ticks"],
		ItemEffects.shot_period_ticks(w),
		"the period the Gun fires at"
	)
	assert_eq(f, WorldReader.new(w).wand_forecast(), "the reader's forecast of the held wand")


func test_order_dependent_pairs_forecast_differently() -> void:
	var w := W.world(&"gun", [&"gun_big_shot", &"split_shot"])
	var a := _text(WandForecast.of(w, _codes(w, [&"gun_big_shot", &"split_shot"])))
	var b := _text(WandForecast.of(w, _codes(w, [&"split_shot", &"gun_big_shot"])))
	assert_ne(a[0], b[0], "Big·Split reads unlike Split·Big: %s / %s" % [a[0], b[0]])
	assert_string_contains(a[0], "Bolt")
	assert_string_contains(a[0], "on hit:")
	var g := W.world(&"gun", [&"ember_core", &"gun_twin"])
	var c := _text(WandForecast.of(g, _codes(g, [&"ember_core", &"split_shot"])))
	var d := _text(WandForecast.of(g, _codes(g, [&"split_shot", &"ember_core"])))
	assert_ne(c[0], d[0], "Ember·Split reads unlike Split·Ember: %s / %s" % [c[0], d[0]])


func test_the_forecast_writes_nothing() -> void:
	var w := W.world(&"gun", [&"gun_big_shot", &"split_shot", &"ember_core"])
	W.run(w, 30, InputFrame.SHOOT, InputFrame.SHOOT)
	var book := Modifiers.book(w)
	var hash0 := w.state_hash()
	var slots := w.mod_slots.duplicate()
	var r := WorldReader.new(w)
	var read := r.wand()
	for k in 3:
		r.wand_forecast(WorldReader.wand_moved(read, k, (k + 1) % 3))
	WandForecast.of(w, _codes(w, [&"ember_core", &"split_shot", &"gun_big_shot"]))
	assert_eq(w.state_hash(), hash0, "the state hash doesn't move")
	assert_eq(w.mod_slots, slots, "the wand is the same")
	assert_same(w.attack_book, book, "the cached book is the same object")


func test_every_forecast_phrase_has_en_and_es() -> void:
	var keys := PackedStringArray()
	for d: Dictionary in [
		WandForecast.FORM_KEYS, WandForecast.STATUS_KEYS, WandForecast.TRIGGER_KEYS
	]:
		for k: Variant in d:
			keys.append(String(d[k]))
	for k: String in [
		"UI_FORECAST_TITLE",
		"UI_FORECAST_AFTER",
		"UI_FORECAST_LINE",
		"UI_FORECAST_THEN",
		"UI_FORECAST_AND",
		"UI_FORECAST_COUNT",
		"UI_FORECAST_BIG",
		"UI_FORECAST_SMALL",
		"UI_FORECAST_PIERCES",
		"UI_FORECAST_BOUNCES",
		"UI_FORECAST_CHAINS",
		"UI_FORECAST_HOMES",
		"UI_FORECAST_RETURNS",
		"UI_FORECAST_REPEATS",
		"UI_FORECAST_REPEAT",
		"UI_FORECAST_NUMBERS_GUN",
		"UI_FORECAST_NUMBERS_BLADE",
		"UI_FORECAST_FORM_LASER",
		"UI_FORECAST_FORM_BOMB",
		"UI_FORECAST_FORM_LANCE",
		"UI_FORECAST_FORM_GLAIVE",
		"UI_FORECAST_FORM_SEEKERS",
		"UI_FORECAST_FORM_WAVE",
		"UI_FORECAST_FORM_WISPS",
		"UI_FORECAST_FORM_VOID",
		"UI_FORECAST_FORM_RUNE",
		"UI_FORECAST_FORM_PELLETS",
	]:
		keys.append(k)
	var rows := {}
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3:
			rows[row[0]] = row
	for k in keys:
		assert_true(rows.has(k), "%s is in strings.csv" % k)
		if rows.has(k):
			var row: PackedStringArray = rows[k]
			assert_false(row[1].is_empty(), "%s has en" % k)
			assert_false(row[2].is_empty(), "%s has es" % k)
			assert_eq(
				row[1].count("%s"), row[2].count("%s"), "%s: en and es take the same arguments" % k
			)


func _text(f: Dictionary) -> PackedStringArray:
	TranslationServer.set_locale("en")
	return WorldReader.wand_forecast_text(f, func(k: StringName) -> String: return tr(k))

extends SceneTree
## v0.9.0 BR (PLAN C75 "per-form DPS sheets"; owner Q28 "the most broken could be unlocked, maybe 2 of them"; AF1 "a
## full charge matches the orbs on one target (about 1.0x)"): the direct damage of each of the ten Gun forms against
## the plain orbs, on a Gun run (the shipped wand and slot table, floor 5, so ShotCap's merges apply), crit off, no
## attack speed, no elements. The harness is tests/unit/sim/test_lance.gd's test_single_target_dps_against_the_orbs
## (every DAMAGE event on a standing dummy that isn't damage over time, counted from tick 120), not the Playground's
## meter (DpsTally counts the same events' HP taken, damage over time included; with no elements and 1 000 000 HP
## dummies the two agree).
## Scenes, the hero at the start, aiming along +x, holding SHOOT (the Lance: hold 72 ticks for a full charge, release,
## rest 23 ticks, as test_lance):
## - single: one dummy (radius 0.35) at 4 m; ticks 120..1800 (28 s);
## - line: five at 2, 3.5, 5, 6.5, 8 m on the aim line; ticks 120..720 (10 s);
## - pack: five on a 3 m arc at 4 m (0.75 rad, centred on the aim); ticks 120..720 (10 s).
## Each form at its card's level 1 and 5, alone and with Twin Lv 5 where its row allows Twin; the ratio is against
## the plain orbs (no cards) in the same scene. Prints a table and writes build/balance/forms_dps.txt; copy the
## printed numbers into evidence by hand.
##   godot --headless --path . -s scripts/balance/forms_dps.gd

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const FROM := 120
const FORMS: Array = [
	[&"orbs", &""],
	[&"laser", &"gun_laser"],
	[&"bomb", &"gun_bomb"],
	[&"void", &"gun_void"],
	[&"lance", &"gun_lance"],
	[&"scatter", &"gun_scatter"],
	[&"glaive", &"gun_glaive"],
	[&"seekers", &"gun_seekers"],
	[&"wave", &"gun_wave"],
	[&"wisps", &"gun_wisps"],
]


func _initialize() -> void:
	var scenes := {
		"single": [[Vector2(4.0, 0.0)], 1800],
		"line": [_line(), 720],
		"pack": [_pack(), 720],
	}
	var base := {}
	for sc: String in scenes:
		base[sc] = _damage(&"", 1, false, scenes[sc][0], scenes[sc][1])
	var lines := PackedStringArray()
	lines.append(
		(
			"orbs baseline (plain, no cards): single %d, line %d, pack %d"
			% [base["single"], base["line"], base["pack"]]
		)
	)
	lines.append(
		"form | card Lv | Twin Lv 5 | single x | line x | pack x | single dmg | line dmg | pack dmg"
	)
	for f: Array in FORMS:
		var levels: Array = [1] if f[1] == &"" else [1, 5]
		for lv: int in levels:
			for twin: bool in [false, true]:
				if twin and not _twin_allowed(f[1]):
					continue
				var d := {}
				for sc: String in scenes:
					d[sc] = _damage(f[1], lv, twin, scenes[sc][0], scenes[sc][1])
				(
					lines
					. append(
						(
							"%s | %s | %s | %.3f | %.3f | %.3f | %d | %d | %d"
							% [
								f[0],
								"-" if f[1] == &"" else str(lv),
								"yes" if twin else "no",
								float(d["single"]) / float(base["single"]),
								float(d["line"]) / float(base["line"]),
								float(d["pack"]) / float(base["pack"]),
								d["single"],
								d["line"],
								d["pack"],
							]
						)
					)
				)
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/balance"))
	var out := FileAccess.open("res://build/balance/forms_dps.txt", FileAccess.WRITE)
	if out != null:
		out.store_string(text + "\n")
		out.close()
	quit(0)


static func _line() -> Array:
	var at: Array = []
	for k in 5:
		at.append(Vector2(2.0 + 1.5 * k, 0.0))
	return at


## Five on a 3 m arc of a 4 m circle round the hero: 0.75 rad, centred on the aim, 0.1875 rad apart.
static func _pack() -> Array:
	var at: Array = []
	for k in 5:
		var a := (k - 2) * 0.1875
		at.append(Vector2(4.0 * cos(a), 4.0 * sin(a)))
	return at


## A Gun run on floor 5 with the shipped wand and slot table, holding nothing yet.
static func _world() -> World:
	var w := W.world(&"gun")
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 5
	w.run_floor = 5
	return w


static func _twin_allowed(form: StringName) -> bool:
	var w := _world()
	if form != &"":
		BuildSlots.take(w, W.item(w, form))
	return AttackSlots.usable(w, W.item(w, &"gun_twin"))


## The direct damage dealt to the dummies at `at` (offsets from the hero) in ticks [FROM, ticks) by `form` at card
## level `lv` (Twin Lv 5 too when `twin`).
static func _damage(form: StringName, lv: int, twin: bool, at: Array, ticks: int) -> int:
	var w := _world()
	if form != &"":
		BuildSlots.take(w, W.item(w, form))
		CardLevels.set_level(w, W.item(w, form), lv)
	if twin:
		BuildSlots.take(w, W.item(w, &"gun_twin"))
		CardLevels.set_level(w, W.item(w, &"gun_twin"), 5)
	Modifiers.invalidate(w)
	var ids := {}
	for p: Vector2 in at:
		w.add_dummy(w.player_pos() + p, 0.35, HP)
		ids[w.actors.ids[w.actors.ids.size() - 1]] = true
	if form == &"gun_lance":
		while w.tick < ticks:
			W.run(w, 72, 0, W.S)
			W.run(w, 1, 0, 0)
			W.run(w, 23, 0, 0)
	else:
		W.run(w, ticks, 0, W.S)
	var total := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if not ids.has(e.target_id) or e.tags & SimEvent.TAG_DOT:
			continue
		if e.tick < FROM or e.tick >= ticks:
			continue
		total += e.amount
	return total

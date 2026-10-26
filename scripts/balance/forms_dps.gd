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
	[&"rune_explosion", &"gun_rune_explosion"],  # v0.9.5 FC0: replaces the Scatter
	[&"glaive", &"gun_glaive"],
	[&"seekers", &"gun_seekers"],
	[&"wave", &"gun_wave"],
	[&"wisps", &"gun_wisps"],
]

## v0.9.5 FC0: forms that hit around the hero (their reach is under the far scenes' 4 m) are measured in the NEAR scenes
## too, against the orbs in the same NEAR scenes: single at 2.5 m; line five at 1 to 3 m (0.5 m apart); pack five on
## a 2.5 m arc of 1.2 rad (0.3 rad apart). Their far rows stay (they read ~0, the ring does not reach 4 m).
const NEAR: Array[StringName] = [&"rune_explosion"]
## v0.9.5 FC1: the Laser's card combinations measured after the table.
const LASER_COMBOS: Array = [
	[],
	[&"gun_pierce"],
	[&"gun_homing"],
	[&"gun_homing", &"gun_pierce"],
	[&"gun_big_shot"],
	[&"gun_rapid_fire"],
	[&"halo_shot"],
	[&"gun_backfire"],
	[&"gun_echo"],
	[&"gun_mine"],
	[&"split_shot", &"gun_pierce"],
]
## v0.9.5 FC2: the Bomb's card combinations (a card alone each), after the Laser's.
const BOMB_COMBOS: Array = [
	[],
	[&"halo_shot"],
	[&"gun_ring"],
	[&"gun_backfire"],
	[&"gun_ricochet"],
	[&"gun_homing"],
	[&"gun_echo"],
	[&"gun_big_shot"],
	[&"gun_rapid_fire"],
	[&"split_shot"],
	[&"gun_mine"],
]
## v0.9.5 FC3: the Void's card combinations (a card alone each).
const VOID_COMBOS: Array = [
	[],
	[&"gun_ring"],
	[&"gun_backfire"],
	[&"gun_ricochet"],
	[&"gun_homing"],
	[&"gun_echo"],
	[&"gun_big_shot"],
	[&"gun_rapid_fire"],
	[&"split_shot"],
	[&"gun_mine"],
	[&"orbit_rounds"],
]

## v0.9.5 FC5: the Rune Explosion's card combinations (a card alone each; Twin at its Lv 1), in the NEAR scenes.
const RUNE_COMBOS: Array = [
	[],
	[&"gun_twin"],
	[&"gun_ring"],
	[&"gun_ricochet"],
	[&"gun_homing"],
	[&"gun_echo"],
	[&"gun_big_shot"],
	[&"gun_rapid_fire"],
	[&"split_shot"],
	[&"gun_mine"],
]


func _scenes(near: bool) -> Dictionary:
	if near:
		var line: Array = []
		var pack: Array = []
		for k in 5:
			line.append(Vector2(1.0 + 0.5 * k, 0.0))
			var a := (k - 2) * 0.3
			pack.append(Vector2(2.5 * cos(a), 2.5 * sin(a)))
		return {"single": [[Vector2(2.5, 0.0)], 1800], "line": [line, 720], "pack": [pack, 720]}
	return {
		"single": [[Vector2(4.0, 0.0)], 1800],
		"line": [_line(), 720],
		"pack": [_pack(), 720],
	}


func _initialize() -> void:
	var scenes := _scenes(false)
	var near := _scenes(true)
	var base := {}
	var base_near := {}
	for sc: String in scenes:
		base[sc] = _damage(&"", 1, false, scenes[sc][0], scenes[sc][1])
		base_near[sc] = _damage(&"", 1, false, near[sc][0], near[sc][1])
	var lines := PackedStringArray()
	lines.append(
		(
			"orbs baseline (plain, no cards): single %d, line %d, pack %d"
			% [base["single"], base["line"], base["pack"]]
		)
	)
	lines.append(
		(
			"orbs baseline, NEAR scenes (for %s): single %d, line %d, pack %d"
			% [NEAR, base_near["single"], base_near["line"], base_near["pack"]]
		)
	)
	lines.append(
		"form | card Lv | Twin Lv 5 | single x | line x | pack x | single dmg | line dmg | pack dmg"
	)
	for f: Array in FORMS:
		var levels: Array = [1] if f[1] == &"" else [1, 5]
		for lv: int in levels:
			for pair: Array in _variants(f[0]):
				var twin: bool = pair[0]
				var is_near: bool = pair[1]
				var sset: Dictionary = near if is_near else scenes
				var bset: Dictionary = base_near if is_near else base
				if twin and not _twin_allowed(f[1]):
					continue
				var d := {}
				for sc: String in sset:
					d[sc] = _damage(f[1], lv, twin, sset[sc][0], sset[sc][1])
				(
					lines
					. append(
						(
							"%s | %s | %s | %.3f | %.3f | %.3f | %d | %d | %d"
							% [
								str(f[0]) + (" (near)" if is_near else ""),
								"-" if f[1] == &"" else str(lv),
								"yes" if twin else "no",
								float(d["single"]) / float(bset["single"]),
								float(d["line"]) / float(bset["line"]),
								float(d["pack"]) / float(bset["pack"]),
								d["single"],
								d["line"],
								d["pack"],
							]
						)
					)
				)
	# v0.9.5 FC1: the Laser with the cards that bend it (alone, Twin off), against the same orbs baseline.
	# v0.9.5 FC2: and the Bomb with the cards that change it.
	for set_of: Array in [
		["laser", &"gun_laser", LASER_COMBOS],
		["bomb", &"gun_bomb", BOMB_COMBOS],
		["void", &"gun_void", VOID_COMBOS]
	]:
		for combo: Array in set_of[2]:
			var d := {}
			for sc: String in scenes:
				d[sc] = _damage(set_of[1], 1, false, scenes[sc][0], scenes[sc][1], combo)
			(
				lines
				. append(
					(
						"%s + %s | 1 | no | %.3f | %.3f | %.3f | %d | %d | %d"
						% [
							set_of[0],
							"+".join(combo) if not combo.is_empty() else "(plain)",
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
	# v0.9.5 FC5: the Rune Explosion with its cards (a card alone each), in the NEAR scenes against the NEAR orbs.
	for combo: Array in RUNE_COMBOS:
		var d := {}
		for sc: String in near:
			d[sc] = _damage(&"gun_rune_explosion", 1, false, near[sc][0], near[sc][1], combo)
		(
			lines
			. append(
				(
					"rune_explosion (near) + %s | 1 | no | %.3f | %.3f | %.3f | %d | %d | %d"
					% [
						"+".join(combo) if not combo.is_empty() else "(plain)",
						float(d["single"]) / float(base_near["single"]),
						float(d["line"]) / float(base_near["line"]),
						float(d["pack"]) / float(base_near["pack"]),
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


## [Twin?, near scenes?] pairs measured for form `id`: the far scenes (Twin off, on), and a NEAR form's near ones too.
static func _variants(id: StringName) -> Array:
	var out: Array = [[false, false], [true, false]]
	if id in NEAR:
		out.append_array([[false, true], [true, true]])
	return out


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
static func _damage(
	form: StringName, lv: int, twin: bool, at: Array, ticks: int, cards: Array = []
) -> int:
	var w := _world()
	if form != &"":
		BuildSlots.take(w, W.item(w, form))
		CardLevels.set_level(w, W.item(w, form), lv)
	if twin:
		BuildSlots.take(w, W.item(w, &"gun_twin"))
		CardLevels.set_level(w, W.item(w, &"gun_twin"), 5)
	for c: StringName in cards:
		BuildSlots.take(w, W.item(w, c))
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
		# v0.9.5 FC0: the dummies are put back each tick (a real enemy walks back in; the Rune Explosion's 0.4 m shove
		# would carry a standing dummy out of its reach for good). Nothing else displaces them.
		var spots := {}
		for id: int in ids:
			spots[id] = w.actors.pos(w.actors.index_of(id))
		for t in ticks:
			W.run(w, 1, 0, W.S)
			for id: int in spots:
				w.actors.set_pos(w.actors.index_of(id), spots[id])
	var total := 0
	for e in W.events(w, SimEvent.Kind.DAMAGE):
		if not ids.has(e.target_id) or e.tags & SimEvent.TAG_DOT:
			continue
		if e.tick < FROM or e.tick >= ticks:
			continue
		total += e.amount
	return total

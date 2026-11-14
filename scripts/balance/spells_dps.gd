extends SceneTree
## v0.11.0 O12 (PLAN E5; docs/roadmap/v0.11.0/SPELLS.md "Starting values", owner-approved): each spell's damage
## against the wand's, on the forms_dps dummies. Seeded and deterministic (crit off, no randomness but the world's
## named streams): the same numbers on every run.
## What is counted, over ticks [0, WINDOW) (60 s; a 12 s spell casts 5 times, Meteor (16 s) 4, Burning Ground 6):
## - a spell's damage: every DAMAGE event on the scene's dummies whose effect id starts with the spell's id (its hits,
##   its zones' pulses, Frost Nova's shatter, Hemorrhage's cash-in). The element's statuses (burn, venom, bleed, frost)
##   are not counted: they are the element's, shared with the element card, as forms_dps counts direct damage only;
## - the wand's damage (O12's column, "wand all"): every other DAMAGE event of the player on the dummies that isn't
##   damage over time (forms_dps's rule), in the same run;
## - O12b (owner, OWNER_QUESTIONS E5-b "Count wand only"): "wand only" = "wand all" without the damage whose effect id
##   is an element card's own effect (ELEMENT_EFFECTS). The O12b shares are spell / wand only.
## Damage is the HP the hit took (amount_applied): the same as the hit's amount on the 1 000 000 HP dummies, and no
## overkill on the dying ones.
## Each run holds the wand and the element cards of its spells (a spell is only offered with its element card, and
## Hemorrhage and Leech need bleed). The wands: the plain orbs (the reference the budget was set from), the Laser and
## the Glaive at card Lv 1 (Gun, floor 5, shipped wand and slot table, as forms_dps), and the plain Blade (melee every
## 9 ticks, as AttackScenario).
## O12's scenes (standing 1 000 000 HP dummies put back each tick, the hero still, aiming +x): FAR (forms_dps's: one
## at 4 m; five at 2..8 m on the aim line; five on a 3 m arc at 4 m), NEAR (forms_dps's near: 2.5 m; 1..3 m; a 2.5 m
## arc) and the Blade's (1.5 m; 1..2 m; a 1.5 m arc).
## O12b's scenes (the world's dummy steering: each walks at DUMMY_SPEED toward the hero plus the world's ±3 m jitter,
## re-rolled from rng_ai, held KEEP_M off the hero (Blade: KEEP_BLADE_M); the hero aims at the nearest dummy each tick):
## - MOVING: six 1 000 000 HP dummies (they live the whole window) start on a 4 m ring; the hero walks a loop (a
##   circle at half stick, one lap every LOOP_TICKS), so they chase and circle it and Toxic Cloud trails;
## - DYING: normal-HP dummies (STREAM_BASE_HP at floor 5's enemy_hp_floor_permille of the shipped run) in waves of
##   WAVE_N every WAVE_TICKS on a WAVE_R_M ring (turned each wave), at most STREAM_CAP alive; the hero stands. They die,
##   so kill-triggered effects count (Venom Orb's Lv 5 pools, Ice Lances' splits, the bleed spread). Kills reported.
## Parts (one process each, so they run side by side):
## godot --headless --path . -s scripts/balance/spells_dps.gd -- --wand=<orbs|laser|glaive|blade> --part=<part>
##   part: spells (O12), builds (O12), spells_b / builds_b (O12b: old and new scenes, wand all and wand only),
##   effects (the wand column's damage by effect id, per element card, plain wand, no spell).
## Each writes build/balance/spells_dps_<wand>_<part>.txt (`--out=<dir>` for a folder under build/); copy the printed
## numbers into evidence by hand.
## `--quick` (the smoke test): one spell, one scene, 2 s.

const W := preload("res://tests/support/mx4_world.gd")
const HP := 1000000
const WINDOW := 3600
const WANDS := {
	"orbs": [&"gun", &""],
	"laser": [&"gun", &"gun_laser"],
	"glaive": [&"gun", &"gun_glaive"],
	"blade": [&"blade", &""],
}
## The effect ids of the element cards' own direct damage, left out of "wand only" (found with --part=effects:
## Storm Core's jumps, Ember Core's burst on a kill; the cards' statuses (ember_edge, venom, bleed) are DoT, never
## in it).
const ELEMENT_EFFECTS: Array[StringName] = [&"storm_core", &"ember_core"]
## The element cards (the spells' element_card ids), for --part=effects.
const ELEMENT_CARDS: Array[StringName] = [
	&"ember_core", &"frost_core", &"storm_core", &"venom_core", &"shared_bleed"
]
## O12b's moving and dying scenes.
const DUMMY_SPEED := 2.4  # m/s: a common enemy walk (mine layer, splitter); the dummies' steering
const KEEP_M := 2.0
const KEEP_BLADE_M := 1.0
const LOOP_TICKS := 360  # the hero's walking loop: one lap of a circle in 6 s at half stick
const MOVING_N := 6
const MOVING_R_M := 4.0
const STREAM_BASE_HP := 40  # arc caster, mine layer: a common mid enemy's base HP
const WAVE_N := 5
const WAVE_TICKS := 180
const WAVE_R_M := 7.0
const STREAM_CAP := 10
## The spells measured in the NEAR scenes (their reach is about the hero); the rest in the FAR ones.
const NEAR_SPELLS: Array[int] = [
	Spells.FROST_NOVA,
	Spells.BURNING_GROUND,
	Spells.STATIC_FIELD,
	Spells.TOXIC_CLOUD,
	Spells.BLOOD_THORNS,
]
## The builds next to the wand: 0 to 4 spells (O10's three first), then three other 4-spell mixes; all 15 appear.
const BUILDS: Array = [
	[],
	[Spells.FIREBALL],
	[Spells.FIREBALL, Spells.SKY_STRIKE],
	[Spells.FIREBALL, Spells.SKY_STRIKE, Spells.FROST_NOVA],
	[Spells.FIREBALL, Spells.SKY_STRIKE, Spells.FROST_NOVA, Spells.VENOM_ORB],
	[Spells.BLIZZARD, Spells.METEOR, Spells.BALL_LIGHTNING, Spells.HEMORRHAGE],
	[Spells.ICE_LANCES, Spells.BURNING_GROUND, Spells.STATIC_FIELD, Spells.SPITTER_VINE],
	[Spells.TOXIC_CLOUD, Spells.BLOOD_THORNS, Spells.LEECH, Spells.FIREBALL],
]

var _window := WINDOW
## The last _measure's non-spell player damage by "effect id|dot|direct" (for --part=effects).
var _by_effect := {}


func _initialize() -> void:
	var wand := "orbs"
	var part := "spells"
	var out_dir := "res://build/balance"
	var quick := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wand="):
			wand = a.substr(7)
		elif a.begins_with("--part="):
			part = a.substr(7)
		elif a.begins_with("--out="):
			out_dir = "res://build/" + a.substr(6).trim_prefix("build/")
		elif a == "--quick":
			quick = true
	if not WANDS.has(wand):
		push_error("spells_dps: unknown wand %s" % wand)
		quit(1)
		return
	var lines := PackedStringArray()
	if quick:
		_window = 120
		var r := _measure(wand, [Spells.FIREBALL], 1, [_far()["single"]])
		lines.append("quick | orbs + fireball Lv 1 | single | spell %d | wand %d" % [r[0], r[1]])
	elif part == "builds":
		lines = _builds(wand)
	elif part == "spells_b":
		lines = _spells_b(wand)
	elif part == "builds_b":
		lines = _builds_b(wand)
	elif part == "effects":
		lines = _effects(wand)
	else:
		lines = _spells(wand)
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var name := "spells_dps_quick.txt" if quick else "spells_dps_%s_%s.txt" % [wand, part]
	var out := FileAccess.open(out_dir + "/" + name, FileAccess.WRITE)
	if out != null:
		out.store_string(text + "\n")
		out.close()
	quit(0)


## Each spell alone next to the wand, Lv 1 and Lv 5, in its home scenes: the spell's and the wand's damage per scene,
## the share (spell / wand) per scene and their mean, and Lv 5 / Lv 1 (the scenes' summed spell damage).
func _spells(wand: String) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("wand %s, window %d ticks (%.0f s)" % [wand, _window, _window / 60.0])
	lines.append(
		(
			"spell | scenes | Lv | share single | share line | share pack | mean share"
			+ " | spell dmg s/l/p | wand dmg s/l/p | Lv5/Lv1"
		)
	)
	var w0 := _world(wand, [])
	for k in w0.spell_tables.size():
		var sc := _home(wand, k)
		var sums := {}
		for lv: int in [1, 5]:
			var sp := PackedInt32Array()
			var wd := PackedInt32Array()
			var shares := PackedFloat32Array()
			for at: Array in sc[1].values():
				var r := _measure(wand, [k], lv, [at])
				sp.append(r[0])
				wd.append(r[1])
				shares.append(float(r[0]) / float(maxi(r[1], 1)))
			sums[lv] = sp[0] + sp[1] + sp[2]
			var mean := (shares[0] + shares[1] + shares[2]) / 3.0
			var ratio := "-"
			if lv == 5:
				ratio = "%.2f" % (float(sums[5]) / float(maxi(sums[1], 1)))
			(
				lines
				. append(
					(
						"%s | %s | %d | %.3f | %.3f | %.3f | %.3f | %d/%d/%d | %d/%d/%d | %s"
						% [
							w0.spell_tables[k].id,
							sc[0],
							lv,
							shares[0],
							shares[1],
							shares[2],
							mean,
							sp[0],
							sp[1],
							sp[2],
							wd[0],
							wd[1],
							wd[2],
							ratio,
						]
					)
				)
			)
	return lines


## The builds at Lv 1 in all six scenes (FAR and NEAR; the Blade's three for the Blade): the spells' damage over the
## wand's per scene and the mean (the build's added share).
func _builds(wand: String) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(
		"wand %s, window %d ticks (%.0f s), spells at Lv 1" % [wand, _window, _window / 60.0]
	)
	var scenes := _scene_list(wand)
	lines.append(
		(
			"build | n | added share per scene (%s) | mean added | spells dmg | wand dmg"
			% [", ".join(scenes.keys())]
		)
	)
	var w0 := _world(wand, [])
	for b: Array in BUILDS:
		var names := PackedStringArray()
		for k: int in b:
			names.append(str(w0.spell_tables[k].id).trim_prefix("spell_"))
		var shares := PackedStringArray()
		var mean := 0.0
		var sp_total := 0
		var wd_total := 0
		for at: Array in scenes.values():
			var r := _measure(wand, b, 1, [at])
			var s := float(r[0]) / float(maxi(r[1], 1))
			shares.append("%.3f" % s)
			mean += s / scenes.size()
			sp_total += r[0]
			wd_total += r[1]
		(
			lines
			. append(
				(
					"%s | %d | %s | %.3f | %d | %d"
					% [
						"(none)" if b.is_empty() else "+".join(names),
						b.size(),
						" ".join(shares),
						mean,
						sp_total,
						wd_total,
					]
				)
			)
		)
	return lines


## O12b: each spell alone next to the wand, Lv 1 and Lv 5, in its O12 home scenes (single, line, pack) and the two
## new ones (moving, dying). One row per spell, level and scene: spell dmg, wand all, wand only, share (spell / wand
## only), kills; then per level the three means (old 3, new 2, all 5) and Lv 5 / Lv 1 of each (summed spell dmg).
func _spells_b(wand: String) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(
		(
			"wand %s, window %d ticks (%.0f s); share = spell / wand only"
			% [wand, _window, _window / 60.0]
		)
	)
	lines.append("row | spell | Lv | scene | spell dmg | wand all | wand only | share | kills")
	lines.append(
		(
			"sum | spell | Lv | mean share old3 | mean share new2 | mean share all5"
			+ " | spell dmg old3/new2/all5 | Lv5/Lv1 old3 | Lv5/Lv1 new2 | Lv5/Lv1 all5"
		)
	)
	var w0 := _world(wand, [])
	for k in w0.spell_tables.size():
		var scenes := _scenes_b(wand, k)
		var sums := {}
		for lv: int in [1, 5]:
			var shares := []
			var sp := []
			for label: String in scenes:
				var r := _measure(wand, [k], lv, scenes[label])
				var s := float(r[0]) / float(maxi(r[2], 1))
				shares.append(s)
				sp.append(r[0])
				lines.append(
					(
						"row | %s | %d | %s | %d | %d | %d | %.3f | %d"
						% [w0.spell_tables[k].id, lv, label, r[0], r[1], r[2], s, r[3]]
					)
				)
			var old3: int = sp[0] + sp[1] + sp[2]
			var new2: int = sp[3] + sp[4]
			sums[lv] = [old3, new2, old3 + new2]
			var ratio := ["-", "-", "-"]
			if lv == 5:
				for j in 3:
					ratio[j] = "%.2f" % (float(sums[5][j]) / float(maxi(sums[1][j], 1)))
			(
				lines
				. append(
					(
						"sum | %s | %d | %.3f | %.3f | %.3f | %d/%d/%d | %s | %s | %s"
						% [
							w0.spell_tables[k].id,
							lv,
							(shares[0] + shares[1] + shares[2]) / 3.0,
							(shares[3] + shares[4]) / 2.0,
							(shares[0] + shares[1] + shares[2] + shares[3] + shares[4]) / 5.0,
							old3,
							new2,
							old3 + new2,
							ratio[0],
							ratio[1],
							ratio[2],
						]
					)
				)
			)
	return lines


## O12b: the builds at Lv 1 in O12's six scenes (FAR + NEAR; the Blade's three) and the two new ones: the added share
## (spells / wand only) per scene, then the means over the old scenes, the new two and all.
func _builds_b(wand: String) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(
		(
			"wand %s, window %d ticks (%.0f s), spells at Lv 1; share = spells / wand only"
			% [wand, _window, _window / 60.0]
		)
	)
	var scenes := {}
	var old := _scene_list(wand)
	for s: String in old:
		scenes[s] = [old[s]]
	var n_old := scenes.size()
	var dyn := _new_scenes(wand)
	for s: String in dyn:
		scenes[s] = dyn[s]
	lines.append(
		(
			(
				"build | n | added share per scene (%s) | mean old%d | mean new2 | mean all%d"
				% [", ".join(scenes.keys()), n_old, scenes.size()]
			)
			+ " | spells dmg | wand all | wand only | kills dying"
		)
	)
	var w0 := _world(wand, [])
	for b: Array in BUILDS:
		var names := PackedStringArray()
		for k: int in b:
			names.append(str(w0.spell_tables[k].id).trim_prefix("spell_"))
		var shares := PackedStringArray()
		var old_sum := 0.0
		var new_sum := 0.0
		var sp_total := 0
		var all_total := 0
		var only_total := 0
		var kills := 0
		var j := 0
		for s: String in scenes:
			var r := _measure(wand, b, 1, scenes[s])
			var share := float(r[0]) / float(maxi(r[2], 1))
			shares.append("%.3f" % share)
			if j < n_old:
				old_sum += share
			else:
				new_sum += share
			sp_total += r[0]
			all_total += r[1]
			only_total += r[2]
			if s == "dying":
				kills = r[3]
			j += 1
		(
			lines
			. append(
				(
					"%s | %d | %s | %.3f | %.3f | %.3f | %d | %d | %d | %d"
					% [
						"(none)" if b.is_empty() else "+".join(names),
						b.size(),
						" ".join(shares),
						old_sum / n_old,
						new_sum / (scenes.size() - n_old),
						(old_sum + new_sum) / scenes.size(),
						sp_total,
						all_total,
						only_total,
						kills,
					]
				)
			)
		)
	return lines


## The player's non-spell damage by effect id (dot or direct; "wand all" holds the direct ones), the plain wand with
## no element card and with each one alone, no spell, in O12's FAR line (the Blade's line) and the dying stream.
func _effects(wand: String) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(
		"wand %s, window %d ticks: player damage on the dummies by effect id" % [wand, _window]
	)
	lines.append("card | scene | effect id | dot/direct | damage")
	var line_at: Array = _blade()["line"] if wand == "blade" else _far()["line"]
	var scenes := {"line": [line_at], "dying": _new_scenes(wand)["dying"]}
	var sets: Array = [[]]
	for c: StringName in ELEMENT_CARDS:
		sets.append([c])
	for cards: Array in sets:
		for s: String in scenes:
			_measure(wand, [], 1, scenes[s], cards)
			var keys := _by_effect.keys()
			keys.sort()
			for key: String in keys:
				var parts := key.split("|")
				(
					lines
					. append(
						(
							"%s | %s | %s | %s | %d"
							% [
								"(none)" if cards.is_empty() else str(cards[0]),
								s,
								parts[0],
								parts[1],
								_by_effect[key],
							]
						)
					)
				)
	return lines


## [label, {scene: dummies}] where spell k is measured with `wand`.
func _home(wand: String, k: int) -> Array:
	if wand == "blade":
		return ["blade", _blade()]
	if k in NEAR_SPELLS:
		return ["near", _near()]
	return ["far", _far()]


## O12b: spell k's scenes: its O12 home three ("<home> single" ...) and the two new ones.
func _scenes_b(wand: String, k: int) -> Dictionary:
	var sc := _home(wand, k)
	var out := {}
	for s: String in sc[1]:
		out["%s %s" % [sc[0], s]] = [sc[1][s]]
	var dyn := _new_scenes(wand)
	for s: String in dyn:
		out[s] = dyn[s]
	return out


func _scene_list(wand: String) -> Dictionary:
	if wand == "blade":
		return _blade()
	var out := {}
	for s: String in _far():
		out["far " + s] = _far()[s]
	for s: String in _near():
		out["near " + s] = _near()[s]
	return out


## O12b: the moving pack and the dying stream (scene dictionaries for _measure).
static func _new_scenes(wand: String) -> Dictionary:
	var keep := KEEP_BLADE_M if wand == "blade" else KEEP_M
	var ring: Array = []
	for k in MOVING_N:
		var a := TAU * k / MOVING_N
		ring.append(Vector2(MOVING_R_M * cos(a), MOVING_R_M * sin(a)))
	return {
		"moving": {"at": ring, "hp": HP, "keep": keep, "walk": true},
		"dying": {"at": [], "hp": _stream_hp(), "keep": keep, "waves": true},
	}


## A STREAM_BASE_HP enemy's HP on floor 5 of the shipped run (its enemy_hp_floor_permille), tier 0.
static func _stream_hp() -> int:
	var run: RunDefinition = W.repo().get_def(&"run", RunSaver.RUN_ID)
	var pm := run.enemy_hp_floor_permille
	return roundi(STREAM_BASE_HP * pm[mini(4, pm.size() - 1)] / 1000.0)


static func _far() -> Dictionary:
	var line: Array = []
	var pack: Array = []
	for k in 5:
		line.append(Vector2(2.0 + 1.5 * k, 0.0))
		var a := (k - 2) * 0.1875
		pack.append(Vector2(4.0 * cos(a), 4.0 * sin(a)))
	return {"single": [Vector2(4.0, 0.0)], "line": line, "pack": pack}


static func _near() -> Dictionary:
	var line: Array = []
	var pack: Array = []
	for k in 5:
		line.append(Vector2(1.0 + 0.5 * k, 0.0))
		var a := (k - 2) * 0.3
		pack.append(Vector2(2.5 * cos(a), 2.5 * sin(a)))
	return {"single": [Vector2(2.5, 0.0)], "line": line, "pack": pack}


static func _blade() -> Dictionary:
	var line: Array = []
	var pack: Array = []
	for k in 5:
		line.append(Vector2(1.0 + 0.25 * k, 0.0))
		var a := (k - 2) * 0.3
		pack.append(Vector2(1.5 * cos(a), 1.5 * sin(a)))
	return {"single": [Vector2(1.5, 0.0)], "line": line, "pack": pack}


## A world with `wand` (forms_dps's: floor 5, the shipped wand and slot table) holding the element cards of `spells`
## and the cards `extra` (ids).
static func _world(wand: String, spells: Array, extra: Array = []) -> World:
	var r := W.repo()
	var w := W.world(WANDS[wand][0])
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 5
	w.run_floor = 5
	w.spell_tables = SpellCompiler.compile(r, w.item_tables)
	w.spell_rules = SpellCompiler.compile_rules(r)
	var form: StringName = WANDS[wand][1]
	if form != &"":
		BuildSlots.take(w, W.item(w, form))
		CardLevels.set_level(w, W.item(w, form), 1)
	var cards := {}
	for k: int in spells:
		var card: StringName = w.item_tables[w.spell_tables[k].element_item].id
		if not cards.has(card):
			cards[card] = true
			w.add_item(w.spell_tables[k].element_item)
	for id: StringName in extra:
		if not cards.has(id):
			cards[id] = true
			w.add_item(W.item(w, id))
	Modifiers.invalidate(w)
	return w


## [spells' damage, wand all, wand only, kills] in ticks [0, _window) with `spells` at level `lv` next to `wand`.
## `scene`: O12's [offsets] (standing 1 000 000 HP dummies put back each tick, the hero still, aiming +x), or an O12b
## dictionary {"at": offsets, "hp": hp, "keep": m, "walk": the hero loops, "waves": the dying stream}: the dummies
## steer (World.dummy_speed / dummy_keep_distance), the hero aims at the nearest one.
func _measure(wand: String, spells: Array, lv: int, scene: Variant, extra: Array = []) -> Array:
	var sc: Dictionary = scene if scene is Dictionary else {"at": scene[0], "hp": HP, "hold": true}
	var hold: bool = sc.get("hold", false)
	var walk: bool = sc.get("walk", false)
	var waves: bool = sc.get("waves", false)
	var hp: int = sc.get("hp", HP)
	var w := _world(wand, spells, extra)
	for k: int in spells:
		Spells.take(w, k)
		w.spell_levels[Spells.slot_of(w, k)] = lv
	if not hold:
		w.dummy_speed = DUMMY_SPEED / SimTick.TICKS_PER_SECOND
		w.dummy_keep_distance = sc.get("keep", KEEP_M)
		w.player_hp_floor = 1
	var prefixes := PackedStringArray()
	for k: int in spells:
		prefixes.append(str(w.spell_tables[k].id))
	var spots := {}
	for p: Vector2 in sc["at"]:
		var id := w.add_dummy(w.player_pos() + p, 0.35, hp)
		spots[id] = w.player_pos() + p
	var blade: bool = WANDS[wand][0] == &"blade"
	var pid := w.actors.ids[0]
	var seen := w.last_event_seq()
	var spell_dmg := 0
	var wand_all := 0
	var wand_only := 0
	var kills := 0
	var wave := 0
	_by_effect = {}
	for t in _window:
		if waves and t % WAVE_TICKS == 0:
			_wave(w, spots, hp, wave)
			wave += 1
		var aim := 0
		var move := Vector2i.ZERO
		if not hold:
			aim = _aim_nearest(w, spots)
		if walk:
			var a := TAU * (t % LOOP_TICKS) / LOOP_TICKS
			move = Vector2i(roundi(cos(a) * 64.0), roundi(sin(a) * 64.0))
		var pressed := InputFrame.PRIMARY if blade and t % 9 == 0 else 0
		var held := 0 if blade else InputFrame.SHOOT
		w.step(InputFrame.make(move, aim, 300, held, pressed))
		if hold:
			for id: int in spots:
				w.actors.set_pos(w.actors.index_of(id), spots[id])
		for e in w.events_since(seen):
			seen = e.seq
			if not spots.has(e.target_id) or e.owner_id != pid:
				continue
			if e.kind == SimEvent.Kind.KILL:
				kills += 1
				continue
			if e.kind != SimEvent.Kind.DAMAGE:
				continue
			var eff := str(e.effect_id)
			var mine := false
			for pre in prefixes:
				if eff.begins_with(pre):
					mine = true
			if mine:
				spell_dmg += e.amount_applied
				continue
			var dot := (e.tags & SimEvent.TAG_DOT) != 0
			var key := "%s|%s" % [eff, "dot" if dot else "direct"]
			_by_effect[key] = _by_effect.get(key, 0) + e.amount_applied
			if dot:
				continue
			wand_all += e.amount_applied
			if not ELEMENT_EFFECTS.has(e.effect_id):
				wand_only += e.amount_applied
	return [spell_dmg, wand_all, wand_only, kills]


## The dying stream's wave `n`: up to WAVE_N dummies on the WAVE_R_M ring (turned 0.7 rad a wave), the alive ones
## capped at STREAM_CAP.
static func _wave(w: World, spots: Dictionary, hp: int, n: int) -> void:
	var alive := 0
	for id: int in spots:
		var i := w.actors.index_of(id)
		if i >= 0 and w.actors.dead[i] == 0:
			alive += 1
	for k in mini(WAVE_N, STREAM_CAP - alive):
		var a := 0.7 * n + TAU * k / WAVE_N
		var p := w.player_pos() + Vector2(WAVE_R_M * cos(a), WAVE_R_M * sin(a))
		spots[w.add_dummy(p, 0.35, hp)] = p


## The aim at the nearest living dummy of the scene (0 when none).
static func _aim_nearest(w: World, spots: Dictionary) -> int:
	var me := w.player_pos()
	var best := -1.0
	var aim := 0
	for id: int in spots:
		var i := w.actors.index_of(id)
		if i < 0 or w.actors.dead[i] == 1:
			continue
		var d := w.actors.pos(i) - me
		var d2 := d.length_squared()
		if best < 0.0 or d2 < best:
			best = d2
			aim = Kin.angle_of(d)
	return aim

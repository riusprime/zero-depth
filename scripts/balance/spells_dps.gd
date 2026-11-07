extends SceneTree
## v0.11.0 O12 (PLAN E5; docs/roadmap/v0.11.0/SPELLS.md "Starting values", owner-approved): each spell's damage
## against the wand's, on the forms_dps dummies. Seeded and deterministic (crit off, standing 1 000 000 HP dummies put
## back each tick, no randomness but the world's named streams): the same numbers on every run.
## What is counted, over ticks [0, WINDOW) (60 s; a 12 s spell casts 5 times, Meteor (16 s) 4, Burning Ground 6):
## - a spell's damage: every DAMAGE event on the dummies whose effect id starts with the spell's id (its hits, its
##   zones' pulses, Frost Nova's shatter, Hemorrhage's cash-in). The element's statuses (burn, venom, bleed, frost) are
##   not counted: they are the element's, shared with the element card, as forms_dps counts direct damage only;
## - the wand's damage: every other DAMAGE event of the player on the dummies that isn't damage over time (forms_dps's
##   rule), in the same run.
## Each run holds the wand and the element cards of its spells (a spell is only offered with its element card, and
## Hemorrhage and Leech need bleed). The wands: the plain orbs (the reference the budget was set from), the Laser and
## the Glaive at card Lv 1 (Gun, floor 5, shipped wand and slot table, as forms_dps), and the plain Blade (melee every
## 9 ticks, as AttackScenario). The scenes: FAR (forms_dps's: one at 4 m; five at 2..8 m on the aim line; five on a 3 m
## arc at 4 m), NEAR (forms_dps's near: 2.5 m; 1..3 m; a 2.5 m arc) and the Blade's (1.5 m; 1..2 m; a 1.5 m arc), all
## along +x, the aim and facing.
## Parts (one process each, so they run side by side):
## godot --headless --path . -s scripts/balance/spells_dps.gd -- --wand=<orbs|laser|glaive|blade> --part=<spells|builds>
## Each writes build/balance/spells_dps_<wand>_<part>.txt; copy the printed numbers into evidence by hand.
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


func _initialize() -> void:
	var wand := "orbs"
	var part := "spells"
	var quick := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wand="):
			wand = a.substr(7)
		elif a.begins_with("--part="):
			part = a.substr(7)
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
	else:
		lines = _spells(wand)
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/balance"))
	var name := "spells_dps_quick.txt" if quick else "spells_dps_%s_%s.txt" % [wand, part]
	var out := FileAccess.open("res://build/balance/" + name, FileAccess.WRITE)
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


## [label, {scene: dummies}] where spell k is measured with `wand`.
func _home(wand: String, k: int) -> Array:
	if wand == "blade":
		return ["blade", _blade()]
	if k in NEAR_SPELLS:
		return ["near", _near()]
	return ["far", _far()]


func _scene_list(wand: String) -> Dictionary:
	if wand == "blade":
		return _blade()
	var out := {}
	for s: String in _far():
		out["far " + s] = _far()[s]
	for s: String in _near():
		out["near " + s] = _near()[s]
	return out


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


## A world with `wand` (forms_dps's: floor 5, the shipped wand and slot table) holding the element cards of `spells`.
static func _world(wand: String, spells: Array) -> World:
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
	Modifiers.invalidate(w)
	return w


## [spells' damage, wand's damage] in ticks [0, _window) with `spells` at level `lv` next to `wand`, against the
## dummies of `scene` ([offsets]).
func _measure(wand: String, spells: Array, lv: int, scene: Array) -> Array:
	var w := _world(wand, spells)
	for k: int in spells:
		Spells.take(w, k)
		w.spell_levels[Spells.slot_of(w, k)] = lv
	var prefixes := PackedStringArray()
	for k: int in spells:
		prefixes.append(str(w.spell_tables[k].id))
	var spots := {}
	for p: Vector2 in scene[0]:
		var id := w.add_dummy(w.player_pos() + p, 0.35, HP)
		spots[id] = w.player_pos() + p
	var blade: bool = WANDS[wand][0] == &"blade"
	var pid := w.actors.ids[0]
	var seen := w.last_event_seq()
	var spell_dmg := 0
	var wand_dmg := 0
	for t in _window:
		var pressed := InputFrame.PRIMARY if blade and t % 9 == 0 else 0
		var held := 0 if blade else InputFrame.SHOOT
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, held, pressed))
		for id: int in spots:
			w.actors.set_pos(w.actors.index_of(id), spots[id])
		for e in w.events_since(seen):
			seen = e.seq
			if e.kind != SimEvent.Kind.DAMAGE or not spots.has(e.target_id):
				continue
			if e.owner_id != pid:
				continue
			var eff := str(e.effect_id)
			var mine := false
			for pre in prefixes:
				if eff.begins_with(pre):
					mine = true
			if mine:
				spell_dmg += e.amount
			elif not e.tags & SimEvent.TAG_DOT:
				wand_dmg += e.amount
	return [spell_dmg, wand_dmg]

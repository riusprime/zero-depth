class_name WandForecast
extends RefCounted
## v0.10.5 O13 (owner P10, 2026-11-01: "ok"; theory audit: let players see the relationships instead of memorising
## them; evidence/O13_WAND_FORECAST.md): the wand forecast, the Build page's and the Swap panel's live preview of what
## a wand fires. It compiles the wand with the sim's own compiler (Modifiers.compile_for on build_modifiers_of: the
## function the sim runs on the held wand) and reads the attack spec that comes out, so the forecast can't disagree
## with the outcome (EI-07: forecasts call the same sim function). It writes nothing: the compiled book is its own and
## World.attack_book is never touched.
##
## of() gives:
## - "line": the spell read left to right as translation keys and their arguments (Wand.render's shape): the root
##   spell's noun (×N when it fires several), then each part the cards gave it (size, statuses, behaviour, a repeat),
##   then each trigger's cast ("on hit: …") with the child spell read the same way;
## - "numbers": the key numbers (the Gun: shots per attack, damage per shot, the period between attacks, the shot's
##   radius; the Blade: hits per swing, damage per hit averaged over the combo, the combo's ticks, the reach), and the
##   damage per second they make (per_second_x10, a tenth of a point);
## - "numbers_line": those numbers as a translation key and its arguments.
## The damage is the shot's before what changes per hit (crits, Gamble, the enemy's armour, statuses): the spec's
## damage under the weapon's factor (PlayerBuild.bolt_permille / melee_permille), its share (Attacks.share_of) and the
## shot cap's merge (Attacks.merged_damage).

## A part's size word when the spell is this much bigger or smaller than the weapon's own (per mille of its radius or
## reach).
const BIG_PERMILLE := 1150
const SMALL_PERMILLE := 850
## The spell nouns (UI_FORECAST_FORM_<name>).
const FORM_KEYS := {
	AttackSpec.Form.ARC: &"UI_FORECAST_FORM_SLASH",
	AttackSpec.Form.BOLT: &"UI_FORECAST_FORM_BOLT",
	AttackSpec.Form.RING: &"UI_FORECAST_FORM_RING",
	AttackSpec.Form.BEAM: &"UI_FORECAST_FORM_BEAM",
	AttackSpec.Form.ZONE: &"UI_FORECAST_FORM_ZONE",
	AttackSpec.Form.ORBITER: &"UI_FORECAST_FORM_ORBITER",
	AttackSpec.Form.LOB: &"UI_FORECAST_FORM_LOB",
	AttackSpec.Form.BURST: &"UI_FORECAST_FORM_BURST",
	AttackSpec.Form.WEAPON: &"UI_FORECAST_FORM_WEAPON",
}
const STATUS_KEYS := {
	&"burn": &"UI_FORECAST_BURNS",
	&"shock": &"UI_FORECAST_SHOCKS",
	&"bleed": &"UI_FORECAST_BLEEDS",
	&"frost": &"UI_FORECAST_FREEZES",
	&"slow": &"UI_FORECAST_SLOWS",
	&"poison": &"UI_FORECAST_POISONS",
}
const TRIGGER_KEYS := {
	AttackSpec.Trigger.ON_HIT: &"UI_FORECAST_ON_HIT",
	AttackSpec.Trigger.ON_KILL: &"UI_FORECAST_ON_KILL",
	AttackSpec.Trigger.ON_END: &"UI_FORECAST_ON_END",
	AttackSpec.Trigger.ON_CRIT: &"UI_FORECAST_ON_CRIT",
	AttackSpec.Trigger.ON_LAUNCH: &"UI_FORECAST_ON_LAUNCH",
	AttackSpec.Trigger.ON_NTH: &"UI_FORECAST_ON_NTH",
	AttackSpec.Trigger.EVERY_NTH: &"UI_FORECAST_ON_NTH",
}
## The hooks no moment fires (a remnant's, a wisp's mine): the read-back's remnant lines name them, not the forecast.
const SKIPPED_TRIGGERS := [AttackSpec.Trigger.ON_REMNANT, AttackSpec.Trigger.ON_WISP]


## The forecast of the wand holding `codes` (card codes, slot order; the held wand: w.mod_slots).
static func of(w: World, codes: PackedInt32Array) -> Dictionary:
	var book := Modifiers.compile_for(w, Modifiers.build_modifiers_of(w, codes))
	var gun := PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w)
	var n := w.player.combo.size()
	if not gun and n > 0:
		return _blade(w, book, n)
	return _gun(w, book)


## The forecast of a wand read (WorldReader.wand(), or a preview: Wand.moved_read, Wand.swapped_read).
static func of_read(w: World, wand_read: Dictionary) -> Dictionary:
	var codes := PackedInt32Array()
	for c: Dictionary in wand_read.get("cards", []):
		codes.append(int(c["code"]))
	return of(w, codes)


static func _gun(w: World, book: AttackBook) -> Dictionary:
	var spec := book.spec(Modifiers.GUN_BOLT)
	var want := shots(w, spec)
	var fit := want
	if ShotCap.per_attack(w) > 0:
		fit = mini(want, ShotCap.per_attack(w))
	var d := Attacks.bolt_base_damage(spec) * PlayerBuild.bolt_permille(w) / 1000
	if spec.share_permille > 0 and spec.seekers <= 0:
		d = Attacks.share_of(d, spec.share_permille)
	d = Attacks.merged_damage(d, want, fit)
	var milli := ItemEffects.shot_period_milli_of(w, spec)  # v0.10.5 W3-P9: the exact period the shots average
	var volley := fit * d + _repeat_damage(spec, fit * d)
	var area_mm := int(round(_area_m(spec) * 1000.0))
	var nums := {
		"weapon": &"gun",
		"shots": fit,
		"damage": d,
		"period_ticks": (milli + 500) / 1000,
		"period_milli": milli,
		"per_second_x10": _per_second_x10(volley * 1000, milli),
		"area_mm": area_mm,
	}
	var base := Modifiers.base_bolt(w).radius_m
	return {
		"line": {"key": &"UI_FORECAST_LINE", "args": [_spell(spec, fit, base, true)]},
		"numbers": nums,
		"numbers_line": _numbers_line(nums),
	}


static func _blade(w: World, book: AttackBook, n: int) -> Dictionary:
	var pm := PlayerBuild.melee_permille(w)
	var total := 0
	var ticks := 0
	var dmg_sum := 0
	var first := book.spec(Modifiers.step_id(0))
	var hits := 1 + _repeats(first)
	for k in n:
		var s := book.spec(Modifiers.step_id(k))
		var d := s.damage * pm / 1000
		dmg_sum += d
		total += d + _repeat_damage(s, d)
		ticks += BladeForms.step_of(w, k, s).ticks
	var avg := dmg_sum / n
	var reach := Attacks.arc_reach_m(w, first)
	var nums := {
		"weapon": &"blade",
		"shots": hits,
		"damage": avg,
		"period_ticks": ticks,
		"per_second_x10": _per_second_x10(total, ticks),
		"area_mm": int(round(reach * 1000.0)),
	}
	var base := Modifiers.base_step(w, 0)
	return {
		"line": {"key": &"UI_FORECAST_LINE", "args": [_spell(first, 1, _reach_of(base), true)]},
		"numbers": nums,
		"numbers_line": _numbers_line(nums),
	}


## How many projectiles one launch of `spec` fires (the bolts' fan × the Twin's lanes; the weapon's own shot also
## takes Pulse Gun L5's twin bolts: Attacks._bolts' rule).
static func shots(w: World, spec: AttackSpec) -> int:
	if spec.form != AttackSpec.Form.BOLT:
		return maxi(1, spec.count)
	var offsets := Attacks.shot_offsets(spec)
	if spec.has_tag(&"weapon"):
		offsets = Abilities.shot_offsets(w, offsets)
	return offsets.size() * GunForms.lanes(spec, spec.radius_m).size()


## The extra repeats a launch queues (an Echo, a Double Slash): repeats, or the one repeat (0 = none).
static func _repeats(spec: AttackSpec) -> int:
	if spec.repeat_delay_ticks <= 0:
		return 0
	return maxi(1, spec.repeats)


static func _repeat_damage(spec: AttackSpec, d: int) -> int:
	return _repeats(spec) * d * spec.repeat_damage_permille / 1000


## `damage` dealt every `period_ticks` (the Gun passes both x 1000: its period in thousandths of a tick), per second,
## in tenths.
static func _per_second_x10(damage: int, period_ticks: int) -> int:
	if period_ticks <= 0:
		return 0
	return damage * SimTick.TICKS_PER_SECOND * 10 / period_ticks


## The shot's hit radius (m): a bomb's blast, a void's aura, a wave's band, a rune burst, else the bolt's radius.
static func _area_m(spec: AttackSpec) -> float:
	for mm: int in [spec.blast_mm, spec.void_mm, spec.wave_mm, spec.rune_mm]:
		if mm > 0:
			return mm / 1000.0
	return spec.radius_m


static func _reach_of(spec: AttackSpec) -> float:
	return spec.reach_m * (1000 + spec.reach_bonus_permille) / 1000.0


static func _numbers_line(nums: Dictionary) -> Dictionary:
	var gun: bool = nums["weapon"] == &"gun"
	return {
		"key": &"UI_FORECAST_NUMBERS_GUN" if gun else &"UI_FORECAST_NUMBERS_BLADE",
		"args":
		[
			str(nums["shots"]),
			str(nums["damage"]),
			_tenths(int(nums["per_second_x10"])),
			_hundredths(int(nums["area_mm"])),
		],
	}


static func _tenths(v: int) -> String:
	return "%d.%d" % [v / 10, v % 10]


static func _hundredths(mm: int) -> String:
	var c := (mm + 5) / 10
	return "%d.%02d" % [c / 100, c % 100]


## `spec` read left to right: its noun (×count), its parts, then each trigger's cast. `base`: the weapon's own radius
## (a bolt) or reach (a slash), for the size words. `root`: the parts join with arrows (a cast's with commas).
static func _spell(spec: AttackSpec, count: int, base: float, root: bool) -> Dictionary:
	var noun := {"key": _noun(spec), "args": []}
	if count > 1:
		noun = {"key": &"UI_FORECAST_COUNT", "args": [noun, str(count)]}
	var parts: Array = [noun]
	var size := _reach_of(spec) if spec.form == AttackSpec.Form.ARC else spec.radius_m
	if base > 0.0 and size > 0.0 and spec.form != AttackSpec.Form.WEAPON:
		var r := int(size * 1000.0 / base)
		if r >= BIG_PERMILLE:
			parts.append({"key": &"UI_FORECAST_BIG", "args": []})
		elif r <= SMALL_PERMILLE:
			parts.append({"key": &"UI_FORECAST_SMALL", "args": []})
	for k in spec.status_ids.size():
		var id := StringName(spec.status_ids[k])
		var key: StringName = STATUS_KEYS.get(id, &"")
		if id == &"slow" and spec.has_status(&"frost"):  # frost slows too: one word for both
			continue
		if key != &"":
			parts.append({"key": key, "args": []})
	if spec.pierce > 0:
		parts.append({"key": &"UI_FORECAST_PIERCES", "args": [str(spec.pierce)]})
	if spec.bounces > 0:
		parts.append({"key": &"UI_FORECAST_BOUNCES", "args": [str(spec.bounces)]})
	if spec.chains > 0:
		parts.append({"key": &"UI_FORECAST_CHAINS", "args": [str(spec.chains)]})
	if spec.homing > 0 or spec.seekers > 0:
		parts.append({"key": &"UI_FORECAST_HOMES", "args": []})
	if spec.returns > 0 or spec.glaive > 0:
		parts.append({"key": &"UI_FORECAST_RETURNS", "args": []})
	if _repeats(spec) == 1:
		parts.append({"key": &"UI_FORECAST_REPEAT", "args": []})
	elif _repeats(spec) > 1:
		parts.append({"key": &"UI_FORECAST_REPEATS", "args": [str(_repeats(spec))]})
	for h in spec.hooks:
		if h.trigger in SKIPPED_TRIGGERS or h.child == null:
			continue
		var c := h.child
		var cast := _spell(c, shots_of_child(c), base, false)
		var key: StringName = TRIGGER_KEYS.get(h.trigger, &"UI_FORECAST_ON_HIT")
		parts.append({"key": key, "args": [cast]})
	return _join(parts, &"UI_FORECAST_THEN" if root else &"UI_FORECAST_AND")


## A cast's count: its fan × its lanes (no weapon twin: a cast isn't the weapon's own shot).
static func shots_of_child(spec: AttackSpec) -> int:
	if spec.form != AttackSpec.Form.BOLT:
		return maxi(1, spec.count)
	return Attacks.shot_offsets(spec).size() * GunForms.lanes(spec, spec.radius_m).size()


static func _join(parts: Array, key: StringName) -> Dictionary:
	var out: Dictionary = parts[0]
	for k in range(1, parts.size()):
		out = {"key": key, "args": [out, parts[k]]}
	return out


static func _noun(spec: AttackSpec) -> StringName:
	if spec.beam_hold > 0:
		return &"UI_FORECAST_FORM_LASER"
	if spec.blast_mm > 0:
		return &"UI_FORECAST_FORM_BOMB"
	if spec.lance > 0:
		return &"UI_FORECAST_FORM_LANCE"
	if spec.glaive > 0:
		return &"UI_FORECAST_FORM_GLAIVE"
	if spec.seekers > 0:
		return &"UI_FORECAST_FORM_SEEKERS"
	if spec.wave_mm > 0:
		return &"UI_FORECAST_FORM_WAVE"
	if spec.wisps > 0:
		return &"UI_FORECAST_FORM_WISPS"
	if spec.void_mm > 0:
		return &"UI_FORECAST_FORM_VOID"
	if spec.rune_mm > 0:
		return &"UI_FORECAST_FORM_RUNE"
	if spec.pellets > 0:
		return &"UI_FORECAST_FORM_PELLETS"
	if spec.ring_layout > 0:
		return &"UI_FORECAST_FORM_RING"
	return FORM_KEYS.get(spec.form, &"UI_FORECAST_FORM_BOLT")

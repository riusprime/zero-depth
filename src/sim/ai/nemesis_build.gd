class_name NemesisBuild
extends RefCounted
## v0.8.0 FB3 (owner F6 "Weapon + dash + 2-3 cards": "it uses your weapon and dash, echoes your moves and casts the
## strongest 2–3 cards of your wand"; F7 "Nemesis takes its HP and damage from your own build, an even duel";
## FINAL_BOSS.md F6, F7; SIM_CONTRACTS "The final boss"): what the Nemesis takes from the player's build, read once as
## it rises (prepare, from FinalBoss._spawn; again at its first tick after an FB2 save, whose fight lacks it) and kept
## in the fight (FinalFight: saved and hashed), so a card taken later changes nothing mid-duel.
## - The weapon: the run's (PlayerBuild: a Gun without the Blade is the Gun, anything else the Blade).
## - Its HP (BossTable.build_hp): hp_of (v0.8.0 N2: FinalPace's when paced). Its hit and cap: hit_of, cap_of; each
##   attack's damage: damage_of (its class's share of your max HP; in a mimic window your build's hit when more).
## - Its combo: a Blade run's combo steps as the wand compiled them (each step's arc and reach, Attacks.arc_reach_m,
##   clamped to reach_max_m).
## - Its shot (mimic_shots): a Gun run's compiled shot (every card on it) as a hostile volley; a Blade run's thrown
##   slash: the crescents (or blades) its wand throws, else `count` plain crescents (the attack's own).
## - Its cards (card_cast): pick_cards, each compiled alone by the wand compiler on the run's weapon at its level
##   (WandCompile.for_world(...).spec) and copied as a NemesisCast (from_spec): its arc, volley and blast. Pure: no
##   stream is drawn; integer maths for the HP and the hit (64-bit).

## The crescents a Blade run's thrown slash flies at without a card that throws (m per tick: 9 m/s), their radius.
const CRESCENT_SPEED := 0.15
const CRESCENT_RADIUS_M := 0.35
## A copy's damage weight against the plain attack, per mille (Heavy ×1.7 stays under 2000; Flurry's 0.75 over 500).
const WEIGHT_MIN := 500
const WEIGHT_MAX := 2000
## Double Slash's repeats strike again at most this many times.
const ARC_REPEATS_MAX := 2


## Reads the build into the fight for body i (table t); `set_hp`: also its HP (the rise).
static func prepare(w: World, i: int, t: BossTable, set_hp: bool) -> void:
	var f := w.final_fight
	f.ready = true
	f.weapon = weapon_of(w)
	f.hit = hit_of(w, t)
	f.hit_cap = cap_of(w, t)
	f.combo_half = PackedInt32Array()
	f.combo_reach = PackedFloat32Array()
	if f.weapon == BossAttackTable.WEAPON_BLADE:
		for k in w.player.combo.size():
			var s := Modifiers.step(w, k)
			f.combo_half.append(clampi(s.half_arc, 64, 2048))
			f.combo_reach.append(clampf(Attacks.arc_reach_m(w, s), 0.6, t.reach_max_m))
	f.shot = weapon_shot(w, t)
	f.casts.clear()
	for c in pick_cards(w, t.card_casts):
		f.casts.append(compile_card(w, t, c[0], c[1]))
	f.stance = BossTable.STANCE_ECHO
	f.stance_t = t.stance_ticks
	if set_hp and t.build_hp:
		var hp := hp_of(w, t)
		w.actors.max_hp[i] = hp
		w.actors.hp[i] = hp


## The run's weapon (BossAttackTable.WEAPON_BLADE or WEAPON_GUN).
static func weapon_of(w: World) -> int:
	if PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w):
		return BossAttackTable.WEAPON_GUN
	return BossAttackTable.WEAPON_BLADE


# --- F7: HP and damage from the build -----------------------------------------------------------------------------


## Its HP (owner F7): max HP × build_hp_permille / 1000 + the measured DPS × dps_target_ticks / 60 (with at least
## dps_min_seconds measured of the last dps_seconds), clamped to dps_hp_min..dps_hp_max.
static func hp_of(w: World, t: BossTable) -> int:
	return hp_from(w.actors.max_hp[0], FinalBoss.measured(w, t), t)


## The formula on plain numbers (tests): `m` is [damage, seconds] from the meter.
static func hp_from(max_hp: int, m: Array[int], t: BossTable) -> int:
	var hp := max_hp * t.build_hp_permille / 1000
	if m[1] > 0 and m[1] >= t.dps_min_seconds:
		hp += m[0] * t.dps_target_ticks / (m[1] * SimTick.TICKS_PER_SECOND)
	return clampi(hp, t.dps_hp_min, maxi(t.dps_hp_min, t.dps_hp_max))


## The cap on any one hit: damage_cap_permille of the player's max HP (at least 1).
static func cap_of(w: World, t: BossTable) -> int:
	return maxi(1, w.actors.max_hp[0] * t.damage_cap_permille / 1000)


## Its hit (owner F7): the player's weapon damage × build_damage_permille / 1000, at least damage_min, at most the cap.
static func hit_of(w: World, t: BossTable) -> int:
	return hit_from(Modifiers.weapon_damage(w), cap_of(w, t), t)


static func hit_from(weapon_damage: int, cap: int, t: BossTable) -> int:
	return mini(maxi(weapon_damage * t.build_damage_permille / 1000, t.damage_min), cap)


## An attack's damage (v0.8.0 N2, owner O27 "small balls 4-5 big attacks 2", superseding F7's "a fifth of your max HP"
## cap, D36): its own hit is its `damage` per cent of the player's max HP (its hit class: 22 small, 30-34 medium, 50
## big: 5, 4-3, 2 hits); an attack begun in a mimic window (FinalFight.copying) copies your damage: the build's hit ×
## `weight_permille` / 1000 when that is more. At least 1, at most the cap (hit_cap). Without a read build (a lab boss
## outside a fight) the attack's own damage.
static func damage_of(w: World, atk: BossAttackTable, weight_permille: int = 1000) -> int:
	var f := w.final_fight
	if f == null or not f.ready or f.hit <= 0:
		return maxi(1, atk.damage)
	var cap := maxi(1, f.hit_cap)
	var own := maxi(1, w.actors.max_hp[0] * atk.damage / 100)
	if not f.copying:
		return mini(own, cap)
	return clampi(maxi(own, f.hit * weight_permille / 1000), 1, cap)


# --- the cards ----------------------------------------------------------------------------------------------------


## The strongest `n` wand cards the player holds, as [item index, level]: by level (highest first), then rarity
## (legendary, rare, common), then the slot (leftmost first). Only wand cards (CardLevels.is_card: a weapon's pool or
## the shared one; never a trigger, a stat card or an ability), never a retired one.
static func pick_cards(w: World, n: int) -> Array[PackedInt32Array]:
	var held: Array[PackedInt32Array] = []
	for s in w.mod_slots.size():
		var code := w.mod_slots[s]
		if Offers.type_of(code) != Offers.MOD or not CardLevels.is_card(w, code):
			continue
		if w.item_tables[code].retired:
			continue
		held.append(
			PackedInt32Array([code, CardLevels.level(w, code), w.item_tables[code].rarity, s])
		)
	for a in range(1, held.size()):  # an insertion sort: stable, no comparator
		var k := a
		while k > 0 and _stronger(held[k], held[k - 1]):
			var tmp := held[k]
			held[k] = held[k - 1]
			held[k - 1] = tmp
			k -= 1
	var out: Array[PackedInt32Array] = []
	for k in mini(maxi(0, n), held.size()):
		out.append(PackedInt32Array([held[k][0], held[k][1]]))
	return out


static func _stronger(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	if a[1] != b[1]:
		return a[1] > b[1]
	if a[2] != b[2]:
		return a[2] > b[2]
	return a[3] < b[3]


## Card `code` at `level` compiled alone on the run's weapon (the wand compiler: its own ops, its hooks, its once-per-
## line and cast-free rules) and copied as a hostile cast.
static func compile_card(w: World, t: BossTable, code: int, level: int) -> NemesisCast:
	var mods: Array[ModifierTable] = []
	for m in w.item_tables[code].modifiers:
		mods.append(m.at(level))
	var gun := weapon_of(w) == BossAttackTable.WEAPON_GUN
	var base := Modifiers.base_bolt(w) if gun else Modifiers.base_step(w, 0)
	var s := WandCompile.for_world(w, mods).spec(base)
	if not gun:
		BladeForms.settle(s)
	var c := from_spec(w, t, s, base.damage)
	c.code = code
	c.level = level
	c.card_id = w.item_tables[code].id
	return c


## The hostile copy of compiled spec `s` (NemesisCast's closed set): its arc (a slash) or volley (a shot), then from its
## first-level hooks a thrown volley (a slash's crescents or blades), splits (a shot's) and a blast (a burst, a patch, a
## ring or a bomb). `base_damage`: the plain attack's, for the weight.
static func from_spec(w: World, t: BossTable, s: AttackSpec, base_damage: int) -> NemesisCast:
	var c := NemesisCast.new()
	c.damage_permille = clampi(s.damage * 1000 / maxi(1, base_damage), WEIGHT_MIN, WEIGHT_MAX)
	if s.form == AttackSpec.Form.ARC:
		c.arc_half = clampi(s.half_arc, 64, 2048)
		c.arc_reach_m = clampf(Attacks.arc_reach_m(w, s), 0.6, t.reach_max_m)
		var reps := s.repeats if s.repeats > 0 else (1 if s.repeat_delay_ticks > 0 else 0)
		c.arc_strikes = 1 + mini(reps, ARC_REPEATS_MAX)
	elif s.form == AttackSpec.Form.BOLT:
		_volley(c, t, s, false)
	for h in s.hooks:
		var ch := h.child
		if ch == null:
			continue
		if ch.form == AttackSpec.Form.BOLT:
			if not c.has_volley():
				_volley(c, t, ch, s.form == AttackSpec.Form.ARC)
			elif c.vol_split == 0 and not c.vol_circle:
				c.vol_split = clampi(ch.count, 1, 4)
				c.vol_split_spread = clampi(ch.spread, 0, 1024)
		elif _blasts(ch.form) and not c.has_blast():
			c.blast_m = clampf(maxf(ch.radius_m, ch.reach_m), t.blast_min_m, t.blast_max_m)
	_cap_shots(c, t)
	return c


static func _blasts(form: int) -> bool:
	return (
		form == AttackSpec.Form.BURST
		or form == AttackSpec.Form.ZONE
		or form == AttackSpec.Form.RING
		or form == AttackSpec.Form.LOB
	)


## A volley from bolt spec `v` (Twin's side-by-side shots join the fan; Halo's ring goes round; Backfire's goes back).
static func _volley(c: NemesisCast, t: BossTable, v: AttackSpec, thrown: bool) -> void:
	c.vol_count = clampi(v.count * (1 + maxi(0, v.twin)), 1, t.shots_max)
	c.vol_spread = clampi(v.spread + (128 * v.twin if v.count <= 1 else 0), 0, 2048)
	c.vol_circle = v.directions == AttackSpec.DIR_CIRCLE
	c.vol_back = v.back_permille > 0 and not c.vol_circle
	c.vol_speed = clampf(
		v.speed if v.speed > 0.0 else CRESCENT_SPEED, t.shot_speed_min, t.shot_speed_max
	)
	c.vol_radius_m = clampf(
		v.radius_m if v.radius_m > 0.0 else CRESCENT_RADIUS_M,
		t.shot_radius_min_m,
		t.shot_radius_max_m
	)
	var run := maxf(v.speed * v.life_ticks, 4.0) if v.life_ticks > 0 else t.shot_range_m
	c.vol_life = maxi(10, int(minf(run, t.shot_range_m) / c.vol_speed))
	c.look = NemesisCast.LOOK_CRESCENT if thrown or v.has_tag(&"wave") else NemesisCast.LOOK_BOLT


## A volley's every shot (roots, the back shot, their splits) stays within shots_max: splits go first.
static func _cap_shots(c: NemesisCast, t: BossTable) -> void:
	if not c.has_volley():
		return
	var roots := c.vol_count + (1 if c.vol_back else 0)
	while c.vol_split > 0 and roots * (1 + c.vol_split) > t.shots_max:
		c.vol_split -= 1
	if c.vol_split == 0:
		c.vol_split_spread = 0


## The run's ranged form: a Gun run's shot as compiled with every card (Modifiers.bolt); a Blade run's thrown slash (its
## first combo step's thrown crescents or blades when the wand throws any, else the attack's own crescents, set at fire
## time from its count and spread: vol_count 0 here).
static func weapon_shot(w: World, t: BossTable) -> NemesisCast:
	var c := NemesisCast.new()
	if weapon_of(w) == BossAttackTable.WEAPON_GUN:
		var s := Modifiers.bolt(w)
		_volley(c, t, s, false)
		for h in s.hooks:
			if h.child != null and h.child.form == AttackSpec.Form.BOLT and c.vol_split == 0:
				c.vol_split = clampi(h.child.count, 1, 4)
				c.vol_split_spread = clampi(h.child.spread, 0, 1024)
		_cap_shots(c, t)
		return c
	if w.player.combo.size() > 0:
		for h in Modifiers.step(w, 0).hooks:
			if h.child != null and h.child.form == AttackSpec.Form.BOLT:
				_volley(c, t, h.child, true)
				break
	return c

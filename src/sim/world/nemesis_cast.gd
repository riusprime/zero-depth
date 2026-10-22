class_name NemesisCast
extends RefCounted
## v0.8.0 FB3 (owner F6 "Weapon + dash + 2-3 cards": the Nemesis "casts the strongest 2–3 cards of your wand" as its own
## attacks; FINAL_BOSS.md F6): the hostile copy of one of the player's attacks, fixed as the Nemesis rises
## (NemesisBuild.compile_card / weapon_shot) from the spec the wand compiler builds for it (WandCompile: the card alone
## on the run's weapon, at its level). What a hostile copy can do is a closed set, so it is fair and capped:
## - an arc: arc_half (1/4096 turns) each side of the aim, arc_reach_m past the body's edge, struck arc_strikes times
##   (Double Slash's repeats: at most 3 strikes), from a slash card;
## - a volley: vol_count shots (a fan vol_spread wide, or evenly round when vol_circle; also straight back when
##   vol_back), each with vol_split more beside it vol_split_spread apart (Split's splits, fanned from the start), at
##   vol_speed m per tick, vol_radius_m, for vol_life ticks, drawn as `look` (a bolt or a crescent);
## - a blast: a disc of blast_m on the spot the cast locked (Explosive, Mine, Fire's flame, Void's pull: a hook card's
##   burst), struck once. Its hits deal damage_permille of the Nemesis's hit per hit (the card's own weight against the
##   plain attack: Heavy heavier, Flurry lighter; 500..2000). Hook children deeper than one level, trigger cuts and the
##   casts they make are never copied: no shot of a hostile copy splits or explodes again (the BL once-per-line rule)
##   and nothing it hits casts anything (the PF2 cast-free rule). State (WorldSnapshot.STATE_CLASSES): saved and hashed
##   with its fight.

const LOOK_BOLT := &"nemesis_bolt"
const LOOK_CRESCENT := &"nemesis_crescent"

## The wand card it copies (its item index and level; -1 for the weapon's own shot), and that card's id (the views' name
## and icon).
var code := -1
var level := 1
var card_id := &""
var arc_half := 0
var arc_reach_m := 0.0
var arc_strikes := 0
var vol_count := 0
var vol_spread := 0
var vol_circle := false
var vol_back := false
var vol_split := 0
var vol_split_spread := 0
var vol_speed := 0.0
var vol_radius_m := 0.0
var vol_life := 0
var look := LOOK_BOLT
var blast_m := 0.0
var damage_permille := 1000


func has_arc() -> bool:
	return arc_strikes > 0 and arc_reach_m > 0.0


func has_volley() -> bool:
	return vol_count > 0 and vol_speed > 0.0


func has_blast() -> bool:
	return blast_m > 0.0


## Every shot of a volley aimed at `aim` (1/4096 turns): its angles, the roots first then each root's splits.
func angles(aim: int) -> PackedInt32Array:
	var roots := PackedInt32Array()
	if vol_circle:
		for k in vol_count:
			roots.append((aim + k * 4096 / maxi(1, vol_count)) & 4095)
	else:
		for k in vol_count:
			roots.append(BossNemesis.fan_angle(aim, k, vol_count, vol_spread))
		if vol_back:
			roots.append((aim + 2048) & 4095)
	var out := roots.duplicate()
	for r in roots:
		for k in vol_split:
			out.append(BossNemesis.fan_angle(r, k, vol_split, vol_split_spread))
	return out


## The view's read (WorldReader.nemesis): plain data.
func read() -> Dictionary:
	return {
		"code": code,
		"level": level,
		"card_id": card_id,
		"arc": has_arc(),
		"arc_half": arc_half,
		"arc_reach_m": arc_reach_m,
		"arc_strikes": arc_strikes,
		"volley": has_volley(),
		"shots": vol_count,
		"circle": vol_circle,
		"back": vol_back,
		"split": vol_split,
		"look": look,
		"blast": has_blast(),
		"blast_m": blast_m,
	}


func hash_into(h: StateHasher) -> void:
	h.add_string(String(card_id))
	for v in [code, level, arc_half, arc_strikes, vol_count, vol_spread, vol_split]:
		h.add_int(v)
	for v in [vol_split_spread, vol_life, damage_permille]:
		h.add_int(v)
	h.add_int(1 if vol_circle else 0)
	h.add_int(1 if vol_back else 0)
	h.add_string(String(look))
	for v in [arc_reach_m, vol_speed, vol_radius_m, blast_m]:
		h.add_f32(v)

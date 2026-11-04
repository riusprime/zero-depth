class_name CandidateLooks
extends RefCounted
## v0.10.5 W3-O7 (owner F6, F16; G2: docs/roadmap/v0.10.5/W3_O7_VFX_G2.md): the candidate looks the owner picks from,
## for the purple enemy bolt and the Lance's ball, each a row of data/vfx/pack_fx_w3o7.tres (so the session warm-up
## compiles it before a fight). Today's looks stay the default (&""), until the owner picks: set BOLT / LANCE.
## FireballViews and HeroPulseViews ask here for the table id; shot tools and tests set `bolt` / `lance`.
## Presentation only (EI-07): constants and look-ups.
## - The purple bolt (owner, 2026-11-04: "Purple enemy bolts: the recently changed projectiles feel visually
##   underwhelming compared with fireballs"): the Twin Wardens' violet ember (BOLT_LOOKS; VX4 drew it with the pack's
##   mprojectile_basic_vfx_03, beside the amber twin's fire_ball_04). &"a" a violet fireball (fire_ball_04 recoloured:
##   assets/vfx_zd/tinted_fire); &"b" the pack's violet javelin (mprojectile_javelin_vfx_03); &"c" the pack's flare orb
##   (magic_orb_flare_vfx_03, its star Flare left out). Round 2 (W3-O7b; owner: "comparisons with new assets from the
##   premade pack"): &"d" the Ice pack's shard (ice_shard_vfx_02) in violet; &"e" the Ice pack's ball (ice_ball_vfx_01)
##   in violet; &"f" the Magic Projectiles wave (mprojectile_wave_vfx_03); &"g" the Poison pack's bubble
##   (poison_bubble_vfx_01, its Pop and Splats left out).
## - The Lance (owner: "Lance: projectile animation looks like a generic ball and feels worse than the available VFX
##   pack alternatives"): today the pack's big orb of the element (vx2_big_<element>). &"a" the recoloured fireball in
##   the element's colours; &"b" the pack's javelin of the element (vx2_jav_<element>); &"c" the pack's flare orb with
##   its star flare (magic_orb_flare_vfx_02).

const BOLT := &""
const LANCE := &""
const BOLT_LOOKS: Array[StringName] = [&"warden_violet_ember"]
## Candidate -> [its table id, the parts of its scene left out].
const BOLTS := {
	&"a": [&"w3o7_bolt_a", []],
	&"b": [&"w3o7_bolt_b", []],
	&"c": [&"w3o7_bolt_c", ["Flare"]],
	&"d": [&"w3o7_bolt_d", []],
	&"e": [&"w3o7_bolt_e", []],
	&"f": [&"w3o7_bolt_f", []],
	&"g": [&"w3o7_bolt_g", ["Pop", "Splats"]],
}
## Candidate -> [its table id (a "%s" takes the element's kind), its drawn size per metre of the ball's radius, true:
## the fireball's colours (its flame and rim the element's deep tone, its hot puffs and light its hot centre)].
const LANCES := {
	&"a": [&"w3o7_lance_a", 2.6, true],
	&"b": [&"vx2_jav_%s", 5.0, false],
	&"c": [&"w3o7_lance_c", 1.8, false],
}

## The candidates drawn now (BOLT and LANCE unless a shot tool or a test sets them).
static var bolt := BOLT
static var lance := LANCE


## The table id a hostile shot of look `key` draws with: "shot_<key>", or the picked candidate's.
static func bolt_id(key: StringName) -> StringName:
	if BOLT_LOOKS.has(key) and BOLTS.has(bolt):
		return BOLTS[bolt][0]
	return StringName("shot_%s" % key)


## The parts of look `key`'s pack scene left out: `hide` (FireballViews.PACK_HIDE's), or the picked candidate's.
static func bolt_hide(key: StringName, hide: Array) -> Array:
	if BOLT_LOOKS.has(key) and BOLTS.has(bolt):
		return BOLTS[bolt][1]
	return hide


## The Lance ball's [table id, colours, drawn size per metre of radius] for its first element `first` and the shot's
## pack colours `colours`: today's big orb (`big_per_radius` a metre), or the picked candidate's.
static func lance_pack(first: StringName, colours: Dictionary, big_per_radius: float) -> Array:
	if not LANCES.has(lance):
		return [PackLooks.id_of("big", first), colours, big_per_radius]
	var row: Array = LANCES[lance]
	var id := String(row[0])
	if id.contains("%s"):
		id = id % PackLooks.shaped(first)
	var c := colours
	if bool(row[2]):
		c = {
			&"primary": colours.get(&"secondary", Color.WHITE),
			&"secondary": colours.get(&"tertiary", Color.WHITE),
			&"tertiary": colours.get(&"tertiary", Color.WHITE),
		}
	return [StringName(id), c, float(row[1])]

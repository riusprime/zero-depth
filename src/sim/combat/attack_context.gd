class_name AttackContext
extends RefCounted
## v0.6.0 MX1: what one launch of a spec needs that the spec doesn't hold (Attacks.launch): where and which way, the
## damage the caller computed (the build's factors, Overcharge, Momentum, the gamble shrine are runtime), the root
## chain, the effect id its hits carry, and the hook level (depth, proc coefficient in percent).

var origin := Vector2.ZERO
var angle := 0
var damage := 0
## The damage a hook's damage_permille is a share of (the parent's base damage).
var base_damage := 0
var root := 0
var effect_id := &""
## 0 for a root attack; a hook's child launches at depth + 1 with half the proc coefficient (100 → 50 → 25).
var depth := 0
var proc_pct := 100
## An arc's combo step (its reach), -1 for none.
var step := -1
## The actor a hook's beam leaves out (the one just hit), -1 for none.
var exclude := -1
## SimEvent tag bits its hits or bolts carry.
var tags := 0
## v0.6.0 MX2: where a lob lands (has_target; else reach_m along the angle), and how far past the origin a bolt
## leaves (-1: the player's muzzle, past the player's edge; a drone fires from its own position, 0).
var target := Vector2.ZERO
var has_target := false
var muzzle_m := -1.0
## Scatter Blast only: per landed pellet, the damage (the build's bolt factor carries a remainder, so it's taken
## per hit as before MX1), what follows a landed hit (the knockback), and each ray's end (the view's pellet ends).
var damage_fn := Callable()
## v0.6.0 MX4: a repeat (Twin Cast's again) or a back copy (Rearguard) never repeats or turns back again; a burst's
## radius when the caller sizes it at run time (Vent's blast, an echo with the area stat; 0 = the spec's).
var repeat := false
var back := false
## v0.8.0 MR (owner O91; SecondaryProc): a secondary attack (an Echo's repeat, a Double Slash echo; a secondary bolt's
## hit): its hits feed statuses at WandTable.secondary_proc_permille, its hooks' children launch at that share of the
## proc, and its trigger casts at that share of their damage (Attacks.run_hook).
var secondary := false
var radius_m := 0.0
## v0.6.5 WN3: a charged shot's bolts are this much bigger (per mille of the spec's radius; G13 Charge).
var size_permille := 1000
## v0.9.5 WB (owner Q13): this launch's bolts pierce this many more enemies than the spec (the Wisps' shots: 1).
var extra_pierce := 0
## v0.9.5 FC4: a Lance release at full charge (Halo's six lances, Ricochet's bounce; PlayerKit._fire_bolt).
var lance_full := false
var on_landed := Callable()
var on_ray := Callable()


static func make(
	p_origin: Vector2, p_angle: int, p_damage: int, p_root: int, p_tags: int, p_effect: StringName
) -> AttackContext:
	var c := AttackContext.new()
	c.origin = p_origin
	c.angle = p_angle
	c.damage = p_damage
	c.base_damage = p_damage
	c.root = p_root
	c.tags = p_tags
	c.effect_id = p_effect
	return c


## The context a hook's child launches with: one level deeper, half the proc coefficient, the parent's root; v0.8.0
## MR: a repeat's child is a repeat's too (Attacks.run_hook: it launches no trigger's later cast).
func child(at: Vector2, p_damage: int, p_tags: int, p_effect: StringName) -> AttackContext:
	var c := AttackContext.make(at, angle, p_damage, root, p_tags, p_effect)
	c.depth = depth + 1
	c.proc_pct = proc_pct / 2
	c.repeat = repeat and not back  # v0.8.0 MR (O91): a repeat's child launches no later cast either
	return c

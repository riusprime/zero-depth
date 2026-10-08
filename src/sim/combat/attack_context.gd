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
## Scatter Blast only: per landed pellet, the damage (the build's bolt factor carries a remainder, so it's taken
## per hit as before MX1), what follows a landed hit (the knockback), and each ray's end (the view's pellet ends).
var damage_fn := Callable()
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


## The context a hook's child launches with: one level deeper, half the proc coefficient, the parent's root.
func child(at: Vector2, p_damage: int, p_tags: int, p_effect: StringName) -> AttackContext:
	var c := AttackContext.make(at, angle, p_damage, root, p_tags, p_effect)
	c.depth = depth + 1
	c.proc_pct = proc_pct / 2
	return c

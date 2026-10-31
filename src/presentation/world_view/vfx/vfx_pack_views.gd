class_name VfxPackViews
extends RefCounted
## v0.10.0 VX3 (VFX_PACK R19-R26, R28-R30, R41; the owner's purchased Binbun pack through PackFx): the pack's version of
## the VfxLayer's zones (fire, frost, venom and bleed patches), rings, element bursts (frost, shatter, venom, bleed,
## Wildfire), the statuses on an enemy (burn, poison, frost) and Bulwark's guard orbs. The layer asks first; every
## function says whether the pack drew it, and the layer draws its old sprites when it did not (no PackFx, or no room
## in the effect's family). The layer's own lights, floor marks and budgets stay (VfxLayer, VfxCore). Cosmetic only.
## - Held effects (a patch, a ring, a status, an orb) are touched every frame they should be there (PackHold) and go
##   back to PackFx when a frame did not touch them.
## - One-shot effects (a burst) spawn the first frame their seed is drawn (`once`).

## The effect's scale per metre of the patch or ring radius it fills (each scene's own size; the VX3 shots).
const ZONE_PER_M := {
	&"zone_fire_a": 1.25,
	&"zone_fire_b": 1.25,
	&"zone_fire_foe_a": 1.3,
	&"zone_fire_foe_b": 1.3,
	&"zone_frost": 0.5,
	&"zone_frost_mist": 0.5,
	&"zone_venom": 0.55,
	&"zone_bleed": 0.6,
	&"ring_fire": 0.55,
	&"ring_frost": 0.5,
	&"ring_venom": 0.5,
	&"ring_bleed": 0.55,
}
const BURST_PER_M := {
	&"burst_frost": 0.22,
	&"burst_shatter": 0.4,
	&"burst_venom": 0.7,
	&"burst_bleed": 0.7,
	&"burst_wildfire": 0.6,
}
## The ring effect of each element kind (R26: Frost Nova's pulse, Ember Ward's rim).
const RING_IDS := {
	&"fire": &"ring_fire", &"frost": &"ring_frost", &"venom": &"ring_venom", &"bleed": &"ring_bleed"
}
const BURNS: Array[StringName] = [&"status_burn_a", &"status_burn_b", &"status_burn_c"]
const FROSTS: Array[StringName] = [&"status_frost_a", &"status_frost_b"]
const FROST_ZONES: Array[StringName] = [
	&"zone_frost_a", &"zone_frost_b", &"zone_frost_c", &"zone_frost_d"
]
const VENOM_ZONES: Array[StringName] = [&"zone_venom_a", &"zone_venom_b"]
const FIRE_ZONES: Array[StringName] = [&"zone_fire_a", &"zone_fire_b"]
const FOE_FIRE_ZONES: Array[StringName] = [&"zone_fire_foe_a", &"zone_fire_foe_b"]
## A shatter's ice patch and a Wildfire's flames last this long (s).
const SHATTER_S := 0.9
const WILDFIRE_S := 1.0
## A poisoned enemy pops a bubble about this often (ticks, plus up to as much again).
const BUBBLE_TICKS := 70.0
## A body's flames per metre of its height, its mist per metre of its radius.
const FLAME_PER_M := 0.8
const MIST_PER_M := 0.12
## The guard orbs: how many circle the body, and their scale.
const ORBS := 3
const ORB_SCALE := 0.07
## The element each effects kind is drawn in (the pack's effects take ElementLooks' colours).
const KIND_ELEMENT := {
	&"fire": &"ember",
	&"storm": &"storm",
	&"frost": &"frost",
	&"venom": &"venom",
	&"bleed": &"bleed",
	&"void": &"void",
}
## What a burst's seed meant the first time it was drawn (once()).
const ONCE_SPAWN := 0
const ONCE_DONE := 1
const ONCE_OLD := 2
## A burst's seed is forgotten this long (ticks) after it was last drawn.
const SEEN_TICKS := 180.0

var layer: VfxLayer
var zone_holds := PackHold.new()  # patches and rings, held while they are drawn
var status_holds := PackHold.new()  # statuses and orbs, held while their enemy shows them
var _once := {}  # key -> [last tick drawn, ONCE_DONE or ONCE_OLD]


func _init(p_layer: VfxLayer) -> void:
	layer = p_layer


## The pack colours of an effects kind (its element's core, hot and deep). `ground`: for the hero's floor effects, each
## goes through AttackFormLooks.ground_safe, so a fire or bleed patch leans cooler than the telegraphs' hostile hues
## (VFX_PACK I7); an enemy's patch passes false and keeps the warm hues.
static func kind_colors(kind: StringName, ground: bool) -> Dictionary:
	var e: StringName = KIND_ELEMENT.get(kind, &"")
	var p := ElementLooks.core(e)
	var s := ElementLooks.hot(e)
	var t := ElementLooks.deep(e)
	if ground:
		p = AttackFormLooks.ground_safe(p)
		s = AttackFormLooks.ground_safe(s)
		t = AttackFormLooks.ground_safe(t)
	return {&"primary": p, &"secondary": s, &"tertiary": t}


## A held effect's key from its effect's seed, a slot and where it stands (copies of one patch stand apart).
static func zkey(sd: int, slot: int, c: Vector3) -> int:
	return ((sd * 31 + slot) * 1009 + roundi(c.x * 8.0)) * 1013 + roundi(c.z * 8.0)


## A status effect's key from the enemy's id and a slot.
static func skey(sd: int, slot: int) -> int:
	return sd * 64 + slot


static func bkey(sd: int, kind: int) -> int:
	return sd * 16 + kind


## A frame starts (VfxLayer.begin): the layer's PackFx, and the held effects' frame.
func begin(fx: PackFx) -> void:
	zone_holds.fx = fx
	status_holds.fx = fx
	zone_holds.begin()
	status_holds.begin()


## A frame ends (VfxLayer.finish): what nothing touched goes back to PackFx.
func end() -> void:
	zone_holds.end()
	status_holds.end()


## Takes a burst's seed's decision once: ONCE_SPAWN the first frame it is drawn and the pack has room in `family`
## (the caller spawns its effects), ONCE_DONE on the frames after, ONCE_OLD when there was no room (the old look draws
## the whole burst).
func once(key: int, family: StringName) -> int:
	var at := layer.now()
	var seen: Array = _once.get(key, [])
	if not seen.is_empty():
		seen[0] = at
		return int(seen[1])
	for k: int in _once.keys():
		if absf(at - float((_once[k] as Array)[0])) > SEEN_TICKS:
			_once.erase(k)
	var room := layer.pack_fx != null and layer.pack_fx.has_room(family)
	_once[key] = [at, ONCE_DONE if room else ONCE_OLD]
	return ONCE_SPAWN if room else ONCE_OLD


## A one-shot pack effect `id` at `c`, `r` metres across by its per-metre factor, for `life` s (-1: its own length).
func shot(id: StringName, c: Vector3, r: float, colors: Dictionary, life := -1.0) -> void:
	var per: float = BURST_PER_M.get(id, 1.0)
	var size := r * per * (VfxLayer.PACK_THIN_SCALE if layer._lights_off else 1.0)
	var n := PackHold.play(layer.pack_fx, id, c, size, colors, life)
	if n != null and life > 0.0:
		PackHold.loop(n)  # (a one-shot flame area would stop after its particles' lifetime)


## A fire area's flames in the hero's ground-safe colours (an enemy's patch keeps the scene's warm ones): main is the
## deep tone, edge the core and glow the hot centre.
static func tint_fire_area(node: Node3D, hostile: bool) -> void:
	if hostile:
		return
	var wave := node.get_node_or_null("WaveMesh") as MeshInstance3D
	if wave == null or wave.mesh == null:
		return
	var src := wave.mesh.surface_get_material(0) as ShaderMaterial
	if src == null:
		src = wave.material_override as ShaderMaterial
	if src == null:
		return
	var cols := kind_colors(&"fire", true)
	var mat := src.duplicate() as ShaderMaterial  # (the scene's own is shared by every instance)
	mat.set_shader_parameter(&"main_color", cols[&"tertiary"])
	mat.set_shader_parameter(&"edge_color", cols[&"primary"])
	mat.set_shader_parameter(&"glow_color", cols[&"secondary"])
	wave.material_override = mat


# --- Zones and rings ---------------------------------------------------------------------------------------------
## The fire patch (R21): the hero's in fire_area_01/02 (ground-safe colours, I7), an enemy's or boss's in
## fire_area_06/07 (warm), held while it is drawn, its light and scorch kept. False: no room, the old flames draw.
func fire(c: Vector3, r: float, fade: float, age: float, sd: int, hostile: bool) -> bool:
	var ids := FOE_FIRE_ZONES if hostile else FIRE_ZONES
	var id: StringName = ids[absi(sd) % ids.size()]
	# Overlapping patches (a dash's Flame Trail) stay about one layer: one that another patch covers draws no flames.
	if layer._claim(&"fire_zone", c, maxf(VfxLayer.FLAME_SPACING, r), sd):
		var node := zone_holds.touch(
			zkey(sd, 1, c),
			id,
			&"area",
			c,
			r * float(ZONE_PER_M[id]) * (0.5 + 0.5 * fade),
			{},
			tint_fire_area.bind(hostile)
		)
		if node == null:
			return false
	layer._light_merged(
		c + Vector3(0, 0.9, 0),
		VfxLayer.WARM,
		(2.6 + r) * fade * (0.85 + 0.15 * sin(age * 0.9 + sd)),
		r + 3.5,
		2.5
	)
	layer.mark(sd * VfxLayer.MARK_KINDS, &"scorch", c, r * 1.1, VfxLayer.SCORCH)
	return true


## The frost patch (R22): an ice area and a low mist, held; its light and frost mark kept.
func frost_field(c: Vector3, r: float, fade: float, sd: int) -> bool:
	var id: StringName = FROST_ZONES[absi(sd) % FROST_ZONES.size()]
	var cols := kind_colors(&"frost", true)
	var s := r * float(ZONE_PER_M[&"zone_frost"]) * (0.6 + 0.4 * fade)
	if zone_holds.touch(zkey(sd, 2, c), id, &"area", c, s, cols) == null:
		return false
	zone_holds.touch(zkey(sd, 3, c), &"zone_frost_mist", &"area", c, s, cols)
	layer._light(c + Vector3(0, 0.6, 0), VfxLayer.ICE, 0.9 * fade, r + 2.0)
	layer.mark(sd * VfxLayer.MARK_KINDS + 1, &"frost", c, r * 1.2, VfxLayer.FROST_MARK)
	return true


## The venom puddle (R23) or bleed pool (R25: the puddle in bleed's colours), held; the old floor splats stay.
func liquid_field(c: Vector3, r: float, fade: float, sd: int, toxic: bool) -> bool:
	var id: StringName = VENOM_ZONES[absi(sd) % VENOM_ZONES.size()] if toxic else &"zone_bleed"
	var per: float = ZONE_PER_M[&"zone_venom" if toxic else &"zone_bleed"]
	var cols := kind_colors(&"venom" if toxic else &"bleed", true)
	var s := r * per * (0.6 + 0.4 * fade)
	return zone_holds.touch(zkey(sd, 4 if toxic else 5, c), id, &"area", c, s, cols) != null


## The ring of `kind` at radius `r` now (R26), held while the ring is drawn, the layer's light kept (fire and frost).
## False: no room, the old ring draws.
func ring(kind: StringName, c: Vector3, r: float, fade: float, sd: int) -> bool:
	var id: StringName = RING_IDS[kind]
	var cols := kind_colors(kind, true)
	if zone_holds.touch(zkey(sd, 6, c), id, &"area", c, r * float(ZONE_PER_M[id]), cols) == null:
		return false
	if kind == &"fire":
		layer._light(c + Vector3(0, 0.8, 0), VfxLayer.WARM, 2.0 * fade, r + 2.5)
	elif kind == &"frost":
		layer._light(c + Vector3(0, 0.5, 0), VfxLayer.ICE, 1.2 * fade, r + 2.0)
	return true


# --- Bursts (once each) ------------------------------------------------------------------------------------------
## The frost burst (R19) at `u` through its life: vfx_explosion_07 the first frame, and for a shatter a small ice
## patch; the layer's light and frost mark stay. False: no room, the old burst draws.
func frost_burst(c: Vector3, r: float, u: float, sd: int, shatter: bool) -> bool:
	var mode := once(bkey(sd, 5 if shatter else 1), &"explosion")
	if mode == ONCE_OLD:
		return false
	if mode == ONCE_SPAWN:
		var cols := kind_colors(&"frost", false)
		shot(&"burst_frost", c, r, cols)
		if shatter and layer.pack_fx.has_room(&"impact"):
			shot(&"burst_shatter", c, r, cols, SHATTER_S)
	layer._light(c + Vector3(0, 0.8, 0), VfxLayer.ICE, 4.0 * (1.0 - u) * (1.0 - u), r * 2.5 + 1.5)
	layer.mark(sd * VfxLayer.MARK_KINDS + 1, &"frost_burst", c, r * 1.35, VfxLayer.FROST_MARK)
	return true


## The venom or bleed burst (R20): a poison bubble, bleed in its dark red; the layer's light and floor splat stay.
## v0.10.0 FX: its short pack puddle on the splat is gone. False: no room, the old burst draws.
func liquid_burst(c: Vector3, r: float, u: float, sd: int, toxic: bool) -> bool:
	var mode := once(bkey(sd, 2 if toxic else 3), &"impact")
	if mode == ONCE_OLD:
		return false
	var kind := &"venom" if toxic else &"bleed"
	if mode == ONCE_SPAWN:
		var cols := kind_colors(kind, false)
		shot(&"burst_venom" if toxic else &"burst_bleed", c, r, cols)  # v0.10.0 FX: no puddle (the splat decal)
	var col := VfxLayer.VENOM if toxic else VfxLayer.BLOOD
	layer._light(c + Vector3(0, 0.6, 0), col, 2.0 * (1.0 - u), r * 2.0 + 1.0)
	var mark_c := VfxLayer.VENOM_MARK if toxic else VfxLayer.BLOOD_MARK
	layer.mark(sd * VfxLayer.MARK_KINDS + 2, VfxLayer._splat(sd), c, r * 1.3, mark_c)
	return true


## Wildfire spreading from a burning kill (a status payoff): fire_area_03 the first frame, the layer's sparks, light
## and scorch stay. False: no room, the fire sprites' explosion draws.
func wildfire(c: Vector3, r: float, u: float, sd: int) -> bool:
	var mode := once(bkey(sd, 4), &"explosion")
	if mode == ONCE_OLD:
		return false
	if mode == ONCE_SPAWN:
		shot(&"burst_wildfire", c, r, {}, WILDFIRE_S)
	layer._explosion_rest(c, r, u, sd)
	return true


# --- Statuses on an enemy (held, following it) -------------------------------------------------------------------
## `p` moved `d` metres toward the camera, so a flame stands on the body's near side, not inside it.
func front(p: Vector3, d: float) -> Vector3:
	var z := layer._cam_basis.z
	return p + Vector3(z.x, 0.0, z.z).normalized() * d


## Burn (R28): small flames on the body, one of three scenes by enemy. `p` the feet, `top` the body's height.
func burn(p: Vector3, r: float, stacks: int, sd: int, top: float) -> bool:
	var id: StringName = BURNS[absi(sd) % BURNS.size()]
	var size := clampf(top * FLAME_PER_M * (0.85 + 0.08 * stacks), 0.5, 1.8)
	return status_holds.touch(skey(sd, 1), id, &"status", front(p, r * 0.9), size) != null


## Poison (R29): a stink cloud at the body and now and then a bubble.
func poison(p: Vector3, r: float, sd: int, top: float) -> bool:
	var key := skey(sd, 2)
	var node := status_holds.touch(
		key,
		&"status_poison",
		&"status",
		front(p, r * 0.5) + Vector3(0, top * 0.35, 0),
		maxf(r, 0.4) * 2.0
	)
	if node == null:
		return false
	var d := status_holds.data(key)
	var at := layer.now()
	if at >= float(d.get("bubble", 0.0)):
		d["bubble"] = at + BUBBLE_TICKS * (1.0 + VfxLayer.h(sd, int(at / 7.0)))
		var a := TAU * VfxLayer.h(sd, int(at / 5.0))
		var up := top * (0.3 + 0.5 * VfxLayer.h(sd + 1, int(at / 9.0)))
		if layer.pack_fx.has_room(&"status"):
			PackHold.play(
				layer.pack_fx,
				&"status_poison_bubble",
				p + Vector3(cos(a) * r * 0.6, up, sin(a) * r * 0.6),
				0.5,
				kind_colors(&"venom", false)
			)
	return true


## Frost (R30): ice mist at the feet.
func frost(p: Vector3, r: float, sd: int) -> bool:
	var id: StringName = FROSTS[absi(sd) % FROSTS.size()]
	return (
		status_holds.touch(
			skey(sd, 3),
			id,
			&"status",
			p + Vector3(0, 0.05, 0),
			maxf(r, 0.4) * MIST_PER_M,
			kind_colors(&"frost", false)
		)
		!= null
	)


## Bulwark's guard orbs (R41): `charges` orbs circling the body, held. Returns how many the pack draws.
func guard(p: Vector3, r: float, charges: int, sd: int) -> int:
	var gold := ItemLooks.status_color(&"guard")
	var cols := {
		&"primary": gold, &"secondary": gold.lightened(0.5), &"tertiary": gold.darkened(0.3)
	}
	var packed := 0
	for k in mini(charges, ORBS):
		var a := layer.now() / 60.0 * 3.0 + TAU * k / ORBS
		var at := p + Vector3(cos(a) * (r + 0.35), 0.7, sin(a) * (r + 0.35))
		if (
			status_holds.touch(skey(sd, 10 + k), &"guard_orb", &"status", at, ORB_SCALE, cols)
			== null
		):
			break
		packed += 1
	return packed

class_name HitPack
extends RefCounted
## VFX_PACK R10, R11, R14-R17, R43: the hit, impact, spark and flash effects as the pack's scenes
## (PackFx), shared by ImpactFx, HeroFx, HeroCastFx and HitFeel. The old draws are per-frame functions of `u`; a pack
## scene is spawned once, so `state` remembers which instance (layer, tag, seed) already chose its look: PACK (the
## scene plays on its own) or OLD (the family was full, the caller keeps drawing the old look). A new instance is one
## whose `u` went back, or that was not drawn for a while.
## Presentation only (EI-07): nothing here reads or writes the sim.

const NEW := 0
const PACK := 1
const OLD := 2
## An instance not drawn for this many ticks is over (its seed may come again).
const GONE_TICKS := 30.0
const PRUNE_AT := 48
const PRUNE_TICKS := 120.0

## A hit with strength at least this is heavy (a crit, a finisher): the impact scene instead of the hit one.
const HEAVY := 1.2

const ELEMENT_OF := {
	&"fire": &"ember",
	&"storm": &"storm",
	&"frost": &"frost",
	&"venom": &"venom",
	&"bleed": &"bleed",
	&"void": &"void",
}
const HIT_IDS := {
	&"ember": &"vx1_hit_ember",
	&"storm": &"vx1_hit_storm",
	&"frost": &"vx1_hit_frost",
	&"venom": &"vx1_hit_venom",
	&"bleed": &"vx1_hit_bleed",
}
const HIT_PLAIN := &"vx1_hit_plain"
const IMPACT_IDS := {&"ember": &"vx1_impact_ember", &"frost": &"vx1_impact_frost"}
const IMPACT_PLAIN := &"vx1_impact_ember"
const IMPACT_OTHER := &"vx1_impact_other"
const SLASH := &"vx1_slash"
const GUARD := &"vx1_guard"
const WEAK := &"vx1_weak"
const DEFLECT := &"vx1_deflect"
const MUZZLE_IDS := {
	&"ember": &"vx1_muzzle_01",
	&"storm": &"vx1_muzzle_02",
	&"frost": &"vx1_muzzle_03",
	&"venom": &"vx1_muzzle_04",
	&"bleed": &"vx1_muzzle_06",
}
const MUZZLE_NEUTRAL := &"vx1_muzzle_05"
const FLASH_BIG := &"vx1_flash_big"

## Scales (the pack's scene is about a metre across at 1): per metre of the old effect's strength.
const HIT_SCALE := 0.35
const IMPACT_SCALE := 0.3
const SLASH_SCALE := 0.5
const MUZZLE_SCALE := 0.8
const FLASH_PER_M := 0.8
## Per scene: the factor on the scales above (the scenes differ in size: Storm's hit and the Ember and Frost impacts are
## several metres across at 1; found in the shots).
const SCENE_K := {
	&"vx1_hit_storm": 0.4,
	&"vx1_impact_ember": 0.6,
	&"vx1_impact_frost": 0.5,
}
## Flashes smaller than this (m across) keep the old look (the pack's flash is the heavy cast's).
const FLASH_MIN_M := 1.0

## (layer id, tag, seed) -> [last u, mode, last tick].
static var _seen := {}


## The layer's PackFx (VfxLayer has one; a bare VfxCore, or one without the pack: null).
static func pack(layer: Object) -> PackFx:
	if layer == null:
		return null
	return layer.get(&"pack_fx") as PackFx


## [primary, secondary, tertiary] of element `e` (none: the hero's energy).
static func colors(e: StringName) -> Dictionary:
	return {
		&"primary": ElementLooks.core(e),
		&"secondary": ElementLooks.hot(e),
		&"tertiary": ElementLooks.deep(e),
	}


## The colours of a tint `c` (a spark's own colour).
static func tint(c: Color) -> Dictionary:
	return {&"primary": c, &"secondary": c.lerp(Color.WHITE, 0.5), &"tertiary": c.darkened(0.35)}


## The element whose core is `c` (the volley's colours); none: &"".
static func element_for(c: Color) -> StringName:
	for e: StringName in ElementLooks.ELEMENTS:
		if ElementLooks.core(e).is_equal_approx(c):
			return e
	return &""


## The mode of instance (`tag`, `sd`) of `layer` at `u`: NEW when it is a new one (and it is now remembered as NEW
## until `decide`), else the mode it chose.
static func state(layer: VfxCore, tag: StringName, sd: int, u: float) -> int:
	var key := [layer.get_instance_id(), tag, sd]
	var now := layer.now()
	var e: Array = _seen.get(key, [])
	if e.is_empty() or u < float(e[0]) - 0.0001 or absf(now - float(e[2])) > GONE_TICKS:
		if _seen.size() > PRUNE_AT:
			_prune(now)
		_seen[key] = [u, NEW, now]
		return NEW
	e[0] = u
	e[2] = now
	return int(e[1])


static func decide(layer: VfxCore, tag: StringName, sd: int, mode: int) -> void:
	var e: Array = _seen.get([layer.get_instance_id(), tag, sd], [])
	if not e.is_empty():
		e[1] = mode


static func _prune(now: float) -> void:
	for k: Array in _seen.keys():
		if absf(now - float((_seen[k] as Array)[2])) > PRUNE_TICKS:
			_seen.erase(k)


static func clear() -> void:
	_seen.clear()


## The yaw (about up) that turns +X to the flat direction `d`.
static func yaw_of(d: Vector3) -> float:
	return atan2(-d.z, d.x)


## The hit scene's id for effects-layer kind `kind` (&"fire" ...; none: plain), heavy: the impact scene.
static func hit_id(kind: StringName, heavy: bool) -> StringName:
	var e: StringName = ELEMENT_OF.get(kind, &"")
	if heavy:
		return IMPACT_IDS.get(e, IMPACT_PLAIN if e == &"" else IMPACT_OTHER)
	return HIT_IDS.get(e, HIT_PLAIN)


## R14, R15: a bolt's impact at `p` of effects-layer kind `kind`, strength `s`: true when the pack's scene plays it
## (spawned on its first call, then true while it plays); false: draw the old look.
static func hit(layer: VfxCore, kind: StringName, p: Vector3, u: float, sd: int, s: float) -> bool:
	var pk := pack(layer)
	if pk == null:
		return false
	var mode := state(layer, &"hit", sd, u)
	if mode == NEW:
		var heavy := s >= HEAVY
		var fam := &"impact" if heavy else &"hit"
		mode = OLD
		if pk.has_room(fam):
			var e: StringName = ELEMENT_OF.get(kind, &"")
			var k := IMPACT_SCALE if heavy else HIT_SCALE
			var id := hit_id(kind, heavy)
			if pk.spawn(id, p, k * s * float(SCENE_K.get(id, 1.0)), colors(e)) != null:
				mode = PACK
		decide(layer, &"hit", sd, mode)
	return mode == PACK


## A slash's impact at `p` along `tan` (flat, unit), element kind `kind`, strength `s`: the cut turned to the
## slash; a heavy one (the finisher) adds the impact scene. As `hit`.
static func slash(
	layer: VfxCore, kind: StringName, p: Vector3, tan: Vector3, u: float, sd: int, s: float
) -> bool:
	var pk := pack(layer)
	if pk == null:
		return false
	var mode := state(layer, &"slash", sd, u)
	if mode == NEW:
		mode = OLD
		if pk.has_room(&"hit"):
			var e: StringName = ELEMENT_OF.get(kind, &"")
			var node := pk.spawn(SLASH, p, SLASH_SCALE * s, colors(e))
			if node != null:
				node.rotation.y = yaw_of(tan)
				mode = PACK
				if s >= HEAVY and pk.has_room(&"impact"):
					var id := hit_id(kind, true)
					pk.spawn(id, p, IMPACT_SCALE * s * float(SCENE_K.get(id, 1.0)), colors(e))
		decide(layer, &"slash", sd, mode)
	return mode == PACK


## A volley's muzzle spark at `p` along `dir`, in colours `hot` and `col`. As `hit`.
static func muzzle(
	layer: VfxCore, p: Vector3, dir: Vector3, hot: Color, col: Color, u: float, sd: int
) -> bool:
	var pk := pack(layer)
	if pk == null:
		return false
	var mode := state(layer, &"muzzle", sd, u)
	if mode == NEW:
		mode = OLD
		if pk.has_room(&"hit"):
			var node := muzzle_at(pk, p, dir, hot, col)
			if node != null:
				mode = PACK
		decide(layer, &"muzzle", sd, mode)
	return mode == PACK


## One muzzle spark now (the volley's and the hand's): the element's short flash when `col` is an element's core, else
## the neutral one. The node, null when the family is full.
static func muzzle_at(pk: PackFx, p: Vector3, dir: Vector3, hot: Color, col: Color) -> Node3D:
	if pk == null or not pk.has_room(&"hit"):
		return null
	var e := element_for(col)
	var id: StringName = MUZZLE_IDS.get(e, MUZZLE_NEUTRAL)
	var deep := ElementLooks.deep(e) if e != &"" else col.darkened(0.35)
	var node := (
		pk
		. spawn(
			id,
			p,
			MUZZLE_SCALE,
			{&"primary": col, &"secondary": hot, &"tertiary": deep},
		)
	)
	if node != null and dir.length_squared() > 1e-6:
		node.rotation.y = yaw_of(dir)
	return node


## A heavy cast flash `size` m across at `p`. As `hit`; false below FLASH_MIN_M.
static func flash(
	layer: VfxCore, p: Vector3, hot: Color, col: Color, u: float, size: float, sd: int
) -> bool:
	var pk := pack(layer)
	if pk == null or size < FLASH_MIN_M:
		return false
	var mode := state(layer, &"flash", sd, u)
	if mode == NEW:
		mode = OLD
		if pk.has_room(&"impact"):
			var node := pk.spawn(
				FLASH_BIG,
				p,
				FLASH_PER_M * size,
				{&"primary": col, &"secondary": hot, &"tertiary": col.darkened(0.35)}
			)
			if node != null:
				mode = PACK
		decide(layer, &"flash", sd, mode)
	return mode == PACK


## A spark scene `id` at `p` tinted `c`, scaled `k`; false when the family is full (the caller draws its boxes).
static func spark(pk: PackFx, id: StringName, p: Vector3, k: float, c: Color) -> bool:
	if pk == null or not pk.has_room(&"hit"):
		return false
	return pk.spawn(id, p, k, tint(c)) != null

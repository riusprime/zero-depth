class_name CritterBodies
extends RefCounted
## v0.11.0 O9 (PLAN H1, M4; ENEMIES.md H1-H5; owner Q14: "same rules, its own body"): the five horde critters'
## code-made stand-in bodies (the owner's models come later: OWNER_TODO §3.2), built on a HordeAvatar and drawn through
## VAT on its general path (HordeVat: the body is the instance's transform, one gait loop poses the moving parts). Each
## is small, low and one shape at a glance, unlike the Swarmer's red beetle:
## - Dust Mite (Ruins): a fist-sized stone tick, a flat brown dome on six legs that scuttle in two sets of three;
## - Cave Bat (Night Rocks): a small dark body on two stone wings that flap, flying low (it ignores floor hazards);
## - Ember Flea (Red Canyon): a glowing orange body on two folded hind legs, hopping in short arcs;
## - Ice Crab (Frozen Shore): a flat, wide pale-blue shell with two claws that snap; it slides a little when it stops;
## - Star Mote (Starfall): a tiny floating star (a pale-gold octahedron) with a violet tail that sways.
## Their colours are their own (not EnemyPalettes' roles: a critter is the biome's, not a role), each with a hostile
## eye. The hop, the float and the slide move the whole body (exact in VAT: the instance's transform); the legs, wings,
## claws and tail are the gait loop's. Presentation only (EI-07): frame-time animation, nothing reaches the sim.

const KINDS: Array[int] = [
	WorldReader.KIND_DUST_MITE,
	WorldReader.KIND_CAVE_BAT,
	WorldReader.KIND_EMBER_FLEA,
	WorldReader.KIND_ICE_CRAB,
	WorldReader.KIND_STAR_MOTE,
]
## The body's top (m, for the health bar), flying or floating bodies included.
const HEIGHTS := {
	WorldReader.KIND_DUST_MITE: 0.24,
	WorldReader.KIND_CAVE_BAT: 0.78,
	WorldReader.KIND_EMBER_FLEA: 0.3,
	WorldReader.KIND_ICE_CRAB: 0.22,
	WorldReader.KIND_STAR_MOTE: 0.66,
}
## [body, trim, grey, eye] per kind (starting values).
const COLORS := {
	WorldReader.KIND_DUST_MITE: ["#8C7A66", "#5E5046", "#4A423C", "#FF5A3A"],
	WorldReader.KIND_CAVE_BAT: ["#4B4552", "#6E6478", "#38343E", "#FF3A4A"],
	WorldReader.KIND_EMBER_FLEA: ["#E0662A", "#7A2E14", "#4A2A20", "#FFC24A"],
	WorldReader.KIND_ICE_CRAB: ["#A6DAEE", "#5C8CA8", "#4E5E6A", "#FF4A5A"],
	WorldReader.KIND_STAR_MOTE: ["#FFE6A0", "#A898FF", "#5A5470", "#FFF4C8"],
}
## The gait loop's rate per kind (loops a second of frame time): the scuttle, the flap, the flea's kick, the claws'
## snap, the tail's sway.
const GAIT_HZ := {
	WorldReader.KIND_DUST_MITE: 6.0,
	WorldReader.KIND_CAVE_BAT: 7.0,
	WorldReader.KIND_EMBER_FLEA: 2.5,
	WorldReader.KIND_ICE_CRAB: 4.0,
	WorldReader.KIND_STAR_MOTE: 1.6,
}
## The gait loop's samples in the VAT bake (HordeVat.GRIDS).
const GAIT_SAMPLES := 24
## The bat's flight height and the mote's float (m above the ground), the flea's hop (m, its arcs a second).
const BAT_FLY_M := 0.5
const MOTE_FLOAT_M := 0.36
const HOP_M := 0.22
const HOP_HZ := 2.5
## The crab's slide when it stops: how far (m) and how long (s).
const SLIDE_M := 0.14
const SLIDE_SECONDS := 0.35


static func is_critter(kind: int) -> bool:
	return KINDS.has(kind)


static func color(kind: int, slot: StringName) -> Color:
	var row: Array = COLORS.get(kind, [])
	var k := EnemyPalettes.SLOTS.find(slot)
	return Color(String(row[k])) if k >= 0 and not row.is_empty() else ThemePalette.UNKNOWN


## The gait loop's phase (0..1) at frame time `t` for `kind`.
static func phase_at(kind: int, t: float) -> float:
	return fposmod(t * float(GAIT_HZ.get(kind, 1.0)), 1.0)


## Builds `a`'s pieces under its body (HordeAvatar.setup).
static func build(a: HordeAvatar) -> void:
	match a.kind:
		WorldReader.KIND_DUST_MITE:
			_build_mite(a)
		WorldReader.KIND_CAVE_BAT:
			_build_bat(a)
		WorldReader.KIND_EMBER_FLEA:
			_build_flea(a)
		WorldReader.KIND_ICE_CRAB:
			_build_crab(a)
		WorldReader.KIND_STAR_MOTE:
			_build_mote(a)


## The whole body's own move this frame (added to the avatar's place `bp` and lean `brz`; HordeAvatar._pose): the bat's
## flight, the flea's hop, the crab's slide (`slide`, 0..1 through it; < 0: none), the mote's float. `calm`: reduced
## motion (no bob, no hop, no sway).
static func body_move(kind: int, t: float, slide: float, calm: bool) -> Array:
	var bp := Vector3.ZERO
	var brz := 0.0
	match kind:
		WorldReader.KIND_CAVE_BAT:
			bp.y = BAT_FLY_M + (0.0 if calm else sin(t * 3.0) * 0.05)
		WorldReader.KIND_EMBER_FLEA:
			if not calm:
				var hop := absf(sin(t * PI * HOP_HZ))
				bp.y = hop * HOP_M
				brz = (hop - 0.5) * 0.3
		WorldReader.KIND_ICE_CRAB:
			if slide >= 0.0:
				bp.x = sin(clampf(slide, 0.0, 1.0) * PI) * SLIDE_M
		WorldReader.KIND_STAR_MOTE:
			bp.y = MOTE_FLOAT_M + (0.0 if calm else sin(t * 2.4) * 0.05)
			if not calm:
				brz = sin(t * 1.7) * 0.2
	return [bp, brz]


## Poses `a`'s moving parts at gait phase `phase` (0..1): the live pose and the VAT bake both pose through here.
static func pose_parts(a: HordeAvatar, phase: float) -> void:
	var s := sin(phase * TAU)
	var p := a.parts
	match a.kind:
		WorldReader.KIND_DUST_MITE:
			(p["legs_a"] as Node3D).rotation.y = s * 0.35
			(p["legs_b"] as Node3D).rotation.y = -s * 0.35
		WorldReader.KIND_CAVE_BAT:
			(p["wing_l"] as Node3D).rotation.x = -0.2 + s * 0.8
			(p["wing_r"] as Node3D).rotation.x = 0.2 - s * 0.8
		WorldReader.KIND_EMBER_FLEA:
			(p["legs"] as Node3D).rotation.z = 0.4 + s * 0.5
		WorldReader.KIND_ICE_CRAB:
			(p["claw_l"] as Node3D).rotation.y = 0.3 + s * 0.3
			(p["claw_r"] as Node3D).rotation.y = -0.3 - s * 0.3
		WorldReader.KIND_STAR_MOTE:
			(p["tail"] as Node3D).rotation.y = s * 0.45


## The joints (HordeVat.joint_spec) of `a` past its body: each on the gait grid.
static func joints(a: HordeAvatar) -> Array:
	var g := VatBake.GRID_GAIT
	var p := a.parts
	match a.kind:
		WorldReader.KIND_DUST_MITE:
			return [[p["legs_a"], g], [p["legs_b"], g]]
		WorldReader.KIND_CAVE_BAT:
			return [[p["wing_l"], g], [p["wing_r"], g]]
		WorldReader.KIND_EMBER_FLEA:
			return [[p["legs"], g]]
		WorldReader.KIND_ICE_CRAB:
			return [[p["claw_l"], g], [p["claw_r"], g]]
		WorldReader.KIND_STAR_MOTE:
			return [[p["tail"], g]]
	return []


static func _joint(a: HordeAvatar, pname: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pname.to_pascal_case()
	n.position = at
	a.body.add_child(n)
	a.parts[pname] = n
	return n


static func _box(size: Vector3, bevel: float) -> ArrayMesh:
	return NeedleAvatar._chamfer_box(size, bevel, 0.02)


static func _build_mite(a: HordeAvatar) -> void:
	var k := a.kind
	a._piece(
		a.body,
		ArcCasterAvatar._frustum(0.17, 0.08, 0.12, 7),
		Vector3(-0.02, 0.06, 0),
		color(k, &"body")
	)
	a._piece(
		a.body, _box(Vector3(0.1, 0.07, 0.12), 0.02), Vector3(0.15, 0.08, 0), color(k, &"trim")
	)
	a._glow(a.body, Vector3(0.012, 0.025, 0.08), Vector3(0.2, 0.09, 0))
	var leg := _box(Vector3(0.025, 0.025, 0.16), 0.006)
	for leg_set: int in 2:
		var group := _joint(a, "legs_a" if leg_set == 0 else "legs_b", Vector3(0, 0.05, 0))
		for n in 3:
			var x := 0.09 - 0.09 * n
			var side := 1.0 if (n + leg_set) % 2 == 0 else -1.0
			a._piece(group, leg, Vector3(x, 0, 0.14 * side), color(k, &"grey"))


static func _build_bat(a: HordeAvatar) -> void:
	var k := a.kind
	a._piece(a.body, _box(Vector3(0.18, 0.12, 0.12), 0.03), Vector3(0, 0.06, 0), color(k, &"body"))
	a._piece(
		a.body, _box(Vector3(0.08, 0.08, 0.1), 0.02), Vector3(0.11, 0.09, 0), color(k, &"trim")
	)
	for side in [-1.0, 1.0]:  # the ears
		a._piece(
			a.body,
			_box(Vector3(0.03, 0.06, 0.02), 0.006),
			Vector3(0.11, 0.15, 0.03 * side),
			color(k, &"trim")
		)
	a._glow(a.body, Vector3(0.012, 0.02, 0.07), Vector3(0.155, 0.1, 0))
	var wing := _box(Vector3(0.16, 0.015, 0.24), 0.005)
	for side in [-1.0, 1.0]:
		var hinge := _joint(a, "wing_l" if side < 0.0 else "wing_r", Vector3(0, 0.08, 0.06 * side))
		a._piece(hinge, wing, Vector3(-0.02, 0, 0.12 * side), color(k, &"grey"))


static func _build_flea(a: HordeAvatar) -> void:
	var k := a.kind
	a._piece(a.body, ArcCasterAvatar._octahedron(0.1), Vector3(0, 0.12, 0), color(k, &"body"))
	a._glow(a.body, Vector3(0.1, 0.05, 0.1), Vector3(-0.02, 0.17, 0))  # its ember back
	a._piece(
		a.body, _box(Vector3(0.06, 0.05, 0.07), 0.015), Vector3(0.1, 0.11, 0), color(k, &"trim")
	)
	var legs := _joint(a, "legs", Vector3(-0.04, 0.09, 0))
	for side in [-1.0, 1.0]:
		a._piece(
			legs,
			_box(Vector3(0.16, 0.025, 0.025), 0.006),
			Vector3(-0.06, -0.03, 0.07 * side),
			color(k, &"grey")
		)


static func _build_crab(a: HordeAvatar) -> void:
	var k := a.kind
	a._piece(a.body, _box(Vector3(0.26, 0.08, 0.34), 0.03), Vector3(0, 0.07, 0), color(k, &"body"))
	a._piece(
		a.body, _box(Vector3(0.16, 0.04, 0.22), 0.015), Vector3(-0.01, 0.12, 0), color(k, &"trim")
	)
	a._glow(a.body, Vector3(0.012, 0.02, 0.1), Vector3(0.135, 0.1, 0))
	for side in [-1.0, 1.0]:
		a._piece(
			a.body,
			_box(Vector3(0.2, 0.02, 0.06), 0.005),
			Vector3(-0.02, 0.03, 0.2 * side),
			color(k, &"grey")
		)
		var claw := _joint(
			a, "claw_l" if side < 0.0 else "claw_r", Vector3(0.12, 0.07, 0.12 * side)
		)
		a._piece(
			claw,
			_box(Vector3(0.12, 0.05, 0.05), 0.012),
			Vector3(0.07, 0, 0.02 * side),
			color(k, &"trim")
		)


static func _build_mote(a: HordeAvatar) -> void:
	var k := a.kind
	a._piece(a.body, ArcCasterAvatar._octahedron(0.12), Vector3(0, 0.14, 0), color(k, &"body"))
	a._glow(a.body, Vector3(0.05, 0.05, 0.05), Vector3(0.0, 0.14, 0))  # its heart
	for spike: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0)]:
		a._piece(
			a.body,
			_box(Vector3(0.04, 0.04, 0.04), 0.01),
			Vector3(0, 0.14, 0) + spike * 0.13,
			color(k, &"body")
		)
	a._glow(a.body, Vector3(0.012, 0.02, 0.05), Vector3(0.17, 0.15, 0))  # its eye
	var tail := _joint(a, "tail", Vector3(-0.1, 0.14, 0))
	a._piece(tail, _box(Vector3(0.22, 0.03, 0.05), 0.01), Vector3(-0.11, 0, 0), color(k, &"trim"))

class_name CanyonShoreBodies
extends RefCounted
## ENEMIES.md R5-R8; OWNER_TODO §3.2's prompts for these ids: the code-made stand-in bodies of the Red
## Canyon's and the Frozen Shore's signature enemies until the owner's models come, built on a HordeAvatar (the horde
## kinds' way: its pieces, outline, flash, flinch, eye and glow) in the Charger family's style: a faceted shell in the
## role colour, a dark shield-shaped face with one glowing gem visor, a charcoal body, grey segmented limbs with bone
## tips. Each one shape at a glance, and its tell drawn on the body:
## (the Cinder Priest is the owner's model now, CinderPriestAvatar; O17e: the Kiln Beetle,
## KilnBeetleAvatar.)
## - Frost Spitter (ranged blue): a lean four-legged body with a pale ice sac on its throat that swells through the
##   windup.
## - Glacier Turtle (tank bronze): a squat charcoal body on four thick legs under a small bronze cap, a big domed shell
##   of pale ice slabs held in front while it stands (WorldReader.shell_on).
## Their colours are their own (the prompts' role colours; not EnemyPalettes' table, which holds the 14 older kinds).
## Presentation only (EI-07): frame-time animation, nothing reaches the sim.

const KINDS: Array[int] = [
	WorldReader.KIND_FROST_SPITTER,
	WorldReader.KIND_GLACIER_TURTLE,
]
## The body's top (m, for the health bar).
const HEIGHTS := {
	WorldReader.KIND_FROST_SPITTER: 0.85,
	WorldReader.KIND_GLACIER_TURTLE: 1.0,
}
## [body, trim, grey, eye] per kind (starting values: the prompts' role colours, the family's charcoal and greys).
const COLORS := {
	WorldReader.KIND_FROST_SPITTER: ["#3A6BD4", "#262A32", "#56606A", "#8FE6FF"],
	WorldReader.KIND_GLACIER_TURTLE: ["#9A6232", "#2A2828", "#5C5A58", "#FFB04A"],
}
const TURTLE_BODY_SCALE := 1.25
const BONE := Color("#D9CDB8")
const ICE := Color("#A6DAEE")
const SHELL_ICE := Color("#A9D6EE") * 1.9
const SHELL_TOP := Color("#DDF2FF") * 2.0
const SHELL_RIM := Color("#5C8FB0") * 1.2
const SAC := Color("#CFEFFF")


static func is_kind(kind: int) -> bool:
	return KINDS.has(kind)


static func color(kind: int, slot: StringName) -> Color:
	var row: Array = COLORS.get(kind, [])
	var k := EnemyPalettes.SLOTS.find(slot)
	return Color(String(row[k])) if k >= 0 and not row.is_empty() else ThemePalette.UNKNOWN


## Builds `a`'s pieces under its body (HordeAvatar.setup).
static func build(a: HordeAvatar) -> void:
	match a.kind:
		WorldReader.KIND_FROST_SPITTER:
			_build_spitter(a)
		WorldReader.KIND_GLACIER_TURTLE:
			_build_turtle(a)


## Reads actor i's tell drive for `a` (HordeAvatar.sync): the turtle's shell standing.
static func read(a: HordeAvatar, reader: WorldReader, i: int) -> void:
	match a.kind:
		WorldReader.KIND_GLACIER_TURTLE:
			a.sig_on = reader.shell_on(i)


## Poses `a`'s moving parts from its drives (HordeAvatar._pose); returns the glow energy to set (`energy`: the
## windup's).
static func pose(a: HordeAvatar, energy: float, _calm: bool) -> float:
	var p := a.parts
	match a.kind:
		WorldReader.KIND_FROST_SPITTER:
			(p["sac"] as Node3D).scale = Vector3.ONE * (1.0 + a.windup_pose() * 0.6)
		WorldReader.KIND_GLACIER_TURTLE:
			(p["shell"] as Node3D).visible = a.sig_on
	return energy


static func _box(size: Vector3, bevel: float) -> ArrayMesh:
	return NeedleAvatar._chamfer_box(size, bevel, 0.02)


static func _joint(a: HordeAvatar, pname: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pname.to_pascal_case()
	n.position = at
	a.body.add_child(n)
	a.parts[pname] = n
	return n


## The family's face: a dark shield-shaped plate at `at` (its front at +X) with one glowing gem visor.
static func _face(a: HordeAvatar, at: Vector3, s: float) -> void:
	a._piece(
		a.body,
		ArcCasterAvatar._frustum(0.12 * s, 0.07 * s, 0.05 * s, 5),
		at,
		color(a.kind, &"trim")
	)
	a._glow(a.body, Vector3(0.03, 0.04, 0.09) * s, at + Vector3(0.04 * s, 0.03 * s, 0))


## A grey segmented leg with a bone tip, from `at` out to `side` (+1 / -1 on Z), `long` m long.
static func _leg(
	a: HordeAvatar,
	at: Vector3,
	side: float,
	long: float,
	thick: float,
	leg_color: Color = Color(0, 0, 0, 0)
) -> void:
	var grey := color(a.kind, &"grey") if leg_color.a == 0.0 else leg_color
	a._piece(
		a.body,
		_box(Vector3(thick, thick, long * 0.6), thick * 0.3),
		at + Vector3(0, 0, long * 0.3 * side),
		grey
	)
	a._piece(
		a.body,
		_box(Vector3(thick * 0.9, long * 0.5, thick * 0.9), thick * 0.3),
		at + Vector3(0, -long * 0.22, long * 0.62 * side),
		grey
	)
	a._piece(
		a.body,
		_box(Vector3(thick * 0.8, thick * 0.6, thick * 0.8), thick * 0.2),
		at + Vector3(0, -long * 0.48, long * 0.66 * side),
		BONE
	)


static func _build_spitter(a: HordeAvatar) -> void:
	var k := a.kind
	a._piece(
		a.body, _box(Vector3(0.56, 0.22, 0.4), 0.05), Vector3(-0.04, 0.46, 0), color(k, &"trim")
	)
	a._piece(
		a.body, _box(Vector3(0.6, 0.18, 0.44), 0.07), Vector3(-0.06, 0.6, 0), color(k, &"body")
	)
	a._piece(a.body, _box(Vector3(0.2, 0.06, 0.3), 0.02), Vector3(-0.1, 0.71, 0), color(k, &"body"))
	_face(a, Vector3(0.28, 0.52, 0), 1.1)
	var sac := _joint(a, "sac", Vector3(0.22, 0.36, 0))
	a._piece(sac, ArcCasterAvatar._octahedron(0.13), Vector3.ZERO, SAC)
	for n in 2:
		for side in [-1.0, 1.0]:
			_leg(a, Vector3(0.12 - n * 0.28, 0.44, 0.18 * side), side, 0.46, 0.06)


static func _build_turtle(a: HordeAvatar) -> void:
	var k := a.kind
	a._piece(
		a.body, _box(Vector3(0.86, 0.34, 0.8), 0.08), Vector3(-0.06, 0.34, 0), color(k, &"trim")
	)
	a._piece(
		a.body,
		ArcCasterAvatar._frustum(0.32, 0.14, 0.2, 6),
		Vector3(-0.12, 0.5, 0),
		color(k, &"body")
	)
	a._piece(
		a.body, _box(Vector3(0.22, 0.16, 0.2), 0.04), Vector3(0.63, 0.48, 0), color(k, &"body")
	)
	a._piece(
		a.body, _box(Vector3(0.34, 0.14, 0.16), 0.04), Vector3(0.45, 0.47, 0), color(k, &"body")
	)  # the neck
	_face(a, Vector3(0.71, 0.48, 0), 1.2)
	a._glow(a.body, Vector3(0.06, 0.1, 0.24), Vector3(0.77, 0.52, 0))  # a stronger visor glow
	a._glow(a.body, Vector3(0.14, 0.05, 0.16), Vector3(0.69, 0.6, 0))
	for n in 2:
		for side in [-1.0, 1.0]:
			_leg(a, Vector3(0.2 - n * 0.44, 0.24, 0.32 * side), side, 0.3, 0.12, color(k, &"body"))
	var shell := _joint(a, "shell", Vector3(0.6, 0.0, 0))
	# Presentation only: the body reads 1.25x bigger; the shell is counter-scaled so it stays as it was.
	a.body.scale = Vector3.ONE * TURTLE_BODY_SCALE
	shell.scale = Vector3.ONE / TURTLE_BODY_SCALE
	shell.position = Vector3(0.6, 0.0, 0) / TURTLE_BODY_SCALE
	for n in 3:  # the domed shell of ice slabs held in front
		var z := (n - 1) * 0.36
		a._piece(
			shell,
			_box(Vector3(0.14, 0.86 - absf(z) * 0.5, 0.36), 0.05),
			Vector3(0.04 - absf(z) * 0.18, 0.45, z),
			SHELL_ICE
		)
	a._piece(shell, _box(Vector3(0.1, 0.2, 0.9), 0.04), Vector3(0.08, 0.88, 0), SHELL_TOP)
	a._piece(shell, _box(Vector3(0.16, 0.08, 1.0), 0.03), Vector3(0.05, 0.04, 0), SHELL_RIM)  # the dark rim along the foot

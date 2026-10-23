class_name HubStations
extends RefCounted
## v0.9.0 HB: the stations' code stand-ins on the Rune Ring (HUB_MOCKUPS option A; the owner's models replace them:
## docs/art/requests/v0.9.0_ART_LIST.md §4). Each builder draws into `root` (a node at the station's centre on the
## plan frame: +x east, -z north, its front toward +z, the screen's bottom) at its footprint's size, and returns its
## parts: {"glow": the layered glow that brightens when the hero stands at it, ...the hooks}. Presentation only.


## The Rune Archive (opens the Codex): a tall stone shelf of three tiers with blue rune plaques, a reading lamp, and
## the collectibles' shelf slots (CL: `slots`, 16 dark niches across the tiers; show_collected lights them).
static func archive(root: Node3D, half: Vector2, h: float) -> Dictionary:
	var stone := HubProps.stone(HubProps.STONE)
	var dark := HubProps.stone(HubProps.STONE_DARK)
	var w := half.x * 2.0
	var d := half.y * 2.0
	HubProps.box(root, "Back", Vector3(w, h, d * 0.45), stone, Vector3(0, h * 0.5, -d * 0.27))
	HubProps.box(root, "Plinth", Vector3(w + 0.2, 0.3, d), dark, Vector3(0, 0.15, 0))
	var slots: Array[MeshInstance3D] = []
	var tiers := 3
	for t in tiers:
		var y := 0.55 + t * (h - 0.8) / tiers
		HubProps.box(
			root,
			"Shelf%d" % t,
			Vector3(w - 0.1, 0.08, d * 0.5),
			HubProps.stone(HubProps.STONE_LIT),
			Vector3(0, y, -0.05)
		)
		var per := 6 if t < 2 else 4
		for k in per:
			if slots.size() >= 16:
				break
			var x := (k - (per - 1) * 0.5) * (w - 0.5) / per
			var niche := HubProps.box(
				root,
				"Slot%d" % slots.size(),
				Vector3(0.22, 0.26, 0.04),
				dark,
				Vector3(x, y + 0.2, 0.06)
			)
			slots.append(niche)
	# Rune plaques on the shelf's crown.
	for k in 3:
		HubProps.box(
			root,
			"Plaque%d" % k,
			Vector3(0.34, 0.34, 0.03),
			HubProps.emissive(HubProps.BLUE, 2.0),
			Vector3((k - 1) * 0.9, h - 0.25, 0.0)
		)
	var g := HubProps.glow(
		root, "Glow", HubProps.BLUE, HubProps.BLUE_CORE, Vector3(0, h - 0.25, 0.4), 2.2
	)
	return {"glow": g, "slots": slots}


## The Trophy Area (opens the achievements): a back wall with a carved alcove, a brazier lit once a boss has fallen
## (trophy_lit), a golden crown sigil once the final boss fell (trophy_crown), and one plinth per floor boss before it
## (its plaque gold once that boss fell, dark until then).
static func trophy(root: Node3D, half: Vector2, h: float, bosses: Array[bool]) -> Dictionary:
	var stone := HubProps.stone(HubProps.STONE)
	var dark := HubProps.stone(HubProps.STONE_DARK)
	var w := half.x * 2.0
	var d := half.y * 2.0
	HubProps.box(root, "Wall", Vector3(w, h, d * 0.4), stone, Vector3(0, h * 0.5, -d * 0.3))
	HubProps.box(
		root, "Alcove", Vector3(w * 0.45, h * 0.6, 0.06), dark, Vector3(0, h * 0.42, -d * 0.09)
	)
	HubProps.box(root, "Step", Vector3(w + 0.2, 0.25, d), dark, Vector3(0, 0.125, 0))
	var plaques: Array[MeshInstance3D] = []
	var n := bosses.size()
	for i in n:
		var x := (i - (n - 1) * 0.5) * minf(0.62, (w - 0.3) / maxf(1.0, n))
		var lit: bool = bosses[i]
		HubProps.box(
			root,
			"Plinth%d" % i,
			Vector3(0.36, 0.55, 0.36),
			stone,
			Vector3(x, 0.25 + 0.275, d * 0.3)
		)
		var plaque := HubProps.box(
			root,
			"Plaque%d" % i,
			Vector3(0.24, 0.24, 0.04),
			HubProps.emissive(HubProps.GOLD, 2.4) if lit else dark,
			Vector3(x, 0.55 + 0.25, d * 0.3 + 0.2)
		)
		plaque.set_meta(&"lit", lit)
		plaques.append(plaque)
	var brazier := HubProps.kit_piece(
		root,
		"Brazier",
		&"brazier_pole",
		Vector3(0.6, 1.6, 0.6),
		Vector3(w * 0.5 - 0.2, 0.25, -0.1),
		0.0,
		HubProps.STONE_DARK
	)
	var fire := HubProps.glow(
		root, "Fire", HubProps.FIRE, HubProps.GOLD_CORE, Vector3(w * 0.5 - 0.2, 2.0, -0.1), 1.6
	)
	var crown := Node3D.new()
	crown.name = "Crown"
	crown.position = Vector3(0, h + 0.55, -d * 0.2)
	root.add_child(crown)
	var t := TorusMesh.new()
	t.inner_radius = 0.28
	t.outer_radius = 0.36
	t.rings = 24
	t.ring_segments = 6
	HubProps.mesh(crown, "Band", t, HubProps.emissive(HubProps.GOLD, 3.0), Vector3.ZERO)
	for k in 5:
		var a := TAU * k / 5.0
		HubProps.box(
			crown,
			"Point%d" % k,
			Vector3(0.06, 0.2, 0.06),
			HubProps.emissive(HubProps.GOLD, 3.0),
			Vector3(cos(a) * 0.32, 0.12, sin(a) * 0.32)
		)
	var crown_glow := HubProps.glow(
		crown, "Glow", HubProps.GOLD, HubProps.GOLD_CORE, Vector3.ZERO, 1.4
	)
	var g := HubProps.glow(
		root, "Glow", HubProps.GOLD, HubProps.GOLD_CORE, Vector3(0, h * 0.45, 0.2), 2.0
	)
	return {
		"glow": g,
		"plaques": plaques,
		"brazier": brazier,
		"fire": fire,
		"crown": crown,
		"crown_glow": crown_glow
	}


## The Wardrobe (a stand-in until RB's robes): a robe stand with the hero's cream cloak on it, a mirror stone behind,
## and a rune circle under it (RB: the affinity's colour; `robe` is the cloak to recolour).
static func wardrobe(root: Node3D, half: Vector2, h: float) -> Dictionary:
	var stone := HubProps.stone(HubProps.STONE)
	var dark := HubProps.stone(HubProps.STONE_DARK)
	HubProps.box(
		root,
		"Mirror",
		Vector3(half.x * 0.5, h, half.y * 1.8),
		stone,
		Vector3(-half.x * 0.55, h * 0.5, 0)
	)
	HubProps.box(
		root,
		"Glass",
		Vector3(0.03, h * 0.65, half.y * 1.2),
		HubProps.emissive(HubProps.BLUE.darkened(0.4), 0.8),
		Vector3(-half.x * 0.28, h * 0.55, 0)
	)
	HubProps.cylinder(root, "Base", 0.4, 0.5, 0.15, dark, Vector3(half.x * 0.25, 0.075, 0))
	HubProps.cylinder(
		root, "Pole", 0.05, 0.05, h * 0.75, dark, Vector3(half.x * 0.25, h * 0.375 + 0.1, 0), 6
	)
	HubProps.box(root, "Bar", Vector3(0.08, 0.06, 0.9), dark, Vector3(half.x * 0.25, h * 0.78, 0))
	var robe := HubProps.cylinder(
		root,
		"Robe",
		0.12,
		0.42,
		h * 0.6,
		HubProps.stone(HubProps.CREAM, 0.85),
		Vector3(half.x * 0.25, h * 0.45, 0),
		4
	)
	robe.rotation.y = PI * 0.25  # the poncho's diamond
	var g := HubProps.glow(
		root, "Glow", HubProps.BLUE, HubProps.BLUE_CORE, Vector3(half.x * 0.25, 0.4, 0), 1.8
	)
	return {"glow": g, "robe": robe}


## The Progression Station (a stand-in until MP's Rune Fragments): a rune console, a slanted stone desk with a floating
## crystal over it in two rings of light.
static func progression(root: Node3D, half: Vector2, h: float) -> Dictionary:
	var stone := HubProps.stone(HubProps.STONE)
	var dark := HubProps.stone(HubProps.STONE_DARK)
	HubProps.box(
		root, "Desk", Vector3(half.x * 1.6, h * 0.55, half.y * 1.6), stone, Vector3(0, h * 0.275, 0)
	)
	var top := HubProps.box(
		root, "Top", Vector3(half.x * 1.7, 0.1, half.y * 1.2), dark, Vector3(0, h * 0.58, 0)
	)
	top.rotation.y = 0.0
	top.rotation.x = 0.25
	var crystal_mesh := PrismMesh.new()
	crystal_mesh.size = Vector3(0.36, 0.6, 0.36)
	var crystal := HubProps.mesh(
		root,
		"Crystal",
		crystal_mesh,
		HubProps.emissive(HubProps.VIOLET, 3.0),
		Vector3(0, h + 0.35, 0)
	)
	var low := PrismMesh.new()
	low.size = Vector3(0.36, 0.3, 0.36)
	var under := HubProps.mesh(
		root, "CrystalLow", low, HubProps.emissive(HubProps.VIOLET, 3.0), Vector3(0, h + 0.0, 0)
	)
	under.rotation.x = PI
	for k in 2:
		var t := TorusMesh.new()
		t.inner_radius = 0.42 + k * 0.18
		t.outer_radius = 0.46 + k * 0.18
		t.rings = 32
		t.ring_segments = 4
		var ring := HubProps.mesh(
			root, "Ring%d" % k, t, HubProps.emissive(HubProps.BLUE, 2.2), Vector3(0, h + 0.2, 0)
		)
		ring.rotation = Vector3(0.5 + k * 0.6, 0, 0.3 - k * 0.5)
	var g := HubProps.glow(
		root, "Glow", HubProps.VIOLET, HubProps.VIOLET_CORE, Vector3(0, h + 0.2, 0.2), 1.8
	)
	return {"glow": g, "crystal": crystal}


## The Credits stone: a low engraved slab, its carved lines faintly lit.
static func credits(root: Node3D, half: Vector2, h: float) -> Dictionary:
	var stone := HubProps.stone(HubProps.STONE)
	HubProps.box(
		root, "Slab", Vector3(half.x * 2.0, h, half.y * 2.0), stone, Vector3(0, h * 0.5, 0)
	)
	for k in 3:
		HubProps.box(
			root,
			"Line%d" % k,
			Vector3(half.x * (1.4 - k * 0.3), 0.02, 0.05),
			HubProps.emissive(HubProps.GOLD.darkened(0.2), 1.4),
			Vector3(0, h + 0.005, -0.25 + k * 0.25)
		)
	var g := HubProps.glow(
		root, "Glow", HubProps.GOLD, HubProps.GOLD_CORE, Vector3(0, h + 0.3, 0.0), 1.4
	)
	return {"glow": g}

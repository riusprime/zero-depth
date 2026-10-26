class_name HubStations
extends RefCounted
## v0.9.0 HB: the stations on the Rune Ring (HUB_MOCKUPS option A). Each draws the owner's model where it is installed
## (docs/art/requests/v0.9.0_ART_LIST.md §4: hub_archive, hub_trophy_pedestal, hub_wardrobe, hub_station,
## hub_collectible_pedestal; ShopModels) and its code stand-in otherwise (L15), with the code's layered glows and hooks
## on top either way. Each builder draws into `root` (a node at the station's centre on the plan frame: +x east, -z
## north, its front toward +z, the screen's bottom) at its footprint's size, and returns its parts: {"glow": the
## layered glow that brightens when the hero stands at it, "model": the owner's mesh or null, ...the hooks}.
## Presentation only.

## The Rune Archive's shelf slots for the collectibles (CL).
const SLOTS := 16
## v0.9.0 HB3: the owner's trophy wall's depth (m; hb3_prep.py: 3.8 m wide, 2.04 m deep with its shelf).
const TROPHY_WALL_D := 2.04
## v0.9.0 HB3: the stations' low plinths (the Archive's ledge, the Trophy Area's step) in the owner's paving, a
## little darker than the plaza (they were flat dark boxes).
const LEDGE := Color(0.62, 0.6, 0.57)
## v0.9.5 RS1: the Runic Stone's veins (RUNIC_STONE.md S3).
const RUNE_VIOLET := Color("#9B6BFF")


## The Rune Archive (opens the Codex): the owner's bookcase niche (or a stone shelf of three tiers), blue rune plaques,
## three collectible pedestals before it (W45: the found artifacts stand there; CL), and the collectibles' slots
## (CL: `slots`, 16 dark stones along its ledge; HubView.show_collected lights them).
static func archive(root: Node3D, half: Vector2, h: float) -> Dictionary:
	var stone := HubProps.stone(HubProps.STONE)
	var dark := HubProps.stone(HubProps.STONE_DARK)
	var w := half.x * 2.0
	var d := half.y * 2.0
	var body := HubProps.stand_in(root)
	HubProps.box(body, "Back", Vector3(w, h, d * 0.45), stone, Vector3(0, h * 0.5, -d * 0.27))
	for t in 3:
		var y := 0.55 + t * (h - 0.8) / 3.0
		HubProps.box(
			body,
			"Shelf%d" % t,
			Vector3(w - 0.1, 0.08, d * 0.5),
			HubProps.stone(HubProps.STONE_LIT),
			Vector3(0, y, -0.05)
		)
	var model := HubProps.owner_model(root, &"hub_archive", Vector3(0, 0, -d * 0.18), body)
	HubProps.box(
		root,
		"Ledge",
		Vector3(w + 0.2, 0.3, d * 0.35),
		HubDressing.paving(LEDGE),
		Vector3(0, 0.15, d * 0.3)
	)
	var slots: Array[MeshInstance3D] = []
	for k in SLOTS:
		var x := (k - (SLOTS - 1) * 0.5) * (w - 0.2) / SLOTS
		slots.append(
			HubProps.box(
				root, "Slot%d" % k, Vector3(0.14, 0.1, 0.14), dark, Vector3(x, 0.35, d * 0.42)
			)
		)
	for k in 3:
		var at := Vector3((k - 1) * w * 0.36, 0.3, d * 0.3)
		if HubProps.owner_model(root, &"hub_collectible_pedestal", at) == null:
			HubProps.cylinder(
				root, "Pedestal%d" % k, 0.18, 0.22, 0.7, stone, at + Vector3(0, 0.35, 0)
			)
	for k in 3:
		HubProps.box(  # on the stand-in shelf's crown
			body,
			"Plaque%d" % k,
			Vector3(0.34, 0.34, 0.03),
			HubProps.emissive(HubProps.BLUE, 2.0),
			Vector3((k - 1) * 0.9, h - 0.25, d * 0.05)
		)
	var g := HubProps.glow(
		root, "Glow", HubProps.BLUE, HubProps.BLUE_CORE, Vector3(0, h - 0.25, 0.4), 2.2
	)
	return {"glow": g, "slots": slots, "model": model}


## The Trophy Area (opens the achievements): a back wall with a carved alcove, a brazier lit once a boss has fallen
## (trophy_lit), a golden crown sigil once the final boss fell (trophy_crown), and one pedestal per floor boss before
## it (the owner's hub_trophy_pedestal; its plaque gold once that boss fell, dark until then).
static func trophy(root: Node3D, half: Vector2, h: float, bosses: Array[bool]) -> Dictionary:
	var stone := HubProps.stone(HubProps.STONE)
	var dark := HubProps.stone(HubProps.STONE_DARK)
	var w := half.x * 2.0
	var d := half.y * 2.0
	# v0.9.0 HB3: the owner's carved trophy wall (hub_trophy_wall) behind the pedestals, or a code wall and alcove.
	var back := HubProps.stand_in(root)
	HubProps.box(back, "Wall", Vector3(w, h, d * 0.4), stone, Vector3(0, h * 0.5, -d * 0.3))
	HubProps.box(
		back, "Alcove", Vector3(w * 0.45, h * 0.6, 0.06), dark, Vector3(0, h * 0.42, -d * 0.09)
	)
	var wall_z := -d * 0.5 + TROPHY_WALL_D * 0.5 - 0.15
	var wall := HubProps.owner_model(root, &"hub_trophy_wall", Vector3(0, 0, wall_z), back)
	if wall != null:
		h = maxf(h, (ShopModels.get_model(&"hub_trophy_wall")["aabb"] as AABB).size.y)
	HubProps.box(
		root, "Step", Vector3(w + 0.2, 0.25, d), HubDressing.paving(LEDGE), Vector3(0, 0.125, 0)
	)
	var plaques: Array[MeshInstance3D] = []
	var n := bosses.size()
	var step := minf(0.7, (w - 0.2) / maxf(1.0, n))
	for i in n:
		var x := (i - (n - 1) * 0.5) * step
		var lit: bool = bosses[i]
		var top := 0.25 + 0.55
		var model := HubProps.owner_model(root, &"hub_trophy_pedestal", Vector3(x, 0.25, d * 0.28))
		if model != null:
			top = 0.25 + (ShopModels.get_model(&"hub_trophy_pedestal")["aabb"] as AABB).size.y
		else:
			HubProps.box(
				root, "Plinth%d" % i, Vector3(0.36, 0.55, 0.36), stone, Vector3(x, 0.525, d * 0.28)
			)
		var plaque := HubProps.box(
			root,
			"Plaque%d" % i,
			Vector3(0.22, 0.22, 0.05),
			HubProps.emissive(HubProps.GOLD, 2.4) if lit else dark,
			Vector3(x, top + 0.12, d * 0.28)
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


## The Wardrobe (until RB's robes): the owner's wardrobe stand (or a robe stand with the hero's cream cloak and a mirror
## stone), a blue rune circle under it. `robe` (RB's hook) is the stand-in's cloak; with the owner's model the robe is
## part of his mesh (null: RB needs it as its own part to recolour).
static func wardrobe(root: Node3D, half: Vector2, h: float) -> Dictionary:
	var stone := HubProps.stone(HubProps.STONE)
	var dark := HubProps.stone(HubProps.STONE_DARK)
	var body := HubProps.stand_in(root)
	HubProps.box(
		body,
		"Mirror",
		Vector3(half.x * 0.5, h, half.y * 1.8),
		stone,
		Vector3(-half.x * 0.55, h * 0.5, 0)
	)
	HubProps.box(
		body,
		"Glass",
		Vector3(0.03, h * 0.65, half.y * 1.2),
		HubProps.emissive(HubProps.BLUE.darkened(0.4), 0.8),
		Vector3(-half.x * 0.28, h * 0.55, 0)
	)
	HubProps.cylinder(body, "Base", 0.4, 0.5, 0.15, dark, Vector3(half.x * 0.25, 0.075, 0))
	HubProps.cylinder(
		body, "Pole", 0.05, 0.05, h * 0.75, dark, Vector3(half.x * 0.25, h * 0.375 + 0.1, 0), 6
	)
	HubProps.box(body, "Bar", Vector3(0.08, 0.06, 0.9), dark, Vector3(half.x * 0.25, h * 0.78, 0))
	var robe := HubProps.cylinder(
		body,
		"Robe",
		0.12,
		0.42,
		h * 0.6,
		HubProps.stone(HubProps.CREAM, 0.85),
		Vector3(half.x * 0.25, h * 0.45, 0),
		4
	)
	robe.rotation.y = PI * 0.25  # the poncho's diamond
	var model := HubProps.owner_model(root, &"hub_wardrobe", Vector3.ZERO, body)
	var g := HubProps.glow(
		root, "Glow", HubProps.BLUE, HubProps.BLUE_CORE, Vector3(0, 0.4, half.y * 0.6), 1.8
	)
	return {"glow": g, "robe": robe if model == null else null, "model": model}


## The Progression Station (until MP's Rune Fragments): the owner's rune forge workbench (or a slanted stone desk), a
## floating violet crystal over it in two rings of light.
static func progression(root: Node3D, half: Vector2, h: float) -> Dictionary:
	var stone := HubProps.stone(HubProps.STONE)
	var dark := HubProps.stone(HubProps.STONE_DARK)
	var body := HubProps.stand_in(root)
	HubProps.box(
		body, "Desk", Vector3(half.x * 1.6, h * 0.55, half.y * 1.6), stone, Vector3(0, h * 0.275, 0)
	)
	var top := HubProps.box(
		body, "Top", Vector3(half.x * 1.7, 0.1, half.y * 1.2), dark, Vector3(0, h * 0.58, 0)
	)
	top.rotation.x = 0.25
	var model := HubProps.owner_model(root, &"hub_station", Vector3.ZERO, body)
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
		root, "CrystalLow", low, HubProps.emissive(HubProps.VIOLET, 3.0), Vector3(0, h, 0)
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
	return {"glow": g, "crystal": crystal, "model": model}


## The Runic Stone (v0.9.5 RS1, RUNIC_STONE.md S2, S3; was the Credits stone): the owner's tablet on its plinth
## (hub_credits_stone), or a low slab. Locked it is dark and cold, with no glow. The model is one surface, so its veins
## are a thin violet ring at its base (`ring`) plus a small violet light, both off until the stone wakes
## (HubView.set_runic). No halo: `glow` is empty.
static func runic(root: Node3D, half: Vector2, h: float) -> Dictionary:
	var stone := HubProps.stone(HubProps.STONE_DARK)
	var body := HubProps.stand_in(root)
	HubProps.box(
		body, "Slab", Vector3(half.x * 2.0, h, half.y * 2.0), stone, Vector3(0, h * 0.5, 0)
	)
	var model := HubProps.owner_model(root, &"hub_credits_stone", Vector3.ZERO, body)
	if model != null:
		var cold: Material = model.material_override
		if cold is BaseMaterial3D:
			cold = cold.duplicate()
			(cold as BaseMaterial3D).albedo_color = Color(0.52, 0.56, 0.68)  # dark, cold stone
			model.material_override = cold
	var torus := TorusMesh.new()
	var r := maxf(half.x, half.y) + 0.12
	torus.inner_radius = r
	torus.outer_radius = r + 0.05
	var ring := HubProps.mesh(
		root, "Veins", torus, HubProps.emissive(RUNE_VIOLET, 0.0), Vector3(0, 0.06, 0)
	)
	ring.visible = false
	var light := OmniLight3D.new()
	light.name = "VeinLight"
	light.light_color = RUNE_VIOLET
	light.light_energy = 0.0
	light.omni_range = 4.0
	light.position = Vector3(0, h * 0.6, 0)
	root.add_child(light)
	return {"glow": {}, "model": model, "ring": ring, "light": light, "height": h}

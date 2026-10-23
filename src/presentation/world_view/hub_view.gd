class_name HubView
extends Node3D
## v0.9.0 HB (owner Q27; HUB_MOCKUPS option A, the Rune Ring): the hub drawn from its plan (HubLayout) and the hero
## walking it, read from the hub's World through WorldReader once per tick (EI-07). One round plaza in one iso view:
## the Portal Machine in the centre (HubMachine), the 16 floor runes ringing it (lit per collectible: set_runes, CL),
## the stations on the rim (HubStations: the Rune Archive, the Trophy Area, the Wardrobe, the Progression Station, the
## Credits stone), the sealed north gate and the alcove past it (set_gate), braziers and a low rim wall of the kit's
## pieces. The camera stays near the plaza's centre (it leans a third of the way toward the hero), so every station
## is in view from the spawn. The evolving states (HubFlags) arrive as plain values; no toast (W46).
## The hooks other steps fill: show_collected (CL: the Archive's shelf slots and pedestals), set_runes (CL), set_gate
## (CL's Keystone room), set_robe (RB: the Wardrobe's cloak and its rune circle).

## How far the camera leans from the plaza's centre toward the hero (0: fixed on the centre, 1: on the hero).
const CAMERA_LEAN := 0.25
## The point the camera leans from (plan m): with the hero at the spawn the view centres on the machine, so the north
## gate and the south rim both show.
const CAMERA_BIAS := Vector2(0.0, 3.4)
## A soft fill from the camera's side (no shadows), so the stations' fronts read against the mood's back light.
const FILL_ENERGY := 0.45
const RIM_H := 0.9
const RUNE_R := 0.38

var reader: WorldReader
var layout: HubLayout
var stage := StageView.new()
var rig := IsoRig.new()
var ink := InkPass.new()
## The plan frame: plan (x, y) is local (x, 0, -y) (HubLayout: the plan's north is the screen's top).
var plan := Node3D.new()
var hero := Node3D.new()
var avatar := PlayerAvatar.new()
var machine := HubMachine.new()
## Station id -> its parts (HubStations); the machine is under &"portal".
var stations := {}
var runes: Array[MeshInstance3D] = []
var rune_glows: Array[Dictionary] = []
var gate: Node3D
var gate_seal: Node3D
var alcove: Node3D
## The station the hero stands at (brightened).
var focused := &""


## Builds the hub: `states` from HubFlags.states (state id -> bool, &"runes" -> Array[bool]), `trophies` one bool per
## floor boss (HubFlags.boss_trophies), the biome's mood and palette for the light (Ruins).
func setup(
	p_reader: WorldReader,
	p_layout: HubLayout,
	states: Dictionary,
	trophies: Array[bool],
	mood: BiomeMood,
	palette: Dictionary,
	lighting: String
) -> void:
	name = "HubView"
	reader = p_reader
	layout = p_layout
	stage.name = "Light"
	stage.mood = mood
	stage.palette = palette
	stage.lighting = lighting
	add_child(stage)
	stage.build_lighting_only()
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-35.0, IsoRig.YAW_DEG, 0.0)  # along the camera's view
	fill.light_energy = FILL_ENERGY
	fill.light_color = Color(1.0, 0.94, 0.86)
	fill.shadow_enabled = false
	add_child(fill)
	plan.name = "Plan"
	plan.rotation.y = PI * 0.25  # HubLayout.to_sim's 45°, on the 3D floor
	add_child(plan)
	_build_ground()
	_build_rim()
	_build_gate(bool(states.get(&"gate_open", false)))
	plan.add_child(machine)
	machine.set_looped(bool(states.get(&"machine_looped", false)))
	stations[HubLayout.MACHINE] = {"glow": machine.core_glow}
	_build_runes()
	set_runes(states.get(&"runes", []))
	_build_stations(trophies)
	_set_trophy_states(
		bool(states.get(&"trophy_lit", false)), bool(states.get(&"trophy_crown", false))
	)
	hero.name = "Hero"
	add_child(hero)
	avatar.setup(palette.get("outline", Color("#1A1A22")))
	hero.add_child(avatar)
	var hl := StageKit.hero_light(mood)
	if hl != null:
		hero.add_child(hl)
	add_child(rig)
	rig.camera.add_child(ink)
	ink.position = Vector3(0, 0, -1)
	sync()
	rig.snap_to(rig.target)


## After every hub tick: the hero and the camera.
func sync() -> void:
	var pos := reader.player_pos()
	hero.position = SimPlane.to_3d(pos)
	avatar.sync(reader)
	var look := HubLayout.to_sim(CAMERA_BIAS).lerp(pos, CAMERA_LEAN)
	rig.target = SimPlane.to_3d(look)


## Brightens station `id`'s glow (the hero stands at it; &"": none).
func focus(id: StringName) -> void:
	if id == focused:
		return
	focused = id
	machine.focus = 1.0 if id == HubLayout.MACHINE else 0.0
	for k: StringName in stations:
		if k != HubLayout.MACHINE:
			HubProps.set_glow(stations[k]["glow"], 1.6 if k == id else 0.75)


## CL hook: the floor runes lit (one bool per rune, rune 0 due south of the machine; lit: the sigil glows).
func set_runes(lit: Array) -> void:
	for i in runes.size():
		var on := i < lit.size() and bool(lit[i])
		runes[i].set_meta(&"lit", on)
		(runes[i].material_override as StandardMaterial3D).emission_energy_multiplier = (
			2.6 if on else 0.0
		)
		HubProps.set_glow(rune_glows[i], 1.0 if on else 0.0, 0.5)


## Whether floor rune `i` is lit.
func rune_lit(i: int) -> bool:
	return bool(runes[i].get_meta(&"lit", false))


## CL hook: the collectibles on the Archive's shelf (`count` niches lit, in order) and its pedestals.
func show_collected(count: int) -> void:
	var slots: Array = stations.get(&"archive", {}).get("slots", [])
	for i in slots.size():
		var on := i < count
		(slots[i] as MeshInstance3D).material_override = (
			HubProps.emissive(HubProps.BLUE, 1.6) if on else HubProps.stone(HubProps.STONE_DARK)
		)
		(slots[i] as MeshInstance3D).set_meta(&"lit", on)


## RB hook: the Wardrobe's cloak colour.
func set_robe(c: Color) -> void:
	var robe: MeshInstance3D = stations.get(&"wardrobe", {}).get("robe")
	if robe != null:
		robe.material_override = HubProps.stone(c, 0.85)


## The north gate: sealed (its violet-sealed slab across the arch) or open (the slab gone, the alcove lit).
func set_gate(open: bool) -> void:
	gate_seal.visible = not open
	alcove.get_node("Glow").visible = open


func gate_open() -> bool:
	return gate_seal != null and not gate_seal.visible


# --- building -----------------------------------------------------------------------------------------------------


func _p(plan_xy: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(plan_xy.x, h, -plan_xy.y)


func _build_ground() -> void:
	var hub := layout.hub
	var outer := CylinderMesh.new()
	outer.top_radius = hub.radius_m + 9.0
	outer.bottom_radius = hub.radius_m + 9.0
	outer.height = 0.1
	outer.radial_segments = 48
	var edge := HubProps.ground_material(HubProps.PLAZA_SEAM.darkened(0.45))
	HubProps.mesh(plan, "Outer", outer, edge, Vector3(0, -0.07, 0))
	var disc := CylinderMesh.new()
	disc.top_radius = hub.radius_m
	disc.bottom_radius = hub.radius_m
	disc.height = 0.1
	disc.radial_segments = 64
	HubProps.mesh(
		plan, "Plaza", disc, HubProps.ground_material(HubProps.PLAZA), Vector3(0, -0.05, 0)
	)
	# Carved rings in the flagstones: around the machine's dais and along the rune ring.
	for r: float in [hub.rune_ring_m - 0.75, hub.rune_ring_m + 0.75, hub.radius_m - 1.2]:
		var t := TorusMesh.new()
		t.inner_radius = r - 0.06
		t.outer_radius = r + 0.06
		t.rings = 64
		t.ring_segments = 3
		var ring := HubProps.mesh(
			plan, "Groove", t, HubProps.stone(HubProps.PLAZA_SEAM), Vector3(0, -0.035, 0)
		)
		ring.scale.y = 0.2
	# The walk line from the spawn to the machine: worn flagstones.
	var lane := HubProps.box(
		plan,
		"Lane",
		Vector3(1.6, 0.02, hub.spawn.length() - hub.machine_reach_m + 0.6),
		HubProps.stone(HubProps.PLAZA.darkened(0.08)),
		_p(Vector2(0, (hub.spawn.y + -hub.machine_reach_m) * 0.5), 0.0)
	)
	lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spawn_ring := HubProps.floor_pool(
		plan, "SpawnMark", HubProps.BLUE, _p(hub.spawn, 0.03), 1.6
	)
	(spawn_ring.material_override as ShaderMaterial).set_shader_parameter(&"strength", 0.6)


## A low rim of the kit's wall pieces round the plaza, columns at even steps, braziers either side of the gate and on
## the south rim's shoulders; the south rim stays low (nothing tall between the camera and the hero).
func _build_rim() -> void:
	var hub := layout.hub
	var n := maxi(8, hub.wall_pieces)
	var r := hub.radius_m + hub.wall_m * 0.5
	var piece := TAU * r / n
	for k in n:
		var a := TAU * (k + 0.5) / n
		var c := Vector2(cos(a), sin(a)) * r
		if absf(c.x) < hub.gate_half_m + piece * 0.5 and c.y > 0.0:
			continue
		var south := c.y < -hub.radius_m * 0.4
		var h := RIM_H * (0.7 if south else 1.0)
		var id := &"wall_broken" if k % 5 == 2 else &"wall_2m"
		HubProps.kit_piece(
			plan,
			"Rim%d" % k,
			id,
			Vector3(piece + 0.08, h, hub.wall_m),
			_p(c),
			a + PI * 0.5,
			HubProps.STONE
		)
		if k % 3 == 0 and not south:
			HubProps.kit_piece(
				plan,
				"Column%d" % k,
				&"column_broken",
				Vector3(0.9, 1.9, 0.9),
				_p(c * 1.01),
				a,
				HubProps.STONE_LIT
			)
	for spot: Vector2 in [
		Vector2(-3.2, hub.radius_m - 0.9),
		Vector2(3.2, hub.radius_m - 0.9),
		Vector2(-10.6, -6.4),
		Vector2(10.6, -6.4)
	]:
		HubProps.kit_piece(
			plan,
			"Brazier",
			&"brazier_pole",
			Vector3(0.6, 1.8, 0.6),
			_p(spot),
			0.0,
			HubProps.STONE_DARK
		)
		HubProps.glow(plan, "BrazierFire", HubProps.FIRE, HubProps.GOLD_CORE, _p(spot, 1.95), 1.5)
		HubProps.motes(plan, "Embers", HubProps.FIRE, _p(spot, 1.9), 0.15, 8)


## The north gate: the kit's stone arch over the rim's gap, a sealed slab with a violet sigil while closed, and the
## alcove past it (a small round room with a pedestal and a hidden glow: CL's Keystone).
func _build_gate(open: bool) -> void:
	var hub := layout.hub
	var gy := hub.radius_m + hub.wall_m * 0.5
	gate = HubProps.kit_piece(
		plan,
		"Gate",
		&"stone_arch",
		Vector3(hub.gate_half_m * 2.0 + 1.2, 2.6, hub.wall_m + 0.2),
		_p(Vector2(0, gy)),
		0.0,
		HubProps.STONE
	)
	gate_seal = Node3D.new()
	gate_seal.name = "Seal"
	gate_seal.position = _p(Vector2(0, gy))
	plan.add_child(gate_seal)
	HubProps.box(
		gate_seal,
		"Slab",
		Vector3(hub.gate_half_m * 2.0, 2.1, 0.3),
		HubProps.stone(HubProps.STONE_DARK),
		Vector3(0, 1.05, 0)
	)
	var sig := FxTextures.sigil_material(HubProps.VIOLET, 2)
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 1.2
	var sigil := HubProps.mesh(
		gate_seal,
		"Sigil",
		q,
		sig if sig != null else HubProps.emissive(HubProps.VIOLET, 2.0),
		Vector3(0, 1.15, 0.17)
	)
	sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	HubProps.glow(
		gate_seal, "Glow", HubProps.VIOLET, HubProps.VIOLET_CORE, Vector3(0, 1.15, 0.5), 1.6
	)
	alcove = Node3D.new()
	alcove.name = "Alcove"
	alcove.position = _p(hub.alcove_at)
	plan.add_child(alcove)
	var floor_disc := CylinderMesh.new()
	floor_disc.top_radius = hub.alcove_r + 0.4
	floor_disc.bottom_radius = hub.alcove_r + 0.4
	floor_disc.height = 0.1
	floor_disc.radial_segments = 24
	HubProps.mesh(
		alcove,
		"Floor",
		floor_disc,
		HubProps.ground_material(HubProps.PLAZA.darkened(0.25)),
		Vector3(0, -0.05, 0)
	)
	HubProps.cylinder(
		alcove, "Pedestal", 0.35, 0.45, 0.9, HubProps.stone(HubProps.STONE), Vector3(0, 0.45, 0)
	)
	var ag := HubProps.glow(
		alcove, "Glow", HubProps.VIOLET, HubProps.VIOLET_CORE, Vector3(0, 1.3, 0), 1.6
	)
	ag["root"].name = "Glow"
	set_gate(open)


## The 16 floor runes on their ring: dark slate discs with a carved glyph; a lit one glows (an emissive glyph, its
## sigil on the floor and a small light).
func _build_runes() -> void:
	var points := layout.rune_points()
	var slate := HubProps.stone(HubProps.STONE_DARK)
	for i in points.size():
		var p: Vector2 = points[i]
		HubProps.cylinder(
			plan, "RuneStone%d" % i, RUNE_R, RUNE_R + 0.05, 0.08, slate, _p(p, 0.04), 8
		)
		var glyph := BoxMesh.new()
		glyph.size = Vector3(0.36, 0.02, 0.08)
		var m := HubProps.emissive(HubProps.BLUE, 0.0)
		m.albedo_color = HubProps.STONE_DARK.lightened(0.15)
		var g := HubProps.mesh(plan, "Rune%d" % i, glyph, m, _p(p, 0.09))
		g.rotation.y = -TAU * i / float(points.size())
		var cross := HubProps.mesh(g, "Cross", glyph, m, Vector3.ZERO)
		cross.rotation.y = PI * 0.5
		cross.scale = Vector3(0.6, 1.0, 1.0)
		runes.append(g)
		rune_glows.append(
			HubProps.glow(
				plan, "RuneGlow%d" % i, HubProps.BLUE, HubProps.BLUE_CORE, _p(p, 0.25), 0.9
			)
		)


func _build_stations(trophies: Array[bool]) -> void:
	for s: HubStationDefinition in layout.hub.stations:
		var root := Node3D.new()
		root.name = "Station_%s" % s.id
		root.position = _p(s.at)
		plan.add_child(root)
		var parts := {}
		match s.panel:
			&"codex":
				parts = HubStations.archive(root, s.half, s.height_m)
			&"achievements":
				parts = HubStations.trophy(root, s.half, s.height_m, trophies)
			&"wardrobe":
				parts = HubStations.wardrobe(root, s.half, s.height_m)
			&"progression":
				parts = HubStations.progression(root, s.half, s.height_m)
			_:
				parts = HubStations.credits(root, s.half, s.height_m)
		parts["root"] = root
		stations[s.id] = parts
		HubProps.set_glow(parts["glow"], 0.75)


func _set_trophy_states(lit: bool, crown: bool) -> void:
	var t: Dictionary = stations.get(&"trophy", {})
	if t.is_empty():
		return
	HubProps.set_glow(t["fire"], 1.0 if lit else 0.0)
	(t["crown"] as Node3D).visible = crown

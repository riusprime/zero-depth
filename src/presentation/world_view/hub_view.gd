class_name HubView
extends Node3D
## v0.9.0 HB (owner Q27; HUB_MOCKUPS option A, the Rune Ring): the hub drawn from its plan (HubLayout) and the hero
## walking it, read from the hub's World through WorldReader once per tick (EI-07). One round plaza in one iso view:
## the Portal Machine in the centre (HubMachine), the 16 floor runes ringing it (lit per collectible: set_runes, CL),
## the stations (HubStations: the Rune Archive, the Trophy Area, the Wardrobe, the Progression Station, the Credits
## stone), the sealed north gate and the alcove past it (set_gate). The evolving states (HubFlags) arrive as plain
## values; no toast (W46).
## v0.9.0 HB3 (owner: "a bit bigger … separate the runes a bit from the portal … use the top part of the hub to place
## all the interactive things, looking into the middle … decoration, floor … different walls"): a 16 m plaza, the
## runes on the centre medallion's sockets 7.8 m out, every station along the top half turned to the middle, and the
## owner's floor, walls, pillar braziers, gate and props (HubDressing). The camera sees more (VIEW_SIZE) and leans a
## little more toward the hero. v0.9.5 (owner: "a bit of zoom at the hub … like a 15%"): 22.5 → 19.1 m.
## v0.9.0 HB2 (owner: "click, choose weapon and then the character walks upstairs towards the portal and crosses
## it"): walk_into_portal() moves the hero up the machine's steps and through its ring (HubPortalWalk), the portal
## flaring and the camera easing in; `walk_finished` when the hero is through (HubSession starts the run's load).
## The hooks other steps fill: show_collected (CL: the Archive's shelf slots and pedestals), set_runes (CL), set_gate
## (CL's Keystone room), set_robe (RB: the Wardrobe's cloak and its rune circle).

signal walk_finished

## How far the camera leans from the plaza's centre toward the hero (0: fixed on the centre, 1: on the hero).
const CAMERA_LEAN := 0.25
## The point the camera leans from (plan m): with the hero at the spawn the view holds the machine, the stations
## along the top and the spawn.
const CAMERA_BIAS := Vector2(0.0, 4.4)
## v0.9.0 HB3: the hub's view height (m; the run's 17 m showed a 25 m plaza, this one is 32 m).
const VIEW_SIZE := 19.1
## v0.9.0 HB2: during the walk the camera eases toward the machine's ring and closes in this much (1: none).
const WALK_ZOOM := 1.18
## A soft fill from the camera's side (no shadows), so the stations' fronts read against the mood's back light.
const FILL_ENERGY := 0.45
const RUNE_R := 0.38
## v0.9.5 RS1: how long (s) the Runic Stone's pulse lasts.
const PULSE_S := 1.2
## v0.9.0 HB3: a lit rune: the owner's stone with its carved grooves glowing (the albedo's dark grooves -> `glow`).
const RUNE_SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 glow : source_color = vec4(0.17, 0.77, 0.89, 1.0);
uniform float energy = 3.2;
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float groove = 1.0 - smoothstep(0.1, 0.24, lum);
	ALBEDO = mix(c, glow.rgb * 0.35, groove * 0.7);
	EMISSION = glow.rgb * groove * energy;
	ROUGHNESS = 0.85;
}
"""

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
## v0.9.0 CL: the Keystone on the alcove's pedestal (null until shown: set_keystone).
var keystone: Node3D
## v0.9.0 HB3: the pillar braziers' fires (their lights flicker).
var fires: Array[Dictionary] = []
## The station the hero stands at (brightened).
var focused := &""
## v0.9.0 HB2: the walk into the portal (null: none) and what it started from.
var walk: HubPortalWalk
var _walk_tick := 0
var _walk_cam := Vector3.ZERO
var _walk_told := false
var _rune_dark: Material
var _rune_lit: ShaderMaterial
var _t := 0.0
## v0.9.5 RS1: seconds into the Runic Stone's pulse (-1: none) and whether its veins are lit.
var _pulse_t := -1.0
var _veins_on := false


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
	HubDressing.ground(plan, layout.hub)  # v0.9.0 HB3: the owner's floor, walls, pillars, props
	HubDressing.walls(plan, layout.hub)
	fires = HubDressing.pillars(plan, layout.hub)
	HubDressing.props(plan, layout.hub)
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
	var spawn_ring := HubProps.floor_pool(
		plan, "SpawnMark", HubProps.BLUE, _p(layout.hub.spawn, 0.03), 1.6
	)
	(spawn_ring.material_override as ShaderMaterial).set_shader_parameter(&"strength", 0.6)
	hero.name = "Hero"
	add_child(hero)
	avatar.setup(palette.get("outline", Color("#1A1A22")))
	hero.add_child(avatar)
	var hl := StageKit.hero_light(mood)
	if hl != null:
		hero.add_child(hl)
	rig.view_size = VIEW_SIZE
	add_child(rig)
	rig.camera.add_child(ink)
	ink.position = Vector3(0, 0, -1)
	sync()
	rig.snap_to(rig.target)


## After every hub tick: the hero and the camera (v0.9.0 HB2: not while the hero walks into the portal).
func sync() -> void:
	if walk != null:
		return
	var pos := reader.player_pos()
	hero.position = SimPlane.to_3d(pos)
	avatar.sync(reader)
	var look := HubLayout.to_sim(CAMERA_BIAS).lerp(pos, CAMERA_LEAN)
	rig.target = SimPlane.to_3d(look)


## v0.9.0 HB2: the hero walks from where it stands up the machine's steps and through its ring (HubPortalWalk);
## `walk_finished` once it is through. Its length (s).
func walk_into_portal() -> float:
	walk = HubPortalWalk.new(HubLayout.to_plan(reader.player_pos()), machine.walk_points())
	_walk_tick = reader.tick()
	_walk_cam = rig.target
	_walk_told = false
	_advance_walk(0.0)
	return walk.duration()


## v0.9.0 HB2: a press skips the rest of the walk (the hero is through at once).
func finish_walk() -> void:
	if walk != null:
		walk.t = walk.duration()
		_advance_walk(0.0)


func _process(delta: float) -> void:
	_t += delta
	for i in fires.size():
		HubProps.flicker(fires[i], _t, float(i) * 1.7)
	_advance_pulse(delta)
	if walk != null:
		_advance_walk(delta)


## The walk's frame: the hero's node along the path (its height up the steps, shrinking into the ring), the avatar
## told it walks (a tick per 1/60 s of the walk, so its legs stride as in play), the portal's flare and the camera.
func _advance_walk(delta: float) -> void:
	walk.t += delta
	var plan_at := walk.plan_point()
	var sim := HubLayout.to_sim(plan_at)
	hero.position = SimPlane.to_3d(sim, walk.height())
	var s := maxf(0.001, 1.0 - walk.shrink())
	hero.scale = Vector3.ONE * s
	hero.visible = walk.shrink() < 0.999
	var dir := HubLayout.to_sim(walk.heading())
	var tick := _walk_tick + 1 + int(walk.t * 60.0)
	(
		avatar
		. apply_state(
			{
				"tick": tick,
				"pos": sim,
				"aim": int(round(atan2(dir.y, dir.x) / TAU * 4096.0)),
				"dashing": false,
				"swing_t": 0,
				"swing_ticks": 1,
				"swing_angle": 0,
				"combo": 0,
				"guarding": false,
				"dead": false,
				"gun": false,
			}
		)
	)
	machine.set_flare(walk.flare())
	var k := walk.ease_k()
	var ring := SimPlane.to_3d(HubLayout.to_sim(Vector2.ZERO))
	rig.target = _walk_cam.lerp(ring, k)
	rig.set_flourish(0.0, lerpf(1.0, WALK_ZOOM, k))
	if walk.done() and not _walk_told:
		_walk_told = true
		walk_finished.emit()


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
		if _rune_lit != null:  # v0.9.0 HB3: the owner's stone, its grooves glowing
			runes[i].material_override = _rune_lit if on else _rune_dark
		else:
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


## v0.9.0 CL: the Archive's shelf, one niche per collectible in shelf order: a found one's niche glows in its own
## colour (`colors[i]`), the rest stay dark stone.
func show_found(found: Array[bool], colors: Array[Color]) -> void:
	var slots: Array = stations.get(&"archive", {}).get("slots", [])
	for i in slots.size():
		var on := i < found.size() and found[i]
		var c: Color = colors[i] if i < colors.size() else HubProps.BLUE
		(slots[i] as MeshInstance3D).material_override = (
			HubProps.emissive(c, 2.2) if on else HubProps.stone(HubProps.STONE_DARK)
		)
		(slots[i] as MeshInstance3D).set_meta(&"lit", on)


## v0.9.0 CL: the Keystone on the alcove's pedestal (`c` its colour; shown: it waits there to be taken), drawn in
## layers: a faceted stone turning slowly, a white-hot halo, a glow pooled on the pedestal, a light and motes.
func set_keystone(shown: bool, c: Color = HubProps.BLUE) -> void:
	if keystone == null and shown:
		keystone = CollectibleLooks.gem(alcove, "Keystone", c, Vector3(0, 1.25, 0), 0.34)
	if keystone != null:
		keystone.visible = shown


## v0.9.0 CL: whether the Keystone shows on its pedestal.
func keystone_shown() -> bool:
	return keystone != null and keystone.visible


## v0.9.0 RB: the hero wears the Wardrobe's choice in the hub (a Wardrobe.look: the robe's colours and the chosen
## affinity's rune), and the Wardrobe's stand-in robe takes the cloak's colour.
func set_look(look: Dictionary) -> void:
	if look.is_empty():
		return
	avatar.set_look(look)
	set_robe(look["cloak"])


## RB hook: the Wardrobe's cloak colour (the stand-in's robe; with the owner's wardrobe model the robe is part of his
## mesh, so nothing recolours until the art list's `hub_wardrobe_robe` arrives).
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


## The north gate (HubDressing.gate: the owner's gateway, its doors apart; or the kit's arch and a code slab), a violet
## sigil glowing on it while sealed, and the alcove past it (a small round room with a pedestal and a hidden glow:
## CL's Keystone).
func _build_gate(open: bool) -> void:
	var hub := layout.hub
	var gy := hub.radius_m + hub.wall_m * 0.5
	var g := HubDressing.gate(plan, hub, gy)
	gate = g["frame"]
	gate_seal = g["doors"]
	var sig := FxTextures.sigil_material(HubProps.VIOLET, 2)
	var q := QuadMesh.new()
	q.size = Vector2.ONE * (1.6 if g["model"] else 1.2)
	var front := hub.wall_m * 0.5 + 0.2
	if g["model"]:
		var doors_aabb: AABB = ShopModels.get_model(&"hub_sealed_gate_doors")["aabb"]
		front = doors_aabb.end.z + 0.03
	var sigil := HubProps.mesh(
		gate_seal,
		"Sigil",
		q,
		sig if sig != null else HubProps.emissive(HubProps.VIOLET, 2.0),
		Vector3(0, 1.7 if g["model"] else 1.15, front)
	)
	sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	HubProps.glow(
		gate_seal,
		"Glow",
		HubProps.VIOLET,
		HubProps.VIOLET_CORE,
		Vector3(0, 1.7 if g["model"] else 1.15, front + 0.35),
		1.8
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
		HubDressing.paving(HubProps.PLAZA.darkened(0.25)),
		Vector3(0, -0.03, 0)
	)
	HubProps.cylinder(
		alcove, "Pedestal", 0.35, 0.45, 0.9, HubProps.stone(HubProps.STONE), Vector3(0, 0.45, 0)
	)
	var ag := HubProps.glow(
		alcove, "Glow", HubProps.VIOLET, HubProps.VIOLET_CORE, Vector3(0, 1.3, 0), 1.6
	)
	ag["root"].name = "Glow"
	set_gate(open)


## The 16 floor runes on the medallion's sockets (HubLayout.rune_points): the owner's rune stone (v0.9.0 HB3), or a
## dark slate disc with a carved cross; a lit one's grooves glow blue (RUNE_SHADER on his stone, an emissive glyph on
## the stand-in), with its sigil's glow on the floor and a small light.
func _build_runes() -> void:
	var points := layout.rune_points()
	var model := ShopModels.get_model(&"hub_floor_rune")
	var slate := HubProps.stone(HubProps.STONE_DARK)
	if not model.is_empty():
		_rune_dark = model["material"]
		_rune_lit = ShaderMaterial.new()
		_rune_lit.shader = HubProps._shader(RUNE_SHADER)
		var mat := model["material"] as BaseMaterial3D
		if mat != null and mat.albedo_texture != null:
			_rune_lit.set_shader_parameter(&"albedo_tex", mat.albedo_texture)
		_rune_lit.set_shader_parameter(&"glow", HubProps.BLUE)
	for i in points.size():
		var p: Vector2 = points[i]
		var g: MeshInstance3D
		if not model.is_empty():
			g = HubProps.mesh(plan, "Rune%d" % i, model["mesh"], _rune_dark, _p(p, 0.0))
			g.rotation.y = HubLayout.facing(p)  # the glyph reads from the plaza's middle
			g.set_meta(&"model_id", &"hub_floor_rune")
		else:
			HubProps.cylinder(
				plan, "RuneStone%d" % i, RUNE_R, RUNE_R + 0.05, 0.08, slate, _p(p, 0.04), 8
			)
			var glyph := BoxMesh.new()
			glyph.size = Vector3(0.36, 0.02, 0.08)
			var m := HubProps.emissive(HubProps.BLUE, 0.0)
			m.albedo_color = HubProps.STONE_DARK.lightened(0.15)
			g = HubProps.mesh(plan, "Rune%d" % i, glyph, m, _p(p, 0.09))
			g.rotation.y = -TAU * i / float(points.size())
			var cross := HubProps.mesh(g, "Cross", glyph, m, Vector3.ZERO)
			cross.rotation.y = PI * 0.5
			cross.scale = Vector3(0.6, 1.0, 1.0)
		runes.append(g)
		rune_glows.append(
			HubProps.glow(
				plan, "RuneGlow%d" % i, HubProps.BLUE, HubProps.BLUE_CORE, _p(p, 0.3), 1.0
			)
		)


func _build_stations(trophies: Array[bool]) -> void:
	for s: HubStationDefinition in layout.hub.stations:
		var root := Node3D.new()
		root.name = "Station_%s" % s.id
		root.position = _p(s.at)
		root.rotation.y = HubLayout.facing(s.at)  # v0.9.0 HB3: its front to the plaza's middle
		plan.add_child(root)
		var parts := build_station(root, s, trophies)
		parts["root"] = root
		stations[s.id] = parts
		HubProps.set_glow(parts["glow"], 0.75)


## Station `s`'s look under `root` (HubStations, by its panel); returns its parts. v0.9.0 HE: the hub editor
## (tools/hub_editor) draws the stations with it too.
static func build_station(
	root: Node3D, s: HubStationDefinition, trophies: Array[bool]
) -> Dictionary:
	match s.panel:
		&"codex":
			return HubStations.archive(root, s.half, s.height_m)
		&"achievements":
			return HubStations.trophy(root, s.half, s.height_m, trophies)
		&"wardrobe":
			return HubStations.wardrobe(root, s.half, s.height_m)
		&"progression":
			return HubStations.progression(root, s.half, s.height_m)
	return HubStations.runic(root, s.half, s.height_m)  # v0.9.5 RS1: the Runic Stone (was the Credits stone)


## v0.9.5 RS1 (RUNIC_STONE.md S3): the Runic Stone's veins lit violet (awake) or dark (locked: no glow at all).
func set_runic(awake: bool) -> void:
	_veins_on = awake
	_apply_veins(0.0)


## v0.9.5 RS1 (S5): the veins flare once (about 1.2 s) and settle.
func pulse_runic() -> void:
	if _veins_on:
		_pulse_t = 0.0


## v0.9.5 RS2 (S6): the full stone's ring of the 24 runes around its base, turning slowly (RuneRingView), shown or gone.
func set_runic_full(full: bool) -> void:
	var st: Dictionary = stations.get(&"runic", {})
	if st.is_empty():
		return
	var root := st["root"] as Node3D
	var ring := root.get_node_or_null("RuneRing")
	if full and ring == null:
		ring = RuneRingView.new(float(st.get("radius", 1.0)) + 0.45)
		ring.position = Vector3(0, 0.07, 0)
		root.add_child(ring)
	elif not full and ring != null:
		ring.queue_free()


## Whether the Runic Stone's veins are lit now.
func runic_lit() -> bool:
	var ring: Variant = (stations.get(&"runic", {}) as Dictionary).get("ring")
	return ring is MeshInstance3D and (ring as MeshInstance3D).visible


## Where the Runic Stone's top is on the 3D floor (the speech bubble's tail).
func runic_top() -> Vector3:
	var st: Dictionary = stations.get(&"runic", {})
	if st.is_empty():
		return Vector3.ZERO
	var top := float(st.get("height", 1.7)) + 0.3
	return (st["root"] as Node3D).global_position + Vector3(0, top, 0)


func _advance_pulse(delta: float) -> void:
	if _pulse_t < 0.0:
		return
	_pulse_t += delta
	var k := 0.0
	if _pulse_t >= PULSE_S:
		_pulse_t = -1.0
	else:
		k = sin(PI * _pulse_t / PULSE_S)
	_apply_veins(k)


func _apply_veins(pulse: float) -> void:
	var st: Dictionary = stations.get(&"runic", {})
	if st.is_empty():
		return
	var ring := st["ring"] as MeshInstance3D
	ring.visible = _veins_on
	var energy := (2.2 + 4.0 * pulse) if _veins_on else 0.0
	(ring.material_override as StandardMaterial3D).emission_energy_multiplier = energy
	(st["light"] as OmniLight3D).light_energy = (0.5 + 1.6 * pulse) if _veins_on else 0.0


func _set_trophy_states(lit: bool, crown: bool) -> void:
	var t: Dictionary = stations.get(&"trophy", {})
	if t.is_empty():
		return
	HubProps.set_glow(t["fire"], 1.0 if lit else 0.0)
	(t["crown"] as Node3D).visible = crown

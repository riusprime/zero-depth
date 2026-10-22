class_name FinalApproachView
extends Node3D
## v0.9.0 FA (owner C §3: "The altar resembles the starting altar but has a more ominous purple appearance … Activation
## mechanisms must provide obvious visual feedback … Once activated, the purple runes illuminate and begin spinning. A
## buildup animation begins, using a modified version of the starting altar sequence"; Q18; Q17: the vibration on
## "arriving to the new final boss platform"): the final approach's pieces on top of FinalArenaStage's plateau and
## causeway, posed from the sim (WorldReader.approach_*) each sync:
## - the altar: SA's AltarStage in its purple look (AltarStage.final) at the plateau's centre; each lit pylon lights
##   its share of the runes; the buildup plays the altar's timeline with its pop on the buildup's end (the walls rise,
##   the Colossus rises from the altar), then the release;
## - the two rune pylons (code-made: a faceted dark stone with a rune on each face and a crystal on top): dark until
##   pressed, then they lock in (a quick punch, a flash, a burst of motes, the rune and crystal lit, a light); they
##   sink into the plateau once the fight begins (the sim has no body for them);
## - the walls of light: one glowing violet curtain per light wall (WorldReader.approach_light_wall), rising from the
##   floor when they stand;
## - the camera: a thud as the hero lands at the causeway's foot, the vibration climbing through the buildup and a
##   heavier thud as the walls rise.
## Reduced motion: no punch, motes, orbit, rising or vibration; the pieces just light. Presentation only (EI-07).

const VIOLET := AltarStage.VIOLET
const VIOLET_CORE := AltarStage.VIOLET_CORE
const PYLON_H := 2.3
const PYLON_W := 0.75
## The lock-in's punch (s) and size, the pylons' sink (s) once the fight begins, the walls' rise (ticks).
const PUNCH_S := 0.45
const PUNCH := 0.35
const SINK_S := 1.4
const WALL_RISE_TICKS := 30
const WALL_H := 4.5
## The altar's release after the pop (ticks).
const RELEASE_TICKS := 60
## The camera: the landing's thud, the buildup's climb, the walls' thud.
const ARRIVE_THUD := 0.5
const BUILD_LOW := 0.06
const BUILD_PEAK := 0.4
const RISE_THUD := 0.9

var altar: AltarStage
var pylons: Array[Node3D] = []
var walls: Array[MeshInstance3D] = []
var rig: IsoRig
var calm := false
## Pylon k's lock-in has played (tests read it), and the walls have risen.
var locked: Array[bool] = [false, false]
var walls_up := false
var _landed := false
var _crystal_mats: Array[StandardMaterial3D] = []
var _rune_mats: Array[Material] = []
var _lights: Array[OmniLight3D] = []
var _bursts: Array[CPUParticles3D] = []
var _punch_t: Array[float] = [-1.0, -1.0]
var _sink_t := -1.0
var _wall_mat := StandardMaterial3D.new()


func _init() -> void:
	name = "FinalApproach"


func setup(reader: WorldReader, p_rig: IsoRig) -> void:
	rig = p_rig
	calm = ViewPrefs.reduced_motion
	altar = AltarStage.new(AltarStage.final())
	add_child(altar)
	altar.setup(reader.approach_altar_pos())
	for k in reader.approach_pylon_count():
		pylons.append(_build_pylon(k, reader.approach_pylon_pos(k), reader.approach_altar_pos()))
	_wall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wall_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wall_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wall_mat.albedo_color = Color(VIOLET, 0.55)
	for k in reader.approach_light_wall_count():
		var o := reader.approach_light_wall(k)
		var b := BoxMesh.new()
		b.size = Vector3(o.half.x * 2.0 * 0.4, WALL_H, o.half.y * 2.0)
		var mi := MeshInstance3D.new()
		mi.name = "LightWall%d" % k
		mi.mesh = b
		mi.material_override = _wall_mat
		mi.position = SimPlane.to_3d(o.center, WALL_H * 0.5)
		mi.rotation.y = SimPlane.yaw_of(o.angle)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		walls.append(mi)
	for k in pylons.size():
		locked[k] = reader.approach_pylon_lit(k)  # a resumed save: already on, no lock-in replayed
		_apply_pylon(k, 1.0 if locked[k] else 0.0)
	walls_up = reader.approach_walls_up()
	_landed = not reader.arriving()
	if walls_up:
		_sink_t = SINK_S
	sync(reader)


func sync(reader: WorldReader) -> void:
	if altar == null:
		return
	calm = ViewPrefs.reduced_motion
	altar.calm = calm
	if not _landed and reader.arrival_progress() >= 0.5:  # Q17: the landing at the causeway's foot
		_landed = true
		if rig != null:
			rig.thud(ARRIVE_THUD)
	var share := float(reader.approach_pylons_lit()) / maxf(1.0, reader.approach_pylon_count())
	for k in pylons.size():
		if reader.approach_pylon_lit(k) and not locked[k]:
			locked[k] = true
			_punch_t[k] = 0.0 if not calm else -1.0
			if not calm:
				_bursts[k].restart()
			_apply_pylon(k, 1.0)
	var state := reader.approach_state()
	var pop := altar.look.pop_at
	if state == WorldReader.APPROACH_BUILDUP:
		var b := reader.approach_buildup_progress()
		altar.pose(b * pop, share)
		if rig != null:
			rig.vibrate_to(BUILD_LOW + (BUILD_PEAK - BUILD_LOW) * b * b)
	elif state == WorldReader.APPROACH_FIGHT:
		var since := reader.tick() - reader.approach_fight_tick()
		if not walls_up:
			walls_up = true
			_sink_t = 0.0 if not calm else SINK_S
			altar.puff()
			if rig != null:
				rig.thud(RISE_THUD)
		if since < RELEASE_TICKS:
			altar.pose(pop + (1.0 - pop) * float(since) / RELEASE_TICKS, 1.0)
			altar.set_burst(float(since) / (RELEASE_TICKS * 0.6))
		else:
			altar.pose(-1.0, 1.0)
			altar.set_burst(-1.0)
		var rise := 1.0 if calm else clampf(float(since) / WALL_RISE_TICKS, 0.0, 1.0)
		for w in walls:
			w.visible = true
			w.scale = Vector3(1.0, maxf(rise, 0.01), 1.0)
			w.position.y = WALL_H * 0.5 * rise
	else:
		altar.pose(-1.0, share)
	for w in walls:
		w.visible = walls_up


func _process(delta: float) -> void:
	for k in pylons.size():
		if _punch_t[k] >= 0.0:
			_punch_t[k] += delta
			var u := clampf(_punch_t[k] / PUNCH_S, 0.0, 1.0)
			var s := 1.0 + PUNCH * sin(u * PI) * (1.0 - u)
			pylons[k].scale = Vector3(s, s, s)
			_lights[k].light_energy = 2.0 + 6.0 * (1.0 - u)
			if u >= 1.0:
				_punch_t[k] = -1.0
				pylons[k].scale = Vector3.ONE
	if _sink_t >= 0.0 and _sink_t <= SINK_S:
		_sink_t = minf(SINK_S, _sink_t + delta) if not calm else SINK_S
		var v := _sink_t / SINK_S
		for p in pylons:
			p.position.y = -(PYLON_H + 0.3) * v * v
			p.visible = v < 1.0
		if _sink_t >= SINK_S:
			_sink_t = SINK_S + 1.0


## Pylon k lit to `k_lit` (0 dark .. 1 on).
func _apply_pylon(k: int, k_lit: float) -> void:
	var c := _crystal_mats[k]
	c.emission_energy_multiplier = 0.15 + 4.0 * k_lit
	c.albedo_color = VIOLET.darkened(0.7 - 0.5 * k_lit)
	var m := _rune_mats[k]
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("alpha", 0.08 + 1.3 * k_lit)
	elif m is StandardMaterial3D:
		(m as StandardMaterial3D).emission_energy_multiplier = 0.1 + 3.0 * k_lit
	_lights[k].light_energy = 2.0 * k_lit
	_lights[k].visible = k_lit > 0.0


## A pylon: a faceted stone with a rune on its two faces toward and away from the altar and a crystal on top.
func _build_pylon(k: int, at: Vector2, centre: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Pylon%d" % k
	root.position = SimPlane.to_3d(at)
	add_child(root)
	var to := SimPlane.to_3d(centre) - root.position
	root.rotation.y = atan2(to.x, to.z)  # +Z faces the altar
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#3B3442")
	stone.roughness = 0.95
	var base := CylinderMesh.new()
	base.top_radius = PYLON_W * 0.75
	base.bottom_radius = PYLON_W * 0.95
	base.height = 0.3
	base.radial_segments = 6
	base.rings = 1
	_mesh(root, "Base", AltarStage.faceted(base), stone, Vector3(0, 0.15, 0))
	var body := CylinderMesh.new()
	body.top_radius = PYLON_W * 0.32
	body.bottom_radius = PYLON_W * 0.5
	body.height = PYLON_H
	body.radial_segments = 5
	body.rings = 1
	_mesh(root, "Stone", AltarStage.faceted(body), stone, Vector3(0, 0.3 + PYLON_H * 0.5, 0))
	var rune: Material = FxTextures.sigil_material(VIOLET, k % 4)
	if rune == null:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = VIOLET.darkened(0.5)
		sm.emission_enabled = true
		sm.emission = VIOLET
		rune = sm
	_rune_mats.append(rune)
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.62
	for side in [1.0, -1.0]:
		var face := _mesh(root, "Rune", q, rune, Vector3(0, 1.35, side * PYLON_W * 0.43))
		face.rotation.y = 0.0 if side > 0.0 else PI
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gem := SphereMesh.new()
	gem.radius = 0.2
	gem.height = 0.6
	gem.radial_segments = 4
	gem.rings = 2
	var cm := StandardMaterial3D.new()
	cm.emission_enabled = true
	cm.emission = VIOLET
	cm.roughness = 0.25
	_crystal_mats.append(cm)
	_mesh(root, "Crystal", AltarStage.faceted(gem), cm, Vector3(0, PYLON_H + 0.75, 0))
	var light := OmniLight3D.new()
	light.light_color = VIOLET
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = Vector3(0, PYLON_H + 0.6, 0)
	root.add_child(light)
	_lights.append(light)
	var burst := CPUParticles3D.new()
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.vertex_color_use_as_albedo = true
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var mq := QuadMesh.new()
	mq.size = Vector2(0.14, 0.14)
	mq.material = mm
	var fade := Gradient.new()
	fade.set_color(0, Color(VIOLET_CORE, 1.0))
	fade.set_color(1, Color(VIOLET, 0.0))
	burst.name = "Burst"
	burst.mesh = mq
	burst.amount = 36
	burst.one_shot = true
	burst.emitting = false
	burst.explosiveness = 0.9
	burst.lifetime = 0.9
	burst.color_ramp = fade
	burst.direction = Vector3.UP
	burst.spread = 60.0
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 4.5
	burst.gravity = Vector3(0, -2.0, 0)
	burst.position = Vector3(0, PYLON_H + 0.7, 0)
	root.add_child(burst)
	_bursts.append(burst)
	return root


func _mesh(parent: Node3D, n: String, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi

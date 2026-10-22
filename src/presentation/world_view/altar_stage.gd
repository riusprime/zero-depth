class_name AltarStage
extends Node3D
## v0.9.0 SA (owner C §2: "Replace the current starting portal/platform with a substantially larger, fully modeled 3D
## altar … Circular stone platform, approximately 3 times larger … Three or four stone steps … Floating or carved
## arcane runes arranged around the altar. Glowing blue symbols, with optional small crystals or jewels around the
## sides"; "Prefer a reusable altar scene with configurable colors, rune objects, animation timing, sound, and
## activation triggers"): the altar the hero arrives on. One scene, two looks (Look):
## - arrival(): floor 1 of a run (Q16), blue (the hero's player_core), its trigger the arrival's progress
##   (PortalTransitView poses it from WorldReader.arrival_progress);
## - final(): the final approach's altar (FA, C28: "more ominous purple"), its trigger the pylons' activation and the
##   buildup's progress (FinalApproachView poses it from WorldReader.final_approach_*).
## The stand-in (until assets/models/manifest.json lists `arrival_altar`, ShopModels): a round stepped dais 6.6 m
## across (3 × the 2.2 m receiver, C7), four low faceted stone steps to a 4.4 m top, carved rune panels inlaid in the
## top, a landing circle, and jewel sockets on the second step. The floating runes (fx_cast_sigils cells on the sigil
## material, FxTextures; plain glowing diamonds without the sheet) and the jewels are separate objects so each lights on
## its own and the runes orbit (C10, C24); the owner's model replaces only the stone.
## The timeline (fractions of the trigger's progress 0..1, Look): idle (the empty altar) → the runes and jewels light
## one after another → the runes orbit, speeding up → the buildup (particles drawn in, a centre swirl, the glow and
## light climbing) → the pop (pop_at: the burst ring, the dust) → the release (the runes slow, the energy fades). The
## orbit's angle is a pure function of the progress (orbit_angle), so the same tick always looks the same.
## Reduced motion (calm): no orbit, bob, swirl turn or particles: the runes just light. Presentation only (EI-07);
## walk-over: the sim has no height (ROADMAP §6) and keeps its start clear (FloorParams.start_clear_radius).

const MODEL_ID := &"arrival_altar"
## The dais: its outer radius (m), the top's radius, the steps (count, height each).
const RADIUS := 3.3
const TOP_R := 2.2
const STEPS := 4
const STEP_H := 0.055
const STONE := Color("#55575A")
const STONE_DARK := Color("#3A3C40")
const BLUE := Color("#2BC4E2")
const BLUE_CORE := Color("#DDF8FF")
const VIOLET := Color("#9B4DFF")
const VIOLET_CORE := Color("#EBD6FF")
## A rune's glow at rest once woken (after its sequence), and its light-up fade (progress).
const REST_GLOW := 0.22
const LIGHT_FADE := 0.05
## The carved panels inlaid in the top (count, ring radius m).
const PANELS := 10
const PANEL_R := 1.72
const LANDING_R := 0.7
const BURST_REACH := 2.2
const LIGHT_IDLE := 0.0
const LIGHT_PEAK := 7.0
## The runes' slow bob (m, Hz) on the presentation's clock.
const BOB := 0.06
const BOB_HZ := 0.35


## One configuration of the altar (C23): colours, the rune set, the jewels, the timeline and the sound.
class Look:
	extends RefCounted
	var color := BLUE
	var core := BLUE_CORE
	var stone := STONE
	var runes := 10
	var rune_radius := 2.75
	var rune_height := 1.25
	var rune_size := 0.62
	## fx_cast_sigils cells, used round the ring in turn.
	var cells := PackedInt32Array([0, 1, 2, 3])
	var jewels := 8
	## The timeline (fractions of the progress): the runes light from light_from to light_to, one after another; they
	## orbit from orbit_from, faster up to pop_at; the buildup climbs from buildup_from to pop_at; the release after.
	var light_from := 0.08
	var light_to := 0.3
	var orbit_from := 0.22
	var buildup_from := 0.38
	var pop_at := 0.72
	## The pop's overshoot and its burst ring, as shares of the progress (about 0.45 s and 0.55 s of floor 1's 4.0 s).
	var pop_span := 0.11
	var burst_span := 0.14
	## Turns the ring makes over the whole sequence.
	var orbit_turns := 2.2
	## The sound (AudioEvents plays it): its cue id and where its peak is in the file (s), so the peak meets pop_at.
	var cue := &"arrival_altar"
	var cue_peak_s := 2.3


var look: Look
var body := Node3D.new()
## The ring the floating runes hang from (it turns: the orbit).
var ring := Node3D.new()
var runes: Array[MeshInstance3D] = []
var jewels: Array[MeshInstance3D] = []
var panels: Array[MeshInstance3D] = []
var swirl: MeshInstance3D
var landing: MeshInstance3D
var shock: MeshInstance3D
var light := OmniLight3D.new()
var motes := CPUParticles3D.new()
var dust := CPUParticles3D.new()
## The owner's model is drawn, the sigil sheet drew the runes (tests read both).
var uses_model := false
var uses_sheet := false
var calm := false
## The trigger's progress last posed (-1: at rest), the share of runes lit at rest, the buildup's energy (0..1), the
## ring's angle (rad) and whether the sequence has run once (its runes then rest dimly lit). Tests read them.
var progress := -1.0
var share := 0.0
var energy := 0.0
var angle := 0.0
var woken := false
var _rune_glow := PackedFloat32Array()
var _jewel_glow := PackedFloat32Array()
var _rune_mats: Array[Material] = []
var _jewel_mats: Array[StandardMaterial3D] = []
var _panel_mat := StandardMaterial3D.new()
var _landing_mat := StandardMaterial3D.new()
var _shock_mat := StandardMaterial3D.new()
var _swirl_mat: Material
var _t := 0.0


## Floor 1's arrival (SA, Q16: 4.0 s): blue.
static func arrival() -> Look:
	return Look.new()


## The final approach's altar (FA, C28-C31): purple, darker stone, more runes, fewer jewels; its runes are lit by the
## pylons (pose's `share`) and the buildup (about 3 s) starts them spinning at once, with a longer climb to the rise.
static func final() -> Look:
	var l := Look.new()
	l.color = VIOLET
	l.core = VIOLET_CORE
	l.stone = Color("#3B3442")
	l.runes = 12
	l.rune_radius = 2.8
	l.jewels = 6
	l.light_from = 0.0
	l.light_to = 0.08
	l.orbit_from = 0.0
	l.buildup_from = 0.05
	l.pop_at = 0.82
	l.orbit_turns = 2.6
	l.cue = &"final_altar"
	l.cue_peak_s = 2.2
	return l


func _init(p_look: Look = null) -> void:
	name = "AltarStage"
	look = p_look if p_look != null else arrival()
	_build()
	pose(-1.0)


## Stands it at `sim_pos` (the hero's start, or the approach's altar).
func setup(sim_pos: Vector2) -> void:
	position = SimPlane.to_3d(sim_pos)
	calm = ViewPrefs.reduced_motion
	pose(progress, share)


## The pose at the trigger's progress `p` (0..1; < 0: at rest), with `p_share` (0..1) of the runes lit at rest (the
## final altar's pylons).
func pose(p: float, p_share: float = 0.0) -> void:
	progress = p
	share = clampf(p_share, 0.0, 1.0)
	var running := p >= 0.0
	if running and p >= look.pop_at:
		woken = true
	energy = buildup(p) if running else 0.0
	if running and not calm:
		angle = TAU * look.orbit_turns * orbit_share(p)
	ring.rotation.y = -angle
	for i in runes.size():
		_rune_glow[i] = rune_glow(i)
	for j in jewels.size():
		_jewel_glow[j] = jewel_glow(j)
	_apply()


## The buildup's energy at `p`: climbing from buildup_from to the pop, gone by the end.
func buildup(p: float) -> float:
	if p < 0.0:
		return 0.0
	var up := smoothstep(look.buildup_from, look.pop_at, p)
	return up * up * (1.0 - smoothstep(look.pop_at, 1.0, p))


## The share (0..1) of the sequence's turns made by `p`: none before orbit_from, then a speed rising as the square of
## the way to the pop, then falling as the square of what is left (the release): the speed is highest at the pop.
func orbit_share(p: float) -> float:
	var a := look.orbit_from
	var b := look.pop_at
	if p <= a:
		return 0.0
	var total := (1.0 - a) / 3.0
	if p <= b:
		var u := (p - a) / maxf(b - a, 0.001)
		return (b - a) / 3.0 * u * u * u / total
	var v := clampf((p - b) / maxf(1.0 - b, 0.001), 0.0, 1.0)
	return ((b - a) / 3.0 + (1.0 - b) / 3.0 * (1.0 - (1.0 - v) * (1.0 - v) * (1.0 - v))) / total


## When rune `i` lights (progress): one after another round the ring from light_from to light_to.
func rune_light_at(i: int) -> float:
	var n := maxi(1, look.runes - 1)
	return look.light_from + (look.light_to - look.light_from) * float(i) / float(n)


## Rune `i`'s glow now (0..1+; the buildup pushes it past 1, the release lets it down to REST_GLOW).
func rune_glow(i: int) -> float:
	var lit := 1.0 if float(i) < share * look.runes - 0.001 else 0.0
	var p := progress
	if p >= 0.0:
		var at := 0.0 if calm else rune_light_at(i)
		var span := look.light_to if calm else LIGHT_FADE
		lit = maxf(lit, smoothstep(at, at + span, p))
		var settle := 1.0 - (1.0 - REST_GLOW) * smoothstep(look.pop_at, 1.0, p)
		return lit * (settle + 1.4 * buildup(p))
	return maxf(lit, REST_GLOW if woken else 0.0)


## Jewel `j`'s glow: it lights with the rune nearest it, round the ring in the same order.
func jewel_glow(j: int) -> float:
	var i := int(floor(float(j) * look.runes / maxf(1.0, look.jewels)))
	return rune_glow(mini(i, look.runes - 1))


func rune_glow_now(i: int) -> float:
	return _rune_glow[i]


func jewel_glow_now(j: int) -> float:
	return _jewel_glow[j]


## The landing's ring of light running out across the floor: `t` 0..1 through it (outside that: none).
func set_burst(t: float) -> void:
	if t < 0.0 or t >= 1.0:
		shock.visible = false
		return
	shock.visible = true
	var s := 1.0 + (BURST_REACH - 1.0) * (1.0 - (1.0 - t) * (1.0 - t))
	shock.scale = Vector3(s, 1.0, s)
	_shock_mat.albedo_color = Color(look.core, 0.9 * (1.0 - t))


## A puff of dust off the top's rim (the landing).
func puff() -> void:
	dust.restart()


func _process(delta: float) -> void:
	if calm:
		return
	_t += delta
	for i in runes.size():
		runes[i].position.y = look.rune_height + BOB * sin(_t * TAU * BOB_HZ + i * 1.7)
	if energy > 0.0 and _swirl_mat is ShaderMaterial:
		(_swirl_mat as ShaderMaterial).set_shader_parameter("turn", -angle * 2.0 - _t * 3.0)


func _apply() -> void:
	for i in runes.size():
		var g := _rune_glow[i]
		runes[i].visible = g > 0.01
		var m := _rune_mats[i]
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("alpha", clampf(g, 0.0, 2.0))
		elif m is StandardMaterial3D:
			(m as StandardMaterial3D).albedo_color = Color(
				look.color.lerp(look.core, 0.3), clampf(g, 0, 1)
			)
	for j in jewels.size():
		var m := _jewel_mats[j]
		m.emission_energy_multiplier = 0.05 + 3.5 * _jewel_glow[j]
		m.albedo_color = look.color.darkened(0.75 - 0.45 * clampf(_jewel_glow[j], 0.0, 1.0))
	var lit := 0.0
	for g in _rune_glow:
		lit += minf(g, 1.0)
	lit /= maxf(1.0, runes.size())
	_panel_mat.emission_energy_multiplier = 0.02 + 2.2 * lit + 2.5 * energy
	_landing_mat.albedo_color = Color(look.core, clampf(0.05 + 0.25 * lit + 0.7 * energy, 0.0, 1.0))
	light.light_energy = LIGHT_IDLE + 0.8 * lit + LIGHT_PEAK * energy
	light.visible = light.light_energy > 0.01
	swirl.visible = energy > 0.01
	swirl.scale = Vector3.ONE * (0.6 + 0.6 * energy)
	if _swirl_mat is ShaderMaterial:
		var sm := _swirl_mat as ShaderMaterial
		sm.set_shader_parameter("alpha", 1.6 * energy)
		if calm or not is_processing():
			sm.set_shader_parameter("turn", -angle * 2.0)
	elif _swirl_mat is StandardMaterial3D:
		(_swirl_mat as StandardMaterial3D).albedo_color = Color(look.color, 0.8 * energy)
	var on := energy > 0.05 and not calm
	if motes.emitting != on:
		motes.emitting = on
	motes.speed_scale = 0.7 + 0.9 * energy


# --- the build ---------------------------------------------------------------------------------------------------


func _emissive(m: StandardMaterial3D, c: Color) -> void:
	m.albedo_color = c.darkened(0.4)
	m.emission_enabled = true
	m.emission = c
	m.roughness = 0.3


func _additive(m: StandardMaterial3D, c: Color) -> void:
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c


func _mesh(n: String, mesh: Mesh, mat: Material, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## The room dresser's placements (StageDresser.dress) without the loose decoration standing within
## `radius` m of `at` (the altar's footprint: rubble or grass would poke through its steps). Pure (the dress worker).
static func clear_decor(placements: Array, at: Vector2, radius: float) -> Array:
	if radius <= 0.0:
		return placements
	var out: Array = []
	for p: Dictionary in placements:
		var kind: StringName = p.get("kind", &"")
		var pos := SimPlane.to_sim((p["xform"] as Transform3D).origin)
		if kind == &"decor" and pos.distance_to(at) < radius:
			continue
		out.append(p)
	return out


## `mesh` with flat normals (each face its own normal): the faceted low-poly look.
static func faceted(mesh: Mesh) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.deindex()
	st.generate_normals()
	return st.commit()


func _build() -> void:
	body.name = "Body"
	add_child(body)
	var model := ShopModels.get_model(MODEL_ID)
	if not model.is_empty():
		uses_model = true
		var mi := _mesh("Model", model["mesh"], null, Vector3.ZERO, body)
		mi.set_surface_override_material(0, model["material"])
	else:
		_build_stand_in()
	var top := STEPS * STEP_H
	var lm := CylinderMesh.new()
	lm.top_radius = LANDING_R
	lm.bottom_radius = LANDING_R
	lm.height = 0.01
	lm.radial_segments = 32
	lm.rings = 1
	_additive(_landing_mat, Color(look.core, 0.05))
	landing = _mesh("Landing", lm, _landing_mat, Vector3(0, top + 0.012, 0), self)
	landing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_swirl(top)
	_build_runes()
	_build_jewels()
	var sm := TorusMesh.new()
	sm.inner_radius = TOP_R - 0.06
	sm.outer_radius = TOP_R + 0.06
	sm.rings = 48
	sm.ring_segments = 4
	_additive(_shock_mat, Color(look.core, 0.0))
	shock = _mesh("Burst", sm, _shock_mat, Vector3(0, 0.06, 0), self)
	shock.scale = Vector3.ONE
	shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shock.visible = false
	light.name = "Light"
	light.light_color = look.color
	light.omni_range = 7.0
	light.position.y = 1.4
	light.shadow_enabled = false
	add_child(light)
	_build_motes(top)
	_build_dust(top)


## The code-made stand-in (the owner's model replaces it): four faceted stone tiers, carved panels in the top, the
## jewels' sockets on the second step.
func _build_stand_in() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = look.stone
	stone.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = look.stone.darkened(0.35)
	dark.roughness = 0.9
	for k in STEPS:
		var r := RADIUS - (RADIUS - TOP_R) * float(k) / float(STEPS - 1)
		var cm := CylinderMesh.new()
		cm.top_radius = r - 0.04
		cm.bottom_radius = r + 0.02
		cm.height = STEP_H
		cm.radial_segments = 14 + 2 * k  # faceted, low-poly
		cm.rings = 1
		var tier := _mesh(
			"Step%d" % k, faceted(cm), stone if k % 2 == 0 else dark, Vector3.ZERO, body
		)
		tier.position.y = STEP_H * (k + 0.5)
		tier.rotation.y = 0.21 * k  # the facets don't line up: worn, laid stone by stone
	_emissive(_panel_mat, look.color)
	_panel_mat.albedo_color = look.stone.darkened(0.5)
	var top := STEPS * STEP_H
	for k in PANELS:
		var a := TAU * k / PANELS
		var pm := BoxMesh.new()
		pm.size = Vector3(0.46, 0.012, 0.2)
		var p := _mesh(
			"Panel%d" % k,
			pm,
			_panel_mat,
			Vector3(cos(a) * PANEL_R, top + 0.004, sin(a) * PANEL_R),
			body
		)
		p.rotation.y = -a + PI * 0.5
		panels.append(p)
	var ring_in := TorusMesh.new()
	ring_in.inner_radius = PANEL_R + 0.24
	ring_in.outer_radius = PANEL_R + 0.3
	ring_in.rings = 40
	ring_in.ring_segments = 3
	var inlay := _mesh("Inlay", ring_in, _panel_mat, Vector3(0, top, 0), body)
	inlay.scale = Vector3(1.0, 0.2, 1.0)
	var socket_r := (RADIUS + (RADIUS - (RADIUS - TOP_R) / float(STEPS - 1))) * 0.5
	for j in look.jewels:
		var a := TAU * (j + 0.5) / maxf(1.0, look.jewels)
		var so := CylinderMesh.new()
		so.top_radius = 0.1
		so.bottom_radius = 0.13
		so.height = 0.08
		so.radial_segments = 6
		so.rings = 1
		_mesh(
			"Socket%d" % j,
			so,
			dark,
			Vector3(cos(a) * socket_r, STEP_H + 0.04, sin(a) * socket_r),
			body
		)


func _build_runes() -> void:
	ring.name = "Runes"
	add_child(ring)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * look.rune_size
	uses_sheet = FxTextures.get_tex("fx_cast_sigils") != null
	for i in look.runes:
		var a := TAU * i / look.runes
		var mat: Material = null
		if uses_sheet:
			mat = FxTextures.sigil_material(look.color, look.cells[i % look.cells.size()])
		else:
			var sm := StandardMaterial3D.new()
			_additive(sm, Color(look.color, 0.0))
			mat = sm
		_rune_mats.append(mat)
		var r := _mesh(
			"Rune%d" % i,
			quad,
			mat,
			Vector3(cos(a) * look.rune_radius, look.rune_height, sin(a) * look.rune_radius),
			ring
		)
		r.rotation.y = -a + PI * 0.5  # upright, its face out from the centre
		if not uses_sheet:
			r.rotation.z = PI * 0.25  # a diamond
			r.scale = Vector3.ONE * 0.6
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		runes.append(r)
	_rune_glow.resize(look.runes)


func _build_jewels() -> void:
	var socket_r := (RADIUS + (RADIUS - (RADIUS - TOP_R) / float(STEPS - 1))) * 0.5
	var gem := SphereMesh.new()  # an octahedron: four segments, two rings
	gem.radius = 0.11
	gem.height = 0.3
	gem.radial_segments = 4
	gem.rings = 2
	var fm := faceted(gem)
	for j in look.jewels:
		var a := TAU * (j + 0.5) / maxf(1.0, look.jewels)
		var m := StandardMaterial3D.new()
		_emissive(m, look.color)
		m.metallic = 0.2
		_jewel_mats.append(m)
		var g := _mesh(
			"Jewel%d" % j, fm, m, Vector3(cos(a) * socket_r, STEP_H + 0.24, sin(a) * socket_r), self
		)
		g.rotation.y = a
		jewels.append(g)
	_jewel_glow.resize(look.jewels)


func _build_swirl(top: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 3.0
	q.orientation = PlaneMesh.FACE_Y
	_swirl_mat = FxTextures.sigil_material(look.color, 0)
	if _swirl_mat == null:
		var m := StandardMaterial3D.new()
		_additive(m, Color(look.color, 0.0))
		_swirl_mat = m
	swirl = _mesh("Swirl", q, _swirl_mat, Vector3(0, top + 0.03, 0), self)
	swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	swirl.visible = false


## The buildup's particles: motes drawn in from a wide ring to the centre, spiralling up.
func _build_motes(top: float) -> void:
	var mat := StandardMaterial3D.new()
	_additive(mat, Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	quad.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(look.color, 0.0))
	fade.add_point(0.3, Color(look.core, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(look.color, 0.0))
	motes.name = "Motes"
	motes.mesh = quad
	motes.amount = 56
	motes.emitting = false
	motes.lifetime = 1.1
	motes.local_coords = true
	motes.color_ramp = fade
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_axis = Vector3.UP
	motes.emission_ring_radius = look.rune_radius + 0.3
	motes.emission_ring_inner_radius = 1.4
	motes.emission_ring_height = 0.6
	motes.direction = Vector3.UP
	motes.spread = 25.0
	motes.initial_velocity_min = 0.4
	motes.initial_velocity_max = 1.0
	motes.gravity = Vector3(0, 0.6, 0)
	motes.radial_accel_min = -3.5
	motes.radial_accel_max = -2.0
	motes.tangential_accel_min = 2.5
	motes.tangential_accel_max = 4.0
	motes.scale_amount_min = 0.6
	motes.scale_amount_max = 1.5
	motes.position.y = top + 0.2
	add_child(motes)


func _build_dust(top: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(0.24, 0.24)
	quad.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(0.78, 0.76, 0.72, 0.7))
	fade.set_color(1, Color(0.7, 0.68, 0.64, 0.0))
	dust.name = "Dust"
	dust.mesh = quad
	dust.amount = 32
	dust.one_shot = true
	dust.emitting = false
	dust.explosiveness = 0.95
	dust.lifetime = 0.8
	dust.local_coords = false
	dust.color_ramp = fade
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust.emission_ring_axis = Vector3.UP
	dust.emission_ring_radius = TOP_R
	dust.emission_ring_inner_radius = TOP_R * 0.85
	dust.emission_ring_height = 0.05
	dust.direction = Vector3(1, 0.2, 0)
	dust.spread = 180.0
	dust.flatness = 0.85
	dust.initial_velocity_min = 1.5
	dust.initial_velocity_max = 3.4
	dust.gravity = Vector3(0, -1.0, 0)
	dust.damping_min = 2.0
	dust.damping_max = 3.0
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 1.8
	dust.position.y = top + 0.05
	add_child(dust)

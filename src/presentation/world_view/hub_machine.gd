class_name HubMachine
extends Node3D
## v0.9.0 HB (PLAN W42: "the hub portal sends the player into the run; the blue altar is their arrival point"): the
## Portal Machine in the hub's centre. The owner's model (`hub_portal_machine`, delivered 2026-10-22: a tall upright
## stone ring on a stepped platform, "no glow, nothing inside the ring") draws the machine; the code fills its ring.
## Without the model, the stand-in reuses SA's altar (AltarStage.arrival(): the stepped dais, the floating blue runes
## and the jewels, lit at rest) under an upright rune ring on two stone pylons. Either way the ring holds the layered
## glow of the VX bar: a swirling portal, an emissive inlay, a soft halo with a white-hot centre, a pool of light, a
## real light and motes rising. When the hero stands at it (focus) it brightens (and the altar's runes turn faster).
## `looped` (the hub state machine_looped: an Ascension taken) adds a violet outer ring turning the other way.
## Presentation only (EI-07); the clock is a look, never an outcome.

## The stand-in's ring (m): its radius and its centre's height over the dais; the pylons' spread.
const RING_R := 1.3
const RING_Y := 1.95
const PYLON_X := 1.55
## The owner's ring, as shares of his model's height (measured off the 1920 x 1080 shots; starting values): the
## ring's centre height and its opening's radius, and how far in front of the model's middle its face is (m).
const MODEL_RING_Y := 0.53
const MODEL_RING_R := 0.25
const MODEL_RING_Z := 0.0
## v0.9.0 HB2: the climb to the owner's ring (plan m, measured on his model drawn 4.6 m tall): the foot of its front
## steps, their top (the dais, MODEL_DAIS_H m up) and the ring's plane (the dais runs through it).
const MODEL_STEPS_FOOT := -2.75
const MODEL_STEPS_TOP := -1.0
const MODEL_DAIS_H := 1.28
## How far past the ring the hero is gone (m).
const THROUGH := 0.6
## How fast the altar's runes turn (rad/s) at rest and with the hero at the machine.
const TURN_IDLE := 0.25
const TURN_FOCUS := 0.9

var altar := AltarStage.new(AltarStage.arrival())
var stand_in: Node3D
## The owner's model (null: the stand-in draws).
var model: MeshInstance3D
var portal: MeshInstance3D
var outer: MeshInstance3D
var core_glow: Dictionary
var looped := false
var focus := 0.0
## v0.9.0 HB2: the portal's flare as the hero crosses it (0 rest .. 1 full), and its burst of light motes.
var flare := 0.0
var burst: CPUParticles3D
var ring_height := 0.0
var _dais_h := MODEL_DAIS_H
var _focus_shown := 0.0
var _t := 0.0


func _init() -> void:
	name = "PortalMachine"
	stand_in = HubProps.stand_in(self)
	var ring_y := _build_stand_in()
	var ring_r := RING_R
	var ring_z := 0.0
	model = HubProps.owner_model(self, &"hub_portal_machine", Vector3.ZERO, stand_in)
	if model != null:
		var h := model.mesh.get_aabb().size.y
		ring_y = h * MODEL_RING_Y
		ring_r = h * MODEL_RING_R
		ring_z = MODEL_RING_Z
	var inlay := TorusMesh.new()
	inlay.inner_radius = ring_r - 0.05
	inlay.outer_radius = ring_r + 0.03
	inlay.rings = 48
	inlay.ring_segments = 6
	var band_glow := HubProps.mesh(
		self,
		"RingGlow",
		inlay,
		HubProps.emissive(HubProps.BLUE, 3.5),
		Vector3(0, ring_y, ring_z + 0.08)
	)
	band_glow.rotation.x = PI * 0.5
	var q := QuadMesh.new()
	q.size = Vector2.ONE * (ring_r * 2.0 - 0.1)
	portal = HubProps.mesh(
		self, "Portal", q, HubProps.portal_material(), Vector3(0, ring_y, ring_z)
	)
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core_glow = HubProps.glow(
		self,
		"CoreGlow",
		HubProps.BLUE,
		HubProps.BLUE_CORE,
		Vector3(0, ring_y, ring_z + 0.3),
		ring_r * 2.5
	)
	HubProps.motes(self, "Motes", HubProps.BLUE, Vector3(0, 0.3, 0), 2.0, 26)
	var o := TorusMesh.new()
	o.inner_radius = ring_r + 0.32
	o.outer_radius = ring_r + 0.4
	o.rings = 48
	o.ring_segments = 6
	outer = HubProps.mesh(
		self,
		"LoopRing",
		o,
		HubProps.emissive(HubProps.VIOLET, 3.0),
		Vector3(0, ring_y, ring_z + 0.15)
	)
	outer.rotation.x = PI * 0.5
	outer.visible = false
	ring_height = ring_y
	if model == null:
		_dais_h = ring_y - RING_R  # the stand-in's ring sits on its dais
	burst = HubProps.motes(
		self, "Burst", HubProps.BLUE_CORE, Vector3(0, ring_y, ring_z), ring_r, 40
	)
	burst.one_shot = true
	burst.explosiveness = 0.85
	burst.preprocess = 0.0
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = ring_r * 0.6
	burst.direction = Vector3(0, 0, 1)
	burst.spread = 70.0
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.5
	burst.lifetime = 1.0
	burst.emitting = false
	_apply_focus()


## The code stand-in (SA's altar, two pylons, the ring's stone band) under `stand_in`; returns the ring's height.
func _build_stand_in() -> float:
	stand_in.add_child(altar)
	altar.pose(-1.0, 1.0)  # every rune lit at rest
	var top := AltarStage.MODEL_TOP if altar.uses_model else AltarStage.STEPS * AltarStage.STEP_H
	var stone := HubProps.stone(HubProps.STONE_DARK)
	for side in [-1.0, 1.0]:
		HubProps.box(
			stand_in,
			"Pylon",
			Vector3(0.42, RING_Y + 0.4, 0.55),
			stone,
			Vector3(side * PYLON_X, top + (RING_Y + 0.4) * 0.5, 0)
		)
		HubProps.box(
			stand_in,
			"PylonCap",
			Vector3(0.6, 0.18, 0.7),
			HubProps.stone(HubProps.STONE),
			Vector3(side * PYLON_X, top + RING_Y + 0.5, 0)
		)
		HubProps.box(
			stand_in,
			"PylonRune",
			Vector3(0.1, RING_Y * 0.7, 0.03),
			HubProps.emissive(HubProps.BLUE, 2.2),
			Vector3(side * PYLON_X, top + RING_Y * 0.55, 0.29)
		)
	var t := TorusMesh.new()
	t.inner_radius = RING_R - 0.13
	t.outer_radius = RING_R + 0.13
	t.rings = 32
	t.ring_segments = 8
	var band := HubProps.mesh(
		stand_in,
		"RingBand",
		t,
		HubProps.stone(HubProps.STONE_LIT, 0.6),
		Vector3(0, top + RING_Y, 0)
	)
	band.rotation.x = PI * 0.5  # upright, facing south (the camera)
	return top + RING_Y


## v0.9.0 HB2: the hero's climb into the ring, as plan points with their height (x, y: plan m; z: m over the floor):
## the steps' foot, their top, the ring's plane and just past it.
func walk_points() -> Array[Vector3]:
	return [
		Vector3(0.0, MODEL_STEPS_FOOT, 0.0),
		Vector3(0.0, MODEL_STEPS_TOP, _dais_h),
		Vector3(0.0, 0.0, _dais_h),
		Vector3(0.0, THROUGH, _dais_h),
	]


## v0.9.0 HB2: the portal flares as the hero crosses it (k 0..1); its burst of motes fires once as it starts.
func set_flare(k: float) -> void:
	if k > 0.0 and flare <= 0.0 and burst.visible:
		burst.restart()
	flare = k
	_apply_focus()


func set_looped(on: bool) -> void:
	looped = on
	outer.visible = on
	(portal.material_override as ShaderMaterial).set_shader_parameter(
		&"accent_mix", 0.35 if on else 0.0
	)


func _process(delta: float) -> void:
	_focus_shown = move_toward(_focus_shown, focus, delta * 3.0)
	_apply_focus()
	if ViewPrefs.reduced_motion:
		return
	_t += delta
	altar.ring.rotation.y -= delta * lerpf(TURN_IDLE, TURN_FOCUS, _focus_shown)
	if looped:
		outer.rotation.z = -_t * 0.4  # turns in its own plane (the other way)


func _apply_focus() -> void:
	HubProps.set_glow(core_glow, 0.85 + 0.6 * _focus_shown + 1.6 * flare, 1.6)
	(portal.material_override as ShaderMaterial).set_shader_parameter(
		&"strength", 0.9 + 0.5 * _focus_shown + 1.8 * flare
	)

class_name HubMachine
extends Node3D
## v0.9.0 HB (PLAN W42: "the hub portal sends the player into the run; the blue altar is their arrival point"): the
## Portal Machine in the hub's centre. It reuses SA's altar (AltarStage.arrival(): the stepped dais, the floating blue
## runes and the jewels, lit at rest) so the hub's machine and floor 1's altar read as one network, and stands an
## upright rune ring on it: two stone pylons, the ring's emissive band, a swirling portal inside, and the layered glow
## of the VX bar (the core, a soft halo, a pool of light on the dais, a real light, motes rising). When the hero stands
## at it (focus) it brightens and its runes turn faster. `looped` (the hub state machine_looped: an Ascension taken)
## adds a violet outer ring that turns the other way. Presentation only (EI-07); the clock is a look, never an outcome.

const RING_R := 1.3
const RING_Y := 1.95
const PYLON_X := 1.55
## How fast the altar's runes turn (rad/s) at rest and with the hero at the machine.
const TURN_IDLE := 0.25
const TURN_FOCUS := 0.9

var altar := AltarStage.new(AltarStage.arrival())
var ring_band: MeshInstance3D
var portal: MeshInstance3D
var outer: MeshInstance3D
var core_glow: Dictionary
var looped := false
var focus := 0.0
var _focus_shown := 0.0
var _t := 0.0


func _init() -> void:
	name = "PortalMachine"
	add_child(altar)
	altar.pose(-1.0, 1.0)  # every rune lit at rest
	var top := AltarStage.MODEL_TOP if altar.uses_model else AltarStage.STEPS * AltarStage.STEP_H
	var stone := HubProps.stone(HubProps.STONE_DARK)
	var lit_stone := HubProps.stone(HubProps.STONE)
	for side in [-1.0, 1.0]:
		var p := HubProps.box(
			self,
			"Pylon",
			Vector3(0.42, RING_Y + 0.4, 0.55),
			stone,
			Vector3(side * PYLON_X, top + (RING_Y + 0.4) * 0.5, 0)
		)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		HubProps.box(
			self,
			"PylonCap",
			Vector3(0.6, 0.18, 0.7),
			lit_stone,
			Vector3(side * PYLON_X, top + RING_Y + 0.5, 0)
		)
		# A rune strip down each pylon's face (emissive, the network's blue).
		HubProps.box(
			self,
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
	ring_band = HubProps.mesh(
		self, "RingBand", t, HubProps.stone(HubProps.STONE_LIT, 0.6), Vector3(0, top + RING_Y, 0)
	)
	ring_band.rotation.x = PI * 0.5  # upright, facing south (the camera)
	ring_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var inlay := TorusMesh.new()
	inlay.inner_radius = RING_R - 0.05
	inlay.outer_radius = RING_R + 0.03
	inlay.rings = 48
	inlay.ring_segments = 6
	var band_glow := HubProps.mesh(
		self,
		"RingGlow",
		inlay,
		HubProps.emissive(HubProps.BLUE, 3.5),
		Vector3(0, top + RING_Y, 0.1)
	)
	band_glow.rotation.x = PI * 0.5
	var q := QuadMesh.new()
	q.size = Vector2.ONE * (RING_R * 2.0 - 0.1)
	portal = HubProps.mesh(
		self, "Portal", q, HubProps.portal_material(), Vector3(0, top + RING_Y, 0.02)
	)
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core_glow = HubProps.glow(
		self, "CoreGlow", HubProps.BLUE, HubProps.BLUE_CORE, Vector3(0, top + RING_Y, 0.3), 3.2
	)
	HubProps.motes(self, "Motes", HubProps.BLUE, Vector3(0, top + 0.1, 0), 2.0, 26)
	var o := TorusMesh.new()
	o.inner_radius = RING_R + 0.32
	o.outer_radius = RING_R + 0.4
	o.rings = 48
	o.ring_segments = 6
	outer = HubProps.mesh(
		self,
		"LoopRing",
		o,
		HubProps.emissive(HubProps.VIOLET, 3.0),
		Vector3(0, top + RING_Y, -0.05)
	)
	outer.rotation.x = PI * 0.5
	outer.visible = false
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
	HubProps.set_glow(core_glow, 0.85 + 0.6 * _focus_shown, 1.6)
	(portal.material_override as ShaderMaterial).set_shader_parameter(
		&"strength", 0.9 + 0.5 * _focus_shown
	)

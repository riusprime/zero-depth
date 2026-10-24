class_name TidecallerAvatar
extends BossAvatar
## v0.9.0 NB1 (BOSSES_4_5.md N1; art list §2): The Tidecaller, floor 4's boss: a hunched shell-backed sea priest with a
## bell-headed staff, deep teal and brass. The owner's model (assets/models/bosses/boss_tidecaller.glb) comes cut into
## parts (scripts/assets/nb_prep.py: Body, Staff, Bell, ArmL, Shell); BossModels rigs each part as a bone (the bell
## hanging from the staff) and it plays TidecallerClips, and on top of them (_pose_rig) the tide the sim reads out
## (WorldReader.boss_tide) drives it: the bell swings hard while the room pulls, the shell pulses with every push of
## the water, the long arm reaches out through the pull and sweeps back for the push; a sea-green light at its mask
## and shell follows the clips' glow and the tide. With the file missing it is a code stand-in of the same parts (a
## robe cone, a spiral shell, a staff and bell, a reaching arm, a mask with three glowing slits) posed from the same
## inputs (_pose). Presentation only (EI-07): it reads the sim and moves its own children.

const HEIGHT := 3.2
const WALK_SPEED := 1.4
const STRIDE := 1.2

const ROBE := Color("#1F5A55")
const ROBE_DARK := Color("#143A38")
const SHELL := Color("#B9B3A2")
const BRASS := Color("#B08A4A")
const BRASS_DARK := Color("#6A5228")
const SEA := Color("#7FF0C8")
## Points on the owner's model at rest (metres, model frame, from nb_prep.py's pivots turned to +X front): the mask,
## the bell's mouth, the shell's crown, the reaching hand, the chest (the weak point).
const MODEL_MASK := Vector3(0.6, 2.25, 0.0)
const MODEL_BELL := Vector3(0.32, 2.35, 1.1)
const MODEL_SHELL := Vector3(-0.5, 2.7, 0.0)
const MODEL_HAND := Vector3(0.85, 1.05, -1.2)
const MODEL_CHEST := Vector3(0.65, 1.7, 0.0)
const LIGHT_ENERGY := 1.2

var body := Node3D.new()
var staff := Node3D.new()
var bell := Node3D.new()
var arm := Node3D.new()
var shell := Node3D.new()
var sea_light: OmniLight3D
var _slits: Array[MeshInstance3D] = []
## The tide read each tick (WorldReader.boss_tide): its phase (TIDE_*), progress 0..1, and the bell's ringing in the
## windup; smoothed in frame time.
var _tide_phase := WorldReader.TIDE_NONE
var _tide_progress := 0.0
var _tide_windup := false
var _pull := 0.0
var _push := 0.0
var _swing := 0.0


func sync(reader: WorldReader, i: int) -> void:
	var tide := reader.boss_tide(i)
	_tide_phase = int(tide.get("phase", WorldReader.TIDE_NONE))
	_tide_progress = float(tide.get("progress", 0)) / 1000.0
	_tide_windup = bool(tide.get("windup", false))
	super(reader, i)


## Render scripts and tests set the tide directly: "tide_phase" (TIDE_*), "tide_progress" (0..1).
func apply_state(s: Dictionary) -> void:
	if s.has("tide_phase"):
		_tide_phase = int(s["tide_phase"])
		_tide_progress = float(s.get("tide_progress", 0.0))
	super(s)


func model_id() -> StringName:
	return &"boss_tidecaller"


func _code_nodes() -> Array[Node]:
	return [body, staff, bell, arm, shell]


func _weak_point_at() -> Vector3:
	return MODEL_CHEST if imported != null else Vector3(0.6, 1.6, 0)


func _weak_bone() -> StringName:
	return &"body"


func anchor_names() -> Array[StringName]:
	return [&"weak", &"mask", &"bell", &"shell", &"hand"]


func _anchor(point: StringName) -> Vector3:
	if imported == null:
		var code := {
			&"mask": body.position + Vector3(0.55, 0.85, 0),
			&"bell": staff.position + bell.position,
			&"shell": shell.position,
			&"hand": arm.position + Vector3(0.9, -0.5, 0),
		}
		return code.get(point, weak_core.position)
	var rest := {
		&"mask": [&"body", MODEL_MASK],
		&"bell": [&"bell", MODEL_BELL],
		&"shell": [&"shell", MODEL_SHELL],
		&"hand": [&"arm_l", MODEL_HAND],
	}
	if not rest.has(point):
		return weak_core.position
	return _on_bone(rest[point][0], rest[point][1])


## 0..1: how hard the room pulls (tests).
func pull_amount() -> float:
	return _pull


## 0..1: how hard the room pushes (tests).
func push_amount() -> float:
	return _push


## The bell's swing now (radians; tests).
func bell_swing() -> float:
	return _swing


## A sea-green light at the mask that follows the glow and the tide.
func _build_body() -> void:
	super()
	sea_light = OmniLight3D.new()
	sea_light.name = "SeaLight"
	sea_light.light_color = SEA
	sea_light.light_energy = LIGHT_ENERGY
	sea_light.omni_range = 3.2
	sea_light.shadow_enabled = false
	sea_light.position = MODEL_MASK + Vector3(0.4, 0, 0)
	model.add_child(sea_light)


func _build() -> void:
	var p := parts
	body.name = "Body"
	model.add_child(body)
	# The robe: a wide faceted cone of dark kelp cloth to the ground, a narrower shoulder band, a hood.
	p.piece(
		body,
		BossParts.loft(
			BossParts.ngon(9),
			[[0.0, 1.3, 1.2], [0.5, 0.95, 0.9], [1.0, 0.55, 0.5]],
			Vector3(1, 1.9, 1),
			1,
			0.15
		),
		Vector3.ZERO,
		ROBE
	)
	p.piece(body, BossParts.block(Vector3(0.9, 0.5, 1.4), 2, 0.3), Vector3(0.05, 1.9, 0), ROBE_DARK)
	p.piece(body, BossParts.orb(0.42, 3, 7, 4), Vector3(0.3, 2.25, 0), ROBE_DARK)
	# The brass mask with its three glowing slits.
	p.piece(body, BossParts.block(Vector3(0.14, 0.55, 0.3), 4, 0.2), Vector3(0.62, 2.2, 0), BRASS)
	for k in 3:
		_slits.append(
			p.glow(
				body,
				BossParts.block(Vector3(0.04, 0.2, 0.04), 5 + k),
				Vector3(0.7, 2.25, -0.08 + 0.08 * k),
				SEA,
				2.0
			)
		)
	# The spiral shell on its back: stacked shrinking orbs, the crown highest.
	shell.name = "Shell"
	shell.position = Vector3(-0.4, 2.2, 0)
	model.add_child(shell)
	for k in 4:
		p.piece(
			shell,
			BossParts.orb(0.75 - 0.15 * k, 10 + k, 8, 5),
			Vector3(-0.05 * k, 0.28 * k, 0),
			SHELL
		)
	# The staff in its right hand (+Z) and the bell hanging at its top.
	staff.name = "Staff"
	staff.position = Vector3(0.1, 1.6, 1.05)
	model.add_child(staff)
	p.piece(
		staff,
		BossParts.tube(2.9, 0.06, 20, 6),
		Vector3(0, -1.35, 0),
		BRASS_DARK,
		Vector3(0, 0, PI * 0.5)
	)
	bell.name = "Bell"
	bell.position = Vector3(0.2, 1.1, 0.05)
	staff.add_child(bell)
	var flare := [[0.0, 0.55, 0.55], [0.3, 0.4, 0.4], [1.0, 0.25, 0.25]]
	p.piece(
		bell,
		BossParts.loft(BossParts.ngon(10), flare, Vector3(1, 0.6, 1), 21, 0.05),
		Vector3(0, -0.6, 0),
		BRASS
	)
	# The long reaching left arm (-Z) with webbed claws.
	arm.name = "ArmL"
	arm.position = Vector3(0.1, 1.9, -0.7)
	model.add_child(arm)
	p.piece(
		arm,
		BossParts.tube(1.1, 0.12, 30, 6),
		Vector3(0.05, -0.1, -0.05),
		ROBE_DARK,
		Vector3(0, 0.3, -0.7)
	)
	for k in 3:
		p.piece(
			arm,
			BossParts.crystal(0.45, 0.05, 31 + k),
			Vector3(0.85, -0.55, -0.12 + 0.1 * k),
			BRASS,
			Vector3(0, 0, -1.6)
		)


## The stand-in, posed from the same inputs as the owner's model: the plod, the Pull (the staff up and the bell ringing,
## the arm out), the shell's swell for the rings, the arm's reach for the Undertow, the slam's hunch, the tide.
func _pose(dt: float) -> void:
	var walk := _gait(dt, WALK_SPEED, STRIDE)
	var s := sin(_phase)
	var windup := _state == WorldReader.STATE_WINDUP
	var fade := _act_fade()
	_advance_tide(dt)
	var lift := 0.0
	var swell := 0.0
	var reach := 0.0
	var hunch := 0.0
	match _move:
		WorldReader.MOVE_TIDE:
			lift = _wind if windup else 0.0
		WorldReader.MOVE_PATTERN:
			swell = _wind if windup else fade * 0.4
		WorldReader.MOVE_MARKS:
			reach = _wind if windup else -fade * 0.4
		WorldReader.MOVE_SLAM_RING:
			hunch = _wind * 0.3 if windup else fade
	body.position = Vector3(0, absf(s) * 0.05 * walk - hunch * 0.25 - _stagger * 0.15, 0)
	body.rotation = Vector3(s * 0.04 * walk, 0, -0.06 - hunch * 0.4 + _stagger * 0.15)
	staff.position = Vector3(0.1, 1.6 + lift * 0.45 + absf(s) * 0.05 * walk, 1.05)
	staff.rotation = Vector3(lift * 0.3, 0, s * 0.12 * walk)
	bell.rotation = Vector3(_swing, 0, 0)
	arm.rotation = Vector3(0.7 * _pull - 0.4 * _push, 0, 0.9 * reach + 0.5 * _pull)
	var pulse := _shell_pulse()
	shell.scale = Vector3.ONE * (1.0 + 0.12 * swell + pulse)
	shell.position.y = 2.2 + body.position.y
	var glow := 2.0 + 3.0 * maxf(_pull, _push) + 2.0 * swell
	for m in _slits:
		(m.material_override as StandardMaterial3D).emission_energy_multiplier = (
			glow * (1.0 - 0.6 * _stagger)
		)
	if sea_light != null:
		sea_light.light_energy = LIGHT_ENERGY * (1.0 + maxf(_pull, _push))


## The tide's smoothed amounts and the bell's swing: hard and fast while the room pulls (and through the windup's
## ringing), a slow heave in the push, settling otherwise.
func _advance_tide(dt: float) -> void:
	var pulling := 1.0 if _tide_phase == WorldReader.TIDE_PULL else 0.0
	var pushing := 1.0 if _tide_phase == WorldReader.TIDE_PUSH else 0.0
	_pull = move_toward(_pull, pulling, dt * 3.0)
	_push = move_toward(_push, pushing, dt * 3.0)
	var ringing := maxf(_pull, 1.0 if _tide_windup else 0.0)
	var target := sin(_t * 9.0) * 0.55 * ringing + sin(_t * 2.2) * 0.25 * _push
	if ViewPrefs.reduced_motion:
		target *= 0.4
	_swing = lerpf(_swing, target, _rate(14.0, dt))


## The shell's pulse with the water: a beat on each push of the tide.
func _shell_pulse() -> float:
	return 0.07 * _push * maxf(0.0, sin(_t * 5.0)) + 0.03 * _pull * maxf(0.0, sin(_t * 9.0))


func _clip_library() -> Dictionary:
	return TidecallerClips.library()


func _walk_speed() -> float:
	return WALK_SPEED


func _stride() -> float:
	return STRIDE


func _idle_seconds() -> float:
	return 3.2


## After the clips: the tide's bell swing (on top of the clips' ring), the shell's pulse, the arm out through the pull
## and swept back in the push; the light follows the glow and the tide.
func _pose_rig(dt: float) -> void:
	var an := animator
	_advance_tide(dt)
	poser.turn(&"bell", Vector3.RIGHT, _swing + an.param(&"ring"))
	poser.stretch(&"shell", 1.0 + _shell_pulse())
	poser.turn(&"arm_l", Vector3.RIGHT, 0.5 * _pull - 0.3 * _push)
	poser.turn(&"arm_l", Vector3.BACK, 0.35 * _pull)
	if sea_light != null:
		var glow := maxf(0.0, 1.0 + 0.6 * an.param(&"glow") + 0.8 * maxf(_pull, _push))
		sea_light.light_energy = LIGHT_ENERGY * glow * (1.0 - 0.6 * _stagger)
		sea_light.position = _on_bone(&"body", MODEL_MASK) + Vector3(0.4, 0, 0)

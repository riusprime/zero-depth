class_name ClockworkJudgeAvatar
extends BossAvatar
## v0.9.0 NB3 (BOSSES_4_5.md N3; art list §2; PLAN NB: "can you ignore the skeleton?"): The Clockwork Judge, floor
## 5's boss: a tall brass automaton with a clock-face chest and two pendulum arms ending in gavels, gold and black. The
## owner's model (assets/models/bosses/boss_clockwork_judge.glb) comes cut into parts (scripts/assets/nb_prep.py:
## Body, ArmL, ArmR, Gears, HandHour, HandMinute; its broken skeleton dropped); BossModels rigs each part as a bone and
## it plays ClockworkJudgeClips, and on top of them (_pose_rig) the sim's echo (WorldReader.boss_echo) drives it: the
## clock hands sweep, faster and faster as the echo records the player's path and racing while it replays; the waist
## gears turn (whirring in the echo and the Gear Spiral); the pendulum arms keep a slow swing, and the Verdict's gavel
## sways over its square as it locks before the clip swings it down. A gold light at the clock face follows the clips'
## glow and the echo. With the file missing it is a code stand-in of the same parts (a tall clock-case body, a round
## face with two hands, a gear cage at the waist, a crown of gears with a lens eye, two thin arms with gavel weights)
## posed from the same inputs (_pose). Presentation only (EI-07): it reads the sim and moves its own children.

const HEIGHT := 3.6
const WALK_SPEED := 1.3
const STRIDE := 1.0

const BRASS := Color("#C99A3A")
const BRASS_DARK := Color("#6E5020")
const IRON := Color("#1E1C1F")
const FACE := Color("#E8DDB8")
const GOLD := Color("#FFC94A")
## Points on the owner's model at rest (metres, model frame: nb_prep.py's pivots turned to +X front): the lens eye,
## the clock face's centre, the gear cage, the gavels' heads.
const MODEL_EYE := Vector3(0.3, 3.25, 0.0)
const MODEL_CLOCK := Vector3(0.32, 2.32, 0.0)
const MODEL_GEARS := Vector3(0.22, 1.55, 0.0)
const MODEL_GAVEL_L := Vector3(0.05, 0.55, -0.97)
const MODEL_GAVEL_R := Vector3(0.05, 0.55, 0.97)
const LIGHT_ENERGY := 1.3
## The minute hand's sweep at rest (radians a second) and at the echo's height.
const HAND_REST := TAU / 30.0
const HAND_FAST := TAU * 1.6

var body := Node3D.new()
var face := Node3D.new()
var hour := Node3D.new()
var minute := Node3D.new()
var gears := Node3D.new()
var arm_l := Node3D.new()
var arm_r := Node3D.new()
var clock_light: OmniLight3D
var _eye: MeshInstance3D
var _face_glow: MeshInstance3D
## The echo read each tick (WorldReader.boss_echo): how far it has recorded (0..1), its phase (ECHO_*), and the
## Verdict's lock; smoothed in frame time.
var _recording := 0.0
var _echo_phase := WorldReader.ECHO_NONE
var _verdict_lock := 0.0
var _verdict_on := false
var _rush := 0.0
var _minute := 0.0
var _gear := 0.0
var _sway := 0.0


func sync(reader: WorldReader, i: int) -> void:
	var e := reader.boss_echo(i)
	_recording = float(e.get("recording", 0)) / 1000.0
	_echo_phase = int(e.get("phase", WorldReader.ECHO_NONE))
	var v: Dictionary = e.get("verdict", {})
	_verdict_on = not v.is_empty()
	_verdict_lock = 1.0 if bool(v.get("locked", false)) else 0.0
	super(reader, i)


## Render scripts and tests set the echo directly: "echo_recording" (0..1), "echo_phase" (ECHO_*).
func apply_state(s: Dictionary) -> void:
	if s.has("echo_phase"):
		_echo_phase = int(s["echo_phase"])
		_recording = float(s.get("echo_recording", 1.0))
	super(s)


func model_id() -> StringName:
	return &"boss_clockwork_judge"


func _code_nodes() -> Array[Node]:
	return [body, face, hour, minute, gears, arm_l, arm_r]


func _weak_point_at() -> Vector3:
	return MODEL_CLOCK if imported != null else Vector3(0.36, 2.3, 0)


func _weak_bone() -> StringName:
	return &"body"


func anchor_names() -> Array[StringName]:
	return [&"weak", &"eye", &"clock", &"gears", &"gavel_l", &"gavel_r"]


func _anchor(point: StringName) -> Vector3:
	if imported == null:
		var code := {
			&"eye": body.position + Vector3(0.3, 3.25, 0),
			&"clock": body.position + face.position,
			&"gears": gears.position,
			&"gavel_l": arm_l.position + arm_l.basis * Vector3(0, -1.9, 0),
			&"gavel_r": arm_r.position + arm_r.basis * Vector3(0, -1.9, 0),
		}
		return code.get(point, weak_core.position)
	var rest := {
		&"eye": [&"body", MODEL_EYE],
		&"clock": [&"body", MODEL_CLOCK],
		&"gears": [&"gears", MODEL_GEARS],
		&"gavel_l": [&"arm_l", MODEL_GAVEL_L],
		&"gavel_r": [&"arm_r", MODEL_GAVEL_R],
	}
	if not rest.has(point):
		return weak_core.position
	return _on_bone(rest[point][0], rest[point][1])


## The minute hand's angle now (radians; tests).
func minute_angle() -> float:
	return _minute


## How fast the hands sweep now (radians a second; tests): faster as the echo records.
func hand_speed() -> float:
	return HAND_REST + (HAND_FAST - HAND_REST) * _rush


## The gears' turn now (radians; tests).
func gear_angle() -> float:
	return _gear


## A gold light at the clock face that follows the glow and the echo.
func _build_body() -> void:
	super()
	clock_light = OmniLight3D.new()
	clock_light.name = "ClockLight"
	clock_light.light_color = GOLD
	clock_light.light_energy = LIGHT_ENERGY
	clock_light.omni_range = 3.4
	clock_light.shadow_enabled = false
	clock_light.position = MODEL_CLOCK + Vector3(0.45, 0, 0)
	model.add_child(clock_light)


func _build() -> void:
	var p := parts
	body.name = "Body"
	model.add_child(body)
	# The tall clock case on spindly legs and a wide flat base, a high collar, a crown of stacked gears.
	p.piece(body, BossParts.block(Vector3(1.1, 0.12, 1.3), 1, 0.2), Vector3(0, 0.06, 0), IRON)
	var up := Vector3(0, 0, PI * 0.5)  # a tube along +X turned to stand up
	for side: float in [-0.3, 0.3]:
		p.piece(body, BossParts.tube(0.75, 0.06, 2, 6), Vector3(0, 0.12, side), BRASS_DARK, up)
	var case_levels := [[0.0, 0.42, 0.42], [0.5, 0.5, 0.48], [1.0, 0.46, 0.44]]
	p.piece(
		body,
		BossParts.loft(BossParts.ngon(6), case_levels, Vector3(1, 2.1, 1), 3, 0.1),
		Vector3(0, 0.85, 0),
		IRON
	)
	p.piece(body, BossParts.block(Vector3(0.7, 0.2, 1.1), 4, 0.3), Vector3(0, 2.95, 0), BRASS)
	for k in 3:
		var r := 0.3 - 0.07 * k
		p.piece(
			body,
			BossParts.loft(
				BossParts.ngon(10), [[0.0, r, r], [1.0, r, r]], Vector3(1, 0.12, 1), 5 + k
			),
			Vector3(0, 3.08 + 0.13 * k, 0),
			BRASS
		)
	_eye = p.glow(body, BossParts.orb(0.09, 9, 8, 5), Vector3(0.3, 3.25, 0), GOLD, 3.0)
	# The clock face on the chest, its two hands pinned at the centre.
	face.name = "Face"
	face.position = Vector3(0.36, 2.3, 0)
	body.add_child(face)
	p.piece(face, BossParts.block(Vector3(0.06, 0.62, 0.62), 10, 0.5), Vector3.ZERO, FACE)
	_face_glow = p.glow(
		face, BossParts.block(Vector3(0.02, 0.5, 0.5), 11, 0.5), Vector3(0.03, 0, 0), GOLD, 0.6
	)
	hour.name = "HandHour"
	face.add_child(hour)
	p.piece(hour, BossParts.block(Vector3(0.03, 0.2, 0.04), 12), Vector3(0.05, 0.1, 0), IRON)
	minute.name = "HandMinute"
	face.add_child(minute)
	p.piece(minute, BossParts.block(Vector3(0.03, 0.28, 0.03), 13), Vector3(0.06, 0.14, 0), IRON)
	# The gear cage at the waist (it turns).
	gears.name = "Gears"
	gears.position = Vector3(0.22, 1.55, 0)
	model.add_child(gears)
	for k in 2:  # two toothed discs facing front, the smaller one off-centre
		var r := 0.34 - 0.12 * k
		p.piece(
			gears,
			BossParts.loft(
				BossParts.ngon(12), [[0.0, r, r], [1.0, r, r]], Vector3(1, 0.08, 1), 14 + k
			),
			Vector3(0.04 * k, 0, 0.12 * k),
			BRASS,
			up
		)
	# The two pendulum arms from the shoulders, each with its gavel weight.
	for side in 2:
		var arm := arm_l if side == 0 else arm_r
		arm.name = "ArmL" if side == 0 else "ArmR"
		arm.position = Vector3(0, 2.45, -0.75 if side == 0 else 0.75)
		model.add_child(arm)
		p.piece(arm, BossParts.tube(1.7, 0.05, 20 + side, 6), Vector3(0, -1.7, 0), BRASS_DARK, up)
		p.piece(
			arm,
			BossParts.block(Vector3(0.36, 0.28, 0.28), 22 + side, 0.15),
			Vector3(0, -1.9, 0),
			BRASS
		)


## The stand-in, posed from the same inputs as the owner's model: the stiff walk, the arms' pendulum swing, the echo's
## wide arms, the Verdict's gavel, the slam, the hands and the gears.
func _pose(dt: float) -> void:
	var walk := _gait(dt, WALK_SPEED, STRIDE)
	var s := sin(_phase)
	var windup := _state == WorldReader.STATE_WINDUP
	var fade := _act_fade()
	_advance_clock(dt, 0.0, 0.0)
	var spread := 0.0
	var haul := 0.0
	var slam := 0.0
	match _move:
		WorldReader.MOVE_ECHO, WorldReader.MOVE_PATTERN:
			spread = _wind if windup else fade
		WorldReader.MOVE_VERDICT:
			haul = _wind if windup else -fade
		WorldReader.MOVE_SLAM_RING:
			slam = _wind if windup else -fade
	body.position = Vector3(0, absf(s) * 0.04 * walk - _stagger * 0.12, 0)
	body.rotation = Vector3(s * 0.03 * walk + _stagger * 0.15, 0, -0.1 * spread)
	arm_l.rotation = Vector3(0.9 * spread, 0, s * 0.3 * walk + _sway - 1.8 * slam)
	arm_r.rotation = Vector3(-0.9 * spread, 0, -s * 0.3 * walk - _sway - 2.2 * haul - 1.8 * slam)
	minute.rotation = Vector3(-_minute, 0, 0)
	hour.rotation = Vector3(-_minute / 12.0, 0, 0)
	gears.rotation = Vector3(_gear, 0, 0)
	var glow := 1.0 + 2.5 * _rush
	if _eye != null:
		(_eye.material_override as StandardMaterial3D).emission_energy_multiplier = (
			3.0 * glow * (1.0 - 0.6 * _stagger)
		)
	if _face_glow != null:
		(_face_glow.material_override as StandardMaterial3D).emission_energy_multiplier = 0.6 * glow
	if clock_light != null:
		clock_light.light_energy = LIGHT_ENERGY * glow


## The hands' sweep (faster as the echo records, racing as it replays), the gears' turn and the arms' slow pendulum
## swing (stiller while the Verdict locks: the gavel hangs poised).
func _advance_clock(dt: float, tick: float, spin: float) -> void:
	var replay := _echo_phase != WorldReader.ECHO_NONE
	var target := 1.0 if replay else _recording * _recording
	_rush = lerpf(_rush, target, _rate(5.0, dt))
	var calm := 0.3 if ViewPrefs.reduced_motion else 1.0
	_minute = fposmod(_minute + dt * calm * (hand_speed() + tick), TAU)
	_gear = fposmod(_gear + dt * calm * (0.5 + 2.5 * _rush + spin), TAU)
	var poised := 0.25 if _verdict_on and _verdict_lock > 0.0 else 1.0
	_sway = sin(_t * 1.6) * 0.08 * poised * calm


func _clip_library() -> Dictionary:
	return ClockworkJudgeClips.library()


func _walk_speed() -> float:
	return WALK_SPEED


func _stride() -> float:
	return STRIDE


func _idle_seconds() -> float:
	return 2.4


## After the clips: the hands sweep and the gears turn (plus the clips' tick and spin), the arms' slow pendulum swing;
## the light follows the glow and the echo.
func _pose_rig(dt: float) -> void:
	var an := animator
	_advance_clock(dt, an.param(&"tick"), an.param(&"spin"))
	poser.turn(&"hand_minute", Vector3.RIGHT, -_minute)
	poser.turn(&"hand_hour", Vector3.RIGHT, -_minute / 12.0)
	poser.turn(&"gears", Vector3.RIGHT, _gear)
	poser.turn(&"arm_l", Vector3.BACK, _sway)
	poser.turn(&"arm_r", Vector3.BACK, -_sway)
	if clock_light != null:
		var glow := maxf(0.0, 1.0 + 0.6 * an.param(&"glow") + 1.5 * _rush)
		clock_light.light_energy = LIGHT_ENERGY * glow * (1.0 - 0.6 * _stagger)
		clock_light.position = _on_bone(&"body", MODEL_CLOCK) + Vector3(0.45, 0, 0)

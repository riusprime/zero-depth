class_name LanternShadeAvatar
extends BossAvatar
## v0.9.0 NB4 (BOSSES_4_5.md N4; art list §2; PLAN NB: "Keep the empty hood"): The Lantern Shade, floor 5's second
## boss: a tall gaunt wraith in a long torn violet-black cloak that frays into smoke (it floats), an empty hood, long
## arms of dark wood and iron, a lantern on a short chain in its right hand; violet-black and pale gold. The owner's
## model (assets/models/bosses/boss_lantern_shade.glb) comes cut into parts (scripts/assets/nb_prep.py: Body, ArmL,
## ArmR, HandLantern); BossModels rigs each part as a bone (the lantern hanging from the right arm) and it plays
## LanternShadeClips, and on top of them (_pose_rig) it floats (a slow bob), its cloak sways, and the held lantern
## swings on its chain with its glide and its moves; the lantern's light (a hot core and a soft halo drawn over the
## room's dark, and a pale gold light) flares as Lights Out drains the room into it and as the Snuff reaches, and burns
## low once the room is dark, so the Shade can always be found by its lantern while its body stays in the dark. With
## the file missing it is a code stand-in of the same parts (a tall frayed cloak cone, a deep hood, two long arms, a
## caged lantern on a chain) posed from the same inputs (_pose). Presentation only (EI-07): it reads the sim and moves
## its own children.

const HEIGHT := 3.4
const WALK_SPEED := 1.4
const STRIDE := 1.6

const CLOAK := Color("#1E1428")
const CLOAK_DARK := Color("#0F0A16")
const WOOD := Color("#2A2018")
const IRON := Color("#1A181E")
const GOLD := Color("#FFD98A")
const EMBER := Color("#C890FF")
## Points on the owner's model at rest (metres, model frame: nb_prep.py's pivots turned to +X front): the held
## lantern's glass, the hood's opening, the chest (the weak point).
const MODEL_LANTERN := Vector3(0.07, 1.2, 1.22)
const MODEL_HOOD := Vector3(0.2, 2.95, 0.0)
const MODEL_CHEST := Vector3(0.3, 2.1, 0.0)
const LIGHT_ENERGY := 1.6
## The bob's height (metres) and rate (radians a second); the cloak's sway (radians).
const BOB_M := 0.12
const BOB_RATE := 1.4
const SWAY := 0.05

var body := Node3D.new()
var arm_l := Node3D.new()
var arm_r := Node3D.new()
var lantern := Node3D.new()
var lantern_light: OmniLight3D
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _core_mat := StandardMaterial3D.new()
var _halo_mat := StandardMaterial3D.new()
var _glass: MeshInstance3D
## The room's light read each tick (WorldReader.boss_light): dark, and the Shade lit (hittable); smoothed.
var _dark := 0.0
var _dark_target := 0.0
var _boss_lit := true
var _swing := 0.0
var _swing_v := 0.0
var _flare := 0.0
var _bob := 0.0


func sync(reader: WorldReader, i: int) -> void:
	var l := reader.boss_light()
	_dark_target = 1.0 if bool(l.get("dark", false)) else 0.0
	_boss_lit = bool(l.get("boss_lit", true))
	super(reader, i)


## Render scripts and tests set the dark directly: "dark" (0..1).
func apply_state(s: Dictionary) -> void:
	if s.has("dark"):
		_dark_target = float(s["dark"])
		_dark = _dark_target
	super(s)


func model_id() -> StringName:
	return &"boss_lantern_shade"


func _code_nodes() -> Array[Node]:
	return [body, arm_l, arm_r, lantern]


func _weak_point_at() -> Vector3:
	return MODEL_CHEST if imported != null else Vector3(0.3, 2.1, 0)


func _weak_bone() -> StringName:
	return &"body"


func anchor_names() -> Array[StringName]:
	return [&"weak", &"lantern", &"hood"]


func _anchor(point: StringName) -> Vector3:
	if imported == null:
		var code := {
			&"lantern": arm_r.position + arm_r.basis * Vector3(0, -1.64, 0),
			&"hood": body.position + Vector3(0.2, 2.95, 0),
		}
		return code.get(point, weak_core.position)
	var rest := {&"lantern": [&"hand_lantern", MODEL_LANTERN], &"hood": [&"body", MODEL_HOOD]}
	if not rest.has(point):
		return weak_core.position
	return _on_bone(rest[point][0], rest[point][1])


## The held lantern's light now (0..; tests): its flare over its burn.
func lantern_glow() -> float:
	return _glow_now()


## The lantern's swing on its chain now (radians; tests).
func lantern_swing() -> float:
	return _swing


## The float's height now (metres; tests).
func bob_height() -> float:
	return _bob


func _glow_now() -> float:
	var burn := lerpf(1.0, 0.45, _dark)  # it burns low once the room is dark
	return maxf(0.08, burn + 0.55 * _flare) * (1.0 - 0.5 * _stagger)


## The held lantern's light: a hot core and a soft halo (drawn over the room's dark: the Shade is found by its lantern)
## and a pale gold light.
func _build_body() -> void:
	super()
	_core_mat = _glow_mat(GOLD, 2.4, 0.9)
	_halo_mat = _glow_mat(EMBER.lerp(GOLD, 0.45), 1.0, 0.35)
	_core = _sprite(0.34, _core_mat)
	_halo = _sprite(1.3, _halo_mat)
	lantern_light = OmniLight3D.new()
	lantern_light.name = "LanternLight"
	lantern_light.light_color = GOLD
	lantern_light.light_energy = LIGHT_ENERGY
	lantern_light.omni_range = 3.2
	lantern_light.shadow_enabled = false
	model.add_child(lantern_light)


func _sprite(size: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(mi)
	return mi


func _glow_mat(c: Color, energy: float, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.albedo_color = Color(c * energy, a)
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.35, Color(1, 1, 1, 0.45))
	g.gradient = grad
	m.albedo_texture = g
	return m


func _build() -> void:
	var p := parts
	body.name = "Body"
	model.add_child(body)
	# The cloak: a tall frayed cone from a narrow neck to a wide ragged hem a little off the ground, a deep hood.
	var cloak := [[0.0, 0.62, 0.55], [0.35, 0.52, 0.46], [0.75, 0.36, 0.34], [1.0, 0.2, 0.2]]
	p.piece(
		body,
		BossParts.loft(BossParts.ngon(9), cloak, Vector3(1, 2.6, 1), 3, 0.2),
		Vector3(0, 0.2, 0),
		CLOAK
	)
	var hood := [[0.0, 0.34, 0.34], [0.5, 0.38, 0.36], [1.0, 0.12, 0.12]]
	p.piece(
		body,
		BossParts.loft(BossParts.ngon(8), hood, Vector3(1, 0.75, 1), 4, 0.1),
		Vector3(0, 2.75, 0),
		CLOAK_DARK
	)
	p.piece(body, BossParts.orb(0.24, 5, 8, 5), Vector3(0.22, 3.0, 0), Color("#020104"))
	for side in 2:
		var arm := arm_l if side == 0 else arm_r
		arm.name = "ArmL" if side == 0 else "ArmR"
		arm.position = Vector3(0, 2.24, -0.6 if side == 0 else 0.6)
		model.add_child(arm)
		var up := Vector3(0, 0, PI * 0.5)
		p.piece(arm, BossParts.tube(1.1, 0.06, 10 + side, 6), Vector3(0, -1.1, 0), WOOD, up)
		for f in 3:  # long thin fingers
			p.piece(
				arm,
				BossParts.tube(0.28, 0.018, 14 + f, 4),
				Vector3(0.04 * (f - 1), -1.38, 0.04 * (f - 1)),
				IRON,
				up
			)
	lantern.name = "HandLantern"
	lantern.position = Vector3(0, -1.15, 0)
	arm_r.add_child(lantern)
	p.piece(
		lantern,
		BossParts.tube(0.3, 0.012, 20, 4),
		Vector3(0, -0.3, 0),
		IRON,
		Vector3(0, 0, PI * 0.5)
	)
	p.piece(
		lantern, BossParts.block(Vector3(0.26, 0.04, 0.26), 21, 0.2), Vector3(0, -0.32, 0), IRON
	)
	p.piece(
		lantern, BossParts.block(Vector3(0.26, 0.04, 0.26), 22, 0.2), Vector3(0, -0.66, 0), IRON
	)
	_glass = p.glow(
		lantern, BossParts.block(Vector3(0.2, 0.3, 0.2), 23, 0.1), Vector3(0, -0.49, 0), GOLD, 1.5
	)


## The stand-in, posed from the same inputs as the owner's model: the float, the cloak's sway, the glide's lean, the
## arms of each move, the lantern's swing.
func _pose(dt: float) -> void:
	_gait(dt, WALK_SPEED, STRIDE)
	var windup := _state == WorldReader.STATE_WINDUP
	var fade := _act_fade()
	var raise := 0.0
	var reach := 0.0
	var sweep := 0.0
	var flare := 0.0
	match _move:
		WorldReader.MOVE_PATTERN:
			raise = _wind if windup else fade
			flare = raise * (2.0 if _shielded else 1.0)
		WorldReader.MOVE_MARKS:
			reach = _wind if windup else fade
			flare = -0.5 * reach if windup else 1.0 * fade
		WorldReader.MOVE_SLAM_RING:
			sweep = _wind if windup else -fade
			flare = absf(sweep)
	_advance_float(dt, flare, sweep * 1.5 + _vel.length() * 0.2, 0.0)
	body.position = Vector3(0, _bob - _stagger * 0.4, 0)
	body.rotation = Vector3(sin(_t * 0.9) * SWAY, 0, -0.1 * _walk + _stagger * 0.15)
	arm_l.position = Vector3(0, 2.24 + _bob, -0.6)
	arm_r.position = Vector3(0, 2.24 + _bob, 0.6)
	arm_l.rotation = Vector3(0.8 * raise * 0.6, 0, 1.6 * reach - 0.25 * _walk)
	arm_r.rotation = Vector3(-0.3 * reach, 0, 2.3 * raise + 1.6 * reach + 1.4 * sweep - 0.2 * _walk)
	lantern.rotation = Vector3(0, 0, _swing)
	_light_lantern(arm_r.position + arm_r.basis * Vector3(0, -1.64, 0))


## The float (a slow bob), the lantern's swing on its chain (a damped pendulum kicked by the glide and the clips) and
## the flare, smoothed in frame time.
func _advance_float(dt: float, flare: float, kick: float, drift: float) -> void:
	var calm := 0.3 if ViewPrefs.reduced_motion else 1.0
	_dark = move_toward(_dark, _dark_target, dt * 0.6)
	_bob = (sin(_t * BOB_RATE) * 0.5 + 0.5) * BOB_M * calm + 0.04 * drift * calm
	_flare = lerpf(_flare, flare, _rate(6.0, dt))
	var target := kick * 0.35 + sin(_t * 1.1) * 0.06 * calm
	_swing_v += ((target - _swing) * 9.0 - _swing_v * 2.2) * dt
	_swing += _swing_v * dt * calm


## The lantern's glow at `at` (model space): its core and halo over the dark, and its light.
func _light_lantern(at: Vector3) -> void:
	var g := _glow_now()
	var flick := 0.92 + 0.08 * sin(_t * 17.0) * sin(_t * 6.1)
	for s: MeshInstance3D in [_core, _halo]:
		if s != null:
			s.position = at
	if _core != null:
		_core.scale = Vector3.ONE * (0.8 + 0.35 * g)
		_core_mat.albedo_color = Color(GOLD * (2.4 * g * flick), clampf(0.55 + 0.35 * g, 0.0, 1.0))
	if _halo != null:
		_halo.scale = Vector3.ONE * (0.75 + 0.5 * g)
		var hc := EMBER.lerp(GOLD, clampf(0.3 + 0.3 * g, 0.0, 1.0))
		_halo_mat.albedo_color = Color(hc * (1.0 * g), clampf(0.25 * g, 0.0, 0.8))
	if lantern_light != null:
		lantern_light.position = at
		lantern_light.light_energy = LIGHT_ENERGY * g * flick
	if _glass != null:
		(_glass.material_override as StandardMaterial3D).emission_energy_multiplier = (
			1.5 * g * flick
		)


func _clip_library() -> Dictionary:
	return LanternShadeClips.library()


func _walk_speed() -> float:
	return WALK_SPEED


func _stride() -> float:
	return STRIDE


func _idle_seconds() -> float:
	return 3.2


## After the clips: it floats, its cloak sways, the lantern swings on its chain (the glide and the clips' swing kick
## it), and its light follows the clips' flare and burns low in the dark.
func _pose_rig(dt: float) -> void:
	var an := animator
	_advance_float(
		dt, an.param(&"flare"), an.param(&"swing") + _vel.length() * 0.25, an.param(&"drift")
	)
	poser.shift(&"body", Vector3(0, _bob, 0))
	var sway := sin(_t * 0.9) * SWAY * (1.0 + an.param(&"drift"))
	poser.turn(&"body", Vector3.RIGHT, sway)
	poser.turn(&"body", Vector3.BACK, sin(_t * 0.7 + 1.0) * SWAY * 0.6)
	poser.turn(&"hand_lantern", Vector3.BACK, _swing)
	poser.turn(&"hand_lantern", Vector3.RIGHT, _swing * 0.3)
	_light_lantern(_on_bone(&"hand_lantern", MODEL_LANTERN))

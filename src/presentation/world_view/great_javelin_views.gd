class_name GreatJavelinViews
extends Node3D
## The Warlord's great javelin, read from the sim (WorldReader.boss_great_javelin; EI-07), never
## decided here: the fan's javelin at GREAT_SCALE (BossSignatureViews.javelin_mesh and its hot shader), flying level
## along its line (out, and back the way it came), or planted leaning as the small ones do. Embedded, it vibrates with
## an amplitude from the sim's "shake" (harder as a quake pulse nears, hardest through the recall line; none with
## reduced motion). Where it lands it sticks in the stone: the slam's cracks, chips and grit thrown up once
## (GroundSlamViews), a crack mark on the floor, and a low kick of dust on each pulse. The ring and its pulse are
## StoneSpikeViews' quake rings; the lines are TelegraphViews'.

const GREAT_SCALE := 2.2
## Its flight's height (m) and how far its planted head sinks into the floor.
const FLY_Y := 1.5
const SINK := 0.4
const SHAKE_ROT := 0.08  # radians at full shake
const SHAKE_POS := 0.07  # metres at full shake
const CRACK_RADIUS := 2.2
## Its landing: the slam's cracks, chips and grit (no big rocks or heaved plates: a spear, not a boulder), this
## wide (m); a pulse's low dust kick, this wide.
const LAND_M := 1.8
const LAND := (
	GroundSlamViews.P_MID
	| GroundSlamViews.P_GRIT
	| GroundSlamViews.P_DUST
	| GroundSlamViews.P_CRACK
)
const PULSE_M := 1.4

## Its landing and its pulses' dust.
var slams := GroundSlamViews.new(3)
var _mm := MultiMeshInstance3D.new()
var _mat := ShaderMaterial.new()
var _tick := 0
var _state := {}
var _shake := 0.0
var _once := {}  # one-shot effects' keys already played (key -> tick)
var _slammed := {}  # the landings and pulses already slammed (key -> tick)


func _init() -> void:
	name = "GreatJavelins"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = BossSignatureViews.javelin_mesh()
	mm.instance_count = 1
	mm.visible_instance_count = 0
	_mm.multimesh = mm
	var sh := Shader.new()
	sh.code = BossSignatureViews.JAVELIN_SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("hot", BossSignatureViews.HOT)
	_mm.material_override = _mat
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_mm.extra_cull_margin = 16384.0
	add_child(_mm)
	add_child(slams)


func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	var boss := reader.boss_index()
	_state = reader.boss_great_javelin(boss) if boss >= 0 else {}
	_slam()
	_draw(float(_tick))


func _process(_delta: float) -> void:
	if not _state.is_empty():
		_draw(float(_tick) + Engine.get_physics_interpolation_fraction())


## True while a great javelin is drawn (tests and the shots).
func shown() -> bool:
	return not _state.is_empty()


## The vibration the last draw used, 0..1 (tests: follows the sim's "shake").
func shake() -> float:
	return _shake


func _draw(now: float) -> void:
	var mm := _mm.multimesh
	if _state.is_empty():
		mm.visible_instance_count = 0
		_shake = 0.0
		return
	var phase := int(_state["phase"])
	var flying := (
		phase == WorldReader.GREAT_JAVELIN_THROW or phase == WorldReader.GREAT_JAVELIN_RETURN
	)
	var yaw := SimPlane.yaw_of(int(_state["angle"]))
	var length := BossSignatureViews.JAVELIN_LENGTH * GREAT_SCALE
	var glow := 0.0
	var b: Basis
	var o: Vector3
	if flying:
		var t := clampf(
			(now - float(_state["from_tick"])) / maxf(1.0, float(_state["life"])), 0.0, 1.0
		)
		var at := (_state["at"] as Vector2).lerp(_state["to"], t)
		b = Basis(Vector3.UP, yaw)
		var dir := b * Vector3(1, 0, 0)
		o = SimPlane.to_3d(at, FLY_Y) - dir * length * 0.5
		glow = 1.0
		_shake = 0.0
	else:
		_shake = 0.0 if ViewPrefs.reduced_motion else float(_state["shake"]) / 1000.0
		var wob := _shake * SHAKE_ROT * sin(now * 1.9)
		var pitch := BossSignatureViews.JAVELIN_PITCH
		b = Basis(Vector3.UP, yaw + wob) * Basis(Vector3(0, 0, 1), -pitch * (1.0 + wob))
		var dir := b * Vector3(1, 0, 0)
		var at3 := SimPlane.to_3d(_state["at"], -SINK)
		at3.x += _shake * SHAKE_POS * cos(now * 2.7)
		at3.z += _shake * SHAKE_POS * sin(now * 2.3)
		o = at3 - dir * length
		glow = _shake
	var sb := b * Basis.from_scale(Vector3.ONE * GREAT_SCALE)
	var buf := PackedFloat32Array(
		[
			sb.x.x,
			sb.y.x,
			sb.z.x,
			o.x,
			sb.x.y,
			sb.y.y,
			sb.z.y,
			o.y,
			sb.x.z,
			sb.y.z,
			sb.z.z,
			o.z,
			glow,
			0.0,
			0.0,
			0.0
		]
	)
	mm.buffer = buf
	mm.visible_instance_count = 1


## The landing's slam once where it sticks, a low dust kick on each pulse.
func _slam() -> void:
	if _state.is_empty():
		_slammed.clear()
		return
	if int(_state["phase"]) != WorldReader.GREAT_JAVELIN_EMBEDDED:
		return
	var at := SimPlane.to_3d(_state["at"], 0.0)
	var key := "i%d" % int(_state["from_tick"])
	if not _slammed.has(key):
		_slammed[key] = _tick
		slams.slam(at, LAND_M, {"parts": LAND, "amount": 0.7})
	var pulse := "p%d:%d" % [int(_state["from_tick"]), int(_state["pulse"])]
	if bool(_state["struck"]) and not _slammed.has(pulse):
		_slammed[pulse] = _tick
		slams.slam(
			at, PULSE_M, {"parts": GroundSlamViews.P_DUST | GroundSlamViews.P_GRIT, "amount": 0.5}
		)


## A VfxCore drawer: the crack mark on the floor once where it lands.
func draw_fx(layer: VfxCore) -> void:
	if _state.is_empty():
		_once.clear()
		return
	var phase := int(_state["phase"])
	if phase == WorldReader.GREAT_JAVELIN_THROW or phase == WorldReader.GREAT_JAVELIN_RETURN:
		return
	var at := SimPlane.to_3d(_state["at"], 0.05)
	var key := "i%d" % int(_state["from_tick"])
	if phase == WorldReader.GREAT_JAVELIN_EMBEDDED and not _once.has(key):
		_once[key] = _tick
		layer.mark(
			int(_state["from_tick"]) * 16 + 7,
			BossStrikeFx.crack_mark(),
			at,
			CRACK_RADIUS,
			BossStrikeViews.CRACK_MARK
		)

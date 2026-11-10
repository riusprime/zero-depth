class_name BladeSwingFx
extends Node3D
## The Blade's edge spark,
## the slash's counterpart of the Gun's cast spark (HeroCastFx): a light spark rides the laser blade's tip while it
## sweeps its arc (KitView.blade_tip_point, the blade as drawn this frame), flares bigger on the swing's hit tick (the
## cut; the finisher's bigger still) and fades as the blade settles. KitView draws the bright slash edge, PlayerAvatar
## the body's wind-up, swing and follow-through; this adds only the spark.
## - Pooled: POOL sparks built once and reused round-robin, one a swing (nothing is made or freed per swing); their
##   materials are built once and only their parameters change.
## - Timing from the sim's swing ticks (WorldReader.swing_tick / swing_active_tick / swing_sweep_ticks), drawn in frame
##   time; it decides nothing (EI-07). Reduced motion keeps it (a light, no movement of its own).

## VFX_PACK N3: the cut also strikes a pack spark (vfx_hit_04) on the tip, gold or the
## step's element; false: the old flare alone.
const PACK_BLADE := true
const POOL := 3
## The spark's size (metres across) riding the tip, at the cut's flare and the finisher's.
const RIDE_SIZE := 0.32
const CUT_SIZE := 0.62
const FINISHER_SIZE := 0.85
## The pack spark's scale at the cut and the finisher's, and the old flare's share left beside it.
const PACK_CUT_SCALE := 0.2
const PACK_FINISHER_SCALE := 0.32
const PACK_FLARE_SHARE := 0.4
## The flare's fade (seconds) and the fade after the sweep (seconds).
const FLARE_SECONDS := 0.1
const FADE_SECONDS := 0.12

static var _shader: Shader

var kit: KitView
## Sparks started and cuts flared (tests).
var started := 0
var cuts := 0
## Pack sparks struck on the cuts (tests).
var pack_cuts := 0
## Each slot: {node, mat, live, sweeping, flare, fade, big}.
var _slots: Array[Dictionary] = []
var _next := 0
var _live := -1
var _last_t := 0
var _last_step := -1


func _init(p_kit: KitView = null) -> void:
	name = "BladeSwingFx"
	kit = p_kit


func _ready() -> void:
	_build()


func _build() -> void:
	if not _slots.is_empty():
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = HeroCastFx.SPARK
	var core := ImpactFx.HERO.lerp(Color.WHITE, 0.6)
	var tint := ThemePalette.color(&"player_core").lerp(ImpactFx.HERO, 0.5)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for k in POOL:
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("core", core)
		m.set_shader_parameter("tint", tint)
		var node := MeshInstance3D.new()
		node.name = "EdgeSpark%d" % k
		node.mesh = quad
		node.material_override = m
		node.visible = false
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		node.extra_cull_margin = 1.0
		add_child(node)
		(
			_slots
			. append(
				{
					"node": node,
					"mat": m,
					"live": false,
					"sweeping": false,
					"flare": 0.0,
					"fade": 1.0,
					"big": 1.0,
				}
			)
		)


func sync(reader: WorldReader) -> void:
	_build()
	var t := reader.swing_tick()
	var step := reader.combo_step()
	if t <= 0 or reader.player_dead():
		if _live >= 0:
			_slots[_live]["sweeping"] = false
		_last_t = 0
		return
	var fresh := _last_t == 0 or t < _last_t or step != _last_step
	_last_step = step
	if fresh:
		var slot := _slots[_next]
		_live = _next
		_next = (_next + 1) % POOL
		slot["live"] = true
		slot["sweeping"] = true
		slot["flare"] = 0.0
		slot["fade"] = 0.0
		slot["big"] = 1.0
		(slot["node"] as Node3D).visible = true
		started += 1
	var s := _slots[_live]
	if t != _last_t and t == reader.swing_active_tick():  # the cut: the hit tick
		s["flare"] = 1.0
		s["big"] = FINISHER_SIZE / CUT_SIZE if reader.is_finisher() else 1.0
		cuts += 1
		if _pack_cut(reader.is_finisher()):
			s["flare"] = PACK_FLARE_SHARE
	s["sweeping"] = t <= reader.swing_sweep_ticks() + 1
	_last_t = t
	_place(s)


func _process(delta: float) -> void:
	for s in _slots:
		if not s["live"]:
			continue
		s["flare"] = maxf(0.0, float(s["flare"]) - delta / FLARE_SECONDS)
		if not s["sweeping"]:
			s["fade"] = minf(1.0, float(s["fade"]) + delta / FADE_SECONDS)
		_place(s)


func _place(s: Dictionary) -> void:
	var node: MeshInstance3D = s["node"]
	var fade := float(s["fade"])
	if fade >= 1.0:
		s["live"] = false
		node.visible = false
		return
	if kit != null and kit.blade_visible():
		node.position = kit.blade_tip_point()
	var flare := float(s["flare"])
	var size := lerpf(RIDE_SIZE, CUT_SIZE * float(s["big"]), flare)
	node.scale = Vector3.ONE * size
	(s["mat"] as ShaderMaterial).set_shader_parameter("fade", (1.0 - fade) * lerpf(0.7, 1.0, flare))


## How many sparks show now and the pool's size (tests).
func live_count() -> int:
	var n := 0
	for s in _slots:
		n += 1 if s["live"] else 0
	return n


func pool_size() -> int:
	return _slots.size()


## The live spark's size now (tests: it flares on the cut).
func spark_size() -> float:
	return (_slots[_live]["node"] as Node3D).scale.x if _live >= 0 else 0.0


## The cut's pack spark (vx8_cut) on the blade's tip; false when the pack is off or its `hit`
## family is full (the old flare then draws alone).
func _pack_cut(finisher: bool) -> bool:
	var pack := BladePack.pack_of(self) if PACK_BLADE and kit != null else null
	if pack == null or not pack.has_room(&"hit"):
		return false
	var tint := kit.edge_color()  # the element's, the heat tier's, else the hero's blue-white: that is gold here
	var colors := BladePack.colors_of(BladePack.GOLD if tint == ImpactFx.HERO else tint)
	var scale := PACK_FINISHER_SCALE if finisher else PACK_CUT_SCALE
	if pack.spawn(&"vx8_cut", kit.blade_tip_point(), scale, colors) == null:
		return false
	pack_cuts += 1
	return true

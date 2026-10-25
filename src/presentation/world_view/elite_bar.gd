class_name EliteBar
extends Node3D
## v0.9.0 EL (owner W58: "larger, above the elite, distinct colour or frame, readable from the iso camera … Consider
## adding a small elite name"; Q26: "Small name above (Recommended)"): the elite's own health bar, built here in
## place of the G2 mockups (none were approved before the step; the owner judges it in play): a bar WIDTH wide (the
## normal enemy bar is ActorViews.BAR_W, 0.55 m) on a dark track inside a thin gold frame (the elite's gold, never the
## hero's colours), the boss bar's red fill (ThemePalette enemy_bar), a lighter chunk that holds where the last hits
## took HP and then drains (as the boss bar's HealthBarTrail), and the elite's name small above it. Turned to face the
## camera each frame (the iso camera's own basis), drawn over the world (no depth test) so walls never hide it, and
## always shown while the elite is out (not only once hurt). Presentation only: ActorViews feeds it the HP share
## (EI-07).

const WIDTH := 1.4
const HEIGHT := 0.11
const FRAME := 0.03
## The chunk holds this long after a hit, then drains at DRAIN a second (bar shares).
const HOLD_S := 0.4
const DRAIN := 0.8
const GOLD := Color("#F2C14E")
const TRACK := Color(0.06, 0.05, 0.05, 0.85)
const CHUNK := Color("#FFD9B0")
const NAME_PX := 28
const NAME_M := 0.18

## Built in setup (v0.9.0 CI: two up-front ones, replaced there, were left orphaned).
var _fill: MeshInstance3D
var _chunk: MeshInstance3D
var _name := Label3D.new()
var _frac := 1.0
var _shown := 1.0
var _hold := 0.0


func setup(name_text: String) -> void:
	var frame := _quad(Vector2(WIDTH + FRAME * 2.0, HEIGHT + FRAME * 2.0), GOLD, 0)
	add_child(frame)
	var track := _quad(Vector2(WIDTH, HEIGHT), TRACK, 1)
	add_child(track)
	_chunk = _quad(Vector2(WIDTH, HEIGHT), CHUNK, 2)
	add_child(_chunk)
	_fill = _quad(Vector2(WIDTH, HEIGHT), ThemePalette.color(&"enemy_bar"), 3)
	add_child(_fill)
	_name.text = name_text
	_name.font_size = NAME_PX
	_name.pixel_size = NAME_M / NAME_PX
	_name.no_depth_test = true
	_name.render_priority = 4
	_name.modulate = GOLD.lightened(0.35)
	_name.outline_size = 8
	_name.outline_modulate = Color(0, 0, 0, 0.9)
	_name.position = Vector3(0, HEIGHT + NAME_M * 0.9, 0)
	_name.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_name)
	_layout()


## The HP share now (0..1). A drop holds the chunk; a heal moves both.
func set_fraction(frac: float) -> void:
	var f := clampf(frac, 0.0, 1.0)
	if f < _frac:
		_hold = HOLD_S
	else:
		_shown = maxf(_shown, f)
	_frac = f
	_layout()


func fraction() -> float:
	return _frac


## The chunk's share now (tests).
func chunk_fraction() -> float:
	return _shown


func name_text() -> String:
	return _name.text


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:  # face the camera (its basis: the iso view never rolls), keeping the bar's own place
		global_basis = cam.global_basis
	if _shown <= _frac:
		return
	if _hold > 0.0:
		_hold -= delta
		return
	_shown = maxf(_frac, _shown - DRAIN * delta)
	_layout()


## The fill and the chunk grow from the bar's left end (in the billboard's own plane).
func _layout() -> void:
	for pair: Array in [[_fill, _frac], [_chunk, _shown]]:
		var n: MeshInstance3D = pair[0]
		var f: float = maxf(pair[1], 0.001)
		n.scale = Vector3(f, 1, 1)
		n.position = Vector3(-WIDTH * 0.5 * (1.0 - f), 0, n.position.z)


func _quad(size: Vector2, c: Color, priority: int) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = priority
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # so render_priority orders the layers
	mi.material_override = m
	mi.position.z = priority * 0.002
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

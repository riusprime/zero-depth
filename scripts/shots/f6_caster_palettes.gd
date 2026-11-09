extends SceneTree
## v0.11.0 F6: the Arc Caster (on the Cinder Priest's model) beside a Cinder Priest, one image per palette candidate for
## the owner. The shipped default is CinderPriestAvatar.LOOKS[KIND_ARC_CASTER] (= candidate A); B and C are only tried
## here, through the avatar's `palette`. Needs a renderer (not --headless); off screen:
##   APPDATA=<temp> godot --path . --position -10000,-10000 --resolution 900x500 -s scripts/shots/f6_caster_palettes.gd
## Writes build/shots/f6/arc_caster_palette_<a|b|c>.png.

const CANDIDATES := {
	"a":
	{
		"role": Color("#8F8CF2"),
		"base": Color.WHITE,
		"gem": Color("#BFF6FF"),
		"ember": Color("#5FD8FF"),
	},
	"b":
	{
		"role": Color("#B0309A"),
		"base": Color.WHITE,
		"gem": Color("#FFFFFF"),
		"ember": Color("#FF5AD0"),
	},
	"c":
	{
		"role": Color("#8A50D8"),
		"base": Color("#7FE6D6"),
		"gem": Color("#3FEBD0"),
		"ember": Color("#29D9B8"),
	},
}
const SIZE := Vector2i(900, 500)

var _vps := {}
var _frame := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots/f6/"))
	for key: String in CANDIDATES:
		_vps[key] = _scene(key)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 10:
		return false
	for key: String in _vps:
		var img: Image = (_vps[key] as SubViewport).get_texture().get_image()
		var png := ProjectSettings.globalize_path(
			"res://build/shots/f6/arc_caster_palette_%s.png" % key
		)
		img.save_png(png)
		print("f6: " + png)
	return true


func _scene(key: String) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene := Node3D.new()
	vp.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#1b1d24")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#9aa3b5")
	env.environment.ambient_light_energy = 0.55
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#8a7d68")  # the Ruins' sand-stone
	floor_mi.material_override = fm
	scene.add_child(floor_mi)
	var iso := Basis(Vector3.UP, deg_to_rad(45.0)) * Basis(Vector3.RIGHT, deg_to_rad(-35.26))
	var right := Basis(Vector3.UP, deg_to_rad(45.0)) * Vector3.RIGHT
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 4.2
	scene.add_child(cam)
	var look := Vector3(0, 0.8, 0)
	cam.look_at_from_position(look + iso * Vector3.BACK * 12.0, look, Vector3.UP)
	cam.current = true
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = "Candidate %s: Arc Caster (left) beside Cinder Priest (right)" % key.to_upper()
	label.position = Vector2(8, 4)
	label.add_theme_font_size_override(&"font_size", 20)
	vp.add_child(label)
	for side in 2:
		var actor := Node3D.new()
		actor.position = right * (-0.9 if side == 0 else 0.9)
		scene.add_child(actor)
		var facing := Node3D.new()
		facing.rotation.y = 0.35
		actor.add_child(facing)
		var a := CinderPriestAvatar.new()
		a.kind = WorldReader.KIND_ARC_CASTER if side == 0 else WorldReader.KIND_CINDER_PRIEST
		if side == 0:
			a.palette = CANDIDATES[key]
		a.setup(Color("#1A1A22"))
		facing.add_child(a)
		a.set_process(false)
		a.apply_state({"tick": 0, "state": WorldReader.STATE_MOVE})
		a.advance(0.016)
	return vp

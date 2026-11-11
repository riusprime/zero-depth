extends SceneTree
## The effects drawn on the GPU against how they looked when the script built them: one fixed, seeded scene per
## effect at the game's iso camera, with ground, a pool of water, a lava strip and a standing body among the effects
## (the draw order and the blending over and behind them), taken at a fixed frame. Run it on a build before a change and
## on one after, then compare the PNGs (a pixel diff; two runs of the same build give the noise floor). With
## --fixed-fps 60 the shaders' TIME and the bolts' flicker are the same frame for frame, run for run.
##   godot --path . --fixed-fps 60 --resolution 1920x1080 --windowed --position -10000,-10000 --audio-driver Dummy \
##     -s scripts/shots/gpu_fx_pairs.gd -- out=build/shots/gpu_fx/<tag>
## Writes <out>/<scene>.png and prints each path. Scenes (scene=<name>, default bolts): bolts (StormPack's held bolts:
## strikes, a chain, a fan of short ones, the shock forks on a body); rings (the Ring form's travelling element rings
## as the attack canvas draws them, VfxLayer.ring followed by their seed: three storm rings of growing size, a fire,
## a void and a frost one, each flying its own way). keys=place draws the same rings keyed by where they are now (the
## way a travelling ring was held before it was followed: its effects taken again from PackFx as it moves), for the
## before/after pair in one build; ab=no_ring_light draws them without their light (the look of that cut).

const SHOT_FRAME := 90
const NOW := 120.0
## The rings scene: [kind, start, metres moved a frame, radius, fade], one per ring.
const RINGS := [
	[&"storm", Vector3(-2.0, 0.05, 0.5), Vector3(0.06, 0, 0.0), 1.2, 1.0],
	[&"storm", Vector3(2.0, 0.05, -2.5), Vector3(0.0, 0, 0.06), 2.0, 1.0],
	[&"storm", Vector3(0.0, 0.05, 2.5), Vector3(0.05, 0, 0.03), 2.8, 0.8],
	[&"fire", Vector3(-1.5, 0.05, -5.0), Vector3(-0.03, 0, 0.05), 2.0, 1.0],
	[&"void", Vector3(4.0, 0.05, 1.0), Vector3(0.04, 0, 0.04), 2.0, 1.0],
	[&"frost", Vector3(-6.0, 0.05, 1.5), Vector3(0.04, 0, 0.05), 1.6, 1.0],
]

var _out := "res://build/shots/gpu_fx/run"
var _scene := "bolts"
var _by_place := false  # keys=place
var _frame := 0
var _layer: VfxLayer
var _fx: PackFx
var _rig: IsoRig


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = "res://" + a.trim_prefix("out=")
		elif a.begins_with("scene="):
			_scene = a.trim_prefix("scene=")
		elif a == "ab=no_ring_light":
			VfxLayer.ring_lights = false
		elif a == "keys=place":
			_by_place = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_stage()
	_fx = PackFx.new()
	root.add_child(_fx)
	_layer = VfxLayer.new()
	_layer.pack_fx = _fx
	root.add_child(_layer)


func _stage() -> void:
	_rig = IsoRig.new()
	root.add_child(_rig)
	_rig.snap_to(Vector3(2, 0, 2))
	_rig.camera.current = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.05, 0.07)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.35, 0.4)
	env.environment.glow_enabled = true
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	_slab(Vector3(2, -0.01, 2), Vector3(20, 0.02, 20), Color(0.32, 0.27, 0.22), 1.0, false)
	_slab(Vector3(-0.5, 0.0, 4.5), Vector3(4, 0.02, 3), Color(0.15, 0.35, 0.55), 0.6, false)  # water
	_slab(Vector3(5.0, 0.0, -0.5), Vector3(2.5, 0.02, 4), Color(1.0, 0.35, 0.05), 1.0, true)  # lava
	_slab(Vector3(2.6, 0.6, 2.4), Vector3(0.7, 1.2, 0.7), Color(0.55, 0.2, 0.25), 1.0, false)  # a body


func _slab(at: Vector3, size: Vector3, c: Color, alpha: float, glow: bool) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.5
	mi.material_override = m
	mi.position = at
	root.add_child(mi)


func _draw_bolts() -> void:
	var cold := VfxLayer.COLD
	var s := _layer._storm
	# A strike from the sky, a chain over the water, a long beam over the lava, a fan of short arcs round the body.
	s.lightning(Vector3(1, 3.5, 1), Vector3(1, 0.05, 1), 0.9, 4.0, 11, cold, 0.5, true, 0, false)
	s.lightning(
		Vector3(-2, 0.6, 3.5), Vector3(1.2, 0.6, 5.5), 1.0, 4.0, 23, cold, 0.5, false, 0, false
	)
	s.lightning(
		Vector3(4.2, 0.6, -2.5), Vector3(5.8, 0.6, 1.8), 0.8, 4.0, 37, cold, 0.6, false, 0, false
	)
	for k in 5:
		var a := TAU * k / 5.0
		var from := Vector3(2.6, 0.7, 2.4)
		var to := from + Vector3(cos(a), 0.2 * (k - 2), sin(a)) * 1.4
		s.lightning(from, to, 1.0, 4.0, 51 + k, cold, 0.3, false, 0, false)
	s.shock(Vector3(0.5, 0.0, 0.0), 0.4, 77, 4.0, 0.9)


func _draw_rings() -> void:
	var now := NOW + _frame
	for k in RINGS.size():
		var r: Array = RINGS[k]
		var c: Vector3 = r[1] + r[2] * _frame
		var sd := int(c.x * 97.0) * 31 + int(c.z * 89.0) if _by_place else 101 + k * 17
		_layer.ring(r[0], c, r[3], r[4], now, sd, not _by_place)


func _process(_delta: float) -> bool:
	_frame += 1
	_layer.begin(NOW + (_frame if _scene == "rings" else 0))
	if _scene == "rings":
		_draw_rings()
	else:
		_draw_bolts()
	_layer.finish()
	if _frame == SHOT_FRAME:
		var img := root.get_viewport().get_texture().get_image()
		var path := _out + "/%s.png" % _scene
		img.save_png(path)
		print("wrote ", ProjectSettings.globalize_path(path))
	return _frame > SHOT_FRAME

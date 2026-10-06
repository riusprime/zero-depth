class_name WorldViewRoot
extends Node3D
## The 3D view of one room: stage, actors, the iso camera and occlusion. It reads the sim only through
## WorldReader (EI-07); the app calls sync() after every tick.

var reader: WorldReader
var stage := StageView.new()
var actors := ActorViews.new()
var rig := IsoRig.new()
var occlusion_enabled := true


func setup(p_reader: WorldReader, palette: Dictionary, arena_half: float) -> void:
	reader = p_reader
	actors.outline_color = palette["outline"]
	add_child(stage)
	add_child(actors)
	add_child(rig)
	stage.build(reader, palette, arena_half)
	sync()
	rig.snap_to(SimPlane.to_3d(reader.player_pos()))


func sync() -> void:
	actors.sync(reader)
	rig.target = SimPlane.to_3d(reader.player_pos())
	if occlusion_enabled:
		var focus: Array[Vector2] = []
		for i in reader.actor_count():
			focus.append(reader.actor_pos(i))
		stage.apply_occlusion(
			Occlusion.select(rig.toward_camera_on_plane(), rig.pitch_deg, focus, stage.wall_specs)
		)
	else:
		stage.apply_occlusion(PackedInt32Array())

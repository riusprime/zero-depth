class_name WorldViewRoot
extends Node3D
## The 3D view of one room: stage, actors, the iso camera and occlusion. It reads the sim only through
## WorldReader (EI-07); the app calls sync() after every tick.

var reader: WorldReader
var stage := StageView.new()
var actors := ActorViews.new()
var kit := KitView.new()
var utility := UtilityView.new()
var telegraphs := TelegraphViews.new()
var hit_feel: HitFeel
var ink := InkPass.new()
var pickups := PickupViews.new()
## Altars, chests and shard gems (v0.3.0 E).
var rewards := RewardViews.new()
var shards := ShardViews.new()
var item_fx: ItemVisuals
## v0.3.0 G: engine statuses and combo payoffs.
var status_fx: StatusVisuals
var gate: PortalGate
var rig := IsoRig.new()
var occlusion_enabled := true


func setup(p_reader: WorldReader, palette: Dictionary, arena_half: float) -> void:
	reader = p_reader
	BossModels.preload_all()  # v0.3.0 L13: the owner's boss models load with the stage, never on a spawn.
	actors.outline_color = palette["outline"]
	add_child(stage)
	add_child(telegraphs)
	add_child(actors)
	add_child(kit)
	add_child(utility)
	add_child(rig)
	add_child(pickups)
	add_child(rewards)
	add_child(shards)
	item_fx = ItemVisuals.new(kit, actors)
	add_child(item_fx)
	status_fx = StatusVisuals.new(actors)
	add_child(status_fx)
	if reader.has_floor():
		gate = PortalGate.new()
		add_child(gate)
		gate.setup(reader.portal_pos(), reader.portal_angle())
	rig.camera.add_child(ink)
	ink.position = Vector3(0, 0, -1)
	hit_feel = HitFeel.new(actors, rig)
	add_child(hit_feel)
	stage.build(reader, palette, arena_half)
	sync()
	rig.snap_to(SimPlane.to_3d(reader.player_pos()))


func sync() -> void:
	telegraphs.sync(reader)
	actors.sync(reader)
	kit.sync(reader)
	utility.sync(reader)
	hit_feel.sync(reader)
	pickups.sync(reader)
	rewards.sync(reader)
	shards.sync(reader)
	item_fx.sync(reader)
	status_fx.sync(reader)
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

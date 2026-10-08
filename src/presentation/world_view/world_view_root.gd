class_name WorldViewRoot
extends Node3D
## The 3D view of one room: stage, actors, the iso camera and occlusion. It reads the sim only through
## WorldReader (EI-07); the app calls sync() after every tick.

## v0.4.0 SC: walls fade for the hero and the enemies within this distance of it, at most this many of them (with a
## crowd, testing every wall against every enemy each frame cost more than the rest of the view; the X-ray
## silhouettes still show the ones farther off).
const OCCLUSION_RADIUS_M := 10.0
const OCCLUSION_FOCUS_MAX := 24

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
## v0.3.0 L18: overclock heat on the hero, vent blasts, steam and embers.
var heat_fx: HeatVisuals
var gate: PortalGate
## v0.5.0 RT: the Deep gate beside it (null on floors without the choice).
var deep_gate: PortalGate
## v0.3.5 PT: the hero's way into the portal and the arrival on a new floor.
var transit := PortalTransitView.new()
## Run flow (v0.3.0 B): the boss door (null without a boss room).
var boss_door: BossDoorView
## The gamble shrine (v0.3.0 L19; null on a floor without one).
var gamble_shrine: GambleShrineView
## Boss challenge (v0.3.0 BX): the closing band, the pull's vortex, enemies dissolving on the summon.
var challenge := BossChallengeView.new()
## v0.3.5 K: the build skills' forecast, streaks, flashes and tracers.
var skill_fx := SkillVisuals.new()
## v0.4.0 BS: bombs, drones, orbit blades, the blink shock; damage numbers (crits big and yellow).
var ability_fx := AbilityVisuals.new()
var damage_numbers := DamageNumbers.new()
## v0.4.0 EN: mines on the floor, Menders' heal beams, Snipers' tracers.
var horde_fx := HordeVisuals.new()
var rig := IsoRig.new()
var occlusion_enabled := true


func setup(p_reader: WorldReader, palette: Dictionary, arena_half: float) -> void:
	reader = p_reader
	BossModels.preload_all()  # v0.3.0 L13: the owner's boss models load with the stage, never on a spawn.
	actors.outline_color = palette["outline"]
	add_child(stage)
	add_child(telegraphs)
	add_child(challenge)
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
	heat_fx = HeatVisuals.new(kit, actors)
	add_child(heat_fx)
	add_child(skill_fx)  # v0.3.5 K
	add_child(ability_fx)  # v0.4.0 BS
	add_child(damage_numbers)
	add_child(horde_fx)  # v0.4.0 EN
	if reader.has_floor():
		gate = PortalGate.new()
		add_child(gate)
		gate.setup(reader.portal_pos(), reader.portal_angle())
	if reader.has_deep_portal():
		deep_gate = PortalGate.new()
		deep_gate.name = "DeepGate"
		add_child(deep_gate)
		deep_gate.setup(reader.deep_portal_pos(), reader.deep_portal_angle())
		deep_gate.set_deep()
	if reader.has_boss_room():
		boss_door = BossDoorView.new()
		add_child(boss_door)
		boss_door.setup(
			reader.boss_door_center(),
			reader.boss_door_angle(),
			reader.boss_door_width(),
			reader.boss_door_half_thickness(),
			palette["cover"]
		)
	if reader.has_gamble():
		gamble_shrine = GambleShrineView.new()
		add_child(gamble_shrine)
		gamble_shrine.setup(reader.gamble_pos())
	add_child(transit)
	transit.setup(actors, gate)
	transit.deep_gate = deep_gate
	rig.camera.add_child(ink)
	ink.position = Vector3(0, 0, -1)
	hit_feel = HitFeel.new(actors, rig)
	add_child(hit_feel)
	stage.build(reader, palette, arena_half)
	sync()
	rig.snap_to(SimPlane.to_3d(reader.player_pos()))


func sync() -> void:
	telegraphs.sync(reader)
	challenge.sync(reader)
	actors.sync(reader)
	kit.sync(reader)
	utility.sync(reader)
	hit_feel.sync(reader)
	pickups.sync(reader)
	rewards.sync(reader)
	shards.sync(reader)
	item_fx.sync(reader)
	status_fx.sync(reader)
	heat_fx.sync(reader)
	transit.sync(reader)  # after the actors: it poses the hero's model
	skill_fx.sync(reader)  # v0.3.5 K
	ability_fx.sync(reader)  # v0.4.0 BS
	damage_numbers.sync(reader)
	horde_fx.sync(reader)  # v0.4.0 EN
	if boss_door != null:
		boss_door.sync(reader)
	if gamble_shrine != null:
		gamble_shrine.sync(reader)
	# v0.5.0 RT: each gate closes when the other one is taken.
	var open := reader.gate_open(WorldReader.ROUTE_NORMAL)
	if gate != null and reader.has_boss_room() and gate.is_sealed() == open:
		gate.set_sealed(not open)
	var deep_open := reader.gate_open(WorldReader.ROUTE_DEEP)
	if deep_gate != null and deep_gate.is_sealed() == deep_open:
		deep_gate.set_sealed(not deep_open)
	rig.target = SimPlane.to_3d(reader.player_pos())
	if occlusion_enabled:
		var focus: Array[Vector2] = []
		var hero := reader.player_pos()
		for i in reader.actor_count():
			var p := reader.actor_pos(i)
			if i == 0 or (p - hero).length() <= OCCLUSION_RADIUS_M:
				focus.append(p)
				if focus.size() > OCCLUSION_FOCUS_MAX:
					break
		stage.apply_occlusion(
			Occlusion.select(rig.toward_camera_on_plane(), rig.pitch_deg, focus, stage.wall_specs)
		)
	else:
		stage.apply_occlusion(PackedInt32Array())

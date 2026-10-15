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
var heal_orbs := HealOrbViews.new()  # v0.4.0 TU (D8)
var item_fx: ItemVisuals
## v0.3.0 G: engine statuses and combo payoffs.
var status_fx: StatusVisuals
## v0.3.0 L18: overclock heat on the hero, vent blasts, steam and embers.
var heat_fx: HeatVisuals
var gate: PortalGate
## v0.5.0 RT: the Deep gate beside it (null on floors without the choice).
var deep_gate: PortalGate
## v0.7.5 AP: the Ascension portal where the gate stands on a run's last floor of a loop (`gate` is null there).
var ascension: AscensionPortal
## v0.3.5 PT: the hero's way into the portal and the arrival on a new floor.
var transit := PortalTransitView.new()
## Run flow (v0.3.0 B): the boss door (null without a boss room).
var boss_door: BossDoorView
## The gamble shrine (v0.3.0 L19; null on a floor without one).
var gamble_shrine: GambleShrineView
## The shop terminal (v0.5.0 SH; null on a floor without one, or whose shop is a stall).
var shop_terminal: ShopTerminalView
## v0.8.0 SR: the shop's tent stall and its vendor (null on a floor without one: no shop, or a terminal).
var shop_stall: ShopStallView
## Boss challenge (v0.3.0 BX): the closing band, the pull's vortex, enemies dissolving on the summon.
var challenge := BossChallengeView.new()
## v0.3.5 K: the build skills' forecast, streaks, flashes and tracers.
var skill_fx := SkillVisuals.new()
## v0.4.0 BS: bombs, drones, orbit blades, the blink shock; damage numbers (crits big and yellow).
var ability_fx := AbilityVisuals.new()
var damage_numbers := DamageNumbers.new()
## v0.4.0 AB: Arc Field, Frost Nova, the fire, the ability combos; the Overrun room's red door frames.
var element_fx := ElementVisuals.new()
var overrun_doors := OverrunDoorViews.new()
## v0.5.5 AR: the sealed arenas' amber frames and barriers, and the dark veil over the rest of the floor while sealed.
var arenas := ArenaViews.new()
## v0.4.0 EN: mines on the floor, Menders' heal beams, Snipers' tracers.
var horde_fx := HordeVisuals.new()
var events := EventPedestalViews.new()  # v0.5.0 EV: event pedestals, the drone's ring, elite crowns
var cores := CoreViews.new()  # v0.6.0 CU: cores on elites and bosses, the steal window, dodge and stun cues
## v0.6.0 MX3: the attack forms drawn from their final specs (element core, heat edge, motion cues), pooled.
var attack_forms := AttackFormView.new()
var modifier_marks := ModifierOverlays.new()  # v0.6.0 MX4: the shell, the charge, the phase, poison, queued attacks
var blade_forms := BladeFormView.new()  # v0.6.5 WN4: crescents, ghost slashes, fissures, sparks, orbiting blades
## v0.7.5 BF1: the hostile fireballs (pooled per look in MultiMeshes) and the bosses' crystal shields and lobbed shells.
var fireballs := FireballViews.new()
## v0.8.0 GF1 (owner O19): the hero's shots as blue pulses (pooled per look in MultiMeshes) and the cast flourish.
var pulses := HeroPulseViews.new()
var cast_fx := HeroCastFx.new()
var boss_shields := BossShieldView.new()
## v0.8.0 AV (owner O7): the Gatekeeper's shock lanes strike as rows of stone spikes.
var spikes := StoneSpikeViews.new()
## v0.8.0 BS1 (owner O5): the Warlord's javelins stuck in the floor and the Brood Mother's eggs.
var signatures := BossSignatureViews.new()

## v0.8.0 AV part 2 (owner O7): every other boss ground attack strikes as a 3D effect.
var strikes := BossStrikeViews.new()
## v0.8.0 FB1 (owner O16): the final boss's shatter between its bodies (the burst, the shards the next rises from).
var final_views := FinalBossViews.new()
var prism_views := PrismViews.new()  # v0.8.0 FB2: the Prism's Cross, her bolts' aim lines, the window
var nemesis_views := NemesisViews.new()  # v0.8.0 FB3: the Nemesis's card casts and dash afterimages
var rig := IsoRig.new()
var occlusion_enabled := true


func setup(p_reader: WorldReader, palette: Dictionary, arena_half: float) -> void:
	reader = p_reader
	# v0.3.0 L13: the owner's boss models load with the stage, never on a spawn (v0.8.0 FB1: the final boss's three
	# only where its fight is: the final arena, the Playground).
	BossModels.preload_all(reader.final_fight() or not reader.has_gate())
	actors.outline_color = palette["outline"]
	add_child(stage)
	add_child(telegraphs)
	add_child(challenge)
	add_child(actors)
	add_child(kit)
	add_child(utility)
	add_child(rig)
	add_child(pickups)
	actors.hero_mood = stage.mood
	rewards.kit_chest = stage.mood != null  # v0.5.9 Step 5: the owner's chest with the new look
	add_child(rewards)
	add_child(shards)
	add_child(heal_orbs)
	item_fx = ItemVisuals.new(kit, actors)
	add_child(item_fx)
	status_fx = StatusVisuals.new(actors)
	add_child(status_fx)
	heat_fx = HeatVisuals.new(kit, actors)
	add_child(heat_fx)
	add_child(skill_fx)  # v0.3.5 K
	add_child(ability_fx)  # v0.4.0 BS
	add_child(element_fx)  # v0.4.0 AB
	add_child(overrun_doors)
	overrun_doors.setup(reader)
	add_child(arenas)  # v0.5.5 AR
	arenas.setup(reader)
	add_child(damage_numbers)
	add_child(horde_fx)  # v0.4.0 EN
	add_child(events)  # v0.5.0 EV
	events.setup(reader)
	add_child(cores)  # v0.6.0 CU
	add_child(attack_forms)  # v0.6.0 MX3
	if stage.mood != null and VfxLayer.available():  # v0.5.9 art: real fire, explosions and lightning
		var layer := VfxLayer.new()
		add_child(layer)
		attack_forms.vfx = layer
		status_fx.use_vfx(layer)
		layer.drawers.append(_draw_prop_fires)  # the fire props' flames (lighting pass, 2026-10-12)
		fireballs.vfx = layer  # v0.8.0 AV: the big fireballs' lights
		layer.drawers.append(fireballs.draw_lights)
		spikes.vfx = layer  # v0.8.0 AV: the spikes' debris, dust, flash and cracks
		layer.drawers.append(spikes.draw_fx)
		strikes.vfx = layer  # v0.8.0 AV part 2: the strikes' sprites, lights, marks and explosions
		layer.drawers.append(strikes.draw_fx)
	element_fx.forms_drawn = true  # MX3 draws the spec forms (rings, spec patches, bombs)
	ability_fx.forms_drawn = true
	add_child(modifier_marks)  # v0.6.0 MX4
	add_child(blade_forms)  # v0.6.5 WN4
	add_child(fireballs)  # v0.7.5 BF1
	pulses.actors = actors
	pulses.draw_on_sync = false  # each frame's _process draws the pulses
	add_child(pulses)  # v0.8.0 GF1
	add_child(cast_fx)
	add_child(boss_shields)
	add_child(spikes)  # v0.8.0 AV
	add_child(signatures)  # v0.8.0 BS1

	add_child(strikes)  # v0.8.0 AV part 2
	add_child(final_views)  # v0.8.0 FB1
	add_child(prism_views)  # v0.8.0 FB2
	add_child(nemesis_views)  # v0.8.0 FB3
	if reader.has_floor() and reader.ascension_floor():  # v0.7.5 AP: its own look, the gate's place
		ascension = AscensionPortal.new()
		add_child(ascension)
		ascension.setup(reader.portal_pos(), reader.portal_angle())
	elif reader.has_gate():  # v0.7.5 PG: not in the Playground's room (a floor without a gate)
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
		gamble_shrine.kit_model = stage.mood != null  # v0.6.0 Step SR: the owner's shrine with the new look
		add_child(gamble_shrine)
		gamble_shrine.setup(reader.gamble_pos())
	if reader.shop_stall():  # v0.8.0 SR: the biome's tent stall and vendor
		shop_stall = ShopStallView.new()
		add_child(shop_stall)
		shop_stall.setup(reader, stage.prop_style)
	elif reader.has_shop():
		shop_terminal = ShopTerminalView.new()
		add_child(shop_terminal)
		shop_terminal.setup(reader.shop_pos(), reader.shop_angle())
	add_child(transit)
	transit.setup(actors, gate)
	transit.deep_gate = deep_gate
	transit.ascension = ascension  # v0.7.5 AP
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
	heal_orbs.sync(reader)
	item_fx.sync(reader)
	pulses.sync(reader)  # v0.8.0 GF1: after item_fx, which sets the bolt look a new shot takes
	cast_fx.sync(reader)
	status_fx.sync(reader)
	heat_fx.sync(reader)
	transit.sync(reader)  # after the actors: it poses the hero's model
	skill_fx.sync(reader)  # v0.3.5 K
	ability_fx.sync(reader)  # v0.4.0 BS
	element_fx.sync(reader)  # v0.4.0 AB
	overrun_doors.sync(reader)
	arenas.sync(reader)  # v0.5.5 AR
	damage_numbers.sync(reader)
	horde_fx.sync(reader)  # v0.4.0 EN
	events.sync(reader)  # v0.5.0 EV
	cores.sync(reader)  # v0.6.0 CU
	attack_forms.sync(reader)  # v0.6.0 MX3
	modifier_marks.sync(reader)  # v0.6.0 MX4
	blade_forms.sync(reader)  # v0.6.5 WN4
	fireballs.sync(reader)  # v0.7.5 BF1
	boss_shields.sync(reader)
	spikes.sync(reader)  # v0.8.0 AV
	signatures.sync(reader)  # v0.8.0 BS1

	strikes.sync(reader)  # v0.8.0 AV part 2
	final_views.sync(reader)  # v0.8.0 FB1
	prism_views.sync(reader)  # v0.8.0 FB2
	nemesis_views.sync(reader)  # v0.8.0 FB3
	if boss_door != null:
		boss_door.sync(reader)
	if gamble_shrine != null:
		gamble_shrine.sync(reader)
	if shop_terminal != null:
		shop_terminal.sync(reader)
	if shop_stall != null:
		shop_stall.sync(reader)
	# v0.5.0 RT: each gate closes when the other one is taken.
	var open := reader.gate_open(WorldReader.ROUTE_NORMAL)
	if gate != null and reader.has_boss_room() and gate.is_sealed() == open:
		gate.set_sealed(not open)
	if ascension != null and ascension.is_sealed() == open:  # v0.7.5 AP: the column rises
		ascension.set_sealed(not open)
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


## Draws a real flame on each fire prop into the effects layer (inside its frame): the props' own lights stay in
## StageKit.
func _draw_prop_fires(layer: VfxCore) -> void:
	if stage == null or stage.kit == null:
		return
	var fx := layer as VfxLayer
	for k in stage.kit.lights.size():
		var l := stage.kit.lights[k]
		if is_instance_valid(l) and l.is_inside_tree():
			fx.prop_fire(l.global_position - Vector3(0, 0.36, 0), k * 7919 + 13)

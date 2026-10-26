class_name WorldViewRoot
extends Node3D
## The 3D view of one room: stage, actors, the iso camera and occlusion. It reads the sim only through
## WorldReader (EI-07); the app calls sync() after every tick.

## v0.4.0 SC: walls fade for the hero and the enemies within this distance of it, at most this many of them (with a
## crowd, testing every wall against every enemy each frame cost more than the rest of the view; the X-ray
## silhouettes still show the ones farther off).
const OCCLUSION_RADIUS_M := 10.0
const OCCLUSION_FOCUS_MAX := 24
## v0.8.0 BD (O83): the camera's thud as the boss door's slab lands (starting value; none with shake off or reduced
## motion). v0.9.0 CV (owner Q17): a vibration, not a shake.
const DOOR_LAND_THUD := 0.5
## v0.8.0 LD (owner O70: loads never freeze): the parts a view makes when it is made (about 16 ms of the main thread
## together, 23-55 ms on a busy machine, in one frame). A load behind the cover makes them ahead, a few a frame
## (prebuild()); the next WorldViewRoot takes them (_part()). Made the same way either way, so the view is the same.
static var parts: Array[GDScript] = [
	StageView,
	ActorViews,
	KitView,
	UtilityView,
	TelegraphViews,
	InkPass,
	PickupViews,
	RewardViews,
	ShardViews,
	HealOrbViews,
	RemnantViews,  # v0.8.0 RM
	PortalTransitView,
	BossChallengeView,
	SkillVisuals,
	AbilityVisuals,
	DamageNumbers,
	ElementVisuals,
	OverrunDoorViews,
	ArenaViews,
	HordeVisuals,
	EventPedestalViews,
	CoreViews,
	AttackFormView,
	LaserView,  # v0.9.0 LZ
	BombView,  # v0.9.0 BM
	VoidView,  # v0.9.0 VP
	WaveView,  # v0.9.0 AF3
	WispsView,  # v0.9.0 AF3
	LanceView,  # v0.9.0 AF1
	ScatterView,  # v0.9.0 AF1
	RuneExplosionView,  # v0.9.5 FC0
	GlaiveView,  # v0.9.0 AF2
	SeekersView,  # v0.9.0 AF2
	ModifierOverlays,
	BladeFormView,
	FireballViews,
	HeroPulseViews,
	HeroCastFx,
	BossShieldView,
	StoneSpikeViews,
	BossSignatureViews,
	TideViews,  # v0.9.0 NB1
	TideWaveViews,  # v0.9.5 BH4
	TwinViews,  # v0.9.0 NB2
	JudgeViews,  # v0.9.0 NB3
	ShadeViews,  # v0.9.0 NB4
	BossStrikeViews,
	FinalBossViews,
	PrismViews,
	NemesisViews,
	IsoRig,
]

## v0.8.0 LD: the parts prebuild() made, by script, waiting for the next view.
static var _made := {}

var reader: WorldReader
var stage: StageView = _part(StageView)
var actors: ActorViews = _part(ActorViews)
var kit: KitView = _part(KitView)
var utility: UtilityView = _part(UtilityView)
var telegraphs: TelegraphViews = _part(TelegraphViews)
var hit_feel: HitFeel
var ink: InkPass = _part(InkPass)
var pickups: PickupViews = _part(PickupViews)
## Altars, chests and shard gems (v0.3.0 E).
var rewards: RewardViews = _part(RewardViews)
var shards: ShardViews = _part(ShardViews)
var heal_orbs: HealOrbViews = _part(HealOrbViews)  # v0.4.0 TU (D8)
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
## v0.8.0 P2 (owner O28): the Loop device beside it (null on other floors).
var loop_device: LoopDevice
## v0.8.0 RM (owner O91): the remnants (threads, cracks, anchors, marks, fragments, replay paths), their flashes and
## Thermal Break's shatter.
var remnants: RemnantViews = _part(RemnantViews)
## v0.9.5 SM: the Stress Mark's weak-side arcs on the enemies near the hero, and their break flashes.
var stress_marks: StressMarkViews = _part(StressMarkViews)
## v0.3.5 PT: the hero's way into the portal and the arrival on a new floor.
var transit: PortalTransitView = _part(PortalTransitView)
## v0.8.0 N11 (owner O69): the receiver the hero arrives on, in the middle of the first room (null without one).
var receiver: FloorReceiver
## v0.9.0 SA (owner Q16): floor 1 of a run's arrival altar, there instead of the receiver (null elsewhere).
var altar: AltarStage
## v0.9.0 FA (owner C §3, Q18): the final approach's altar, pylons and walls of light (null elsewhere).
var approach_view: FinalApproachView
## Run flow (v0.3.0 B): the boss door (null without a boss room).
var boss_door: BossDoorView
## v0.9.0 TD: the timed door, its rune switches and the secret room's reveal (null on a floor without one).
var timed_door: TimedDoorView
## v0.9.0 RA: the rune puzzle's pillars, its carved slab and its hidden room's reveal (null on a floor without one).
var rune_view: RuneAlignmentView
## v0.9.0 DP: the purple-rune room's dais and runes (null on a floor without one).
var purple: PurpleRuneView
## v0.9.0 LK: the Lockdowns' bars and the Hazard Lockdowns' warnings (null on a floor without any).
var lockdowns: LockdownView
## v0.9.0 SH, HF: the Blood or Chaos shrine and the healing fountain (null on a floor with neither).
var shrines: ShrinesView
## v0.9.0 DX: the cracked wall, the containers and the explosive barrels (null on a floor with none), and the faint rune
## markings by every secret's doorway (null without a secret).
var breakables: BreakablesView
var markings: RuneMarkingsView
## v0.9.0 CL: the floor's collectibles (null on a floor that holds none).
var collectibles: CollectibleView
## v0.9.0 RB: A4 Astral's sense, the secrets near the hero pulsing (null without Astral or without a secret).
var astral: AstralSenseView
## The gamble shrine (v0.3.0 L19; null on a floor without one).
var gamble_shrine: GambleShrineView
## The shop terminal (v0.5.0 SH; null on a floor without one, or whose shop is a stall).
var shop_terminal: ShopTerminalView
## v0.8.0 SR: the shop's tent stall and its vendor (null on a floor without one: no shop, or a terminal).
var shop_stall: ShopStallView
## Boss challenge (v0.3.0 BX): the closing band, the pull's vortex, enemies dissolving on the summon.
var challenge: BossChallengeView = _part(BossChallengeView)
## v0.3.5 K: the build skills' forecast, streaks, flashes and tracers.
var skill_fx: SkillVisuals = _part(SkillVisuals)
## v0.4.0 BS: bombs, drones, orbit blades, the blink shock; damage numbers (crits big and yellow).
var ability_fx: AbilityVisuals = _part(AbilityVisuals)
var damage_numbers: DamageNumbers = _part(DamageNumbers)
## v0.4.0 AB: Arc Field, Frost Nova, the fire, the ability combos; the Overrun room's red door frames.
var element_fx: ElementVisuals = _part(ElementVisuals)
var overrun_doors: OverrunDoorViews = _part(OverrunDoorViews)
## v0.5.5 AR: the sealed arenas' amber frames and barriers, and the dark veil over the rest of the floor while sealed.
var arenas: ArenaViews = _part(ArenaViews)
## v0.4.0 EN: mines on the floor, Menders' heal beams, Snipers' tracers.
var horde_fx: HordeVisuals = _part(HordeVisuals)
var events: EventPedestalViews = _part(EventPedestalViews)  # v0.5.0 EV: event pedestals, the drone's ring, elite crowns
var cores: CoreViews = _part(CoreViews)  # v0.6.0 CU: cores on elites and bosses, the steal window, dodge and stun cues
## v0.9.0 EL: the elites' arrival sigil, the Rift Hunter's rift, the Conduit's beam, the Breaker's dust ring.
var elite_fx: EliteViews = _part(EliteViews)
## v0.6.0 MX3: the attack forms drawn from their final specs (element core, heat edge, motion cues), pooled.
var attack_forms: AttackFormView = _part(AttackFormView)
## v0.9.0 LZ (owner C §6.2): the Laser's beams, per element.
var laser: LaserView = _part(LaserView)
## v0.9.0 BM (owner C §6.3): the bombs in flight and their blasts, per element.
var bombs: BombView = _part(BombView)
## v0.9.0 VP (owner C §6.4): the Void shots in flight, travelling lensing spheres, and the enemies leaning into them.
var voids: VoidView = _part(VoidView)
## v0.9.0 AF3 (owner Q7): the Wave's rolling bands; the wisps circling the hero.
var waves: WaveView = _part(WaveView)
var wisps: WispsView = _part(WispsView)
## v0.9.0 AF1 (owner Q7): the Lance's charge glow and aim line, its release flash; the Scatter's pellets and cone.
var lances: LanceView = _part(LanceView)
var scatter: ScatterView = _part(ScatterView)
## v0.9.5 FC0 (owner): the Rune Explosion's violet dome and rune ring bursting from the hero.
var runes: RuneExplosionView = _part(RuneExplosionView)
## v0.9.0 AF2 (owner Q7): the Glaive's spinning discs out and back; the Seekers' curving darts and their trails.
var glaives: GlaiveView = _part(GlaiveView)
var seekers: SeekersView = _part(SeekersView)
## v0.6.0 MX4: the shell, the charge, the phase, poison, queued attacks.
var modifier_marks: ModifierOverlays = _part(ModifierOverlays)
## v0.6.5 WN4: crescents, ghost slashes, fissures, sparks, orbiting blades.
var blade_forms: BladeFormView = _part(BladeFormView)
## v0.7.5 BF1: the hostile fireballs (pooled per look in MultiMeshes) and the bosses' crystal shields and lobbed shells.
var fireballs: FireballViews = _part(FireballViews)
## v0.8.0 GF1 (owner O19): the hero's shots as blue pulses (pooled per look in MultiMeshes) and the cast flourish.
var pulses: HeroPulseViews = _part(HeroPulseViews)
var cast_fx: HeroCastFx = _part(HeroCastFx)
## v0.8.0 GF3 (owner O22): the Blade's edge spark (KitView draws the slash edge; HitFeel the cut and the hit-stop).
var swing_fx := BladeSwingFx.new(kit)
var boss_shields: BossShieldView = _part(BossShieldView)
## v0.8.0 AV (owner O7): the Gatekeeper's shock lanes strike as rows of stone spikes.
var spikes: StoneSpikeViews = _part(StoneSpikeViews)
## v0.8.0 BS1 (owner O5): the Warlord's javelins stuck in the floor and the Brood Mother's eggs.
var signatures: BossSignatureViews = _part(BossSignatureViews)
## v0.9.0 NB1: the Tidecaller's Pull (the moving water, the bell's toll, the push's swell).
var tides: TideViews = _part(TideViews)
## v0.9.5 BH4: the Tidecaller's crossing waves (a foam line at the wall, then the curling water band).
var tide_waves: TideWaveViews = _part(TideWaveViews)
## v0.9.0 NB2: the Twin Wardens' burning chain, Crossfire's gap lanes and safe spot, the Chain Sweep's lash.
var twins: TwinViews = _part(TwinViews)
## v0.9.0 NB3: the Clockwork Judge's echo (its recording, path and ghost trail) and its Verdict's pendulum.
var judges: JudgeViews = _part(JudgeViews)
## v0.9.0 NB4: the Lantern Shade's dark (a layered darkness pass), the room's lanterns and their pools, your light.
var shades: ShadeViews = _part(ShadeViews)

## v0.8.0 AV part 2 (owner O7): every other boss ground attack strikes as a 3D effect.
var strikes: BossStrikeViews = _part(BossStrikeViews)
## v0.8.0 FB1 (owner O16): the final boss's shatter between its bodies (the burst, the shards the next rises from).
var final_views: FinalBossViews = _part(FinalBossViews)
var prism_views: PrismViews = _part(PrismViews)  # v0.8.0 FB2: the Prism's Cross, her bolts' aim lines, the window
var nemesis_views: NemesisViews = _part(NemesisViews)  # v0.8.0 FB3: the Nemesis's card casts and dash afterimages
var rig: IsoRig = _part(IsoRig)
## v0.8.0 HV (owner O89): the camera's view, read once a tick before the views sync; the enemy models' animation,
## the status effects and the attack forms skip only what is wholly out of the picture (ScreenCull).
var cull := ScreenCull.new()
var occlusion_enabled := true
## v0.8.0 FV (O87): the perf probe's per-view sync breakdown (view name -> total ms); filled only while
## `profile_sync` is on.
var profile_sync := false
var sync_profile := {}
## v0.8.0 P3 (O32): the floor's walls for the occlusion test, indexed once (Occlusion.build_index).
var _occlusion_index := {}


## v0.8.0 LD: makes the parts not made yet for about `budget_ms` (one at least); true when every part is made.
static func prebuild(budget_ms: float) -> bool:
	var from := Time.get_ticks_usec()
	for script: GDScript in parts:
		if _made.has(script):
			continue
		_made[script] = script.new()
		if (Time.get_ticks_usec() - from) / 1000.0 >= budget_ms:
			return _made.size() == parts.size()
	return true


## v0.8.0 LD: frees the parts prebuild() made that no view took (a load that stopped).
static func drop_prebuilt() -> void:
	for o: Object in _made.values():
		if o is Node:
			(o as Node).free()
	_made.clear()


## v0.8.0 LD: a part made ahead by prebuild() when there is one, else a new one.
static func _part(script: GDScript) -> Object:
	if _made.has(script):
		var o: Object = _made[script]
		_made.erase(script)
		return o
	return script.new()


func setup(p_reader: WorldReader, palette: Dictionary, arena_half: float) -> void:
	var q := ViewBuildQueue.new()
	queue_setup(q, p_reader, palette, arena_half)
	q.run_all()


## v0.8.0 N12 (owner O70): the view's build as jobs on `q` (ViewBuildQueue), in setup()'s order: the models read on a
## worker, the views, the devices and props, the stage's parts (StageView.queue_build), the first sync. A load runs
## them over frames behind the loading cover (CoverLoads.build_view); setup() runs them at once.
func queue_setup(
	q: ViewBuildQueue, p_reader: WorldReader, palette: Dictionary, arena_half: float
) -> void:
	reader = p_reader
	# v0.3.0 L13: the owner's boss models load with the stage, never on a spawn (v0.8.0 FB1: the final boss's three
	# only where its fight is: the final arena, the Playground). v0.8.0 N12: with the kit's and the shop's models, on
	# a worker (ViewWarmup).
	q.add_worker(
		"models",
		ViewWarmup.warm.bind(
			reader.final_fight() or not reader.has_gate(),
			stage.mood != null,
			stage.prop_style,
			reader.shop_stall()
		)
	)
	q.add("views", _setup_views.bind(palette))
	q.add("effects", _setup_effects)
	q.add("devices", _setup_devices.bind(palette))
	stage.queue_build(q, reader, palette, arena_half)
	q.add("first_sync", _first_sync)
	q.add("shader_warmup", _warm_shaders)  # v0.8.0 HR (O89; RenderSwitches.SHADER_WARMUP)


## v0.8.0 HR: the window's MSAA under RenderSwitches.MSAA_OFF (the game's root window only).
func _enter_tree() -> void:
	RenderSwitches.apply_viewport(get_viewport())


## v0.8.0 HR: the floor's effect, attack and enemy shaders drawn once, tiny, behind the cover (ShaderWarmup).
func _warm_shaders() -> void:
	ShaderWarmup.build(self, rig.camera, actors)


func _setup_views(palette: Dictionary) -> void:
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
	add_child(elite_fx)  # v0.9.0 EL
	add_child(attack_forms)  # v0.6.0 MX3
	add_child(laser)  # v0.9.0 LZ
	add_child(bombs)  # v0.9.0 BM
	add_child(voids)  # v0.9.0 VP
	add_child(waves)  # v0.9.0 AF3
	add_child(wisps)  # v0.9.0 AF3
	add_child(lances)  # v0.9.0 AF1
	add_child(scatter)  # v0.9.0 AF1
	add_child(runes)  # v0.9.5 FC0
	add_child(glaives)  # v0.9.0 AF2
	add_child(seekers)  # v0.9.0 AF2


## The effects layer (real fire, explosions, lightning) and the views drawn into it or after it.
func _setup_effects() -> void:
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
		layer.drawers.append(final_views.draw_fx)  # v0.8.0 TX2: the shatter's crystal burst
		laser.vfx = layer  # v0.9.0 LZ: the beam's element accent, the impact's sparks and light
		layer.drawers.append(laser.draw_fx)
		bombs.vfx = layer  # v0.9.0 BM: the blasts' element bursts
		layer.drawers.append(bombs.draw_fx)
		layer.drawers.append(lances.draw_fx)  # v0.9.0 AF1: the release's element accent and sparks
		# v0.9.0 VX: the forms' element accents, launches, catches and collapses (HeroFx, VFX_AUDIT.md)
		for v: Node in [voids, scatter, runes, glaives, seekers, waves, wisps]:
			layer.drawers.append(Callable(v, &"draw_fx"))
		seekers.vfx_on = true  # V29: the trail motes become the element's own sprites
	element_fx.forms_drawn = true  # MX3 draws the spec forms (rings, spec patches, bombs)
	ability_fx.forms_drawn = true
	add_child(modifier_marks)  # v0.6.0 MX4
	add_child(blade_forms)  # v0.6.5 WN4
	add_child(fireballs)  # v0.7.5 BF1
	pulses.actors = actors
	pulses.draw_on_sync = false  # each frame's _process draws the pulses
	add_child(pulses)  # v0.8.0 GF1
	add_child(cast_fx)
	add_child(swing_fx)  # v0.8.0 GF3
	add_child(boss_shields)
	add_child(spikes)  # v0.8.0 AV
	add_child(signatures)  # v0.8.0 BS1
	add_child(tides)  # v0.9.0 NB1
	add_child(tide_waves)  # v0.9.5 BH4
	add_child(twins)  # v0.9.0 NB2
	add_child(judges)  # v0.9.0 NB3
	add_child(shades)  # v0.9.0 NB4 (it dims the stage's sun with the dark)
	shades.stage = stage

	add_child(strikes)  # v0.8.0 AV part 2
	add_child(final_views)  # v0.8.0 FB1
	add_child(prism_views)  # v0.8.0 FB2
	add_child(nemesis_views)  # v0.8.0 FB3
	add_child(remnants)  # v0.8.0 RM
	add_child(stress_marks)  # v0.9.5 SM


## The floor's portals and devices, the boss door, the shrine and the shop, the portal transit, the ink and hit feel.
func _setup_devices(palette: Dictionary) -> void:
	if reader.has_floor() and reader.ascension_floor():  # v0.7.5 AP: its own look, the gate's place
		ascension = AscensionPortal.new()
		add_child(ascension)
		ascension.setup(reader.portal_pos(), reader.portal_angle())
		if reader.has_loop_device():  # v0.8.0 P2 (O28): the Loop device beside it
			loop_device = LoopDevice.new()
			add_child(loop_device)
			loop_device.setup(
				reader.loop_device_pos(), reader.loop_device_angle(), reader.loop_device_radius()
			)
	elif reader.has_gate():  # v0.7.5 PG: not in the Playground's room (a floor without a gate)
		gate = PortalGate.new()
		add_child(gate)
		gate.setup(reader.portal_pos(), reader.portal_angle())
	if reader.deep_portal_site():  # v0.9.0 DP: also where the purple runes may still earn it (sealed: unseen)
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
			palette["cover"],
			stage.prop_style  # v0.8.0 BD (O82): the biome's own door
		)
	if reader.has_timed_door():  # v0.9.0 TD
		timed_door = TimedDoorView.new()
		add_child(timed_door)
		timed_door.setup(reader, stage, palette["cover"])
	if reader.has_rune_puzzle():  # v0.9.0 RA
		rune_view = RuneAlignmentView.new()
		add_child(rune_view)
		rune_view.setup(reader, stage, palette["cover"])
	if reader.has_purple_runes():  # v0.9.0 DP
		purple = PurpleRuneView.new()
		purple.biome = stage.prop_style  # v0.9.0 BV: the biome's look
		add_child(purple)
		purple.setup(reader, palette["cover"])
	if reader.has_lockdowns():  # v0.9.0 LK
		lockdowns = LockdownView.new()
		add_child(lockdowns)
		lockdowns.setup(reader, stage.prop_style)
	if reader.has_shrines():  # v0.9.0 SH, HF
		shrines = ShrinesView.new()
		shrines.biome = stage.prop_style  # v0.9.0 BV
		add_child(shrines)
		shrines.setup(reader, palette["cover"])
	if reader.has_cracked_wall() or reader.breakable_count() > 0:  # v0.9.0 DX
		breakables = BreakablesView.new()
		add_child(breakables)
		breakables.setup(reader, stage, palette["cover"])
	if not reader.secret_doors().is_empty():  # v0.9.0 DX (Q29b): hidden rune markings
		markings = RuneMarkingsView.new()
		markings.biome = stage.prop_style  # v0.9.0 BV
		add_child(markings)
		markings.setup(reader)
	if reader.has_collectibles():  # v0.9.0 CL: the pickups, as their sources give them
		collectibles = CollectibleView.new()
		add_child(collectibles)
		collectibles.setup(reader, CollectibleBook.colors())
	if reader.affinity_sense_m() > 0.0 and not reader.secret_spots().is_empty():  # v0.9.0 RB: A4 Astral
		astral = AstralSenseView.new()
		add_child(astral)
		astral.setup(reader, markings.spots if markings != null else PackedVector2Array())
	if reader.has_gamble():
		gamble_shrine = GambleShrineView.new()
		gamble_shrine.kit_model = stage.mood != null  # v0.6.0 Step SR: the owner's shrine with the new look
		gamble_shrine.biome = stage.prop_style  # v0.9.0 BV
		add_child(gamble_shrine)
		gamble_shrine.setup(reader.gamble_pos())
		if attack_forms.vfx != null:  # v0.9.5 SS: its smoke and gold ring ride the effects layer
			attack_forms.vfx.drawers.append(Callable(gamble_shrine, &"draw_fx"))
	if reader.shop_stall():  # v0.8.0 SR: the biome's tent stall and vendor
		shop_stall = ShopStallView.new()
		add_child(shop_stall)
		shop_stall.setup(reader, stage.prop_style)
	elif reader.has_shop():
		shop_terminal = ShopTerminalView.new()
		add_child(shop_terminal)
		shop_terminal.setup(reader.shop_pos(), reader.shop_angle())
	# v0.8.0 N11: every run floor (not the final arena or the Playground) has an arrival. v0.9.0 SA/PT (owner Q16: "only
	# floor 1 the rest of the floor spawn the same portal that you take at the end of the floor"): floor 1 of a run
	# lands on the altar; a later floor's hero steps out of the portal taken (the Deep gate's violet on a Deep floor).
	var arrival_gate: PortalGate = null
	if reader.arrival_altar():  # v0.9.0 SA (Q16): floor 1 of a run lands on the altar
		altar = AltarStage.new(AltarStage.arrival())
		add_child(altar)
		altar.setup(reader.floor_start_pos())
	elif reader.floor_receiver():
		arrival_gate = PortalGate.new()
		arrival_gate.name = "ArrivalGate"
		if reader.floor_is_deep():
			arrival_gate.set_deep()
		arrival_gate.set_arrival()
		add_child(arrival_gate)
	add_child(transit)
	transit.setup(actors, gate)
	transit.receiver = receiver
	transit.arrival_gate = arrival_gate
	transit.altar = altar
	transit.rig = rig
	transit.deep_gate = deep_gate
	transit.ascension = ascension  # v0.7.5 AP
	transit.loop_device = loop_device  # v0.8.0 P2
	if reader.final_approach():  # v0.9.0 FA
		approach_view = FinalApproachView.new()
		add_child(approach_view)
		approach_view.setup(reader, rig)
	rig.camera.add_child(ink)
	ink.position = Vector3(0, 0, -1)
	hit_feel = HitFeel.new(actors, rig)
	hit_feel.hit_stop.kit = kit  # v0.8.0 GF3: the hit-stop holds the blade and its trail too
	add_child(hit_feel)
	if attack_forms.vfx != null:  # v0.8.0 GF2: the hits' impacts, in the effects layer's pools and budget
		attack_forms.vfx.drawers.append(hit_feel.impacts.draw)
	actors.cull = cull  # v0.8.0 HV
	status_fx.cull = cull
	attack_forms.cull = cull


func _first_sync() -> void:
	rig.snap_to(SimPlane.to_3d(reader.player_pos()))  # v0.8.0 HV: the view the first sync culls against
	sync()
	rig.snap_to(SimPlane.to_3d(reader.player_pos()))


## v0.8.0 FV (owner O87, the horde lag): one view's sync, timed into `sync_profile` while `profile_sync` is on (the
## perf probe's --horde; off in the game: a plain call).
## v0.9.5 SM: a broken weak side's orange sparks, through the hit impacts' pools and budget (Effects density scales
## the strength: low a third, medium two thirds).
func _stress_sparks() -> void:
	if hit_feel == null or stress_marks.bursts.is_empty():
		return
	var k := 1.0
	if ViewPrefs.effects_density == "low":
		k = 0.35
	elif ViewPrefs.effects_density == "medium":
		k = 0.7
	for b: Array in stress_marks.bursts:
		var dir: Vector2 = b[1]
		var at := SimPlane.to_3d(b[0] + dir * 0.4, 0.5)
		hit_feel.impacts.add(
			at, SimPlane.to_3d(dir), at, StressMarkViews.ORANGE, int(b[2]), 1.2 * k, ImpactFx.OTHER
		)


func _sync_view(id: StringName, view: Object) -> void:
	if not profile_sync:
		view.call(&"sync", reader)
		return
	var t0 := Time.get_ticks_usec()
	view.call(&"sync", reader)
	sync_profile[id] = float(sync_profile.get(id, 0.0)) + (Time.get_ticks_usec() - t0) / 1000.0


func sync() -> void:
	cull.refresh(rig.camera)  # v0.8.0 HV
	_sync_view(&"telegraphs", telegraphs)
	_sync_view(&"challenge", challenge)
	_sync_view(&"actors", actors)
	_sync_view(&"kit", kit)
	_sync_view(&"swing_fx", swing_fx)  # v0.8.0 GF3: after the blade, whose tip it rides
	_sync_view(&"utility", utility)
	_sync_view(&"hit_feel", hit_feel)
	_sync_view(&"pickups", pickups)
	_sync_view(&"rewards", rewards)
	_sync_view(&"shards", shards)
	_sync_view(&"heal_orbs", heal_orbs)
	_sync_view(&"item_fx", item_fx)
	_sync_view(&"pulses", pulses)  # v0.8.0 GF1: after item_fx, which sets the bolt look a new shot takes
	_sync_view(&"cast_fx", cast_fx)
	_sync_view(&"status_fx", status_fx)
	_sync_view(&"heat_fx", heat_fx)
	_sync_view(&"transit", transit)  # after the actors: it poses the hero's model
	if approach_view != null:
		_sync_view(&"approach", approach_view)  # v0.9.0 FA
	_sync_view(&"skill_fx", skill_fx)  # v0.3.5 K
	_sync_view(&"ability_fx", ability_fx)  # v0.4.0 BS
	_sync_view(&"element_fx", element_fx)  # v0.4.0 AB
	_sync_view(&"overrun_doors", overrun_doors)
	_sync_view(&"arenas", arenas)  # v0.5.5 AR
	_sync_view(&"damage_numbers", damage_numbers)
	_sync_view(&"horde_fx", horde_fx)  # v0.4.0 EN
	_sync_view(&"events", events)  # v0.5.0 EV
	_sync_view(&"cores", cores)  # v0.6.0 CU
	_sync_view(&"elite_fx", elite_fx)  # v0.9.0 EL
	if elite_fx.take_thud():  # v0.9.0 EL: the Breaker's slam near the hero (none with reduced motion)
		rig.thud(EliteViews.THUD)
	_sync_view(&"attack_forms", attack_forms)  # v0.6.0 MX3
	_sync_view(&"laser", laser)  # v0.9.0 LZ
	_sync_view(&"bombs", bombs)  # v0.9.0 BM
	_sync_view(&"voids", voids)  # v0.9.0 VP
	_sync_view(&"waves", waves)  # v0.9.0 AF3
	_sync_view(&"wisps", wisps)  # v0.9.0 AF3
	_sync_view(&"lances", lances)  # v0.9.0 AF1
	_sync_view(&"scatter", scatter)  # v0.9.0 AF1
	_sync_view(&"runes", runes)  # v0.9.5 FC0
	_sync_view(&"glaives", glaives)  # v0.9.0 AF2
	_sync_view(&"seekers", seekers)  # v0.9.0 AF2
	_sync_view(&"modifier_marks", modifier_marks)  # v0.6.0 MX4
	_sync_view(&"blade_forms", blade_forms)  # v0.6.5 WN4
	_sync_view(&"fireballs", fireballs)  # v0.7.5 BF1
	_sync_view(&"boss_shields", boss_shields)
	_sync_view(&"spikes", spikes)  # v0.8.0 AV
	_sync_view(&"signatures", signatures)  # v0.8.0 BS1
	_sync_view(&"tides", tides)  # v0.9.0 NB1
	_sync_view(&"tide_waves", tide_waves)  # v0.9.5 BH4
	_sync_view(&"twins", twins)  # v0.9.0 NB2
	_sync_view(&"judges", judges)  # v0.9.0 NB3
	_sync_view(&"shades", shades)  # v0.9.0 NB4

	_sync_view(&"strikes", strikes)  # v0.8.0 AV part 2
	_sync_view(&"final_views", final_views)  # v0.8.0 FB1
	_sync_view(&"prism_views", prism_views)  # v0.8.0 FB2
	_sync_view(&"nemesis_views", nemesis_views)  # v0.8.0 FB3
	_sync_view(&"remnants", remnants)  # v0.8.0 RM
	_sync_view(&"stress_marks", stress_marks)  # v0.9.5 SM
	_stress_sparks()
	if rune_view != null:  # v0.9.0 RA
		rune_view.sync(reader)
	if purple != null:  # v0.9.0 DP (owner Q17, Q26b): the runes' vibration builds, then lands in a thud
		purple.sync(reader)
		if purple.vibration > 0.0:
			rig.vibrate_to(purple.vibration)
		if purple.take_thud():
			rig.thud(PurpleRuneView.THUD)
	if shrines != null:  # v0.9.0 SH, HF
		shrines.sync(reader)
	if collectibles != null:  # v0.9.0 CL
		collectibles.sync(reader)
	if astral != null:  # v0.9.0 RB: A4 Astral
		astral.sync(reader)
	if lockdowns != null:  # v0.9.0 LK: the bars land with a thud
		lockdowns.sync(reader)
		if lockdowns.take_thud():
			rig.thud(LockdownView.THUD)
	if breakables != null:  # v0.9.0 DX
		breakables.sync(reader)
		if breakables.blasted:
			rig.thud(DOOR_LAND_THUD)
	if timed_door != null:  # v0.9.0 TD
		timed_door.sync(reader)
		if timed_door.slammed:
			rig.thud(DOOR_LAND_THUD)
	if boss_door != null:
		boss_door.sync(reader)
		if boss_door.landed:  # v0.8.0 BD (O83): the slab lands with a thud (v0.9.0 CV: a vibration)
			rig.thud(DOOR_LAND_THUD)
	if gamble_shrine != null:
		gamble_shrine.sync(reader)
	if shop_terminal != null:
		shop_terminal.sync(reader)
	if shop_stall != null:
		shop_stall.sync(reader)
	# v0.5.0 RT: each gate closes when the other one is taken. v0.9.0 PT (C4, Q15): nothing stands before the boss
	# dies; then each grows from a point as the sim forms it (portal_form_progress), and the one not taken collapses.
	var open := reader.gate_open(WorldReader.ROUTE_NORMAL)
	if gate != null and reader.has_boss_room() and gate.is_sealed() == open:
		gate.set_sealed(not open)
	if gate != null and open:
		gate.set_growth(reader.portal_form_progress(WorldReader.ROUTE_NORMAL))
	if ascension != null and ascension.is_sealed() == open:  # v0.7.5 AP: the column rises
		ascension.set_sealed(not open)
	if loop_device != null and loop_device.is_sealed() == open:  # v0.8.0 P2: and the Loop device lights
		loop_device.set_sealed(not open)
	var deep_open := reader.gate_open(WorldReader.ROUTE_DEEP)
	if deep_gate != null and deep_gate.is_sealed() == deep_open:
		deep_gate.set_sealed(not deep_open)
	if deep_gate != null and deep_open:
		deep_gate.set_growth(reader.portal_form_progress(WorldReader.ROUTE_DEEP))
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
		# v0.8.0 P3 (owner O32): the floor's walls indexed once (Occlusion.build_index), not all tested every tick.
		if (
			_occlusion_index.is_empty()
			or _occlusion_index["count"] != stage.wall_specs.size()
			or _occlusion_index["pitch"] != rig.pitch_deg
		):
			_occlusion_index = Occlusion.build_index(rig.pitch_deg, stage.wall_specs)
		stage.apply_occlusion(
			Occlusion.select_in(
				rig.toward_camera_on_plane(), _occlusion_index, focus, stage.wall_specs
			)
		)
	else:
		stage.apply_occlusion(PackedInt32Array())


## Draws a real flame on each fire prop into the effects layer (inside its frame): the props' own lights stay in
## StageKit. v0.8.0 P3 (O32): a prop whose light StageKit hid (out of the view's reach) draws no flame either.
func _draw_prop_fires(layer: VfxCore) -> void:
	if stage == null or stage.kit == null:
		return
	var fx := layer as VfxLayer
	for k in stage.kit.lights.size():
		var l := stage.kit.lights[k]
		if is_instance_valid(l) and l.visible and l.is_inside_tree():
			fx.prop_fire(l.global_position - Vector3(0, 0.36, 0), k * 7919 + 13)

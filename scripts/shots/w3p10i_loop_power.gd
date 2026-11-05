extends SceneTree
## v0.10.5 W3-P10i: pictures of the loop-power screens for the owner, in English:
## constellation_pick (the loop's Constellation offer), starbound_pick (a loop-2 altar offering Echo Cast beside two
## normal cards), starbound_hud (stacks on the buff row), effects (Detonation bursts, an Arc Jump line and a falling
## meteor in a room with enemies) and contact.png (the four). The first two are the real panels on a CardPoolSurvey
## world; the last two run the real game (main.tscn, the dev stage run) with the world's fields posed for the shot.
## A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/w3p10i_loop_power.gd
## Writes build/shots/v0.10.5/w3p10i/{constellation_pick,starbound_pick,starbound_hud,effects,contact}.png.

const OUT := "res://build/shots/v0.10.5/w3p10i/"
const SETTLE := 30
const FALL_STEPS := 12
const MAX_FRAMES := 4000
const NAMES := ["constellation_pick", "starbound_pick", "starbound_hud", "effects"]

var _repo: ContentRepository
var _frame := 0
var _stage := 0
var _wait := 0
var _falls := 0
var _top: Control
var _main: Main


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	TranslationServer.set_locale("en")
	ViewPrefs.effects_density = "high"
	_repo = ContentRepository.load_all()


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > MAX_FRAMES:
		push_error("w3p10i: gave up at stage %d" % _stage)
		quit(1)
		return true
	if _main != null and _main.driver != null:
		_main.driver.world.actors.invuln[0] = 2  # shot setup: the hero can't be hurt
		if _stage >= 7:
			_hide_banners()
	if _wait > 0:
		_wait -= 1
		return false
	match _stage:
		0:
			_constellation()
			_wait = SETTLE
		1:
			_shot(NAMES[0])
			_starbound_pick()
			_wait = SETTLE
		2:
			_shot(NAMES[1])
			_top.queue_free()
			ProfileStore.use_shared(ProfileStore.new(""))
			_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
			root.add_child(_main)
		3:
			if _main.driver == null:
				_main.start_stage()
				return false
			if _main.driver.reader.arriving():
				return false
			_wait = 700
		4:
			var w := _main.driver.world
			w.starbound = PackedInt32Array([1, 3, 2, 4, 2])  # arc, rising, echo, fervour, detonation
			# a far enemy keeps the room uncleared, or the sim zeroes the crit and kill counts
			w.add_dummy(w.player_pos() + Vector2(-9.0, -9.0), 0.4, 100000)
			w.dummy_speed = 0.0
		5:
			var w := _main.driver.world
			w.starbound_crits = 5
			w.starbound_kills = 12
			_wait = 1
		6:
			_shot(NAMES[2])
			_main.driver.paused = true  # from here the shot steps the sim by hand
			_spawn_dummies(_main.driver.world)
			_main.driver.step_once()
			_main.driver.step_once()
			_wait = 3
		7:
			_meteor(_main.driver.world)  # W3-P10l: it falls for FALL_STEPS ticks first, so its flames trail behind it
			_main.driver.step_once()
			_falls = FALL_STEPS
		8:
			if _falls > 0:
				_falls -= 1
				_stage -= 1  # (this stage again next frame, one tick further)
			else:
				_effects(_main.driver.world)
				_wait = 4
			_main.driver.step_once()
		9:
			_shot(NAMES[3])
			_contact()
			print("w3p10i: done")
			quit(0)
			return true
	_stage += 1
	return false


func _backdrop() -> void:
	_top = Control.new()
	_top.size = Vector2(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color("#0A0D18")
	bg.size = _top.size
	_top.add_child(bg)
	root.add_child(_top)


func _constellation() -> void:
	_backdrop()
	var w := CardPoolSurvey.world(_repo, 4242, &"gun", [])
	w.constellation_offer = PackedInt32Array(
		[Constellations.PRISM, Constellations.GLASS_SKY, Constellations.HUNTERS_SKY]
	)
	var p := ConstellationPanel.new()
	_top.add_child(p)
	p.sync(WorldReader.new(w))
	p.skip_deal()
	p._set_focus(0)
	p.deal.time = p.deal.length() + 3.0


func _item(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


func _stat(w: World, id: StringName, rarity: int) -> int:
	for s in w.stat_tables.size():
		if w.stat_tables[s] != null and w.stat_tables[s].id == id:
			return Offers.stat_code(s, rarity)
	return -1


func _starbound_pick() -> void:
	_top.queue_free()
	_backdrop()
	var w := CardPoolSurvey.world(_repo, 4242, &"gun", [])
	w.starbound_tables = ContentCompiler.compile_starbound(_repo)
	w.loop = 2
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	w.rewards.set_offer(
		w.rewards.size() - 1,
		PackedInt32Array(
			[
				_item(w, &"gun_pierce"),
				Offers.starbound_code(Starbound.ECHO_CAST),
				_stat(w, &"damage", 1)
			]
		)
	)
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.INTERACT))
	var p := PickPanel.new()
	_top.add_child(p)
	p.sync(WorldReader.new(w))
	p.skip_deal()
	p._set_focus(1)
	p.deal.time = p.deal.length() + 3.0


## Shot setup: dummies round the hero.
func _spawn_dummies(w: World) -> void:
	var me := w.player_pos()
	var spots := [
		Vector2(3.0, -1.5),
		Vector2(4.0, 0.5),
		Vector2(3.2, 2.2),
		Vector2(5.5, -0.5),
		Vector2(5.0, 2.5),
		Vector2(6.5, 1.0)
	]
	for s: Vector2 in spots:
		w.add_dummy(me + s, 0.4, 100000)
	w.dummy_speed = 0.0


## Shot setup: three bursts, an Arc Jump line, a meteor part-way down and one landing, and two of Starfall's stars
## (one mid-fall, one reaching its target), on the dummies' spots.
func _effects(w: World) -> void:
	var me := w.player_pos()
	var t := w.tick
	for at: Vector2 in [Vector2(3.0, -1.5), Vector2(5.5, -0.5), Vector2(4.0, 0.5)]:
		w.starbound_fx_kind.append(Starbound.FX_BURST)
		w.starbound_fx_tick.append(t - 6)
		w.starbound_fx_from.append(me + at)
		w.starbound_fx_to.append(me + at)
	w.starbound_fx_kind.append(Starbound.FX_JUMP)
	w.starbound_fx_tick.append(w.tick - 1)
	w.starbound_fx_from.append(me + Vector2(5.0, 2.5))
	w.starbound_fx_to.append(me + Vector2(6.5, 1.0))
	# W3-P10l: a meteor landing (its fire burst), a star mid-fall and one reaching its target (its sparkle)
	var land := w.emit_event(SimEvent.Kind.METEOR_LAND, 0, 0, 0, me + Vector2(1.5, -3.0))
	land.amount = 2500
	land.tick = w.tick - 2
	var star := w.emit_event(SimEvent.Kind.STAR, 0, 0, 0, me + Vector2(5.5, -0.5))
	star.tick = w.tick - 5
	var hit := w.emit_event(SimEvent.Kind.STAR, 0, 0, 0, me + Vector2(3.0, -1.5))
	hit.tick = w.tick - StarfallView.STAR_TICKS


## W3-P10l: a meteor part-way down (50 ticks into its 90 when the shot is taken).
func _meteor(w: World) -> void:
	var e := w.emit_event(SimEvent.Kind.METEOR_LAUNCH, 0, 0, 0, w.player_pos() + Vector2(4.0, 2.0))
	e.amount = 90
	e.tick = w.tick - 50 + FALL_STEPS + 2


func _shot(shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := ProjectSettings.globalize_path(OUT + shot_name + ".png")
	img.save_png(path)
	print("w3p10i: shot ", path)


func _contact() -> void:
	var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGB8)
	for k in NAMES.size():
		var img := Image.load_from_file(ProjectSettings.globalize_path(OUT + NAMES[k] + ".png"))
		img.convert(Image.FORMAT_RGB8)
		img.resize(960, 540, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(0, 0, 960, 540), Vector2i((k % 2) * 960, (k / 2) * 540))
	sheet.save_png(ProjectSettings.globalize_path(OUT + "contact.png"))


## W3-P10j: the first-run tips and the "New:" rule banner would cover the effects: hide them for the shot.
func _hide_banners() -> void:
	_main.hints.visible = false
	var todo: Array[Node] = [_main]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		todo.append_array(n.get_children())
		if n is Label and (n as Label).text.begins_with("New"):
			var c := n as Control
			c.visible = false
			if c.get_parent() is Control and (c.get_parent() as Control).get_child_count() == 1:
				(c.get_parent() as Control).visible = false

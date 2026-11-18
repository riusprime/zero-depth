extends SceneTree
## Renders every attack of the Gatekeeper, the Brood Mother, the Lantern Shade, the Tidecaller, the Twin Wardens and
## the final bodies (the Colossus, the Prism, The Fallen) for the boss style audit, in the real game view
## (WorldViewRoot with the biome's mood and look, and the HUD) of a real World stepped one tick per frame, so the pack
## effects play at their own speed. Each attack runs alone (the boss's own picks hushed, the boss standing still) and
## is caught twice: late in its windup (its marker) and just after it strikes (its effect); both frames side by side in
## one file, <out>/<boss>/<nn>_<attack>.png.
## Needs a renderer (no --headless); run it off screen (only=: a comma-separated list of bosses or boss/file):
##   godot --path . --position -10000,-10000 --audio-driver Dummy --fixed-fps 60 \
##     -s scripts/shots/style_audit_b.gd -- out=<folder> [only=<boss>]
## Prints each path with the ticks it was caught at.
const SIZE := Vector2i(960, 540)
## The game's own camera size (IsoRig.view_size).
const GAME_VIEW := 17.0
## Frames drawn before the first tick: the floor's pack warm-up gives its effects back.
const PREP := 8
const SEED := 951
const CARDS := [[&"gun_twin", 2], [&"split_shot", 5], [&"ember_core", 3], [&"halo_shot", 1]]

## Each cell: boss (its folder), file, rig (room: the walled 24 m boss room; final: the final arena with body
## `body`), biome, attack, who (1: the violet Warden), hero (offset from the boss), at (ticks after the start to catch;
## empty: three quarters into the windup and just after the strike), view (camera size), hp (per mille, set before
## `pre` ticks run without an attack).
const CELLS := [
	{"boss": "gatekeeper", "file": "01_rock_rings", "attack": &"rock_rings", "at": [36, 70]},
	{"boss": "gatekeeper", "file": "02_fist_slam", "attack": &"fist_slam"},
	{"boss": "gatekeeper", "file": "03_shock_lanes", "attack": &"shock_lanes", "at": [100, 140]},
	{"boss": "gatekeeper", "file": "04_sweep", "attack": &"sweep", "hero": Vector2(2.5, -1.5)},
	{
		"boss": "gatekeeper",
		"file": "05_quake_pillars_shock_lanes",
		"attack": &"shock_lanes",
		"hp": 640,
		"pre": 260,
		"aim": "pillar",
		"at": [10, 140],
		"view": 22.0
	},
	{"boss": "brood_mother", "file": "01_egg_storm", "attack": &"egg_storm", "at": [40, 120]},
	{"boss": "brood_mother", "file": "02_web_spiral", "attack": &"web_spiral"},
	{"boss": "brood_mother", "file": "03_leap", "attack": &"leap"},
	{"boss": "brood_mother", "file": "04_burrow", "attack": &"burrow", "at": [120, 215]},
	{"boss": "brood_mother", "file": "05_brood", "attack": &"brood", "at": [30, 90]},
	{"boss": "brood_mother", "file": "06_pounce_chain", "attack": &"pounce_chain"},
	{"boss": "lantern_shade", "file": "01_lights_out", "attack": &"lights_out", "at": [120, 260]},
	{"boss": "lantern_shade", "file": "02_wisp_bloom", "attack": &"wisp_bloom"},
	{"boss": "lantern_shade", "file": "03_snuff", "attack": &"snuff"},
	{"boss": "lantern_shade", "file": "04_lantern_sweep", "attack": &"lantern_sweep"},
	{"boss": "tidecaller", "file": "01_the_pull", "attack": &"the_pull"},
	{"boss": "tidecaller", "file": "02_ring_stream", "attack": &"ring_stream"},
	{
		"boss": "tidecaller",
		"file": "03_streams_and_waves",
		"attack": &"",
		"streams": true,
		"at": [240, 420],
		"view": 24.0
	},
	{"boss": "tidecaller", "file": "04_undertow", "attack": &"undertow"},
	{
		"boss": "tidecaller",
		"file": "05_shell_slam",
		"attack": &"shell_slam",
		"hero": Vector2(2.5, -1.5)
	},
	{
		"boss": "twin_wardens",
		"file": "01_sword_combo",
		"attack": &"sword_combo",
		"hero": Vector2(2.5, -1.5)
	},
	{"boss": "twin_wardens", "file": "02_chain_sweep", "attack": &"chain_sweep"},
	{"boss": "twin_wardens", "file": "03_warden_charge", "attack": &"warden_charge"},
	{
		"boss": "twin_wardens",
		"file": "04_overhead",
		"attack": &"overhead",
		"hero": Vector2(2.5, -1.5)
	},
	{"boss": "twin_wardens", "file": "05_rift_charge", "attack": &"rift_charge"},
	{"boss": "twin_wardens", "file": "06_crossfire", "attack": &"crossfire", "who": 1},
	{"boss": "twin_wardens", "file": "07_orb_volley", "attack": &"orb_volley", "who": 1},
	{"boss": "twin_wardens", "file": "08_rune_ring", "attack": &"rune_ring", "who": 1},
	{"boss": "twin_wardens", "file": "09_blink", "attack": &"blink", "who": 1},
	{"boss": "twin_wardens", "file": "10_warden_bolt", "attack": &"warden_bolt", "who": 1},
	{"boss": "twin_wardens", "file": "11_shadow_swords", "attack": &"shadow_swords", "who": 1},
	{
		"boss": "colossus",
		"file": "01_fist_combo",
		"rig": "final",
		"body": 0,
		"attack": &"fist_combo"
	},
	{"boss": "colossus", "file": "02_leap_slam", "rig": "final", "body": 0, "attack": &"leap_slam"},
	{
		"boss": "colossus",
		"file": "03_spike_chase",
		"rig": "final",
		"body": 0,
		"attack": &"spike_chase"
	},
	{
		"boss": "colossus",
		"file": "04_spike_burst",
		"rig": "final",
		"body": 0,
		"attack": &"spike_burst"
	},
	{
		"boss": "colossus",
		"file": "05_boulder_throw",
		"rig": "final",
		"body": 0,
		"attack": &"boulder_throw",
		"hero": Vector2(7.0, -4.0)
	},
	{
		"boss": "prism",
		"file": "01_cross_ring",
		"rig": "final",
		"body": 1,
		"attack": &"cross_ring",
		"at": [150, 380]
	},
	{
		"boss": "prism",
		"file": "02_cross_spiral",
		"rig": "final",
		"body": 1,
		"attack": &"cross_spiral",
		"at": [150, 250]
	},
	{
		"boss": "prism",
		"file": "03_cross_flower",
		"rig": "final",
		"body": 1,
		"attack": &"cross_flower",
		"at": [150, 250]
	},
	{"boss": "prism", "file": "04_crown_ring", "rig": "final", "body": 1, "attack": &"crown_ring"},
	{
		"boss": "prism",
		"file": "05_prism_bolt",
		"rig": "final",
		"body": 1,
		"attack": &"prism_bolt",
		"at": [24, 38]
	},
	{
		"boss": "prism",
		"file": "06_facet_lances",
		"rig": "final",
		"body": 1,
		"attack": &"facet_lances"
	},
	{
		"boss": "prism",
		"file": "07_prism_kneel",
		"rig": "final",
		"body": 1,
		"attack": &"prism_kneel"
	},
	{
		"boss": "nemesis",
		"file": "01_combo",
		"rig": "final",
		"body": 2,
		"attack": &"nemesis_combo",
		"at": [30, 46]
	},
	{
		"boss": "nemesis",
		"file": "02_crescents",
		"rig": "final",
		"body": 2,
		"attack": &"nemesis_crescents"
	},
	{
		"boss": "nemesis",
		"file": "03_volley",
		"rig": "final",
		"body": 2,
		"attack": &"nemesis_volley"
	},
	{
		"boss": "nemesis",
		"file": "04_point_blank",
		"rig": "final",
		"body": 2,
		"attack": &"nemesis_point_blank",
		"hero": Vector2(2.0, -1.5)
	},
	{
		"boss": "nemesis",
		"file": "05_card_1",
		"rig": "final",
		"body": 2,
		"attack": &"nemesis_card_1"
	},
	{
		"boss": "nemesis",
		"file": "06_card_2",
		"rig": "final",
		"body": 2,
		"attack": &"nemesis_card_2"
	},
	{
		"boss": "nemesis",
		"file": "07_fallen_storm",
		"rig": "final",
		"body": 2,
		"attack": &"fallen_storm"
	},
	{
		"boss": "nemesis",
		"file": "08_fallen_rush",
		"rig": "final",
		"body": 2,
		"attack": &"fallen_rush",
		"hero": Vector2(2.5, -1.5)
	},
]
## Each boss's floor look (the run shuffles the biomes; these are one each boss can meet).
const BIOMES := {
	"gatekeeper": &"ruins",
	"brood_mother": &"night_rocks",
	"lantern_shade": &"starfall",
	"tidecaller": &"frozen_shore",
	"twin_wardens": &"frozen_shore",
}

var _vp: SubViewport
var _world: World
var _root: WorldViewRoot
var _hud: Hud
var _reader: WorldReader
var _out := "res://build/style_audit/"
var _only := ""
var _k := -1
var _boss := -1
var _hero := Vector2.ZERO
var _prep := 0
var _pre := 0
var _t := -1
var _at: Array[int] = []
var _shots: Array[Image] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4).trim_suffix("/") + "/"
		elif a.begins_with("only="):
			_only = a.substr(5)
	TranslationServer.set_locale("en")
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)


func _next() -> bool:
	_k += 1
	while _k < CELLS.size() and _only != "" and not _picked(CELLS[_k]):
		_k += 1
	if _k >= CELLS.size():
		return false
	_build(CELLS[_k])
	return true


func _build(c: Dictionary) -> void:
	if _root != null:
		_root.queue_free()
		_hud.queue_free()
	var final: bool = c.get("rig", "room") == "final"
	if final:
		_world = _final_world(int(c["body"]))
	else:
		_world = _room_world(c)
	var i := _boss_index()
	_hero = _world.actors.pos(i) + (c.get("hero", Vector2(5.0, -3.0)) as Vector2)
	_world.actors.set_pos(0, _hero)
	_world.actors.hp[0] = 1 << 20
	_world.actors.max_hp[0] = 1 << 20
	_world.actors.invuln[0] = 1 << 20
	if c.has("hp"):
		_world.actors.invuln[i] = 0
		_world.actors.hp[i] = _world.actors.max_hp[i] * int(c["hp"]) / 1000
	_world.step(InputFrame.new())
	_reader = WorldReader.new(_world)
	var repo := ContentRepository.load_all()
	var look: BiomeDefinition
	var half := 14.0
	if final:
		look = repo.get_def(&"final_arena", &"hollow_arena")
		half = _reader.final_arena_radius() + 4.0
	else:
		look = repo.get_def(&"biomes", BIOMES[c["boss"]])
	_root = WorldViewRoot.new()
	_vp.add_child(_root)
	_root.stage.mood = look.mood
	_root.stage.prop_style = look.id
	_root.stage.look = look.look
	_root.setup(_reader, look.palette, half)
	var size: float = c.get("view", GAME_VIEW)
	_root.rig.view_size = size
	_root.rig.camera.size = size
	_root.rig.snap_to(SimPlane.to_3d((_hero + _world.actors.pos(i)) * 0.5))
	_root.rig.set_process(false)
	_root.rig.set_physics_process(false)
	_root.rig.camera.current = true
	_hud = Hud.new()
	_vp.add_child(_hud)
	_hud.objective_hints.gate = _always
	_prep = PREP
	_pre = int(c.get("pre", 0))
	_t = -1
	_shots.clear()
	_at.clear()
	for v in c.get("at", []):
		_at.append(int(v))


func _always(_reason: StringName) -> bool:
	return true


func _room_world(c: Dictionary) -> World:
	var id := StringName(c["boss"])
	var w := JudgeLab.world(11)
	var i := BossLab.ready_boss(w, id, Vector2(-2.0, 2.0))
	_boss = w.actors.ids[i]
	match id:
		&"tidecaller":
			TideLab.hush(w, _boss)
			BossAi.table_of(w, i).streams = c.get("streams", false)
		&"twin_wardens":
			TwinsLab.hush(w, _boss)
			var j := BossTwin.partner_of(w, i)
			w.actors.set_pos(j, Vector2(-8.0, 7.0))
			if int(c.get("who", 0)) == 1:
				w.actors.set_pos(i, Vector2(-8.0, 7.0))
				w.actors.set_pos(j, Vector2(-2.0, 2.0))
				_boss = w.actors.ids[j]
		_:
			_hush(BossAi.table_of(w, i))
	return w


func _final_world(body: int) -> World:
	var w: World
	if body == 2:
		w = NemesisLab.world(SEED, &"gun", CARDS, true, true)
	else:
		w = FinalLab.arena(FinalLab.run_state(SEED))
		FinalLab.past_rise(w)
		if body == 1:
			FinalBoss.jump(w, 1)
			FinalLab.past_rise(w)
	var i := FinalLab.body(w)
	_boss = w.actors.ids[i]
	_hush(BossAi.table_of(w, i))
	w.actors.set_pos(i, w.final_fight.home)
	return w


## The boss starts nothing on its own and stands where it is.
func _hush(t: BossTable) -> void:
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.sig_every_ticks = 0
	t.speed = 0.0


func _boss_index() -> int:
	return _world.actors.index_of(_boss)


func _tick() -> void:
	_world.actors.set_pos(0, _hero)
	_world.actors.hp[0] = _world.actors.max_hp[0]
	_world.step(InputFrame.new())
	_root.sync()
	_hud.sync(_reader)


func _start() -> void:
	var c: Dictionary = CELLS[_k]
	var i := _boss_index()
	_world.actors.state[i] = EnemyAi.State.MOVE
	var t := BossAi.table_of(_world, i)
	if c["attack"] == &"":  # Nothing started: what the boss runs on its own (its streams) is caught
		return
	var a := t.attack_index(c["attack"])
	if a < 0:
		print("style_audit_b: no attack ", c["attack"])
		_at = [0]
		return
	if c.get("aim", "") == "pillar":
		_aim_through_pillar(i)
	BossLab.start(_world, i, c["attack"])
	if _at.is_empty():
		var at := t.attacks[a]
		_at = [at.windup_ticks * 3 / 4, at.windup_ticks + mini(at.active_ticks, 40) + 8]


## The hero beyond the boss's first quake pillar, so its lanes run through it and shatter it.
func _aim_through_pillar(i: int) -> void:
	var mine := BossQuake.pillars_of(_world, _world.actors.ids[i])
	if mine.is_empty():
		return
	var p := BossQuake.center(_world.bosses, mine[0])
	var from := _world.actors.pos(i)
	_hero = from + (p - from).normalized() * (from.distance_to(p) + 2.5)
	_world.actors.set_pos(0, _hero)


func _save() -> void:
	var c: Dictionary = CELLS[_k]
	var img := Image.create(SIZE.x * _shots.size(), SIZE.y, false, Image.FORMAT_RGB8)
	for n in _shots.size():
		img.blit_rect(_shots[n], Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * n, 0))
	var dir: String = _out + String(c["boss"]) + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path: String = dir + String(c["file"]) + ".png"
	img.save_png(path)
	print("style_audit_b: ", ProjectSettings.globalize_path(path), "  at ", _at)


func _process(_delta: float) -> bool:
	var going := _k >= 0 and _k < CELLS.size()
	if _k < 0:
		going = _next()
	elif going:
		going = _frame()
	if not going:
		quit(0)
	return not going


## One frame of the current cell; false once the last cell is saved.
func _frame() -> bool:
	if _prep > 0:
		_prep -= 1
		_root.sync()
		_hud.sync(_reader)
	elif _pre > 0:
		_pre -= 1
		_tick()
	elif _t < 0:
		_start()
		_t = 0
		_tick()
	elif _shots.size() < _at.size() and _t >= _at[_shots.size()] + 1:
		# This frame shows the last tick's sync.
		var img := _vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		_shots.append(img)
		if _shots.size() >= _at.size():
			_save()
			return _next()
	else:
		_tick()
		_t += 1
	return true


## A cell `only=` asks for: its boss, or its boss/file (a comma-separated list).
func _picked(c: Dictionary) -> bool:
	for o in _only.split(","):
		if o == c["boss"] or o == "%s/%s" % [c["boss"], c["file"]]:
			return true
	return false

# gdlint: disable=max-file-lines
extends SceneTree
## v0.10.5 W3-O4 (PLAN F18, a G1: measure, change nothing): the progression audit's numbers. Owner 2026-11-04: forms
## don't always beat the default, Wave/Void + Fire + Venom is huge by floor 2, power plateaus across loops, a few cards
## dominate. Fights reuse tests/support/build_fight.gd's arena and rules (the Playground's world: one walled room,
## every wand slot, heat on, crit on, the hero unhurtable; the Gun holds Shoot and stands still, the Blade presses
## Primary every tick and walks at the nearest dummy), with one change: the Lance is held for its full charge and
## released (scripts/balance/forms_dps.gd's cycle), since a held Shoot never fires it.
## Two scenes per build:
## - single: one endless dummy 5 m (Gun) / 1.6 m (Blade) ahead; DPS = every point of HP it lost (DpsTally: hits and
##   damage over time) over the fight.
## - crowd: BuildFight's PACK (12 dummies in a 4 x 3 grid, a dead one back at its spot 1 s later) of `hp` each; DPS
##   over the fight and the time to kill the first 12 ("clear s", the fight's length + if not cleared).
## The Rune Explosion (a burst around the hero) is fought with its dummies where the Blade's stand.
## Sections (section=a|b|c|d, or all):
## - a: every form at its card's level 1 (Gun forms have one level; Blade forms at 1 and 5) vs the default attack, no
##   elements, no stats, floor-1 crowd HP.
## - b: form x element (each of the five, Lv 1 and Lv 3) and the stacked builds by floor 1-5 and loops 1-3 (TRACKS:
##   cards and levels inside the wand's slots by floor 4..8 and the level ceilings 2/3/5/5/5, plus three offence stat
##   cards a floor as three_curves.gd's bot), each against that floor's crowd HP: the Charger's floor-1 HP x
##   five_floors' HP factor / floor 1's x 3.5 per loop past the first x the catch-up m (CatchUp.multiplier on the
##   build's P at floor entry, cap + 0.25 T + 0.5 a loop, T = 2 a loop).
## - c: each card's marginal gain (Lv 1, and at its floor-3 ceiling) added to four typical floor-3 builds, single and
##   crowd, next to the change in the catch-up's P (what the hidden scaling sees of it).
## - d: the end of the staircase: the floor-5 stack plus N more stat-card floors (3 a floor) and its stats read back.
## v0.10.5 W3-P3 (overlevels): from loop 2, b3's tracks hold their floor-5 cards (a loop never takes cards away) and
## take `over_per_floor` level-ups a floor (default 2: an altar's and a chest's pick), round robin over the cards in
## build order, each up to its cap that loop (level_max + loop − 1); the world is on that loop with the shipped pacing
## table so the cap holds. d adds the floor-5 build at loop 2 / 3 with every overlevel taken. over=0: no overlevels
## (the cards at their floor-5 levels, the world in loop 1: the numbers before W3-P3). over_permille=N probes another
## overlevel step (every category; the data unchanged). out=<name> names the file.
## v0.10.5 W3-P10h (docs/roadmap/v0.10.5/W3_W7_LOOP_POWER_G1.md T1-T3): b3's looped rows can also hold the loop-only
## power of W3-P10 (p10=1, the default; p10=0 the W3-P3 rows as before; p10=both each track's loops 2+ both ways, the
## same loop-1 rows and P chain up to loop 2):
## - the Constellation pick: at each loop's start (2..), the offer the run seed `const_seed` (default 1) draws
##   (Constellations.offer, the shipped rule), answered by the track's fixed preference (P10: the first offered id in
##   its order); const_offer=0 takes the preference's best still offerable id instead (no draw). A Gun track's Prism
##   adds its next element card (P10 "prism", Lv 1; it then takes overlevels like the others).
## - the Starbound cards: a regular altar's offer holds one with the loop's chance (rewards floor.tres
##   starbound_permille: 20 % at loop 2, 30 % from loop 3); the probe takes `sb_altars` (default 2: the floor's regular
##   altars) offers a floor and so floor(chance x sb_altars x floors so far) Starbound picks by a floor of the loop
##   (2 at loop 2's floor 5, 3 more at loop 3's), each in place of one of that floor's overlevel picks (the altar's),
##   always taken, its card round robin over the track's Starbound preference (P10 "starbound"). The card the stream
##   would draw is not modelled: the preference stands in for it.
## The b3 summary prints each track's floor-5 power against the HP (eff single / eff crowd) at loops 2 and 3 as a % of
## loop 1's. The W3-P10 A rules (overflow) are sim rules: the probe picks them up as they are in the tree it runs on.
## Weak builds for T2: gun_stats_only and blade_stats_only (the default attack, the stat cards only).
## Prints lines and writes build/<dir>/<out>.txt (dir default progression_audit); copy numbers into the audit by hand.
##   godot --headless --path . -s scripts/balance/progression_audit.gd -- section=a seconds=12
##   godot --headless --path . -s scripts/balance/progression_audit.gd -- section=b part=tracks p10=both
##     dir=balance/w3p10h out=b3_p10   (W3-P10h)

const RESPAWN_TICKS := 60
const ENDLESS := 0

const GUN_FORMS: Array[StringName] = [
	&"",
	&"gun_laser",
	&"gun_void",
	&"gun_lance",
	&"gun_rune_explosion",
	&"gun_glaive",
	&"gun_seekers",
	&"gun_wave",
	&"gun_wisps",
]
## Blade forms (loot_category form). Counter and Parry Edge answer enemy attacks; the dummies never attack.
const BLADE_FORMS: Array[StringName] = [
	&"",
	&"echo_slash",
	&"blade_orbit",
	&"chain_cut",
	&"fissure",
	&"flurry",
	&"heavy",
	&"lunge_step",
	&"counter",
	&"parry_edge",
]
const ELEMENTS: Array[StringName] = [
	&"ember_core", &"venom_core", &"shared_bleed", &"storm_core", &"frost_core"
]

## Stacked builds by floor: [weapon, [floor 1 tokens], ..., [floor 5 tokens]]; each floor lists the whole build
## ("id:level"). Slots by floor 4/5/6/7/8 (data/wand/wand.tres); levels under the ceilings 2/3/5/5/5 and (v0.10.5
## W3-P2) the element ceilings 1/2/2/3/3
## (data/rewards/pacing.tres; Gun forms and pattern/secondary cards have level_max 1, elements and Split/Twin/Halo 3).
const TRACKS := {
	"gun_orbs_plain":
	[
		&"gun",
		["gun_twin:1", "gun_pierce:1"],
		["gun_twin:2", "gun_pierce:1", "gun_homing:1"],
		["gun_twin:3", "gun_pierce:1", "gun_homing:1", "split_shot:1"],
		["gun_twin:3", "gun_pierce:1", "gun_homing:1", "split_shot:2", "chain_blast:1"],
		[
			"gun_twin:3",
			"gun_pierce:1",
			"gun_homing:1",
			"split_shot:3",
			"chain_blast:2",
			"shared_faultline:1"
		],
	],
	"gun_void_fire_venom":
	[
		&"gun",
		["gun_void:1", "ember_core:1", "venom_core:1"],
		["gun_void:1", "ember_core:2", "venom_core:2", "chain_blast:1"],
		[
			"gun_void:1",
			"ember_core:2",
			"venom_core:2",
			"chain_blast:2",
			"split_shot:1",
			"gun_twin:1"
		],
		[
			"gun_void:1",
			"ember_core:3",
			"venom_core:3",
			"chain_blast:3",
			"split_shot:2",
			"gun_twin:2",
			"gun_homing:1"
		],
		[
			"gun_void:1",
			"ember_core:3",
			"venom_core:3",
			"chain_blast:4",
			"split_shot:3",
			"gun_twin:3",
			"gun_homing:1",
			"gun_echo:1"
		],
	],
	"gun_wave_fire_venom":
	[
		&"gun",
		["gun_wave:1", "ember_core:1", "venom_core:1"],
		["gun_wave:1", "ember_core:2", "venom_core:2", "chain_blast:1"],
		[
			"gun_wave:1",
			"ember_core:2",
			"venom_core:2",
			"chain_blast:2",
			"split_shot:1",
			"gun_twin:1"
		],
		[
			"gun_wave:1",
			"ember_core:3",
			"venom_core:3",
			"chain_blast:3",
			"split_shot:2",
			"gun_twin:2",
			"gun_homing:1"
		],
		[
			"gun_wave:1",
			"ember_core:3",
			"venom_core:3",
			"chain_blast:4",
			"split_shot:3",
			"gun_twin:3",
			"gun_homing:1",
			"gun_echo:1"
		],
	],
	"blade_plain":
	[
		&"blade",
		["wide_arc:1", "double_slash:1"],
		["wide_arc:2", "double_slash:2", "finisher_plus:1"],
		["wide_arc:3", "double_slash:3", "finisher_plus:2", "riposte_chain:1"],
		["wide_arc:4", "double_slash:4", "finisher_plus:3", "riposte_chain:2", "blade_storm:1"],
		[
			"wide_arc:5",
			"double_slash:5",
			"finisher_plus:4",
			"riposte_chain:3",
			"blade_storm:2",
			"split_wave:1"
		],
	],
	"blade_wave_elements":
	[
		&"blade",
		["echo_slash:1", "ember_core:1", "venom_core:1"],
		["echo_slash:2", "ember_core:2", "venom_core:2", "chain_blast:1"],
		[
			"echo_slash:3",
			"ember_core:2",
			"venom_core:2",
			"chain_blast:2",
			"shared_bleed:1",
			"split_wave:1"
		],
		[
			"echo_slash:4",
			"ember_core:3",
			"venom_core:3",
			"chain_blast:3",
			"shared_bleed:2",
			"split_wave:2",
			"storm_core:1"
		],
		[
			"echo_slash:5",
			"ember_core:3",
			"venom_core:3",
			"chain_blast:4",
			"shared_bleed:3",
			"split_wave:3",
			"storm_core:2",
			"frost_core:1"
		],
	],
	"blade_wave_no_elements":
	[
		&"blade",
		["echo_slash:1", "wide_arc:1"],
		["echo_slash:2", "wide_arc:2", "double_slash:1"],
		["echo_slash:3", "wide_arc:3", "double_slash:2", "finisher_plus:1", "split_wave:1"],
		[
			"echo_slash:4",
			"wide_arc:4",
			"double_slash:3",
			"finisher_plus:2",
			"split_wave:2",
			"blade_storm:1"
		],
		[
			"echo_slash:5",
			"wide_arc:5",
			"double_slash:4",
			"finisher_plus:3",
			"split_wave:3",
			"blade_storm:2",
			"riposte_chain:1"
		],
	],
	# W3-P10h (T2): weak builds, no engine: the default attack and the stat cards only.
	"gun_stats_only": [&"gun", [], [], [], [], []],
	"blade_stats_only": [&"blade", [], [], [], [], []],
}
const TRACK_ORDER: Array[String] = [
	"gun_orbs_plain",
	"gun_void_fire_venom",
	"gun_wave_fire_venom",
	"blade_plain",
	"blade_wave_no_elements",
	"blade_wave_elements",
	"gun_stats_only",
	"blade_stats_only",
]
## W3-P10h: each track's W3-P10 policy: "const" its Constellation preference (best first), "prism" the element card a
## Gun run's first / second Prism adds, "starbound" its Starbound cards, round robin.
const C_PRISM := Constellations.PRISM
const C_TWIN := Constellations.TWIN_STAR
const C_GLASS := Constellations.GLASS_SKY
const C_STAR := Constellations.STARFALL
const C_DEEP := Constellations.DEEP_WOUNDS
const C_NOVA := Constellations.SUPERNOVA
const C_HUNT := Constellations.HUNTERS_SKY
const GUN_ELEMENTS_P10 := {
	"const": [C_TWIN, C_PRISM, C_GLASS, C_DEEP, C_STAR, C_NOVA, C_HUNT],
	"prism": ["shared_bleed:1", "storm_core:1"],
	"starbound": [Starbound.ECHO_CAST, Starbound.DETONATION, Starbound.ARC_JUMP],
}
const BLADE_PLAIN_P10 := {
	"const": [C_TWIN, C_GLASS, C_NOVA, C_STAR, C_HUNT, C_DEEP, C_PRISM],
	"prism": [],
	"starbound": [Starbound.FERVOUR, Starbound.RISING_EDGE, Starbound.ARC_JUMP],
}
const WEAK_P10 := {
	"const": [C_GLASS, C_NOVA, C_STAR, C_HUNT, C_TWIN, C_DEEP, C_PRISM],
	"prism": [],
	"starbound": [Starbound.RISING_EDGE, Starbound.FERVOUR, Starbound.ARC_JUMP],
}
const P10 := {
	"gun_orbs_plain":
	{
		"const": [C_TWIN, C_GLASS, C_NOVA, C_STAR, C_HUNT, C_PRISM, C_DEEP],
		"prism": [],
		"starbound": [Starbound.ARC_JUMP, Starbound.ECHO_CAST, Starbound.RISING_EDGE],
	},
	"gun_void_fire_venom": GUN_ELEMENTS_P10,
	"gun_wave_fire_venom": GUN_ELEMENTS_P10,
	"blade_plain": BLADE_PLAIN_P10,
	"blade_wave_no_elements": BLADE_PLAIN_P10,
	"blade_wave_elements":
	{
		"const": [C_DEEP, C_PRISM, C_TWIN, C_GLASS, C_STAR, C_NOVA, C_HUNT],
		"prism": [],
		"starbound": [Starbound.DETONATION, Starbound.ECHO_CAST, Starbound.ARC_JUMP],
	},
	"gun_stats_only": WEAK_P10,
	"blade_stats_only": WEAK_P10,
}

## Section c's floor-3 bases: [name, weapon, tokens].
const BASES: Array = [
	["gun_orbs", &"gun", []],
	["gun_void", &"gun", ["gun_void:1"]],
	["blade_default", &"blade", []],
	["blade_wave", &"blade", ["echo_slash:3"]],
]
## Section c's cards per weapon.
const GUN_CARDS: Array[StringName] = [
	&"gun_twin",
	&"halo_shot",
	&"gun_ring",
	&"gun_backfire",
	&"gun_pierce",
	&"gun_ricochet",
	&"gun_homing",
	&"gun_echo",
	&"gun_big_shot",
	&"gun_rapid_fire",
	&"split_shot",
	&"gun_mine",
	&"orbit_rounds",
	&"gun_threadline",
	&"gun_spiral",
	&"gun_swirl",
	&"chain_blast",
	&"shared_faultline",
	&"shared_stress_mark",
	&"ember_core",
	&"venom_core",
	&"shared_bleed",
	&"storm_core",
	&"frost_core",
]
const BLADE_CARDS: Array[StringName] = [
	&"echo_slash",
	&"blade_orbit",
	&"chain_cut",
	&"fissure",
	&"flurry",
	&"heavy",
	&"lunge_step",
	&"thrust",
	&"whirl",
	&"wide_arc",
	&"double_slash",
	&"split_wave",
	&"blade_storm",
	&"finisher_plus",
	&"riposte_chain",
	&"chain_blast",
	&"shared_faultline",
	&"shared_stress_mark",
	&"ember_core",
	&"venom_core",
	&"shared_bleed",
	&"storm_core",
	&"frost_core",
]
## Section c/d's stat-only cards (rare: floor 3's rarity in three_curves.gd's bot): [stat, rarity].
const STAT_CARDS: Array = [
	["damage", 1],
	["attack_speed", 1],
	["crit_chance", 1],
	["crit_damage", 1],
	["glass_cannon", 1],
	["onrush", 1],
	["third_strike", 1],
	["close_quarters", 1],
	["overkill", 1],
]

var _repo: ContentRepository
var _biome: BiomeDefinition
var _seconds := 12.0
var _base_hp := 0
var _floor_hp := PackedInt32Array()
var _loop_hp := 3500
var _cu: CatchUpTable
var _out := PackedStringArray()
var _items := {}
var _tables: Array = []
var _stats := {}
## W3-P3: the shipped pacing table (overlevels), whether b3/d take overlevels, how many a floor, the fights' loop.
var _pacing: LootPacingTable
var _over := true
var _over_per_floor := 2
var _loop := 1
## W3-P10h: the p10 mode ("1", "0", "both"), the Constellation draw, the Starbound model, and the next fight's
## Constellations (in pick order) and Starbound picks (by card).
var _p10 := "1"
var _const_seed := 1
var _const_offer := true
var _sb_altars := 2
var _sb_rate := PackedInt32Array()
var _sb_tables: Array[StarboundTable] = []
var _consts := PackedInt32Array()
var _sb := PackedInt32Array()


func _initialize() -> void:
	var args := ScriptArgs.parse()
	_seconds = float(args.get("seconds", 12))
	_repo = ContentRepository.load_all()
	var run_def: RunDefinition = _repo.get_def(&"run", RunSaver.RUN_ID)
	_biome = _repo.get_def(&"biomes", run_def.biomes[0])
	_floor_hp = run_def.enemy_hp_floor_permille
	_loop_hp = run_def.loop_enemy_hp_permille
	_cu = ContentCompiler.compile_catch_up(_repo.get_def(&"scaling", &"catch_up"))
	_pacing = RunContentCompiler.compile_loot_pacing(_repo.get_def(&"loot_pacing", &"pacing"))
	_over = int(args.get("over", 1)) != 0
	_over_per_floor = int(args.get("over_per_floor", 2))
	if args.has("over_permille"):  # a probe of another overlevel value (the shipped data stays as it is)
		var pm := int(args["over_permille"])
		_pacing.overlevel_permille = PackedInt32Array([pm, pm, pm, pm, pm])
	_p10 = String(args.get("p10", "1"))
	_const_seed = int(args.get("const_seed", 1))
	_const_offer = int(args.get("const_offer", 1)) != 0
	_sb_altars = int(args.get("sb_altars", 2))
	var rewards: RewardsDefinition = _repo.get_def(&"rewards", &"floor")
	_sb_rate = rewards.starbound_permille
	_sb_tables = ContentCompiler.compile_starbound(_repo)
	var probe := PlaygroundScenario.build(_repo, &"gun", _biome)
	_base_hp = probe.enemy_table(ActorStore.Kind.CHARGER).hp
	var section := String(args.get("section", "all"))
	_line(
		"progression_audit section=%s seconds=%.1f crowd base hp %d" % [section, _seconds, _base_hp]
	)
	if section in ["a", "all"]:
		_section_a()
	if section in ["b", "all"]:
		_section_b(args)
	if section in ["c", "all"]:
		_section_c(args)
	if section in ["d", "all"]:
		_section_d(args)
	_line("determinism: %s" % _determinism())
	var dir := "res://build/%s" % String(args.get("dir", "progression_audit"))  # W3-P10h
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out_name := String(args.get("out", section))  # W3-P3
	var f := FileAccess.open("%s/%s.txt" % [dir, out_name], FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_out) + "\n")
		f.close()
	quit(0)


func _line(s: String) -> void:
	print(s)
	_out.append(s)


# --- a: forms vs the default -----------------------------------------------------------------------------------
func _section_a() -> void:
	_line("## a: forms vs the default (no elements, no stats; crowd HP %d)" % _base_hp)
	_line("weapon | form | Lv | single dps | x default | crowd dps | x default | clear s | P")
	for weapon: StringName in [&"gun", &"blade"]:
		var forms := GUN_FORMS if weapon == &"gun" else BLADE_FORMS
		var base := _both(weapon, [], _base_hp)
		for form: StringName in forms:
			var levels: Array = [1]
			if weapon == &"blade" and form != &"":
				levels = [1, 5]
			for lv: int in levels:
				var toks: Array = [] if form == &"" else ["%s:%d" % [form, lv]]
				var r := base if form == &"" else _both(weapon, toks, _base_hp)
				_line(
					(
						"%s | %s | %s | %.1f | %.2f | %.1f | %.2f | %s | %d"
						% [
							weapon,
							"default" if form == &"" else str(form),
							"-" if form == &"" else str(lv),
							r["single"],
							r["single"] / maxf(0.01, base["single"]),
							r["crowd"],
							r["crowd"] / maxf(0.01, base["crowd"]),
							r["clear"],
							r["p"],
						]
					)
				)


# --- b: form x element, and the stacks by floor and loop -------------------------------------------------------
func _section_b(args: Dictionary) -> void:
	var part := String(args.get("part", "all"))
	if part in ["pairs", "all"]:
		_line(
			"## b1: form x element (the element at Lv 1 / Lv 3; no stats; crowd HP %d)" % _base_hp
		)
		_line(
			"weapon | form | element | Lv | single dps | x form alone | crowd dps | x form alone | clear s"
		)
		for weapon: StringName in [&"gun", &"blade"]:
			var forms: Array = (
				[&"", &"gun_void", &"gun_wave", &"gun_laser", &"gun_seekers", &"gun_glaive"]
				if weapon == &"gun"
				else [&"", &"echo_slash", &"flurry", &"heavy"]
			)
			for form: StringName in forms:
				var ft: Array = (
					[] if form == &"" else ["%s:%d" % [form, 1 if weapon == &"gun" else 3]]
				)
				var alone := _both(weapon, ft, _base_hp)
				for el: StringName in ELEMENTS:
					for lv: int in [1, 3]:
						var toks := ft.duplicate()
						toks.append("%s:%d" % [el, lv])
						var r := _both(weapon, toks, _base_hp)
						_line(
							(
								"%s | %s | %s | %d | %.1f | %.2f | %.1f | %.2f | %s"
								% [
									weapon,
									"default" if form == &"" else str(form),
									el,
									lv,
									r["single"],
									r["single"] / maxf(0.01, alone["single"]),
									r["crowd"],
									r["crowd"] / maxf(0.01, alone["crowd"]),
									r["clear"],
								]
							)
						)
	if part in ["pairs", "stacks", "all"]:  # v0.10.5 W3-P1b: part=stacks runs b2 alone
		_line(
			(
				"## b2: element stacking on one form (each step adds one element at Lv 3; crowd HP %d)"
				% _base_hp
			)
		)
		_line(
			"weapon | build | single dps | x previous | x form alone | crowd dps | x previous | x form alone"
		)
		var stacks: Array = [
			[&"blade", "echo_slash:3"],
			[&"blade", ""],
			[&"gun", "gun_void:1"],
			[&"gun", "gun_wave:1"]
		]
		var pick := String(args.get("stacks", ""))  # v0.10.5 W3-P1b: stacks=1,2 runs only those (0-based)
		for si in stacks.size():
			if pick != "" and not (str(si) in pick.split(",")):
				continue
			var st: Array = stacks[si]
			var toks: Array = [] if st[1] == "" else [st[1]]
			var first := _both(st[0], toks, _base_hp)
			var prev := first
			_line(
				(
					"%s | %s | %.1f | - | 1.00 | %.1f | - | 1.00"
					% [st[0], "+".join(toks), first["single"], first["crowd"]]
				)
			)
			for el: StringName in ELEMENTS:
				toks.append("%s:3" % el)
				var r := _both(st[0], toks, _base_hp)
				_line(
					(
						"%s | %s | %.1f | %.2f | %.2f | %.1f | %.2f | %.2f"
						% [
							st[0],
							"+".join(toks),
							r["single"],
							r["single"] / maxf(0.01, prev["single"]),
							r["single"] / maxf(0.01, first["single"]),
							r["crowd"],
							r["crowd"] / maxf(0.01, prev["crowd"]),
							r["crowd"] / maxf(0.01, first["crowd"]),
						]
					)
				)
				prev = r
	if part in ["tracks", "all"]:
		var loops := int(args.get("loops", 3))
		var only := String(args.get("tracks", ""))
		_line(
			"## b3: stacked builds by floor and loop (the floor's crowd HP x the catch-up m read at floor entry)"
		)
		_line(
			(
				"track | loop | floor | cards | stats | P entry | m | crowd hp | single dps | crowd dps | clear s"
				+ " | eff single | eff crowd | card levels | P10 | constellations | starbound picks | missing"
			)
		)
		var modes: Array = [false, true] if _p10 == "both" else ([false] if _p10 == "0" else [true])
		var summary: Array = []
		for name: String in TRACK_ORDER:
			if only != "" and not (name in only.split(",")):
				continue
			var tr: Array = TRACKS[name]
			var p_entry := _fresh_p(weapon_of(tr))
			var l1 := {}
			for f in range(1, 6):  # loop 1: the same rows either way (W3-P10 acts from loop 2, T3)
				l1 = _track_row(name, 1, f, p_entry, false)
				p_entry = l1["p"]
			var p_l1 := p_entry
			for p10: bool in modes:
				p_entry = p_l1
				var f5 := {1: l1}
				for loop in range(2, loops + 1):
					for f in range(1, 6):
						var row := _track_row(name, loop, f, p_entry, p10)
						p_entry = row["p"]
						if f == 5:
							f5[loop] = row
				summary.append([name, p10, f5])
		_b3_summary(summary, loops)


## W3-P10h: one b3 row of track `name` (printed): floor f of loop `loop`, P `p_entry` at its entry, with (p10) the
## track's Constellations and Starbound picks by then. {p, single, crowd, consts, sb}: eff single / crowd.
func _track_row(name: String, loop: int, f: int, p_entry: int, p10: bool) -> Dictionary:
	var tr: Array = TRACKS[name]
	var weapon := weapon_of(tr)
	var pname := name if p10 else ""
	var toks := _loop_tokens(tr, loop, f, pname)  # W3-P3: loop 2 on: the floor-5 cards, overlevels taken
	var stats := _stat_tokens(loop, f)
	toks.append_array(stats)
	var threat := 2 * (loop - 1)
	var cap := CatchUp.cap_at(_cu.cap_permille, _cu, f, threat) + 500 * (loop - 1)
	var m := CatchUp.multiplier(p_entry, CatchUpTable.at_floor(_cu.expected_permille, f), cap)
	var hp := _crowd_hp(f, loop, m)
	_loop = loop if (_over or p10) else 1
	_consts = _consts_at(pname, loop)
	_sb = _sb_at(pname, loop, f)
	var r := _both(weapon, toks, hp)
	var consts := _consts
	var sb := _sb
	_loop = 1
	_consts = PackedInt32Array()
	_sb = PackedInt32Array()
	# effective: the DPS over the floor's enemy HP factor (hp / base hp), so 1.0 = today's DPS against floor 1's plain
	# HP.
	var factor := float(hp) / float(_base_hp)
	_line(
		(
			"%s | %d | %d | %d | %d | %d | %d | %d | %.1f | %.1f | %s | %.2f | %.2f | %s | %s | %s | %s | %d"
			% [
				name,
				loop,
				f,
				toks.size() - stats.size(),
				stats.size(),
				p_entry,
				m,
				hp,
				r["single"],
				r["crowd"],
				r["clear"],
				r["single"] / factor,
				r["crowd"] / factor,
				_levels_of(toks),
				"on" if p10 else "off",
				_const_names(consts),
				_sb_text(sb),
				r["missing"],
			]
		)
	)
	return {
		"p": r["p"],
		"single": r["single"] / factor,
		"crowd": r["crowd"] / factor,
		"consts": consts,
		"sb": sb,
	}


## W3-P10h: each track's floor-5 power against the HP at loops 2.. as a % of its loop-1 floor 5 (T1: 80-120 % for a
## strong build; T2: under 50 % at loop 2 for a weak one).
func _b3_summary(summary: Array, loops: int) -> void:
	_line(
		"## b3 summary: floor-5 eff (dps / (crowd hp / base hp)) at loop L as % of loop 1 floor 5"
	)
	var head := "track | P10 | L1 F5 eff single | L1 F5 eff crowd"
	for loop in range(2, loops + 1):
		head += " | L%d F5 single %% | L%d F5 crowd %%" % [loop, loop]
	_line(head + " | constellations | starbound picks (last row)")
	for s: Array in summary:
		var f5: Dictionary = s[2]
		var base: Dictionary = f5[1]
		var row := (
			"%s | %s | %.2f | %.2f" % [s[0], "on" if s[1] else "off", base["single"], base["crowd"]]
		)
		var last: Dictionary = base
		for loop in range(2, loops + 1):
			var r: Dictionary = f5[loop]
			row += (
				" | %.0f | %.0f"
				% [
					100.0 * r["single"] / maxf(0.001, base["single"]),
					100.0 * r["crowd"] / maxf(0.001, base["crowd"])
				]
			)
			last = r
		_line(row + " | %s | %s" % [_const_names(last["consts"]), _sb_text(last["sb"])])


static func weapon_of(tr: Array) -> StringName:
	return tr[0]


## W3-P10h: the Constellations track `name` holds in loop `loop` (none for "" or loop 1), in pick order: each loop's
## offer (Constellations.offer on _const_seed; const_offer=0: every id still offerable) answered by P10's preference.
func _consts_at(name: String, loop: int) -> PackedInt32Array:
	var held := PackedInt32Array()
	if name == "":
		return held
	var pref: Array = P10[name]["const"]
	for l in range(2, loop + 1):
		var offer := (
			Constellations.offer(_const_seed, l, held)
			if _const_offer
			else Constellations.offerable(held)
		)
		if offer.is_empty():
			continue
		var pick := offer[0]
		for id: int in pref:
			if offer.has(id):
				pick = id
				break
		held.append(pick)
	return held


## W3-P10h: Starbound picks on floor f of loop `loop` (class doc: floor(chance x sb_altars x floors) so far, less the
## floors before).
func _sb_floor(loop: int, f: int) -> int:
	if loop < Starbound.FROM_LOOP or _sb_rate.is_empty():
		return 0
	var rate := _sb_rate[mini(loop - Starbound.FROM_LOOP, _sb_rate.size() - 1)]
	return rate * _sb_altars * f / 1000 - rate * _sb_altars * (f - 1) / 1000


## W3-P10h: the Starbound picks by card track `name` holds at floor f of loop `loop` (round robin over its preference).
func _sb_at(name: String, loop: int, f: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if name == "":
		return out
	out.resize(Starbound.COUNT)
	var pref: Array = P10[name]["starbound"]
	var n := 0
	for l in range(Starbound.FROM_LOOP, loop + 1):
		for ff in range(1, (5 if l < loop else f) + 1):
			for k in _sb_floor(l, ff):
				out[pref[n % pref.size()]] += 1
				n += 1
	return out


static func _const_names(ids: PackedInt32Array) -> String:
	var out := PackedStringArray()
	for id in ids:
		out.append(String(Constellations.NAMES.get(id, "?")))
	return "-" if out.is_empty() else "+".join(out)


static func _sb_text(sb: PackedInt32Array) -> String:
	if sb.is_empty():
		return "-"
	var names := ["arc", "edge", "echo", "fervour", "deto"]
	var out := PackedStringArray()
	for k in sb.size():
		if sb[k] > 0:
			out.append("%s x%d" % [names[k], sb[k]])
	return "-" if out.is_empty() else " ".join(out)


## W3-P3: track `tr`'s cards on floor f of loop `loop`: loop 1 its floor's build; later loops its floor-5 build, with
## (when _over) _over_per_floor level-ups a floor from loop 2 on, round robin over the cards in build order, each up to
## its cap that loop (level_max + loop - 1, CardLevels.cap's rule with the shipped one overlevel a loop).
## W3-P10h: with `p10` (a track name), each loop's Prism adds the track's next P10 "prism" card at that loop's start,
## and each floor's Starbound picks (_sb_floor) take the place of as many of its overlevel picks.
func _loop_tokens(tr: Array, loop: int, f: int, p10: String = "") -> Array:
	var toks: Array = (tr[mini(5, f) if loop <= 1 else 5] as Array).duplicate()
	if loop <= 1 or (not _over and p10 == ""):
		return toks
	var ids: Array[StringName] = []
	var lv: Array[int] = []
	for tok: String in toks:
		var p := tok.split(":")
		ids.append(StringName(p[0]))
		lv.append(int(p[1]))
	var rr := 0
	var prisms := 0
	for l in range(2, loop + 1):
		if p10 != "":
			var adds: Array = P10[p10]["prism"]
			var held := _consts_at(p10, l).count(Constellations.PRISM)
			while prisms < held:
				if prisms < adds.size():
					var p := String(adds[prisms]).split(":")
					ids.append(StringName(p[0]))
					lv.append(int(p[1]))
				prisms += 1
		if not _over:
			continue
		for ff in 5 if l < loop else f:
			var picks := _over_per_floor - (_sb_floor(l, ff + 1) if p10 != "" else 0)
			for k in maxi(0, picks):
				for tries in ids.size():
					var c := rr % ids.size()
					rr += 1
					if lv[c] < _level_max(ids[c]) + (l - 1) * _pacing.overlevels_per_loop:
						lv[c] += 1
						break
	var out: Array = []
	for c in ids.size():
		out.append("%s:%d" % [ids[c], lv[c]])
	return out


## W3-P3: the card levels of `toks` ("id:level"; stat cards left out), joined by "/".
static func _levels_of(toks: Array) -> String:
	var out := PackedStringArray()
	for tok: String in toks:
		if not tok.begins_with("s:"):
			out.append(tok.split(":")[1])
	return "/".join(out)


## Crowd HP on floor f of loop `loop` at catch-up m (per mille).
func _crowd_hp(f: int, loop: int, m: int) -> int:
	var hp := float(_base_hp) * float(_floor_hp[f - 1]) / float(_floor_hp[0])
	hp *= pow(float(_loop_hp) / 1000.0, loop - 1)
	hp *= float(m) / 1000.0
	return maxi(1, int(round(hp)))


## The offence stat cards held at the end of floor f of loop `loop`: three a floor, damage / attack speed / crit chance
## round robin (three_curves.gd's bot): common on floors 1-2, rare on 3-4, epic on 5; every floor of an earlier loop
## counted at its own rarity.
static func _stat_tokens(loop: int, f: int) -> Array:
	var out: Array = []
	var stats: Array[StringName] = [&"damage", &"attack_speed", &"crit_chance"]
	var n := 0
	for l in range(1, loop + 1):
		for ff in range(1, 6):
			if l == loop and ff > f:
				break
			var rarity := 0 if ff <= 2 else (1 if ff <= 4 else 2)
			for k in 3:
				out.append("s:%s:%d" % [stats[n % 3], rarity])
				n += 1
	return out


# --- c: each card's marginal gain -----------------------------------------------------------------------------
func _section_c(args: Dictionary) -> void:
	var hp := _crowd_hp(3, 1, 1000)
	var only := String(args.get("bases", ""))
	_line(
		(
			"## c: marginal gain of one card on a floor-3 build (floor-3 stats: 9 cards; crowd HP %d)"
			% hp
		)
	)
	_line("base | card | Lv | single x | crowd x | P x | real/P single | real/P crowd")
	for b: Array in BASES:
		if only != "" and not (String(b[0]) in only.split(",")):
			continue
		var weapon: StringName = b[1]
		var base_toks: Array = (b[2] as Array).duplicate()
		base_toks.append_array(_stat_tokens(1, 3))
		var base := _both(weapon, base_toks, hp)
		_line(
			(
				"%s | (base) | - | single %.1f | crowd %.1f | P %d | clear %s"
				% [b[0], base["single"], base["crowd"], base["p"], base["clear"]]
			)
		)
		var cards := GUN_CARDS if weapon == &"gun" else BLADE_CARDS
		for c: StringName in cards:
			var idx := _item_idx(c)
			if idx < 0:
				continue
			var lmax := mini(3, _level_max(c))  # floor 3's ceiling is 5; elements cap at 3
			for lv: int in [1] if lmax <= 1 else [1, lmax]:
				var toks := base_toks.duplicate()
				var replaced := false
				for k in toks.size():
					if String(toks[k]).begins_with(String(c) + ":"):
						toks[k] = "%s:%d" % [c, lv]
						replaced = true
				if not replaced:
					toks.append("%s:%d" % [c, lv])
				var r := _both(weapon, toks, hp)
				if r["missing"] > 0:
					_line("%s | %s | %d | (not allowed with this base)" % [b[0], c, lv])
					continue
				var sx: float = r["single"] / maxf(0.01, base["single"])
				var cx: float = r["crowd"] / maxf(0.01, base["crowd"])
				var px: float = float(r["p"]) / maxf(1.0, float(base["p"]))
				_line(
					(
						"%s | %s | %d | %.2f | %.2f | %.2f | %.2f | %.2f"
						% [
							b[0],
							c,
							lv,
							sx,
							cx,
							px,
							(sx - 1.0) / maxf(0.001, px - 1.0),
							(cx - 1.0) / maxf(0.001, px - 1.0)
						]
					)
				)
		for sc: Array in STAT_CARDS:
			var toks := base_toks.duplicate()
			toks.append("s:%s:%d" % [sc[0], sc[1]])
			var r := _both(weapon, toks, hp)
			var sx: float = r["single"] / maxf(0.01, base["single"])
			var cx: float = r["crowd"] / maxf(0.01, base["crowd"])
			var px: float = float(r["p"]) / maxf(1.0, float(base["p"]))
			_line(
				(
					"%s | stat %s (rare) | - | %.2f | %.2f | %.2f | %.2f | %.2f"
					% [
						b[0],
						sc[0],
						sx,
						cx,
						px,
						(sx - 1.0) / maxf(0.001, px - 1.0),
						(cx - 1.0) / maxf(0.001, px - 1.0)
					]
				)
			)


# --- d: past the staircase ------------------------------------------------------------------------------------
func _section_d(args: Dictionary) -> void:
	var extra_floors := int(args.get("extra", 15))
	_line(
		"## d: the floor-5 builds plus more stat floors (3 epic offence cards a floor), single dps (endless dummy)"
	)
	_line(
		(
			"track | extra floors | stat cards | damage % | attack speed raw % | rate % | crit % | single dps"
			+ " | x at floor 5 | W3-P3: dps with the loop's overlevels (loop 1 + extra / 5) | x at floor 5 | card levels"
		)
	)
	for name: String in ["gun_void_fire_venom", "blade_wave_elements", "gun_orbs_plain"]:
		var tr: Array = TRACKS[name]
		var weapon: StringName = tr[0]
		var first := 0.0
		for extra in range(0, extra_floors + 1, 5):
			var toks: Array = (tr[5] as Array).duplicate()
			var stats := _stat_tokens(1, 5)
			var n := stats.size()
			var names: Array[StringName] = [&"damage", &"attack_speed", &"crit_chance"]
			for k in extra * 3:
				stats.append("s:%s:2" % names[(n + k) % 3])
			toks.append_array(stats)
			var w := _world(weapon, toks)
			var r := _fight(w, weapon, true, ENDLESS)
			if extra == 0:
				first = r["dps"]
			var ol := 1 + extra / 5  # W3-P3: the loop these extra floors reach, at its floor 5
			var otoks := _loop_tokens(tr, ol, 5)
			otoks.append_array(stats)
			_loop = ol if _over else 1
			var ro := _fight(_world(weapon, otoks), weapon, true, ENDLESS)
			_loop = 1
			_line(
				(
					"%s | %d | %d | %d | %d | %d | %d | %.1f | %.2f | %.1f | %.2f | %s"
					% [
						name,
						extra,
						stats.size(),
						Stats.value(w, Stats.Stat.DAMAGE) / 10 - 100,
						AttackRate.stat_bonus(w) / 10,
						CatchUp.rate_permille(w) / 10 - 100,
						Stats.crit_chance(w) / 10,
						r["dps"],
						r["dps"] / maxf(0.01, first),
						ro["dps"],
						ro["dps"] / maxf(0.01, first),
						_levels_of(otoks),
					]
				)
			)


# --- the fights -----------------------------------------------------------------------------------------------
## Single and crowd fights of `tokens` on `weapon` with crowd HP `hp`: {single, crowd, clear, p, missing}.
func _both(weapon: StringName, tokens: Array, hp: int) -> Dictionary:
	var ws := _world(weapon, tokens)
	var s := _fight(ws, weapon, true, ENDLESS)
	var wc := _world(weapon, tokens)
	var c := _fight(wc, weapon, false, hp)
	var clear := (
		"%.1f" % (float(c["ttk"]) / SimTick.TICKS_PER_SECOND)
		if c["ttk"] > 0
		else "%.0f+" % _seconds
	)
	return {
		"single": s["dps"],
		"crowd": c["dps"],
		"clear": clear,
		"p": s["p"],
		"missing": s["missing"],
	}


## A Playground world holding `tokens` ("id:level" cards, "s:<stat>:<rarity>" stat cards), in order.
func _world(weapon: StringName, tokens: Array) -> World:
	var w := PlaygroundScenario.build(_repo, weapon, _biome)
	if _loop > 1:  # W3-P3: the loop and the shipped pacing table, so the cards can hold their overlevels
		w.loop = _loop
		w.loot_pacing = _pacing
	if not _consts.is_empty() or not _sb.is_empty():  # W3-P10h: the loop's Constellations, then its Starbound cards
		w.starbound_tables = _sb_tables
		for id in _consts:
			w.constellation_offer = PackedInt32Array([id])
			Constellations.take(w, 0)
		for k in _sb.size():
			for n in _sb[k]:
				Starbound.take(w, k)
	var api := PlaygroundApi.new(w)
	api.god = true
	var missing := 0
	for tok: String in tokens:
		var p := tok.split(":")
		var ok := false
		if p[0] == "s":
			var stat := _stat_index(StringName(p[1]))
			ok = stat >= 0 and api.grant_now(Offers.stat_code(stat, int(p[2])))
		else:
			var idx := _item_idx(StringName(p[0]))
			ok = idx >= 0 and api.grant_now(idx, int(p[1]))
		if not ok:
			missing += 1
	w.set_meta(&"missing", missing)
	w.set_meta(&"api", api)
	return w


## One fight on world `w` (class doc): {dps, ttk, p, missing}.
func _fight(w: World, weapon: StringName, single: bool, hp: int) -> Dictionary:
	var api: PlaygroundApi = w.get_meta(&"api")
	var reader := WorldReader.new(w)
	w.catch_up_table = _cu
	var p := CatchUp.power(w)
	w.catch_up_table = null
	var blade := weapon == &"blade"
	# The Rune Explosion bursts around the hero (forms_dps.gd's NEAR scenes): its dummies stand where the Blade's do.
	var near := blade or w.items_owned.has(_item_idx(&"gun_rune_explosion"))
	var hero := w.player_pos()
	var spots := PackedVector2Array()
	if single:
		spots.append(hero + (Vector2(1.6, 0.0) if near else Vector2(5.0, 0.0)))
	else:
		for k in BuildFight.PACK_COLS * BuildFight.PACK_ROWS:
			var col := k / BuildFight.PACK_ROWS
			var row := k % BuildFight.PACK_ROWS
			if near:
				spots.append(hero + Vector2(1.6 + 0.9 * col, -0.9 + 0.9 * row))
			else:
				spots.append(hero + Vector2(4.5 + 1.2 * col, -1.2 + 1.2 * row))
	var live := PackedInt32Array()
	var dead_at := PackedInt32Array()
	var first := {}
	for at in spots:
		var ok := api.place_dummy_now(at, hp)
		var id := w.actors.ids[w.actors.size() - 1] if ok else -1
		live.append(id)
		dead_at.append(-1)
		if id >= 0:
			first[id] = true
	var lance := w.items_owned.has(_item_idx(&"gun_lance"))
	var hold := LanceMods.hold_ticks(w, Modifiers.bolt(w)) if lance else 0
	var tally := DpsTally.new()
	var ttk := -1
	var total := int(round(_seconds * SimTick.TICKS_PER_SECOND))
	for t in total:
		api.apply_pending()
		w.step(_input(w, reader, blade, lance, hold, t))
		tally.observe(reader)
		if ttk < 0 and not single:
			var any := false
			for id: int in first:
				var i := reader.actor_index(id)
				any = any or (i >= 0 and not reader.actor_dead(i))
			if not any:
				ttk = t + 1
		if not single:
			_respawn(w, api, reader, spots, live, dead_at, hp)
	return {
		"dps": float(tally.total) * SimTick.TICKS_PER_SECOND / maxf(1.0, float(total)),
		"ttk": ttk,
		"p": p,
		"missing": int(w.get_meta(&"missing")),
		"hash": w.state_hash(),
	}


## BuildFight's input, and the Lance's hold / release / rest cycle (forms_dps.gd).
static func _input(
	w: World, reader: WorldReader, blade: bool, lance: bool, hold: int, t: int
) -> InputFrame:
	var hero := w.player_pos()
	var target := BuildFight._nearest(reader, hero)
	var to := (target - hero) if target != Vector2.INF else Vector2.RIGHT
	var aim := Kin.angle_of(to)
	var dist := int(clampf(to.length() * 100.0, 0.0, SimTick.AIM_DIST_MAX_CM))
	var move := Vector2i.ZERO
	var held := 0 if blade else InputFrame.SHOOT
	var pressed := InputFrame.PRIMARY if blade else 0
	if lance:
		var cycle := hold + 24
		held = InputFrame.SHOOT if t % cycle < hold else 0
	if blade and target != Vector2.INF:
		var d := to.normalized()
		move = Vector2i(roundi(d.x * 127.0), roundi(d.y * 127.0))
	return InputFrame.make(move, aim, dist, held, pressed)


static func _respawn(
	w: World,
	api: PlaygroundApi,
	reader: WorldReader,
	spots: PackedVector2Array,
	live: PackedInt32Array,
	dead_at: PackedInt32Array,
	hp: int
) -> void:
	for k in spots.size():
		if live[k] < 0:
			continue
		var i := reader.actor_index(live[k])
		if i >= 0 and not reader.actor_dead(i):
			continue
		if dead_at[k] < 0:
			dead_at[k] = w.tick
		elif w.tick - dead_at[k] >= RESPAWN_TICKS and api.place_dummy_now(spots[k], hp):
			live[k] = w.actors.ids[w.actors.size() - 1]
			dead_at[k] = -1


func _fresh_p(weapon: StringName) -> int:
	var w := _world(weapon, [])
	w.catch_up_table = _cu
	return CatchUp.power(w)


func _determinism() -> String:
	var toks: Array = ["gun_void:1", "ember_core:2", "venom_core:2"]
	var a := _fight(_world(&"gun", toks), &"gun", false, _base_hp)
	var b := _fight(_world(&"gun", toks), &"gun", false, _base_hp)
	return "MATCH" if a["hash"] == b["hash"] else "MISMATCH"


func _item_idx(id: StringName) -> int:
	if _items.is_empty():
		var t := ContentCompiler.compile_items(_repo)
		for k in t.size():
			_items[t[k].id] = k
	return int(_items.get(id, -1))


func _level_max(id: StringName) -> int:
	if _tables.is_empty():
		_tables = ContentCompiler.compile_items(_repo)
	var idx := _item_idx(id)
	if idx < 0:
		return 1
	var m: int = _tables[idx].level_max
	return CardLevels.MAX_LEVEL if m <= 0 else m


func _stat_index(id: StringName) -> int:
	if _stats.is_empty():
		var t := ContentCompiler.compile_stat_cards(_repo)
		for k in t.size():
			if t[k] != null:
				_stats[t[k].id] = k
	return int(_stats.get(id, -1))

class_name EffectsCatalog
extends RefCounted
## v0.10.5 W3-O12 (owner, 2026-11-04: "a repository of how all of the current effects look in the game for the premade
## pack and the already used or original from the game enemies, and effects from all abilities and enemies so I can
## compare the pack to what we have"; docs/roadmap/v0.10.5/W3_O12_VFX_GALLERY.md): the Effects gallery's entries, in
## five groups. A dev tool (debug builds, EffectsGallery); it reads the content, the pack table and the files, and
## decides nothing in the game.
## - hero, enemies, bosses: a small sim each (EffectStage builds it from the entry's `recipe`), drawn by the real game
##   view, so the looks are the game's.
## - pack_used: every PackFx row (data/vfx/*.tres) as the game colours and scales it.
## - pack_unused: every effect scene under PACK_DIRS that no PackFx row, no script or content file and no used scene
##   names (found by scanning, so a newly installed scene shows up by itself).
## Each entry: {group, title, source, use, kind (&"sim" | &"pack"), recipe (sim) | scene, id, family, def (pack)}.

const GROUPS: Array[StringName] = [&"hero", &"enemies", &"bosses", &"pack_used", &"pack_unused"]
const GROUP_KEYS := {
	&"hero": &"UI_FXG_GROUP_HERO",
	&"enemies": &"UI_FXG_GROUP_ENEMIES",
	&"bosses": &"UI_FXG_GROUP_BOSSES",
	&"pack_used": &"UI_FXG_GROUP_PACK_USED",
	&"pack_unused": &"UI_FXG_GROUP_PACK_UNUSED",
}
## Where the pack's effect scenes are (the vendor packs, and ours in their style).
const PACK_DIRS: Array[String] = ["res://assets/BinbunVFX", "res://assets/vfx_zd"]
## Where a reference to a scene may be: the game's scripts and scenes, and its content.
const SOURCE_DIRS: Array[String] = ["res://src", "res://data"]
const SOURCE_EXT: Array[String] = [".gd", ".tres", ".tscn"]
## The families whose effects fly (EffectStage moves them across the stage).
const FLY_FAMILIES: Array[StringName] = [&"projectile", &"enemy_shot", &"trail", &"bolt"]
## The families that stay and loop while held (EffectStage spawns them once, held).
const HELD_FAMILIES: Array[StringName] = [&"area", &"cloud", &"status", &"beam", &"mark"]
## An unused scene's family, from words in its path (first match; else a one-shot hit).
const GUESS := [
	["mprojectile", &"projectile"],
	["fire_ball", &"projectile"],
	["ice_ball", &"projectile"],
	["ice_shard", &"projectile"],
	["magic_orb", &"projectile"],
	["poison_bubble", &"projectile"],
	["fire_trail", &"trail"],
	["beam", &"beam"],
	["laser", &"beam"],
	["area", &"area"],
	["forcefield", &"area"],
	["puddle", &"area"],
	["pillar", &"area"],
	["ripple", &"area"],
	["rim_", &"area"],
	["lift_", &"area"],
	["pulse_", &"area"],
	["cloud", &"cloud"],
	["mist", &"cloud"],
	["stink", &"cloud"],
	["smoke", &"cloud"],
	["/fire_", &"status"],
	["candle", &"status"],
	["drips", &"status"],
	["explosion", &"explosion"],
	["blast", &"explosion"],
	["impact", &"impact"],
]
## Hero entries per build: [name key, attack, buttons pressed in the loop, heat to hold (0: none)].
const BASE_MOVES := [
	[&"UI_FXG_ATTACK", true, 0, 0],
	[&"UI_FXG_SKILL", false, InputFrame.SKILL, 0],
	[&"UI_FXG_DASH", false, InputFrame.DASH, 0],
	[&"UI_FXG_VENT", false, InputFrame.VENT, 90],
]

static var _texts := {}
static var _words := {}
static var _paths := {}

var repo: ContentRepository
var biome: BiomeDefinition
var entries: Array[Dictionary] = []
## Every effect scene found under PACK_DIRS (sorted).
var scenes := PackedStringArray()
## Scene path -> why it counts as used (a PackFx id, a file, or "part of" a used scene).
var used := {}
## The scenes nothing uses (sorted).
var unused := PackedStringArray()
## Per pack folder (assets/BinbunVFX/<pack>, assets/vfx_zd): [in use, unused].
var per_pack := {}


## `with_sims` false leaves out the three sim groups (the unit test of the pack lists).
static func build(p_repo: ContentRepository = null, with_sims := true) -> EffectsCatalog:
	var c := EffectsCatalog.new()
	c.repo = p_repo if p_repo != null else ContentRepository.load_all()
	c.biome = c.repo.get_def(&"biomes", &"ruins")
	c._scan_pack()
	if with_sims:
		c._add_hero()
		c._add_enemies_and_bosses()
	c._add_pack_used()
	c._add_pack_unused()
	return c


func in_group(group: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		if e["group"] == group:
			out.append(e)
	return out


# --- The pack's scenes ---------------------------------------------------------------------------------------------
## Every .tscn under `dirs` (an exported build's .tscn.remap counts as its scene), sorted.
static func scan_scenes(dirs: Array[String] = PACK_DIRS) -> PackedStringArray:
	var out := PackedStringArray()
	for d in dirs:
		_walk(d, out)
	out.sort()
	return out


static func _walk(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tscn") and not out.has(dir + "/" + name):
			out.append(dir + "/" + name)
	for s in DirAccess.get_directories_at(dir):
		_walk(dir + "/" + s, out)


## The text of every script, scene and content file under SOURCE_DIRS (read once a session).
static func source_texts() -> Dictionary:
	if _texts.is_empty():
		for d in SOURCE_DIRS:
			_read_under(d, _texts)
	return _texts


static func _read_under(dir: String, out: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir):
		for ext in SOURCE_EXT:
			if f.ends_with(ext):
				out[dir + "/" + f] = FileAccess.get_file_as_string(dir + "/" + f)
	for s in DirAccess.get_directories_at(dir):
		_read_under(dir + "/" + s, out)


## Every quoted word in `texts`' scripts (an id, a prefix the code builds ids from) -> the scripts that quote it, and
## every scene path quoted anywhere in `texts` -> the first file that does (indexed once a session for source_texts).
static func quoted(texts: Dictionary) -> Array[Dictionary]:
	if is_same(texts, _texts) and not _words.is_empty():
		return [_words, _paths]
	var words := {}
	var paths := {}
	var word_re := RegEx.create_from_string('"([A-Za-z0-9_]+)')  # (also "vx1_hit_%s", "vx2_jav_" + e)
	var path_re := RegEx.create_from_string('"(res://[^"]+[.]tscn)"')
	for file: String in texts:
		var text: String = texts[file]
		if file.ends_with(".gd"):
			for m in word_re.search_all(text):
				var w := m.get_string(1)
				var files: PackedStringArray = words.get(w, PackedStringArray())
				if not files.has(file.get_file()):
					files.append(file.get_file())
					words[w] = files  # (a packed array is a copy: put it back)
		for m in path_re.search_all(text):
			if not paths.has(m.get_string(1)):
				paths[m.get_string(1)] = file.get_file()
	if is_same(texts, _texts):
		_words = words
		_paths = paths
	return [words, paths]


## Which of `all` are used, and why: a row of `def` (its id), a quoted path in `texts` (the file), or a path in the
## text of a scene already used (its parts: a shared sub-scene). The rest are unused.
static func referenced(
	all: PackedStringArray, def: PackFxDefinition, texts: Dictionary
) -> Dictionary:
	var out := {}
	if def != null:
		for k in def.count():
			if all.has(def.scenes[k]) and not out.has(def.scenes[k]):
				out[def.scenes[k]] = "PackFx %s" % def.ids[k]
	var paths: Dictionary = quoted(texts)[1]
	for path in all:
		if not out.has(path) and paths.has(path):
			out[path] = paths[path]
	var todo: Array = out.keys()
	while not todo.is_empty():  # the parts of a used scene are used
		var parent: String = todo.pop_back()
		var text := FileAccess.get_file_as_string(parent)
		for path in all:
			if not out.has(path) and text.contains('"' + path + '"'):
				out[path] = "part of %s" % parent.get_file()
				todo.append(path)
	return out


func _scan_pack() -> void:
	scenes = scan_scenes()
	used = referenced(scenes, PackFx.shared_def(), source_texts())
	for path in scenes:
		var pack := pack_of(path)
		if not per_pack.has(pack):
			per_pack[pack] = [0, 0]
		if used.has(path):
			per_pack[pack][0] += 1
		else:
			unused.append(path)
			per_pack[pack][1] += 1


## The pack folder of a scene: assets/BinbunVFX/<pack> or assets/vfx_zd.
static func pack_of(path: String) -> String:
	var rel := path.trim_prefix("res://")
	var parts := rel.split("/")
	if parts.size() >= 3 and parts[1] == "BinbunVFX":
		return "%s/%s/%s" % [parts[0], parts[1], parts[2]]
	return "%s/%s" % [parts[0], parts[1]]


static func guess_family(path: String) -> StringName:
	for g: Array in GUESS:
		if path.contains(g[0]):
			return g[1]
	return &"hit"


## The scripts that quote effect id `id` (the id itself, else the longest prefix of it ending in "_" that a script
## quotes, for ids the code builds: "vx2_jav_" + element), at most `n`.
static func code_uses(id: StringName, n := 3) -> PackedStringArray:
	var words: Dictionary = quoted(source_texts())[0]
	var probe := String(id)
	while probe != "":
		if words.has(probe):
			return (words[probe] as PackedStringArray).slice(0, n)
		var cut := probe.trim_suffix("_").rfind("_")
		probe = probe.substr(0, cut + 1) if cut > 0 else ""
	return PackedStringArray()


# --- The sim groups ------------------------------------------------------------------------------------------------
func _add_hero() -> void:
	for build_id: StringName in [&"gun", &"blade"]:
		var b: BuildDefinition = repo.get_def(&"build", build_id)
		for m: Array in BASE_MOVES:
			(
				entries
				. append(
					{
						"group": &"hero",
						"kind": &"sim",
						"title": "%s · %s" % [tr(b.name_key), tr(m[0])],
						"source": tr(&"UI_FXG_SRC_VIEW") % b.resource_path.get_file(),
						"use": tr(&"UI_FXG_USE_BUILD") % tr(b.name_key),
						"recipe":
						{
							"build": build_id,
							"attack": m[1],
							"press": m[2],
							"heat": m[3],
							"target": &"dummies",
						},
					}
				)
			)
	for d: Resource in repo.all_of(&"ability"):
		var a := d as AbilityDefinition
		if a == null or a.start_weapon != &"":
			continue  # the start weapons are the builds' attacks above
		(
			entries
			. append(
				{
					"group": &"hero",
					"kind": &"sim",
					"title": tr(a.name_key),
					"source": tr(&"UI_FXG_SRC_VIEW") % a.resource_path.get_file(),
					"use": tr(&"UI_FXG_USE_ABILITY") % a.id,
					"recipe":
					{
						"build": &"gun",
						"attack": true,
						"ability": a.id,
						"press": InputFrame.UTILITY | InputFrame.SKILL,
						"heat": 0,
						"target": &"dummies",
					},
				}
			)
		)
	var items := repo.all_of(&"items")
	items.sort_custom(
		func(x: Resource, y: Resource) -> bool: return String(x.get(&"id")) < String(y.get(&"id"))
	)
	for d: Resource in items:
		var it := d as ItemDefinition
		if it == null:
			continue
		var tags := it.tags
		var press := 0
		var heat := 0
		if tags.has("dash"):
			press = InputFrame.DASH
		if tags.has("heat"):
			press |= InputFrame.VENT
			heat = 90
		(
			entries
			. append(
				{
					"group": &"hero",
					"kind": &"sim",
					"title": "%s (%s)" % [tr(it.name_key), it.id],
					"source": tr(&"UI_FXG_SRC_VIEW") % it.resource_path.get_file(),
					"use": tr(&"UI_FXG_USE_CARD") % ", ".join(tags),
					"recipe":
					{
						"build": &"blade" if it.requires_weapon == &"blade" else &"gun",
						"attack": true,
						"item": it.id,
						"press": press,
						"heat": heat,
						"target": &"dummies",
					},
				}
			)
		)


func _add_enemies_and_bosses() -> void:
	var w := PlaygroundScenario.build(repo, &"gun", biome, Vector2i(2, 2), false)
	var api := PlaygroundApi.new(w)
	var kinds: Array = ActorStore.Kind.keys()
	for e: Dictionary in api.enemy_choices():
		var k: int = e["kind"]
		(
			entries
			. append(
				{
					"group": &"enemies",
					"kind": &"sim",
					"title": tr(e["name_key"]),
					"source": tr(&"UI_FXG_SRC_ACTOR") % String(kinds[k]).to_lower(),
					"use": tr(&"UI_FXG_USE_ENEMY"),
					"recipe": {"build": &"gun", "attack": false, "enemy": k, "press": 0, "heat": 0},
				}
			)
		)
	for b: Dictionary in api.boss_choices():
		var t: BossTable = w.boss_tables[b["index"]]
		for late in [false, true]:
			(
				entries
				. append(
					{
						"group": &"bosses",
						"kind": &"sim",
						"title":
						(
							"%s · %s"
							% [
								tr(t.name_key),
								tr(&"UI_FXG_PHASE_LAST" if late else &"UI_FXG_PHASE_FIRST")
							]
						),
						"source": tr(&"UI_FXG_SRC_ACTOR") % String(t.id),
						"use": tr(&"UI_FXG_USE_BOSS"),
						"recipe":
						{
							"build": &"gun",
							"attack": false,
							"boss": b["index"],
							"late": late,
							"press": 0,
							"heat": 0,
						},
					}
				)
			)


# --- The pack groups -----------------------------------------------------------------------------------------------
func _add_pack_used() -> void:
	var def := PackFx.shared_def()
	if def == null:
		return
	var file_of := {}
	for path in ContentScanner.scan(PackFx.DEFS_DIR):
		var d := load(path) as PackFxDefinition
		if d != null:
			for id in d.ids:
				if not file_of.has(id):
					file_of[id] = path.get_file()
	for k in def.count():
		var id := def.ids[k]
		var code := code_uses(id)
		(
			entries
			. append(
				{
					"group": &"pack_used",
					"kind": &"pack",
					"title": String(id),
					"source": def.scenes[k].trim_prefix("res://"),
					"use":
					(
						tr(&"UI_FXG_USE_ROW")
						% [
							file_of.get(id, "?"),
							def.families[k],
							", ".join(code) if not code.is_empty() else "—"
						]
					),
					"id": id,
					"family": def.families[k],
					"def": null,
				}
			)
		)


func _add_pack_unused() -> void:
	if unused.is_empty():
		return
	var def := PackFxDefinition.new()
	def.id = &"w3o12_unused"
	for n in unused.size():
		def.ids.append(StringName("unused_%03d" % n))
		def.scenes.append(unused[n])
		def.families.append(guess_family(unused[n]))
		def.scales.append(1.0)
		def.primary.append(Color(0, 0, 0, 0))
		def.secondary.append(Color(0, 0, 0, 0))
		def.tertiary.append(Color(0, 0, 0, 0))
	for n in unused.size():
		(
			entries
			. append(
				{
					"group": &"pack_unused",
					"kind": &"pack",
					"title": unused[n].get_file().get_basename(),
					"source": unused[n].trim_prefix("res://"),
					"use": tr(&"UI_FXG_USE_NONE") % def.families[n],
					"id": def.ids[n],
					"family": def.families[n],
					"def": def,
				}
			)
		)

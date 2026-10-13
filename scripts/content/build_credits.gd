extends SceneTree
## v0.7.5 SM (owner N8): builds the credits' licence list (data/credits/licences.tres, LicenceListDefinition) from
## the repo, so nothing in it is typed by hand: every assets/**/manifest.json's licence line and file count, every
## font licence in assets/fonts (with the fonts it covers, named by the font files themselves) and every addon's
## licence (its plugin.cfg name and version; "not shipped" when export_presets.cfg's exclude filter leaves it out).
## Run after adding an asset manifest, a font or an addon:
## godot --headless --path . -s scripts/content/build_credits.gd
## tests/content/test_credits_licences.gd fails while the committed copy differs from a fresh build.

const OUT := "res://data/credits/licences.tres"
const ASSETS := "res://assets"
const FONTS := "res://assets/fonts"
const ADDONS := "res://addons"
const PRESETS := "res://export_presets.cfg"


func _initialize() -> void:
	var def := build()
	var issues := def.validate()
	for i in issues:
		push_error(i.message)
	if not issues.is_empty() or ResourceSaver.save(def, OUT) != OK:
		push_error("could not write " + OUT)
		quit(1)
		return
	print("wrote %s (%d entries)" % [OUT, def.count()])
	quit(0)


## The list the repo describes now. Tests compare it with the committed copy.
static func build() -> LicenceListDefinition:
	var def := LicenceListDefinition.new()
	def.id = &"generated"
	for path in manifests(ASSETS):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var m: Dictionary = data if typeof(data) == TYPE_DICTIONARY else {}
		var files := _file_count(m)
		var rel := path.trim_prefix("res://")
		var body := "%s · %d files" % [String(m.get("licence", "")), files]
		if String(m.get("licence", "")).is_empty():
			body = ""  # validate() reports it: every manifest says whose its files are
		_add(def, LicenceListDefinition.KIND_ASSETS, rel.get_base_dir(), rel, body, true)
	for f in _sorted(DirAccess.get_files_at(FONTS)):
		if f.get_extension() == "txt":
			var src := FONTS.path_join(f)
			_add(
				def,
				LicenceListDefinition.KIND_FONT,
				_font_names(),
				src.trim_prefix("res://"),
				FileAccess.get_file_as_string(src).strip_edges(),
				true
			)
	var excluded := _excluded()
	for dir in _sorted(DirAccess.get_directories_at(ADDONS)):
		var base := ADDONS.path_join(dir)
		var lic := _licence_file(base)
		var cfg := ConfigFile.new()
		var title := dir
		if cfg.load(base.path_join("plugin.cfg")) == OK:
			title = (
				"%s %s"
				% [cfg.get_value("plugin", "name", dir), cfg.get_value("plugin", "version", "")]
			)
		_add(
			def,
			LicenceListDefinition.KIND_ADDON,
			title.strip_edges(),
			lic.trim_prefix("res://") if lic != "" else base.trim_prefix("res://"),
			FileAccess.get_file_as_string(lic).strip_edges() if lic != "" else "",
			not excluded.has("addons/%s/*" % dir)
		)
	return def


## Every manifest.json under `root`, sorted.
static func manifests(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(root):
		if f == "manifest.json":
			out.append(root.path_join(f))
	for d in DirAccess.get_directories_at(root):
		out.append_array(manifests(root.path_join(d)))
	out.sort()
	return out


static func _add(
	def: LicenceListDefinition, kind: int, title: String, src: String, body: String, ship: bool
) -> void:
	def.kinds.append(kind)
	def.titles.append(title)
	def.sources.append(src)
	def.bodies.append(body)
	def.shipped.append(1 if ship else 0)


## The files a manifest lists: every dictionary with a "path" in any of its lists.
static func _file_count(m: Dictionary) -> int:
	var n := 0
	for v: Variant in m.values():
		if typeof(v) == TYPE_ARRAY:
			for e: Variant in v:
				if typeof(e) == TYPE_DICTIONARY and (e as Dictionary).has("path"):
					n += 1
	return n


## The font families in assets/fonts, read from the font files ("Atkinson Hyperlegible").
static func _font_names() -> String:
	var names := PackedStringArray()
	for f in _sorted(DirAccess.get_files_at(FONTS)):
		if f.get_extension() in ["ttf", "otf"]:
			var font := load(FONTS.path_join(f)) as FontFile
			var family := (
				font.font_name if font != null and font.font_name != "" else f.get_basename()
			)
			if not names.has(family):
				names.append(family)
	return ", ".join(names)


static func _licence_file(dir: String) -> String:
	for f in _sorted(DirAccess.get_files_at(dir)):
		var up := f.to_upper()
		if up.begins_with("LICENSE") or up.begins_with("LICENCE") or up.begins_with("COPYING"):
			return dir.path_join(f)
	return ""


## export_presets.cfg's exclude filter entries (every preset).
static func _excluded() -> PackedStringArray:
	var out := PackedStringArray()
	var cfg := ConfigFile.new()
	if cfg.load(PRESETS) != OK:
		return out
	for s in cfg.get_sections():
		if cfg.has_section_key(s, "exclude_filter"):
			for part in String(cfg.get_value(s, "exclude_filter")).split(","):
				out.append(part.strip_edges())
	return out


static func _sorted(a: PackedStringArray) -> PackedStringArray:
	var out := a.duplicate()
	out.sort()
	return out

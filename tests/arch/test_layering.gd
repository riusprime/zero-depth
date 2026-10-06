extends GutTest
## ARCHITECTURE §2–§3: app → presentation → application → sim → content; debug → application.
## Nothing imports app/ or debug/. Presentation sees the sim only through WorldReader and value types (EI-07).

const RANK := {"content": 0, "sim": 1, "application": 2, "presentation": 3, "debug": 3, "app": 4}
const PRESENTATION_SIM_ALLOWED := ["WorldReader", "SimEvent", "InputFrame", "SimTick", "Kin", "Obb"]


func _layer_of(path: String) -> String:
	var rel := path.trim_prefix("res://src/")
	return rel.get_slice("/", 0)


func _class_layers() -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	for path in GdSource.files_under("res://src"):
		var m := re.search(GdSource.read(path))
		if m != null:
			out[m.get_string(1)] = _layer_of(path)
	return out


static func allowed(from: String, to: String, cls: String) -> bool:
	if from == to:
		return true
	if to == "app" or to == "debug":
		return from == "app"
	if from == "debug":
		return to != "presentation"
	if from == "presentation" and to == "sim":
		return cls in PRESENTATION_SIM_ALLOWED
	return RANK[to] < RANK[from]


func test_no_reference_crosses_a_layer_the_wrong_way() -> void:
	var layers := _class_layers()
	assert_true(layers.has("World") and layers["World"] == "sim", "the scan sees the sim")
	var word := RegEx.create_from_string("\\b[A-Z]\\w+\\b")
	var path_re := RegEx.create_from_string("res://src/(\\w+)/")
	for path in GdSource.files_under("res://src"):
		var from := _layer_of(path)
		var text := GdSource.read(path)
		var code := GdSource.code_only(text)
		for m in word.search_all(code):
			var cls := m.get_string()
			if layers.has(cls):
				assert_true(
					allowed(from, layers[cls], cls),
					"%s (%s) uses %s (%s)" % [path, from, cls, layers[cls]]
				)
		for m in path_re.search_all(text):
			var to: String = m.get_string(1)
			if RANK.has(to):
				assert_true(allowed(from, to, ""), "%s (%s) loads a path in %s" % [path, from, to])


func test_rules() -> void:
	assert_false(allowed("sim", "application", "X"))
	assert_false(allowed("presentation", "sim", "World"))
	assert_true(allowed("presentation", "sim", "WorldReader"))
	assert_false(allowed("application", "app", "X"))
	assert_true(allowed("app", "debug", "X"))

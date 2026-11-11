extends GutTest
## EI-02: src/sim is pure (ARCHITECTURE §3). Word-bounded and recursive, unlike Deathventory's scan.
## One seam is allowed (LOCKED_DECISIONS 2026-11-11): the sim's own kernel class is looked up and made in exactly one
## file, by exactly the calls in SEAM_CALLS; every other ClassDB use anywhere in src/sim fails.

## The one file that may name ClassDB, and the only calls it may make.
const SEAM_FILE := "res://src/sim/world/native_world.gd"
const SEAM_CALLS: Array[String] = ["ClassDB.class_exists(CLASS)", "ClassDB.instantiate(CLASS)"]

const BANNED := [
	"\\bNode\\b",
	"\\bSceneTree\\b",
	"\\bget_tree\\b",
	"\\bget_node\\b",
	"\\bemit_signal\\b",
	"\\bawait\\b",
	"\\bTween\\b",
	"\\bTimer\\b",
	"\\bInput\\b",
	"\\bTime\\.",
	"\\bOS\\.",
	"\\bEngine\\.",
	"\\bload\\(",
	"\\bpreload\\(",
	"\\brandi",
	"\\brandf",
	"\\brandomize\\b",
	"\\bRandomNumberGenerator\\b",
	"\\bcosmetic\\b",
	"\\bsin\\(",
	"\\bcos\\(",
	"\\btan\\(",
	"\\batan2?\\(",
	"\\bpow\\(",
	"\\bexp\\(",
	"\\blog\\(",
	"\\.angle\\(",
	"\\.rotated\\(",
	"\\bfrom_angle\\(",
	"\\bangle_to(_point)?\\(",
	"\\.slerp\\(",
	"\\bClassDB\\b",
]


static func violations(code: String) -> PackedStringArray:
	var found := PackedStringArray()
	for pattern: String in BANNED:
		var re := RegEx.create_from_string(pattern)
		if re.search(code) != null:
			found.append(pattern)
	return found


func test_sim_sources_are_pure() -> void:
	var files := GdSource.files_under("res://src/sim")
	assert_gt(files.size(), 10, "the scan found the sim sources")
	for path in files:
		var code := GdSource.code_only(GdSource.read(path))
		if path == SEAM_FILE:
			for call in SEAM_CALLS:
				assert_eq(code.count(call), 1, "%s makes %s exactly once" % [path, call])
				code = code.replace(call, "")
		var bad := violations(code)
		assert_eq(bad, PackedStringArray(), path)


## The seam file exists and is the World's only way to its native side (World._init calls NativeWorld.make).
func test_the_native_seam_is_the_one_named_file() -> void:
	assert_true(FileAccess.file_exists(SEAM_FILE))
	var world := GdSource.code_only(GdSource.read("res://src/sim/world/world.gd"))
	assert_true(world.contains("NativeWorld.make()"), "World gets its native side from the seam")
	assert_eq(
		violations('var m := ClassDB.instantiate(&"Foo")'), PackedStringArray(["\\bClassDB\\b"])
	)


func test_the_lint_catches_planted_tokens() -> void:
	assert_eq(violations("var x := randf()"), PackedStringArray(["\\brandf"]))
	assert_eq(violations("var a := v.angle()").size(), 1)
	assert_eq(violations("var f := InputFrame.new()").size(), 0, "word-bounded: InputFrame is fine")
	assert_eq(
		violations(GdSource.code_only('var s := "randf() in a string" # sin( in a comment')).size(),
		0
	)

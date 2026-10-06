extends GutTest
## EI-02: src/sim is pure (ARCHITECTURE §3). Word-bounded and recursive, unlike Deathventory's scan.

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
		var bad := violations(GdSource.code_only(GdSource.read(path)))
		assert_eq(bad, PackedStringArray(), path)


func test_the_lint_catches_planted_tokens() -> void:
	assert_eq(violations("var x := randf()"), PackedStringArray(["\\brandf"]))
	assert_eq(violations("var a := v.angle()").size(), 1)
	assert_eq(violations("var f := InputFrame.new()").size(), 0, "word-bounded: InputFrame is fine")
	assert_eq(
		violations(GdSource.code_only('var s := "randf() in a string" # sin( in a comment')).size(),
		0
	)

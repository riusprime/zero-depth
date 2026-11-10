extends GutTest
## v0.11.1 T1 (owner L7): Main.quick_start is a test-only switch. The game ships with it false and nothing in src/ sets
## it (E2e.boot does; it is static, so its value at run time is whatever the last boot set: the source is checked).


func test_main_declares_the_switch_false() -> void:
	var src := FileAccess.get_file_as_string("res://src/app/main.gd")
	assert_string_contains(src, "\nstatic var quick_start := false\n", "false by default")


func test_nothing_in_src_sets_it() -> void:
	var setters := []
	var re := RegEx.create_from_string("quick_start\\s*=[^=]")  # an assignment (not its `:=` declaration, not `==`)
	var todo: Array[String] = ["res://src"]
	while not todo.is_empty():
		var dir: String = todo.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			todo.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var path := dir.path_join(f)
			if re.search(FileAccess.get_file_as_string(path)) != null:
				setters.append(path)
	assert_eq(setters, [], "no game code turns the switch on")

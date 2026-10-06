extends GutTest


func test_scan_is_sorted_recursive_and_matches_disk() -> void:
	var found := ContentScanner.scan("res://data")
	var sorted := found.duplicate()
	sorted.sort()
	assert_eq(found, sorted)
	assert_has(found, "res://data/player/runner.tres", "nested folders are walked")
	assert_has(found, "res://data/biomes/ruins.tres")
	var on_disk := _tres_on_disk("res://data")
	on_disk.sort()
	assert_eq(found, on_disk)


func test_scan_of_a_missing_folder_is_empty() -> void:
	assert_eq(ContentScanner.scan("res://no_such_folder").size(), 0)


func _tres_on_disk(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_tres_on_disk(dir.path_join(d)))
	return out

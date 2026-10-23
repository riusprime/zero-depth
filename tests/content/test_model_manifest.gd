extends GutTest
## Owner-supplied models (docs/art/ART_DIRECTION.md §5.2): assets/models/manifest.json lists each model's id, path
## and sha256, and the files on disk match it exactly, both ways. v0.5.9: the kit pieces and its ground textures too.

const MANIFEST := "res://assets/models/manifest.json"

## v0.9.0 MI2 (owner 2026-10-22: "here are new models and textures"): his v0.9.0 models are listed by the ids the
## art list and the views use, each within its triangle budget (scripts/assets/mi2_prep.py's), and the three elites are
## cut into named parts for code animation (EL poses them).
const V090_BUDGETS := {
	&"arrival_altar": 6000,
	&"approach_stairs": 3000,
	&"arena_wall_segment": 3000,
	&"arena_pillar": 3000,
	&"arena_brazier": 3000,
	&"arena_gate": 6000,
	&"elite_breaker": 5000,
	&"elite_rift_hunter": 5000,
	&"elite_conduit": 5000,
	&"lockdown_seal": 3000,
	&"rune_switch": 3000,
	&"rune_pillar": 3000,
	&"rune_mural": 3000,
	&"cracked_wall": 3000,
	&"cracked_wall_broken": 3000,
	&"healing_fountain": 3000,
	&"shrine_blood": 3000,
	&"shrine_chaos": 3000,
	&"shrine_fortune": 3000,
	&"purple_rune_dais": 3000,
	&"stone_spike": 600,
	&"floor_receiver": 3000,
	&"hub_portal_machine": 8000,
	&"hub_archive": 3000,
	&"hub_wardrobe": 3000,
	&"hub_station": 3000,
	&"hub_trophy_pedestal": 1000,
	&"hub_collectible_pedestal": 1000,
	&"hub_collectible_pedestal_b": 1000,
}
const ELITE_PARTS := {
	&"elite_breaker": ["arm_l", "arm_r", "back_slab", "body", "head", "leg_l", "leg_r"],
	&"elite_rift_hunter": ["blade_l", "blade_r", "body", "head", "leg_l", "leg_r", "shards"],
	&"elite_conduit": ["body", "head", "ring", "shards", "staff"],
}
## v0.9.0 NB1: the new bosses' parts (static) and skin joints (rigged; test_the_v090_bosses_are_listed_cut_or_rigged).
const NB_PARTS := {
	&"boss_tidecaller": ["ArmL", "Bell", "Body", "Shell", "Staff"],
	&"boss_twin_warden_violet": ["Body", "Helm", "Shield", "Sword"],
	&"boss_lantern_shade": ["ArmL", "ArmR", "Body", "HandLantern"],
}
const NB_RIGGED := {&"boss_twin_warden_amber": 52, &"boss_clockwork_judge": 49}


func _manifest() -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	assert_typeof(data, TYPE_DICTIONARY, "the manifest parses")
	return (data as Dictionary).get("models", [])


func test_every_listed_model_exists_with_its_hash() -> void:
	var models := _manifest()
	assert_gt(models.size(), 0)
	for m: Dictionary in models:
		var path := "res://" + String(m["path"])
		assert_true(FileAccess.file_exists(path), path)
		assert_eq(FileAccess.get_sha256(path), m["sha256"], "%s matches its hash" % m["id"])
		assert_true(path.get_file().get_basename() == String(m["id"]), "file named by id")


func test_every_model_file_is_listed() -> void:
	var listed := {}
	for m: Dictionary in _manifest():
		listed["res://" + String(m["path"])] = true
	for dir in [
		"res://assets/models/bosses",
		"res://assets/models/kit",
		"res://assets/models/shop",
		"res://assets/models/enemies",  # v0.8.0 MI
		"res://assets/models/devices",
		"res://assets/models/doors",  # v0.8.0 BD
		"res://assets/models/arena",  # v0.9.0 MI2
		"res://assets/models/fx",
		"res://assets/models/hub",
	]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".glb") or f.ends_with(".res"):
				assert_true(listed.has(dir.path_join(f)), "%s is in the manifest" % f)


func test_the_boss_models_are_the_ids_the_avatars_ask_for() -> void:
	var ids := []
	for m: Dictionary in _manifest():
		ids.append(StringName(m["id"]))
	for id: StringName in BossModels.SPECS:
		assert_has(ids, id)


func test_every_kit_texture_is_listed_with_its_hash() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var listed := {}
	for t: Dictionary in data.get("textures", []):
		var path := "res://" + String(t["path"])
		assert_true(FileAccess.file_exists(path), path)
		assert_eq(FileAccess.get_sha256(path), t["sha256"], "%s matches its hash" % t["id"])
		listed[path] = true
	for dir in [
		"res://assets/textures/kit", "res://assets/textures/vfx", "res://assets/textures/ui"
	]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".png"):
				assert_true(listed.has(dir.path_join(f)), "%s is in the manifest" % f)


## v0.8.0 MI: every enemy model the avatars ask for is delivered, and the Loop device's.
func test_the_enemy_and_device_models_are_delivered() -> void:
	var ids := []
	for m: Dictionary in _manifest():
		ids.append(StringName(m["id"]))
	for id: StringName in EnemyModels.SPECS:
		assert_has(ids, id, "%s is delivered" % id)
	assert_has(ids, &"loop_device")


func test_the_kit_models_are_the_ids_the_dresser_asks_for() -> void:
	var ids := []
	for m: Dictionary in _manifest():
		ids.append(StringName(m["id"]))
	for id: StringName in KitModels.SPECS:
		assert_has(ids, id, "%s is delivered" % id)


func test_the_v090_models_are_listed_within_their_budgets() -> void:
	var paths := {}
	for m: Dictionary in _manifest():
		paths[StringName(m["id"])] = "res://" + String(m["path"])
	for id: StringName in V090_BUDGETS:
		assert_true(paths.has(id), "%s is listed" % id)
		if not paths.has(id):
			continue
		var root := (load(paths[id]) as PackedScene).instantiate()
		var tris := 0
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				tris += mi.mesh.surface_get_array_index_len(s) / 3
		root.free()
		assert_between(tris, 1, int(V090_BUDGETS[id] * 1.02), "%s: %d triangles" % [id, tris])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var tex := []
	for t: Dictionary in data.get("textures", []):
		tex.append(StringName(t["id"]))
	for id in [&"ground_arena", &"ground_snow", &"rune_marking"]:
		assert_has(tex, id, "%s is listed" % id)


func test_the_elites_are_cut_into_named_parts() -> void:
	for id: StringName in ELITE_PARTS:
		var root := (load("res://assets/models/enemies/%s.glb" % id) as PackedScene).instantiate()
		var names := []
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			names.append(String(mi.name))
		root.free()
		names.sort()
		assert_eq(names, ELITE_PARTS[id], "%s's parts" % id)


## v0.9.0 NB1 (owner 2026-10-23: "you will have to animate the bosses like with the other ones"): the four new bosses'
## five files (scripts/assets/nb_prep.py) are listed, each a boss's triangles (the art list's 15-20k, nothing
## simplified) with its three maps at 1024 px; the static ones are cut into the parts the art list names (the Lantern
## Shade's file has no lantern cage, so only its arms and held lantern), the rigged ones keep their Mixamo skeleton.
func test_the_v090_bosses_are_listed_cut_or_rigged() -> void:
	var paths := {}
	for m: Dictionary in _manifest():
		paths[StringName(m["id"])] = "res://" + String(m["path"])
	for id: StringName in NB_PARTS.keys() + NB_RIGGED.keys():
		assert_true(paths.has(id), "%s is listed" % id)
		if not paths.has(id):
			continue
		var root := (load(paths[id]) as PackedScene).instantiate()
		var tris := 0
		var names := []
		var skel: Skeleton3D = null
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			names.append(String(mi.name))
			for s in mi.mesh.get_surface_count():
				tris += mi.mesh.surface_get_array_index_len(s) / 3
				var mat := mi.mesh.surface_get_material(s) as StandardMaterial3D
				assert_not_null(mat, "%s has its material" % id)
				if mat != null:
					assert_eq(
						mat.albedo_texture.get_width(), 1024, "%s: the colour map at 1024" % id
					)
					assert_true(mat.normal_enabled, "%s keeps its normal map" % id)
		for n: Node in root.find_children("*", "Skeleton3D", true, false):
			skel = n
		assert_between(tris, 15000, 20000, "%s: %d triangles" % [id, tris])
		if NB_PARTS.has(id):
			names.sort()
			assert_eq(names, NB_PARTS[id], "%s's parts" % id)
			assert_null(skel, "%s is static" % id)
		else:
			assert_not_null(skel, "%s keeps its skeleton" % id)
			if skel != null:
				# Every skin joint is a bone (Godot adds the end nodes too, and spells "mixamorig:" with "_").
				assert_gte(skel.get_bone_count(), NB_RIGGED[id], "%s's joints" % id)
				assert_gt(skel.find_bone("mixamorig_Hips"), -1, "%s: the Mixamo hips" % id)
		root.free()

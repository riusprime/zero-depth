extends GutTest
## v0.10.5 (PERF_PLAYLOG_1: the HUD's single-frame spikes): Hud.sync puts each part's cost in its own PerfMarks
## bucket "hud.<part>", which the perf log's `bd` column carries; with the marks off it adds none.

const PARTS: Array[StringName] = [
	&"hud.hp",
	&"hud.danger",
	&"hud.depths",
	&"hud.top",
	&"hud.minimap",
	&"hud.rewards",
	&"hud.kit",
	&"hud.events",
	&"hud.rooms",
	&"hud.shop",
	&"hud.prompts",
	&"hud.build",
	&"hud.swap",
]


func after_each() -> void:
	PerfMarks.on = false
	PerfMarks.clear()


func _hud() -> Array:
	var w := World.new(9, PlayerTable.starting_values())
	var hud := Hud.new()
	add_child_autofree(hud)
	return [hud, WorldReader.new(w)]


func test_each_part_of_the_sync_has_its_bucket() -> void:
	var made := _hud()
	PerfMarks.on = true
	PerfMarks.clear()
	(made[0] as Hud).sync(made[1])
	for k in PARTS:
		assert_eq(int(PerfMarks.calls.get(k, 0)), 1, "%s entered once per sync" % k)
	var bd := {}
	PerfBreakdown.gather(null, null, bd)
	assert_true(bd.has("hud.minimap"), "the recorder's breakdown carries the HUD's buckets")


func test_off_the_sync_adds_no_bucket() -> void:
	var made := _hud()
	PerfMarks.clear()
	(made[0] as Hud).sync(made[1])
	assert_true(PerfMarks.us.is_empty(), "marks off: nothing recorded")

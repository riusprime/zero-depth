extends GutTest
## The scorecard (v0.5.0 SCD; PLAN R7: every SCORECARD §2 cell from a reproducible command). Quick mode in process
## (ScoreSuite, as scripts/sims/scorecard.gd --quick plays it, on fewer and shorter runs): every cell is produced
## and well-formed, whether or not its band is met; a run record is byte-reproducible; and the cell rules hold on
## hand-made records (Wilson intervals, drought, divergence, a flat synergy curve is not a rise).

## One of each policy kind a cell needs, on 2 seeds, 10 s of floor 1 (the CLI's --quick plays QUICK_POLICIES).
const TEST_POLICIES: Array[String] = [
	"competent:blade",
	"competent:gun",
	"element:blade",
	"competent+t:blade",
	"exploit:salvage:gun",
	"exploit:chain:blade",
]
const TEST_TICKS := 600

var _repo: ContentRepository
var _doc := {}


func before_all() -> void:
	_repo = ContentRepository.load_all()
	var records: Array = []
	for t in ScoreSuite.tasks(TEST_POLICIES, [1, 2]):
		records.append(ScoreSuite.play(_repo, t, 1, TEST_TICKS))
	var config := {"sha": "test", "mode": "quick", "command": "test", "seeds": "1..2"}
	config.merge({"policies": TEST_POLICIES, "floors": 1, "floor_ticks": TEST_TICKS})
	_doc = ScoreSuite.document(records, config, {}, "not run in the unit test", _repo)


func test_every_scorecard_metric_has_a_well_formed_cell() -> void:
	var cells: Dictionary = _doc["cells"]
	assert_eq(ScoreCells.IDS.size(), 23, "SCORECARD §2 lists 23 metrics")
	assert_eq(cells.size(), ScoreCells.IDS.size(), "one cell per metric, no more")
	for id: String in ScoreCells.IDS:
		assert_true(cells.has(id), "%s is produced" % id)
		if not cells.has(id):
			continue
		var c: Dictionary = cells[id]
		assert_eq(c["id"], id)
		assert_true(ScoreCells.STATUSES.has(c["status"]), "%s: status %s" % [id, c["status"]])
		assert_false(String(c["band"]).is_empty(), "%s names its band" % id)
		assert_true(c["value"] is Dictionary, "%s has a value" % id)
		if c["status"] == "NOT YET RUN" or c["status"] == "no data":
			assert_false(String(c["note"]).is_empty(), "%s says why" % id)
	assert_eq(cells["M-BENCH"]["status"], "NOT YET RUN", "no bench in process: said, not guessed")


func test_the_document_and_table_serialise() -> void:
	var text := JSON.stringify(_doc, "\t", true)
	assert_not_null(JSON.parse_string(text), "the document is valid JSON")
	var md := ScoreSuite.markdown(_doc)
	for id: String in ScoreCells.IDS:
		assert_string_contains(md, "| %s |" % id)
	assert_eq((_doc["runs"] as Array).size(), TEST_POLICIES.size() * 2)


func test_a_run_record_is_byte_reproducible() -> void:
	var a := ScoreSuite.play(_repo, "competent:gun#1", 1, TEST_TICKS)
	var b := ScoreSuite.play(_repo, "competent:gun#1", 1, TEST_TICKS)
	assert_eq(JSON.stringify(a, "", true), JSON.stringify(b, "", true))
	assert_gt((a["rooms"] as Array).size(), 0, "the recorder saw a room")
	var back: Variant = ScoreSuite.ints(JSON.parse_string(JSON.stringify(a, "", true)))
	assert_eq(
		JSON.stringify(back, "", true),
		JSON.stringify(a, "", true),
		"a record read back from its file is the record played (the CLI's workers write files)"
	)


func test_tasks_parse_back() -> void:
	assert_eq(
		ScoreSuite.parse("competent:blade@expert#3"),
		{"policy": "competent", "build": "blade", "skill": "expert", "seed": 3}
	)
	assert_eq(
		ScoreSuite.parse("exploit:salvage:gun#12"),
		{"policy": "exploit:salvage", "build": "gun", "skill": "average", "seed": 12}
	)
	assert_eq(ScoreSuite.tasks(["a:blade"], [1, 2]), PackedStringArray(["a:blade#1", "a:blade#2"]))
	assert_eq(ScoreSuite.file_of("competent+t:gun@novice#2"), "competent_plust_gun_at_novice_s2.json")


func test_wilson_and_distributions() -> void:
	var w := ScoreCells.wilson(5, 10)
	assert_eq(w["rate"], 0.5)
	assert_almost_eq(float(w["lo"]), 0.2366, 0.0001)
	assert_almost_eq(float(w["hi"]), 0.7634, 0.0001)
	assert_eq(ScoreCells.wilson(0, 0)["n"], 0)
	var d := ScoreCells.dist([5, 1, 3, 2, 4])
	assert_eq([d["median"], d["p10"], d["p90"], d["max"]], [3.0, 1.0, 5.0, 5.0])


## A hand-made competent record: rooms g 1..6, a relevant offer in g 1 and g 5.
func _record(policy: String, picks: Array, focus: String = "") -> Dictionary:
	var rooms: Array = []
	for g in range(0, 7):
		rooms.append({"floor": 1, "room": g, "g": g, "ehp": 100, "dealt": 0, "combat_ticks": 0})
	return {
		"task": "%s:blade#1" % policy,
		"seed": 1,
		"policy": policy,
		"build": "blade",
		"skill": "average",
		"focus": focus,
		"result": "died",
		"rooms": rooms,
		"offers":
		[
			{"floor": 1, "room": 1, "g": 1, "relevant": 1, "engine": 0, "cards": [], "picked": []},
			{"floor": 1, "room": 5, "g": 5, "relevant": 1, "engine": 1, "cards": [], "picked": []},
		],
		"picks": picks,
	}


func test_drought_engine_and_divergence_rules() -> void:
	var comp := _record("competent", [{"card": "a", "g": 1}, {"card": "b", "g": 3}])
	var spec := _record("element", [{"card": "a", "g": 1}, {"card": "c", "g": 3}], "element")
	var d := ScoreCells._drought([comp])
	assert_eq(d["value"]["longest_per_run"]["max"], 3.0, "g 2-4 offered nothing relevant")
	assert_eq(d["status"], "missed", "3 > 2 (PD-07)")
	var e := ScoreCells._engine([comp])
	assert_eq([e["value"]["wins"], e["value"]["n"]], [0, 1], "the engine card came in Room 5")
	var v := ScoreCells._diverge([comp, spec])
	assert_eq(v["value"]["all"]["median"], 3.0, "the second pick differs, in room 3")
	assert_eq(v["status"], "met")


func test_a_flat_synergy_curve_is_not_a_rise() -> void:
	var floors: Array = []
	for k in 6:
		var items: Array = ["ember_edge"] if k >= 3 else []
		(
			floors
			. append(
				{
					"floor": 1,
					"dealt_total": 100,
					"dealt_by_effect": {"-": 100},
					"end_items": items,
					"end_abilities": [],
				}
			)
		)
	var r := {"policy": "competent", "skill": "average", "floors": floors}
	var c := ScoreCells._synergy([r])
	assert_eq(c["status"], "missed", "0 % fire damage at 0 and at 1 stack does not rise")

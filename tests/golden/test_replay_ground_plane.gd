extends GutTest
## EI-11: a 10,000-tick replay reproduces every checkpoint hash. Runs on ubuntu and on windows CI, against the
## same fixture, which is the cross-OS determinism proof.

const FIXTURE := "res://tests/golden/fixtures/replay_ground_plane.json"


func test_replay_matches_every_checkpoint() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var got := ReplayRunner.run(
		int(expected["seed"]), int(expected["ticks"]), int(expected["every"])
	)
	var want: Array = expected["hashes"]
	assert_eq(got["hashes"].size(), want.size(), "checkpoint count")
	var first_bad := -1
	for i in mini(want.size(), got["hashes"].size()):
		if got["hashes"][i] != want[i]:
			first_bad = i
			break
	assert_eq(
		first_bad,
		-1,
		"first mismatching checkpoint (tick %d)" % ((first_bad + 1) * int(expected["every"]))
	)
	assert_eq(got["final"], expected["final"])
	print("REPLAY| final=", got["final"])


func test_two_runs_in_one_process_agree() -> void:
	var a := ReplayRunner.run(99, 600, 60)
	var b := ReplayRunner.run(99, 600, 60)
	assert_eq(a["hashes"], b["hashes"])

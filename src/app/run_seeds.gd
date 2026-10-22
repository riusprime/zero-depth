class_name RunSeeds
extends RefCounted
## v0.8.0 N1 (owner O53: "every run should run a random seed for it before the game starts so it never feels the
## same"): how Main picks a new run's seed, drawn here in the app layer (the sim only ever receives it).
## - The game: a fresh random 31-bit seed for every new run (the build picker's pick, Restart, the next run after a
##   death), the first run of a session too.
## - A fixed mode keeps runs reproducible on purpose: `Main.fixed_seed` set before main.tscn boots (the e2e tests:
##   E2e.boot), else `--seed=N` on the command line, else a tool run (`godot -s <script>`: GUT, the shot and check
##   scripts) keeps Main.STAGE_SEED. In a fixed mode the first new run takes the seed and each later one the next
##   (seed + 1), as every run did before N1.
## - Saves keep their stored seed (Continue), and the dev panel's seed field sets one on purpose (Main._reseed).

## Main.fixed_seed's values besides a seed (>= 0).
const AUTO := -2
const RANDOM := -1

## The resolved mode: RANDOM, or the first seed of a fixed order.
var mode := RANDOM
var _count := 0
var _rng := RandomNumberGenerator.new()


func _init(p_mode: int) -> void:
	mode = p_mode
	if mode < 0:
		_rng.randomize()


## The seed mode of this session: `fixed` (Main.fixed_seed) unless AUTO, else the command line's --seed=N, else a
## tool run's `stage_seed`, else RANDOM.
static func resolve(fixed: int, stage_seed: int) -> int:
	if fixed != AUTO:
		return fixed
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed=") and a.substr(7).is_valid_int():
			return maxi(0, a.substr(7).to_int())
	var args := OS.get_cmdline_args()
	if "-s" in args or "--script" in args:
		return stage_seed
	return RANDOM


## The seed of the next new run.
func next() -> int:
	var s := mode + _count if mode >= 0 else 1 + int(_rng.randi() % 0x7FFFFFFE)
	_count += 1
	return s

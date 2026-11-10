class_name Seeds
extends RefCounted
## v0.11.1 Step 4 (owner L8, 2026-11-10, asked "200 seeds per PR and 1,000 at release, or 1,000 always?": "if 200 is
## enough go for it"): how many seeds a seed loop runs. On a developer machine and in seams.sh a loop runs at most
## 200; the GitHub full suite sets ZD_FULL_SEEDS=1 (.github/workflows/verify.yml) and runs the full count, so each
## version still gets its 1,000. Test-side only: tests may read the environment, the sim never does.
##
## A threshold over the seed set is written as a share of the loop's own count (`seeds * 8 / 10`), so it scales
## exactly and is unchanged at the full count.

const ENV := "ZD_FULL_SEEDS"
const LOCAL_MAX := 200


## The seeds a loop of `full` seeds runs here: `full` in the GitHub full suite, at most 200 elsewhere.
static func count(full: int) -> int:
	return count_for(full, OS.get_environment(ENV))


## The rule under count(): `full` when `flag` (the environment variable's value) is "1", else at most LOCAL_MAX.
static func count_for(full: int, flag: String) -> int:
	return full if flag == "1" else mini(full, LOCAL_MAX)

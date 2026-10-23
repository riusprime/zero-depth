class_name HubStateDefinition
extends Resource
## v0.9.0 HB (PLAN W45, W46): one evolving state of the hub, keyed on a profile flag (CONTENT_SCHEMA §11). The hub
## reads the flag when it is built (HubFlags) and its view changes quietly: no toast (W46). The flag grammar:
## - `achievement:<id>`: that achievement is unlocked;
## - `codex:<page>:<id>`: that Codex entry is unlocked;
## - `codex_total:<page>:<counter>:<n>`: the Codex page's counter summed over its entries is at least n;
## - `count:<section>:<n>`: the profile section holds at least n entries (CL's `collectibles` with profile v2);
## - `profile:<section>:<key>`: the profile section's key is true (a hook for MP, RB and CL).

## Each flag kind and how many `:`-separated parts follow it.
const KINDS := {"achievement": 1, "codex": 2, "codex_total": 3, "count": 2, "profile": 2}

@export var id: StringName
@export var flag := ""


## Whether `flag` follows the grammar (a `%d` stands for a number: the floor runes' pattern).
static func flag_ok(flag: String) -> bool:
	var parts := flag.split(":")
	if parts.size() < 2 or not KINDS.has(parts[0]) or parts.size() - 1 != int(KINDS[parts[0]]):
		return false
	for k in range(1, parts.size()):
		if parts[k].is_empty():
			return false
	if parts[0] in ["codex_total", "count"]:
		var n := parts[parts.size() - 1]
		return n == "%d" or (n.is_valid_int() and int(n) >= 0)
	return true

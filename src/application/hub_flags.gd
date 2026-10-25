class_name HubFlags
extends RefCounted
## v0.9.0 HB (PLAN W45): reads the hub's evolving states from the profile (HubStateDefinition's flag grammar). It only
## reads: a section the profile doesn't hold yet (CL's `collectibles` before profile v2) reads as empty and is never
## created, so an old profile loads and saves as it was. Never part of a run or any sim hash.

var profile: ProfileStore
var codex: CodexStore
var achievements: AchievementStore


func _init(p_profile: ProfileStore, p_codex: CodexStore, p_achievements: AchievementStore) -> void:
	profile = p_profile
	codex = p_codex
	achievements = p_achievements


## Whether `flag` holds now (false for a malformed one).
func value(flag: String) -> bool:
	if not HubStateDefinition.flag_ok(flag):
		return false
	var p := flag.split(":")
	var on := false
	match p[0]:
		"achievement":
			on = achievements != null and achievements.is_unlocked(StringName(p[1]))
		"codex":
			on = codex != null and codex.is_unlocked(StringName(p[1]), StringName(p[2]))
		"codex_total":
			on = codex != null and codex.total(StringName(p[1]), StringName(p[2])) >= int(p[3])
		"count":
			on = _section(p[1]).size() >= int(p[2])
		"profile":
			on = bool(_section(p[1]).get(p[2], false))
	return on


## Every state of `hub` by id (true: shown), and the floor runes lit (Array[bool], one per rune).
func states(hub: HubDefinition) -> Dictionary:
	var out := {}
	for s in hub.states:
		out[s.id] = value(s.flag)
	var runes: Array[bool] = []
	for i in hub.rune_count:
		runes.append(value(hub.rune_flag % (i + 1)))
	out[&"runes"] = runes
	return out


## The trophy plinths: each floor boss of the Codex (`boss_ids`, in the catalog's order) and whether it has fallen.
func boss_trophies(boss_ids: Array) -> Array[bool]:
	var out: Array[bool] = []
	for id: StringName in boss_ids:
		out.append(codex != null and codex.count(&"bosses", id, &"kills") > 0)
	return out


func _section(name: String) -> Dictionary:
	var v: Variant = profile.data.get(name) if profile != null else null
	return v if typeof(v) == TYPE_DICTIONARY else {}

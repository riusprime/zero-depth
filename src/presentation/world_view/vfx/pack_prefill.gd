class_name PackPrefill
extends RefCounted
## Every floor makes a new PackFx, so
## each pack id's pool starts empty and a floor's first hit, zone, bolt or status of each kind instanced its scene
## mid-fight. The floor's load (WorldViewRoot, behind the cover, one job an id) now fills the pools of the ids the
## floor can use with a few idle instances. The scenes and their pipelines are the session's (PackFxSessionWarm warms
## each id once at the menu), so the idle instances need no draw of their own. Looks only (EI-07).
## - The ids: every row but the hostile shots' and the elite beam's (FireballPack, EliteViews fill those), and the
##   bosses' rows (bx_*) only on a floor with a boss (its room, the final fight, or one alive).
## - How many: PER_ID, or as many as were live at once earlier this session (the hero's build: what the last floors
##   used most), up to PEAK_MAX. Spawns past them instance their scene as before.

## Idle instances per id at least (a starting value: a first hit on two foes).
const PER_ID := 2
## The most a floor's load makes of one id (a starting value).
const PEAK_MAX := 6
## The bx_* rows the hero's views use too (BlinkFlash, ModifierOverlays), on any floor.
const HERO_BX: Array[StringName] = [&"bx_flash", &"bx_shell"]


## The ids a floor fills (`boss_floor`: the floor has a boss).
static func ids(pack: PackFx, boss_floor: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	if pack == null:
		return out
	var own := {}
	for id in FireballPack.ids():
		own[id] = true
	for id in EliteViews.pack_ids():
		own[id] = true
	for id in pack.warm_ids():
		if own.has(id):
			continue
		if not boss_floor and String(id).begins_with("bx_") and not HERO_BX.has(id):
			continue
		out.append(id)
	return out


## How many idle instances of `effect_id` a floor's load makes.
static func count(effect_id: StringName) -> int:
	return clampi(PackFx.peak(effect_id), PER_ID, PEAK_MAX)


## True when the floor has a boss to fight (its room, the final arena, or a boss alive).
static func boss_floor(reader: WorldReader) -> bool:
	return reader != null and (reader.has_boss_room() or reader.final_fight() or reader.any_boss())


## Fills `effect_id`'s pool in `pack` (a load job).
static func fill(pack: PackFx, effect_id: StringName) -> void:
	if pack != null:
		pack.prefill(effect_id, count(effect_id))

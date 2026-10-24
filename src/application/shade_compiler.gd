class_name ShadeCompiler
extends RefCounted
## v0.9.0 NB4 (BOSSES_4_5.md N4; BossShade): compiles the Lantern Shade's numbers (its own file: ContentCompiler is
## at its line limit). A Lights Out's dark and the room's light (from its first Lights Out) onto the boss's table; a
## Snuff's flag onto its attack.


## PatternCompiler.compile_boss_attack: a Lights Out's dark_ticks, a Snuff's flag.
static func compile_attack(def: BossAttackDefinition, t: BossAttackTable) -> void:
	var sp := def.shape_params
	t.snuff = int(sp.get("snuff", 0)) == 1
	if ShadeRules.is_lights_out(def):
		t.dark_ticks = maxi(1, SimTick.seconds_to_ticks(float(sp.get("dark_seconds", 0.0))))


## PatternCompiler.compile_cadence: the room's light, from the boss's first Lights Out (none: no lanterns).
static func compile_boss(def: BossDefinition, t: BossTable) -> void:
	for a in def.attacks:
		if not ShadeRules.is_lights_out(a):
			continue
		var sp := a.shape_params
		t.lamp_count = clampi(int(sp.get("lamps", 0)), 0, ShadeRules.MAX_LAMPS)
		t.lamp_inset_m = float(sp.get("inset_m", 0.0))
		t.light_m = float(sp.get("light_m", 0.0))
		t.lamp_m = float(sp.get("lamp_m", 0.0))
		t.lamp_ticks = SimTick.seconds_to_ticks(float(sp.get("lamp_seconds", 0.0)))
		t.relight_m = float(sp.get("relight_m", 0.0))
		return

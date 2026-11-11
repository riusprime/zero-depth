class_name DevPanel
extends PanelContainer
## Developer panel stub (debug builds only), adapted from Deathventory's release gate: it opens only when
## unlocked() is true, toggled by backtick (physical key). Shows seed, tick, FPS and ticks per frame; buttons
## pause, step one tick, hash now and reseed, spawn a chosen boss near the player and a
## chosen normal enemy, all through DebugApi. the hidden catch-up's readout (developers only; the player
## never sees it: owner D4 "Yes, but hidden").

var api: DebugApi
var _info := Label.new()
var _hash := Label.new()
var _boss := Label.new()
var _enemy := Label.new()
var _ability := Label.new()
var _mod := Label.new()  # The modifier card GrantMod gives
var _catch_up := Label.new()
var _intensity := Label.new()  # The intensity director's readout
var _native := Label.new()  # Which native kernels this world runs, and which the next one will


static func unlocked(debug_build: bool = OS.is_debug_build()) -> bool:
	return debug_build


func _init(p_api: DebugApi) -> void:
	name = "DevPanel"
	api = p_api
	position = Vector2(24, 24)
	var col := VBoxContainer.new()
	add_child(col)
	var title := Label.new()
	title.text = "UI_DEV_PANEL"
	col.add_child(title)
	_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_info)
	_hash.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_hash)
	for spec: Array in [
		["Pause", "UI_DEV_PAUSE", api.toggle_pause],
		["Step", "UI_DEV_STEP", api.request_step],
		["Hash", "UI_DEV_HASH", func() -> void: _hash.text = api.hash_now().left(16)],
		["Reseed", "UI_DEV_RESEED", func() -> void: api.reseed(api.world.seed_value + 1)],
		["NextBoss", "UI_DEV_NEXT_BOSS", api.next_boss],
		["SpawnBoss", "UI_DEV_SPAWN_BOSS", api.request_boss],
		["God", "UI_DEV_GOD", api.toggle_god],
		["KillBoss", "UI_DEV_KILL_BOSS", api.kill_boss],
		["NextEnemy", "UI_DEV_NEXT_ENEMY", api.next_enemy],
		["SpawnEnemy", "UI_DEV_SPAWN_ENEMY", api.request_enemy],
		["SpawnElite", "UI_DEV_SPAWN_ELITE", api.request_elite],  # TEST HELPER (core theft)
		["NextAbility", "UI_DEV_NEXT_ABILITY", api.next_ability],  # v0.4.0 BS
		["GrantAbility", "UI_DEV_GRANT_ABILITY", api.grant_ability],
		["NextMod", "UI_DEV_NEXT_MOD", api.next_mod],  # v0.6.0 MX4
		["GrantMod", "UI_DEV_GRANT_MOD", api.grant_mod],  # v0.6.0 MX2
		["CurseChest", "UI_DEV_CURSE_CHEST", api.curse_next_chest],  # v0.5.0 EV
		["GoOverrun", "UI_DEV_GO_OVERRUN", api.go_overrun],  # v0.4.0 AB
		["GoArena", "UI_DEV_GO_ARENA", api.go_arena],  # v0.5.5 AR
		["ClearWave", "UI_DEV_CLEAR_WAVE", api.clear_wave],
		["NextPhase", "UI_DEV_NEXT_PHASE", api.next_phase],  # v0.4.0 TU
	]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.focus_mode = Control.FOCUS_NONE
		if spec[0] == "God":  # it shows whether God is on: it outlasts the panel (owner, 2026-11-10)
			b.toggle_mode = true
			b.button_pressed = api.god
		b.pressed.connect(spec[2])
		col.add_child(b)
	for id: StringName in DebugApi.view_switches:  # The views' own switches
		var sw: Array = DebugApi.view_switches[id]
		var b := Button.new()
		b.name = "Switch_" + String(id)
		b.text = sw[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(sw[1])
		col.add_child(b)
	_boss.name = "BossChoice"
	_boss.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_boss)
	_enemy.name = "EnemyChoice"
	_enemy.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_enemy)
	_ability.name = "AbilityChoice"
	_ability.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_ability)
	_mod.name = "ModChoice"
	_mod.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_mod)
	_catch_up.name = "CatchUp"
	_catch_up.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_catch_up)
	_intensity.name = "Intensity"
	_intensity.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_intensity)
	_native.name = "NativeCore"
	_native.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_native)


func _process(_delta: float) -> void:
	_info.text = (
		"seed %d  tick %d  %d fps  %d ticks/frame%s%s"
		% [
			api.world.seed_value,
			api.world.tick,
			Engine.get_frames_per_second(),
			api.ticks_last_frame,
			"  [paused]" if api.paused else "",
			switch_text(),
		]
	)
	var w := api.world
	_boss.text = (
		tr(w.boss_tables[api.boss_choice].name_key)
		if api.boss_choice < w.boss_tables.size()
		else ""
	)
	var kinds := api.enemy_kinds()
	var k := kinds[api.enemy_choice % kinds.size()] if not kinds.is_empty() else -1
	_enemy.text = tr(w.enemy_table(k).name_key) if k >= 0 else ""
	var ab := w.ability_tables
	_ability.text = (
		"%s  L%d" % [tr(ab[api.ability_choice].name_key), Abilities.level_of(w, api.ability_choice)]
		if api.ability_choice < ab.size()
		else ""
	)
	var mc := api.mod_choice
	_mod.text = tr(w.item_tables[mc].name_key) if mc >= 0 and mc < w.item_tables.size() else ""
	_catch_up.text = catch_up_text(w)
	_intensity.text = intensity_text(WorldReader.new(w))
	_native.text = native_text(w.native_on, World.native_kernels)


## "native core: move,ai,strike,shots,nav" or "native core: off (script sim)" for the world running now; when the
## switch has changed since that world was made, also what the next one gets (a World keeps the kernels it was made
## with).
static func native_text(live: int, next: int) -> String:
	var out := "native core: %s" % _kernels(live)
	if next != live:
		out += "  ->  %s from the next floor or run" % _kernels(next)
	return out


static func _kernels(bits: int) -> String:
	return NativeWorld.names_of(bits) if bits != 0 else "off (script sim)"


## The view switches' states (" enemy_vat on"), developers only.
static func switch_text() -> String:
	var out := ""
	for id: StringName in DebugApi.view_switches:
		var on: bool = (DebugApi.view_switches[id] as Array)[2].call()
		out += "  %s %s" % [id, "on" if on else "off"]
	return out


## "m ×1.41 (P 2000 / E 1000, cap ×1.75) · boss ×1.20 (P … / E …, cap …)", or "" without the table.
static func catch_up_text(w: World) -> String:
	if w.catch_up_table == null:
		return ""
	var s := w.catch_up
	var out := (
		"m x%.2f (P %d / E %d, cap x%.2f)" % [s.enemy / 1000.0, s.power, s.expected, s.cap / 1000.0]
	)
	if s.boss_expected > 0:
		out += (
			"  boss x%.2f (P %d / E %d, cap x%.2f)"
			% [s.boss / 1000.0, s.boss_power, s.boss_expected, s.boss_cap / 1000.0]
		)
		if not w.catch_up_table.boss_pace_permille.is_empty():  # The paced boss HP
			out += "  boss HP x%.2f (paced)" % (CatchUp.boss_hp_permille(w) / 1000.0)
	return out


## "intensity 512 PEAK 3.2 s", or "" without the director (developers only; the player sees no cue).
static func intensity_text(r: WorldReader) -> String:
	if not r.has_intensity():
		return ""
	var mode: String = IntensityState.Mode.keys()[r.intensity_mode()]
	var out := "intensity %d %s" % [r.intensity(), mode]
	if r.intensity_timer() > 0:
		out += " %.1f s" % (r.intensity_timer() / float(SimTick.TICKS_PER_SECOND))
	if r.intensity_standing() != IntensityState.Standing.BETWEEN:  # "… struggling" or "… strong"
		out += " " + String(IntensityState.Standing.keys()[r.intensity_standing()]).to_lower()
	return out

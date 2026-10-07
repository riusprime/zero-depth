class_name DevPanel
extends PanelContainer
## Developer panel stub (debug builds only), adapted from Deathventory's release gate: it opens only when
## unlocked() is true, toggled by backtick (physical key). Shows seed, tick, FPS and ticks per frame; buttons
## pause, step one tick, hash now and reseed, and (v0.3.0 C) spawn a chosen boss near the player, all through
## DebugApi.

var api: DebugApi
var _info := Label.new()
var _hash := Label.new()
var _boss := Label.new()


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
	]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[2])
		col.add_child(b)
	_boss.name = "BossChoice"
	_boss.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_boss)


func _process(_delta: float) -> void:
	_info.text = (
		"seed %d  tick %d  %d fps  %d ticks/frame%s"
		% [
			api.world.seed_value,
			api.world.tick,
			Engine.get_frames_per_second(),
			api.ticks_last_frame,
			"  [paused]" if api.paused else ""
		]
	)
	var w := api.world
	_boss.text = (
		tr(w.boss_tables[api.boss_choice].name_key)
		if api.boss_choice < w.boss_tables.size()
		else ""
	)

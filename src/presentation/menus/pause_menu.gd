class_name PauseMenu
extends MenuPanel
## Resume, restart the run, Options (v0.3.0 O), or return to the main menu (v0.3.0 B). Shown over the stage; the
## sim is paused (no ticks) while it's open. Keyboard, mouse and pad all work through the focus (MenuPanel).
## v0.8.0 MU (Ember stone): the game blurred behind, the list on a stone slab on the left, the run's line and
## the key hint under it; no build cards beside it (owner: not needed). v0.6.5 WN2: a Build row under Resume opens the
## Build page (BuildPage: the wand's order, rearranged here). v0.7.5 CX: a Codex row after Options opens the Codex
## (CodexView) over the paused game.
## v0.9.0 HB (owner 2026-10-23, "To the hub (Recommended)"): in a run the last row leaves to the Rune Ring hub, the run
## saved for Continue (the end panel's words, UI_TO_HUB); the dev Playground keeps Main menu.

signal resume_pressed
signal build_pressed
signal options_pressed
signal codex_pressed
signal restart_pressed
signal main_menu_pressed
signal hub_pressed  # v0.9.0 HB: the in-run exit

var run_line: Label
## v0.10.5 O6, v0.11.0 F12: the depths' answer (the HUD's skull and multiplier, no sentence), shown only above ×1.
var depths_line: DepthsTag
## v0.10.5 O5b: the loop rules' line under the run's (hidden on loop 1).
var rules_line: Label
## The run line's numbers, so a language switch (Options opened from here) words it again (v0.6.0 UP).
var _run := []
var _loop := 1  # v0.7.5 AP
## v0.10.5 O5b: the loop rules' name keys.
var _rules := PackedStringArray()


func _init(to_hub: bool = true) -> void:
	super()  # v0.10.5 W3-O18: in Astral (MenuPanel)
	name = "PauseMenu"
	add_backdrop()
	add_title("UI_PAUSED")
	add_button("UI_RESUME", func() -> void: resume_pressed.emit()).name = "Resume"
	add_button("UI_BUILD", func() -> void: build_pressed.emit()).name = "Build"  # v0.6.5 WN2
	add_button("UI_RESTART_RUN", func() -> void: restart_pressed.emit()).name = "Restart"
	add_button("UI_OPTIONS", func() -> void: options_pressed.emit()).name = "Options"  # v0.3.0 O
	add_button("UI_CODEX", func() -> void: codex_pressed.emit()).name = "Codex"  # v0.7.5 CX
	if to_hub:  # v0.9.0 HB
		add_button("UI_TO_HUB", func() -> void: hub_pressed.emit()).name = "Hub"
	else:
		add_button("UI_MAIN_MENU", func() -> void: main_menu_pressed.emit()).name = "MainMenu"
	run_line = add_note("")
	run_line.name = "RunLine"
	run_line.visible = false
	depths_line = DepthsTag.new()
	depths_line.name = "DepthsLine"
	footer.add_child(depths_line)
	rules_line = add_note("")
	rules_line.name = "RulesLine"
	rules_line.visible = false
	add_hint("UI_PAUSE_HINT")


## The run so far under the list: "Floor 1 · 03:42 · 87 kills · 146 shards" (Main passes the recap's numbers).
## v0.7.5 AP: `loop` > 1 puts "Loop N · " first.
func show_run(floor_index: int, seconds: float, kills: int, shards: int, loop: int = 1) -> void:
	var secs := int(seconds)
	_run = [floor_index, secs / 60, secs % 60, kills, shards]
	_loop = loop
	run_line.text = Hud.loop_prefix(self, _loop) + tr("UI_PAUSE_RUN") % _run
	run_line.visible = true


## Main's recap (Main.run_recap: floor, seconds, kills, shards, loop, v0.10.5 O5b rules; empty: no run line) and,
## on a floor, the depths' answer from `reader` (v0.10.5 O6).
func show_recap(recap: Dictionary, reader: WorldReader = null) -> void:
	if not recap.is_empty():
		show_run(
			recap["floor"],
			recap["seconds"],
			recap["kills"],
			int(recap.get("shards", 0)),
			int(recap.get("loop", 1))  # v0.7.5 AP
		)
		show_rules(recap.get("rules", PackedStringArray()))
	if reader != null and reader.has_floor():
		show_depths(reader.catch_up_permille())


## v0.10.5 O6, v0.11.0 F12: the skull and "×1.41" when the floor's m is above ×1; hidden otherwise.
func show_depths(m_permille: int) -> void:
	depths_line.set_multiplier(m_permille)


## v0.10.5 O5b: "Loop rules: Quickened · Shielded" (name keys; none: the line hides).
func show_rules(keys: PackedStringArray) -> void:
	_rules = keys
	rules_line.visible = not keys.is_empty()
	_word_rules()


func _word_rules() -> void:
	var names := PackedStringArray()
	for k in _rules:
		names.append(tr(k))
	rules_line.text = tr("UI_PAUSE_RULES") % " · ".join(names) if not names.is_empty() else ""


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED:
		return
	_word_rules()
	if not _run.is_empty():
		run_line.text = Hud.loop_prefix(self, _loop) + tr("UI_PAUSE_RUN") % _run

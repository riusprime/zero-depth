extends "res://scripts/shots/mu_shots.gd"
## v0.8.0 MU (G2, owner O14): the main menu in the three directions (MuKit), en and es, over a floor of the game
## (the shipped main menu draws on an empty screen; a direction picked here would get a menu backdrop of its own).
## The rows are the shipped menu's for a fresh profile with no save (MainMenu: Play, Options, Credits, Codex, then
## Playground and Galleries when this build shows them, Quit), Play focused. Command and output: mu_shots.gd.


func _screen() -> String:
	return "main_menu"


func _screen_caption() -> String:
	return "main menu"


func _build(dir: int) -> Control:
	var rows: Array = ["UI_PLAY", "UI_OPTIONS", "UI_CREDITS", "UI_CODEX"]
	if DevGate.enabled():
		rows.append("UI_PLAYGROUND")
	if OS.is_debug_build():
		rows.append("UI_GALLERIES")
	rows.append("UI_QUIT")
	return Kit.menu_screen(dir, self, rows, 0, GameVersion.label())

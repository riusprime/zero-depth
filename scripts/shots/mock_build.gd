extends "res://scripts/shots/mu_shots.gd"
## v0.8.0 MU (G2, owner O14): the pause menu's Build page in the three directions (MuKit), en and es: the posed wand
## of eight cards with two triggers (WorldReader.wand()), its brackets and the game's own read-back
## (WorldReader.wand_describe / wand_render), the third tile focused. Command and output: mu_shots.gd.


func _screen() -> String:
	return "build"


func _screen_caption() -> String:
	return "Build page"


func _build(dir: int) -> Control:
	return Kit.build_screen(dir, self, _main.driver.reader.wand(), 2)

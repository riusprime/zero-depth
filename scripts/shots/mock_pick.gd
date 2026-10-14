extends "res://scripts/shots/mu_shots.gd"
## v0.8.0 MU (G2, owner O14): the 3-card pick in the three directions (MuKit), en and es, over the paused floor with
## the HUD. Real cards through the game's own faces (PickPanel.card_face on the live WorldReader): Frost Nova (a new
## ability, as a free altar's first card), Ember Edge (a common mod already in the wand: its level badge reads the
## level-up) and Cold Snap (a rare mod), the middle one focused; the altar's title and hint. Command and output:
## mu_shots.gd.

const ABILITY := &"frost_nova"
const MODS: Array[StringName] = [&"ember_edge", &"cold_snap"]


func _screen() -> String:
	return "pick"


func _screen_caption() -> String:
	return "card pick"


func _keep_hud() -> bool:
	return true


func _build(dir: int) -> Control:
	var w := _main.driver.world
	var reader: WorldReader = _main.driver.reader
	var codes: Array[int] = [Offers.ABILITY_BASE + ability_index(w, ABILITY)]
	for id in MODS:
		codes.append(item_index(w, id))
	var faces: Array = []
	for code in codes:
		faces.append(PickPanel.card_face(self, reader, code))
	return Kit.pick_screen(dir, faces, 1, tr("PICK_TITLE_ALTAR"), tr("PICK_HINT"))

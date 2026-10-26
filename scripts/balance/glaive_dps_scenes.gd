extends SceneTree
## v0.9.5 FC6: the Glaive cards whose gain needs enemies in the right place (forms_dps.gd's three scenes put them on
## the aim line, where Halo's three other discs, Mine's far-point hold, Homing's bend and Split's fork cannot show).
## Each scene is measured with the plain Glaive and with the cards (a card alone, or the pair named), same harness as
## forms_dps.gd (its _damage: a Gun run on floor 5, crit off, no attack speed, no elements, dummies put back each tick,
## direct damage from tick 120). Prints a table, writes build/balance/glaive_scenes.txt; copy it into evidence by hand.
##   godot --headless --path . -s scripts/balance/glaive_dps_scenes.gd

const D := preload("res://scripts/balance/forms_dps.gd")
const TICKS := 720


## [label, enemy offsets from the hero, [card sets]].
static func _scenes() -> Array:
	return [
		[
			"cross: four at 3 m, 90 degrees apart",
			[Vector2(3, 0), Vector2(0, 3), Vector2(-3, 0), Vector2(0, -3)],
			[
				[&"halo_shot"],
				[&"gun_backfire"],
				[&"halo_shot", &"gun_echo"],
				[&"halo_shot", &"gun_echo", &"gun_big_shot"]
			],
		],
		[
			"far five: a cluster at 7.4 m (the disc's far point)",
			[
				Vector2(7.4, -0.6),
				Vector2(7.4, -0.3),
				Vector2(7.4, 0),
				Vector2(7.4, 0.3),
				Vector2(7.4, 0.6)
			],
			[
				[&"gun_mine"],
				[&"gun_mine", &"gun_ring"],
				[&"gun_mine", &"gun_echo"],
				[&"gun_mine", &"gun_echo", &"gun_ring"],
				[&"gun_mine", &"halo_shot"]
			],
		],
		[
			"aside: one at 5.5 m, 1.5 m off the aim",
			[Vector2(5.5, 1.5)],
			[[&"gun_homing"]],
		],
		[
			"fork: one at 3 m and two on the +-30 degree lines at 5.1 m",
			[Vector2(3, 0), Vector2(5.1, 1.0), Vector2(5.1, -1.0)],
			[[&"split_shot"]],
		],
		[
			"pack: five on a 3 m arc at 4 m (forms_dps pack)",
			D._pack(),
			[
				[&"gun_ring", &"gun_echo", &"gun_big_shot"],
				[&"halo_shot", &"gun_echo", &"gun_big_shot"],
				[&"gun_ring", &"gun_mine", &"gun_big_shot"]
			],
		],
	]


func _initialize() -> void:
	var lines := PackedStringArray()
	lines.append("scene | cards | x vs plain Glaive | dmg | plain dmg")
	for sc: Array in _scenes():
		var base: int = D._damage(&"gun_glaive", 1, false, sc[1], TICKS, [])
		for cards: Array in sc[2]:
			var d: int = D._damage(&"gun_glaive", 1, false, sc[1], TICKS, cards)
			lines.append(
				(
					"%s | %s | %.3f | %d | %d"
					% [sc[0], "+".join(cards), float(d) / float(base), d, base]
				)
			)
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/balance"))
	var out := FileAccess.open("res://build/balance/glaive_scenes.txt", FileAccess.WRITE)
	if out != null:
		out.store_string(text + "\n")
		out.close()
	quit(0)

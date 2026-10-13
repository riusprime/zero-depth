class_name FloorCadence
extends RefCounted
## v0.7.5 MG (owner N10, N12): "every two floors". A floor feature (the shop, cursed chests) is on floor
## `floor_index` when floor_index >= first and (floor_index - first) is a multiple of `every`: with first 1 and every
## 2, floors 1, 3, 5, 7 ... (a 3-floor run gets floors 1 and 3). `every` <= 0: never; `every` 1: every floor from
## `first`. floor_index counts the run's floors from 1 and must keep counting past the run's last floor (an endless
## loop passes the run's absolute floor number, never the floor within a loop, or two featured floors could meet
## where one loop ends and the next begins). A pure function of the floor number: no draw, no state.


static func on(floor_index: int, first: int, every: int) -> bool:
	if every <= 0 or floor_index < first:
		return false
	return (floor_index - first) % every == 0

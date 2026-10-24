class_name CollectibleView
extends Node3D
## v0.9.0 CL (COLLECTIBLES.md): the floor's collectibles as the sim shows them (WorldReader.collectibles): once a
## source gives one, its pickup (CollectibleLooks, in the collectible's colour) floats where it lies; taken, it flares
## and rises away. A final body's piece shows and goes the same tick (it comes to the hero): its flare plays where the
## hero stands. Reads the reader only (EI-07).

const HEIGHT_M := 0.75
const SIZE_M := 0.36

## Collectible id -> its colour (the content's; the default blue without it).
var colors := {}
## Collectible id -> its pickup node (while it shows).
var gems := {}
var _done := {}


func setup(reader: WorldReader, p_colors: Dictionary = {}) -> void:
	name = "Collectibles"
	colors = p_colors
	sync(reader)


func sync(reader: WorldReader) -> void:
	for c: Dictionary in reader.collectibles():
		var id: StringName = c["id"]
		if int(c["shown_tick"]) < 0 or _done.has(id):
			continue
		if not gems.has(id):
			var p := SimPlane.to_3d(c["pos"])
			gems[id] = CollectibleLooks.gem(
				self,
				"Gem_%s" % id,
				colors.get(id, HubProps.BLUE),
				Vector3(p.x, HEIGHT_M, p.z),
				SIZE_M
			)
		if int(c["taken_tick"]) >= 0:
			var g := gems[id] as CollectibleLooks
			if is_instance_valid(g):
				g.vanish()
			gems.erase(id)
			_done[id] = true


## The pickup showing for collectible `id` (null when none shows).
func gem_of(id: StringName) -> CollectibleLooks:
	var g: Variant = gems.get(id)
	return g if g != null and is_instance_valid(g) else null

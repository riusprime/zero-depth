class_name Gallery
extends Node3D
## Proof scenes for the v0.0.1 gates (PLAN Step 7): one showcase room drawn by the real views.
## Debug builds reach it from the main menu's GALLERIES button; the shots script captures it.

const BIOMES := {
	&"ruins": ["#CBAD91", "#D0B396", "#8C8C90", "#9D6B4C", "#A08A74", "#FFF1DC", "#1A1A22"],
	&"night_rocks": ["#486796", "#50709F", "#395077", "#3C3A44", "#253043", "#B8C8F0", "#EEF2F8"],
	&"red_canyon": ["#C55946", "#D0614B", "#7A3D36", "#9D6B4C", "#4C3032", "#FFD2C0", "#1A1A22"],
	&"frozen_shore": ["#D1DAE4", "#C7D3E1", "#303C52", "#455B77", "#436C8E", "#E8F0FF", "#1A1A22"],
}

var world: World
var view: WorldViewRoot


## A seeded showcase: the player, three enemies, slabs between them, shots in flight.
static func showcase_world(seed_value: int) -> World:
	var w := World.new(seed_value, PlayerTable.starting_values())
	var walls: Array[Obb] = []
	walls.append(Obb.make(Vector2(0, 9.5), Vector2(9, 0.4), 0))
	walls.append(Obb.make(Vector2(0, -9.5), Vector2(9, 0.4), 0))
	walls.append(Obb.make(Vector2(9.5, 0), Vector2(0.4, 9), 0))
	walls.append(Obb.make(Vector2(-9.5, 0), Vector2(0.4, 9), 0))
	walls.append(Obb.make(Vector2(-3.2, -1.0), Vector2(1.6, 0.25), 512))  # faces the camera
	walls.append(Obb.make(Vector2(3.5, 2.5), Vector2(0.25, 1.8), 0))
	walls.append(Obb.make(Vector2(-4.0, 4.0), Vector2(1.2, 0.25), 1024 + 256))
	walls.append(Obb.make(Vector2(5.0, -4.0), Vector2(2.0, 0.25), 512))
	w.set_walls(walls)
	w.dummy_fire_period = 12
	w.dummy_speed = 0.0
	w.projectile_life = 200
	w.add_dummy(Vector2(4.5, 4.0), 0.35, 10)
	w.add_dummy(Vector2(6.0, -1.5), 0.35, 10)
	w.add_dummy(Vector2(-4.4, 0.2), 0.35, 10)  # behind that slab as the camera sees it: the occlusion case
	for t in 50:  # the first volley is mid-flight
		w.step(InputFrame.new())
	return w


static func palette_of(biome: StringName) -> Dictionary:
	var keys := BiomeDefinition.PALETTE_KEYS
	var vals: Array = BIOMES[biome]
	var out := {}
	for i in keys.size():
		out[keys[i]] = Color(vals[i])
	return out


func setup(biome: StringName, pitch_deg: float, technique: StringName, occlusion: bool) -> void:
	world = showcase_world(4)
	view = WorldViewRoot.new()
	view.actors.technique = technique
	view.occlusion_enabled = occlusion
	view.rig.set_pitch(pitch_deg)
	view.rig.view_size = 15.0
	add_child(view)
	view.setup(WorldReader.new(world), palette_of(biome), 10.0)

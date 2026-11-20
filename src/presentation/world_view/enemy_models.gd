class_name EnemyModels
extends RefCounted
## The owner's enemy models (owner 2026-10-18: "enemies are not animated and will need to be animated if
## needed"): assets/models/enemies/<id>.glb, prepared offline by scripts/assets/mi_prep.py: turned to our facing
## frame (+X the front, Y up, metres, feet on the ground), cut into the parts that move (one node each, its origin
## at the part's pivot: the Shield Bearer's shield and legs, the Splitter's halves, arms and legs, the Mender's
## crystals and cross, the Lens Drone's ring of feet) and, in each part, into up to three surfaces by what the
## texture shows there: `base` (the charcoal frame and bone, coloured as delivered), `role` (the plates, greyscale in
## the texture, so the avatar tints them in the kind's role colour, EnemyPalettes) and `glow` (eyes, seam, crystals:
## the avatar's glowing accent). No rig: HordeAvatar and LensDroneAvatar pose the parts in code. Read once per kind
## and cached; a missing file gives {} and the avatar keeps its code-made body.

const DIR := "res://assets/models/enemies/"
## Per kind: the model file's id and the height (m) the avatar scales it to (the code bodies' heights, HordeAvatar
## HEIGHTS; the Mender's without its float, the Lens Drone's pod).
const SPECS := {
	&"mender": {"height": 1.45},
	&"shield_bearer": {"height": 1.25},
	&"splitter": {"height": 0.95},
	&"lens_drone": {"height": 0.5},
	# The owner's elites (prepared by scripts/assets/mi2_prep.py: parts, `base` and `glow`), at the art
	# list's heights (EliteAvatar poses them).
	&"elite_breaker": {"height": 2.6},
	&"elite_rift_hunter": {"height": 2.1},
	&"elite_conduit": {"height": 2.3},
	# The Scrap Hound (scripts/assets/o17_prep_scrap_hound.py: chest, hips, head, tail, two-part legs;
	# ScrapHoundAvatar poses them), at the request row's 0.7 m.
	&"scrap_hound": {"height": 0.7},
	# The Rock Lurker (scripts/assets/o17_prep_rock_lurker.py; RockLurkerAvatar poses it)
	&"rock_lurker": {"height": RockLurkerAvatar.HEIGHT},
	# The owner's Stone Thrower (scripts/assets/o17_prep_stone_thrower.py: its parts and its rock),
	# posed by StoneThrowerAvatar.
	&"stone_thrower": {"height": 1.6},
	# The owner's Cinder Priest (scripts/assets/o17_prep_cinder_priest.py: parts, `base`, `role`, `glow`),
	# its height with the staff (CinderPriestAvatar poses it).
	&"cinder_priest": {"height": 1.75},
	# The Kiln Beetle (scripts/assets/o17_prep_kiln_beetle.py: shell, body, head, eight two-part legs;
	# KilnBeetleAvatar poses them), at the request row's 0.7 m.
	&"kiln_beetle": {"height": 0.7},
	# The Frost Spitter (scripts/assets/frost_spitter_prep.py: shell, body, head, sac, four two-part legs;
	# FrostSpitterAvatar poses them), at the request row's 0.85 m.
	&"frost_spitter": {"height": 0.85},
	# The Wire Weaver (scripts/assets/wire_weaver_prep.py: body, head, spool, four two-part legs, two two-part
	# arms; WireWeaverAvatar poses them), at the request row's 1.0 m.
	&"wire_weaver": {"height": WireWeaverAvatar.HEIGHT},
	# The Glacier Turtle (scripts/assets/glacier_turtle_prep.py: body, carapace, head, shield, four two-part legs;
	# GlacierTurtleAvatar poses them), 0.9 m tall (1.33 m long: the shield's face at the sim's radius).
	&"glacier_turtle": {"height": 0.9},
	# The Gravity Node (scripts/assets/gravity_node_prep.py: face plate, core, two shell halves, two rings;
	# GravityNodeAvatar poses them), about the request row's 0.9 m orb with its rings.
	&"gravity_node": {"height": GravityNodeAvatar.MODEL_HEIGHT},
	# The Arc Caster (scripts/assets/arc_caster_prep.py: torso, two robe tiers, hood, staff arm, staff, two-part free
	# arm, three shards; ArcCasterAvatar poses them), its height with the staff.
	&"arc_caster": {"height": ArcCasterAvatar.MODEL_HEIGHT},
	# The Star Warper (scripts/assets/star_warper_prep.py: torso, star head, two two-part arms, a three-part tail,
	# three shards; StarWarperAvatar poses them, floating).
	&"star_warper": {"height": StarWarperAvatar.MODEL_HEIGHT},
	# The Hatchling and the Swarmer (scripts/assets/hatchling_swarmer_prep.py: body, carapace or wing cases,
	# mandibles, six two-part legs; HatchlingAvatar and SwarmerModel pose them), the horde's small sizes.
	&"hatchling": {"height": HatchlingAvatar.MODEL_HEIGHT},
	&"swarmer": {"height": 0.25},
	# The Needle and the Sniper (scripts/assets/needle_sniper_prep.py: body, shell, barrel, two-part legs;
	# NeedleAvatar / SniperAvatar pose them), at the request rows' 1.1 m and 1.3 m.
	&"needle": {"height": NeedleAvatar.HEIGHT},
	&"sniper": {"height": SniperAvatar.HEIGHT},
	# The Warden (scripts/assets/warden_prep.py: body, head, two-part arms, three-part legs; WardenAvatar poses
	# them), the old code golem's 1.2 m.
	&"warden": {"height": 1.2},
	# The Mine Layer (scripts/assets/mine_layer_prep.py: body, head, hopper, hatch, mine, six two-part legs;
	# MineLayerModel poses them on HordeAvatar), 0.8 m long.
	&"mine_layer": {"height": MineLayerModel.TOP},
	# The Dust Mite, the Ember Flea and the Ice Crab (scripts/assets/critter_prep.py: body, legs, the flea's thighs
	# and shins, the crab's claws; CritterModel poses them): no taller than CritterBodies.HEIGHTS and about as wide
	# as the sim's body (the mite 0.37 m by 0.42 m across its legs, the crab 0.4 m by 0.46 m).
	&"dust_mite": {"height": 0.2},
	&"ember_flea": {"height": 0.3},
	&"ice_crab": {"height": 0.15},
	# The Cave Bat and the Star Mote (critter_prep.py: the bat's two-part wings, the mote's five points and three-part
	# tail; FlyerModel poses them): no taller than CritterBodies.HEIGHTS over their flight and float.
	&"cave_bat": {"height": FlyerModel.MODEL_H[WorldReader.KIND_CAVE_BAT]},
	&"star_mote": {"height": FlyerModel.MODEL_H[WorldReader.KIND_STAR_MOTE]},
}
const SURFACES: Array[StringName] = [&"base", &"role", &"glow"]

## Where models are looked up (tests point it elsewhere to see the fallback).
static var dir := DIR
static var _cache := {}


## {"parts": {name: {"pivot": Vector3 (metres, model frame), "mesh": ArrayMesh, "surfaces": [&"base" | &"role" |
## &"glow" per surface]}}, "texture": Texture2D (the shared colour map), "scale": metres per model unit to reach
## SPECS' height, "height": the model's own height} or {} when the file is missing.
static func get_model(id: StringName) -> Dictionary:
	var path := dir + String(id) + ".glb"
	if _cache.has(path):
		return _cache[path]
	var out := {}
	if SPECS.has(id) and ResourceLoader.exists(path):
		out = _read(load(path) as PackedScene, float(SPECS[id]["height"]))
	_cache[path] = out
	return out


static func has_model(id: StringName) -> bool:
	return not get_model(id).is_empty()


static func clear_cache() -> void:
	_cache.clear()
	CritterModel.clear_cache()


static func _read(scene: PackedScene, height: float) -> Dictionary:
	if scene == null:
		return {}
	var root := scene.instantiate()
	var parts := {}
	var tex: Texture2D = null
	var top := 0.0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var surfaces: Array[StringName] = []
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			var nm := StringName(m.resource_name) if m != null else &"base"
			surfaces.append(nm if nm in SURFACES else &"base")
			if tex == null and m != null and m.albedo_texture != null:
				tex = m.albedo_texture
		var box := mi.mesh.get_aabb()
		top = maxf(top, mi.position.y + box.end.y)
		parts[StringName(mi.name)] = {"pivot": mi.position, "mesh": mi.mesh, "surfaces": surfaces}
	root.free()
	if parts.is_empty():
		return {}
	return {"parts": parts, "texture": tex, "scale": height / maxf(top, 0.0001), "height": top}

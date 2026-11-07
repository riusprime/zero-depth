class_name VariantViews
extends Node3D
## v0.11.0 O13a (ENEMIES.md V1-V5): what the biome variants leave on the floor, read through WorldReader (EI-07), in the
## premade packs' effects (PD-13):
## - an Ember Charger's fire trail: the pack's enemy fire patch (VfxLayer.field &"fire", hostile: zone_fire_foe_a/b,
##   fire_area_06/07), dimmer until it burns (its arm time) and fading out over its last half second;
## - a Frost Charger's slick: the pack's ice patch (VfxLayer.field &"frost": zone_frost_a-d, ice_area_vfx_01-04),
##   fading out over its last second;
## - a Rubble Warden's fallen crust: each rock the kit's small boulder (KitModels boulder_small, as the crust it wore:
##   VariantLooks), with a puff of the pack's dust where it lands (bx_smoke_dust, smoke_vfx_05) the first frame it
##   shows;
## - a Split Sniper's split: the pack's hit spark (vx1_hit_storm, vfx_hit_01, in violet) at the split point the tick
##   its shot fires (its four tracer lines are HordeVisuals').
## The patches are drawn by draw_fx (a VfxCore drawer); the rocks and the sparks by sync. Nothing here decides.

const ROCK_MODEL := &"boulder_small"
## A rock's drawn size over its sim footprint (its side), and its height (m).
const ROCK_SPREAD := 1.25
const ROCK_HEIGHT := 0.55
const DUST_ID := &"bx_smoke_dust"
const DUST_SCALE := 0.45
const SPARK_ID := &"vx1_hit_storm"
const SPARK_SCALE := 0.9
const SPARK_COLORS := {
	&"primary": Color(0.86, 0.7, 1.0),
	&"secondary": Color(0.6, 0.4, 1.0),
	&"tertiary": Color(0.3, 0.15, 0.6)
}
## Ticks a trail fades over before it goes (fire, slick), and the fire's look before it burns.
const FIRE_FADE_TICKS := 30.0
const SLICK_FADE_TICKS := 60.0
const UNLIT_FADE := 0.55

## The effects layer (WorldViewRoot sets it; null: no patches) and the pack (null: no dust or spark).
var vfx: VfxCore = null
var pack_fx: PackFx = null
var _trails := {}
var _rocks: Array[MeshInstance3D] = []
var _states := {}
var _tick := 0.0


func sync(reader: WorldReader) -> void:
	_tick = float(reader.tick())
	_trails = reader.variant_trails()
	_sync_rocks(reader.rubble_pieces())
	if reader.any_kind(WorldReader.KIND_SPLIT_SNIPER):
		_sync_splits(reader)
	elif not _states.is_empty():
		_states.clear()


## Trails drawn this frame (tests).
func trail_count() -> int:
	var kinds: PackedInt32Array = _trails.get("kind", PackedInt32Array())
	return kinds.size()


func rock_count() -> int:
	return _rocks.size()


## A VfxCore drawer: each trail as the pack's patch.
func draw_fx(layer: VfxCore) -> void:
	var vl := layer as VfxLayer
	if vl == null or _trails.is_empty():
		return
	var kinds: PackedInt32Array = _trails["kind"]
	for k in kinds.size():
		var c := SimPlane.to_3d(_trails["pos"][k], 0.0)
		var r: float = _trails["r"][k]
		var left := float(_trails["left"][k])
		var age := float(_trails["age"][k])
		var sd: int = _trails["seed"][k]
		if kinds[k] == WorldReader.TRAIL_FIRE:
			var fade := clampf(left / FIRE_FADE_TICKS, 0.0, 1.0)
			if _trails["lit"][k] == 0:
				fade *= UNLIT_FADE
			vl.field(&"fire", c, r, fade, age, sd, true)
		else:
			vl.field(&"frost", c, r, clampf(left / SLICK_FADE_TICKS, 0.0, 1.0), age, sd)


func _sync_rocks(pieces: Array) -> void:
	while _rocks.size() > pieces.size():
		_rocks.pop_back().queue_free()
	for k in range(_rocks.size(), pieces.size()):
		var at := SimPlane.to_3d(pieces[k][0], 0.0)
		var side: float = float(pieces[k][1]) * 2.0 * ROCK_SPREAD
		var mi := MeshInstance3D.new()
		var piece := KitModels.get_piece(ROCK_MODEL)
		if piece.is_empty():
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			mi.mesh = box
		else:
			mi.mesh = piece["mesh"]
			mi.material_override = piece["material"]
		mi.position = at
		mi.scale = Vector3(side, ROCK_HEIGHT, side)
		mi.rotation.y = 0.9 * k
		add_child(mi)
		_rocks.append(mi)
		if pack_fx != null:
			pack_fx.spawn(DUST_ID, at, DUST_SCALE)


func _sync_splits(reader: WorldReader) -> void:
	for i in range(1, reader.actor_count()):
		if reader.actor_kind(i) != WorldReader.KIND_SPLIT_SNIPER:
			continue
		var id := reader.actor_id(i)
		var st := reader.actor_state(i)
		if st == WorldReader.STATE_ACTIVE and _states.get(id, st) != st and pack_fx != null:
			var lanes := reader.sniper_lines(i)
			if lanes.size() > 1:
				var first: Obb = lanes[0]
				var mid := first.center + Kin.dir(first.angle) * first.half.x
				pack_fx.spawn(
					SPARK_ID, SimPlane.to_3d(mid, SimPlane.CORE_HEIGHT), SPARK_SCALE, SPARK_COLORS
				)
		_states[id] = st
	for id in _states.keys():
		if reader.actor_index(id) < 0:
			_states.erase(id)

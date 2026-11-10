class_name HazardViews
extends Node3D
## v0.11.0 F8 (owner 4.2; PD-13: the premade packs): the bosses' arena hazards, read through WorldReader.boss_hazards
## (EI-07). Nothing here decides.
## - Warning (before it arms): only a ring at its full radius, nothing inside it; a rock's ring is gold and the rock
##   falls into it from above (the kit's boulder, the same KitModels piece the Stone Thrower's fallback throws).
## - Armed: the Foundry's a burning pool (VfxLayer.field &"fire", hostile: the pack's zone_fire_foe_a/b); the Brood
##   Mother's a venom pool (VfxLayer.field &"venom": zone_venom_a/b); the Siege Engine's fallen rubble (the kit's
##   boulders) inside the pack's rim (ring_bleed: rim_area_vfx_01, in dust colours) over the boss strikes' crack mark,
##   its landing the pack's short impact (vx1_impact_other: 18 ticks), no Smoke (S3: no smoke over a telegraph).
## - Each fades over its last FADE_TICKS: the pack zones shrink through VfxLayer.field's fade, the rubble sinks into the
##   floor.

const FADE_TICKS := 60.0
const RING_KIND := {&"lava": &"fire", &"venom": &"venom"}
const FIELD_KIND := {&"lava": &"fire", &"venom": &"venom"}
## The rock's ring and ground patch (scale per metre of radius), and their colours.
const ROCK_RING_ID := &"ring_bleed"
const ROCK_RING_PER_M := 0.55
const ROCK_RING_COLORS := {
	&"primary": Color(1.0, 0.78, 0.32),
	&"secondary": Color(0.95, 0.55, 0.14),
	&"tertiary": Color(0.55, 0.3, 0.08)
}
const ROCK_ZONE_ID := &"ring_bleed"
const ROCK_ZONE_PER_M := 0.55
const ROCK_ZONE_COLORS := {
	&"primary": Color(0.5, 0.42, 0.3),
	&"secondary": Color(0.32, 0.26, 0.18),
	&"tertiary": Color(0.16, 0.13, 0.09)
}
const ROCK_MODEL := &"boulder_small"
## The rubble: pieces per zone, how far out (share of the radius), their size and the sink as it fades (m).
const RUBBLE := 6
const RUBBLE_REACH := 0.72
const RUBBLE_SCALE := 0.75
const RUBBLE_SINK_M := 0.6
## The falling rock: its start height (m) and size.
const FALL_M := 9.0
const FALL_SCALE := 1.1
## The landing: the pack's rock impact, without its smoke and core (S3).
const IMPACT_ID := &"vx1_impact_other"
const IMPACT_SCALE := 0.8
const IMPACT_HIDE := ["Core", "Smoke", "Ground_Impact", "Impact_Streaks1", "Impact_Streaks2"]
const IMPACT_COLORS := {
	&"primary": Color(0.8, 0.75, 0.68),
	&"secondary": Color(0.56, 0.5, 0.45),
	&"tertiary": Color(0.3, 0.27, 0.24)
}
const CRACK_COLOR := Color(0.09, 0.07, 0.06, 0.9)
const CRACK_KEY := 0x5B000000

var vfx: VfxCore = null
var pack_fx: PackFx = null
var _rows: Array = []
var _holds := PackHold.new()
## hazard id -> its meshes (the falling rock, or the rubble).
var _meshes := {}
var _landed := {}


## Hazards drawn now, warning rings drawn, rubble pieces standing (tests).
func hazard_count() -> int:
	return _rows.size()


func sync(reader: WorldReader) -> void:
	_rows = reader.boss_hazards()
	var alive := {}
	for r: Dictionary in _rows:
		alive[r["id"]] = true
		if r["look"] == &"rock":
			_sync_rock(r)
	for k: int in _meshes.keys():
		if not alive.has(k):
			for n: Node3D in _meshes[k]:
				n.queue_free()
			_meshes.erase(k)
			_landed.erase(k)


## A VfxCore drawer: each hazard this frame, in the pack's effects.
func draw_fx(layer: VfxCore) -> void:
	var vl := layer as VfxLayer
	if vl == null:
		return
	_holds.fx = pack_fx
	_holds.begin()
	for r: Dictionary in _rows:
		var c := SimPlane.to_3d(r["centre"], 0.0)
		var sd: int = r["id"] * 97 + 31
		var radius: float = r["radius"]
		var age := float(r["armed_ticks"])
		var fade := clampf(float(r["left"]) / FADE_TICKS, 0.0, 1.0)
		var look: StringName = r["look"]
		if look == &"rock":
			_draw_rock(r, c, radius, fade)
		elif not r["armed"]:
			vl.ring(RING_KIND[look], c, radius, 1.0, age, sd)
		else:
			vl.field(FIELD_KIND[look], c, radius, fade, age, sd, look == &"lava")
	_holds.end()


func _draw_rock(r: Dictionary, c: Vector3, radius: float, fade: float) -> void:
	if not r["armed"]:
		_holds.touch(
			r["id"] * 2, ROCK_RING_ID, &"area", c, radius * ROCK_RING_PER_M, ROCK_RING_COLORS
		)
		return
	_holds.touch(
		r["id"] * 2 + 1,
		ROCK_ZONE_ID,
		&"area",
		c,
		radius * ROCK_ZONE_PER_M * (0.5 + 0.5 * fade),
		ROCK_ZONE_COLORS
	)


func _piece() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var piece := KitModels.get_piece(ROCK_MODEL)
	if not piece.is_empty():
		mi.mesh = piece["mesh"]
		mi.material_override = piece["material"]
	add_child(mi)
	return mi


func _sync_rock(r: Dictionary) -> void:
	var id: int = r["id"]
	var c := SimPlane.to_3d(r["centre"], 0.0)
	if not r["armed"]:
		if not _meshes.has(id):
			var mi := _piece()
			mi.scale = Vector3.ONE * FALL_SCALE
			_meshes[id] = [mi]
		var u := float(r["warn"]) / 1000.0
		(_meshes[id][0] as Node3D).position = c + Vector3(0.0, FALL_M * (1.0 - u * u), 0.0)
		return
	if not _landed.has(id):
		_land(id, c, r["radius"])
	var sink := RUBBLE_SINK_M * (1.0 - clampf(float(r["left"]) / FADE_TICKS, 0.0, 1.0))
	for k in (_meshes[id] as Array).size():
		var n: Node3D = _meshes[id][k]
		n.position.y = -sink


## The landing: the falling rock goes, the rubble stands in its ring, the impact and the crack (no smoke).
func _land(id: int, c: Vector3, radius: float) -> void:
	_landed[id] = true
	if _meshes.has(id):
		for n: Node3D in _meshes[id]:
			n.queue_free()
	var list: Array[Node3D] = []
	for k in RUBBLE:
		var a := TAU * float(k) / float(RUBBLE) + float(id) * 1.3
		var d := radius * (RUBBLE_REACH if k % 2 == 0 else RUBBLE_REACH * 0.55)
		var mi := _piece()
		mi.position = c + Vector3(cos(a) * d, 0.0, sin(a) * d)
		mi.rotation.y = a * 3.0
		mi.scale = Vector3.ONE * (RUBBLE_SCALE * (0.8 + 0.2 * float(k % 3)))
		list.append(mi)
	_meshes[id] = list
	if pack_fx != null:
		pack_fx.spawn(
			IMPACT_ID, c + Vector3(0, 0.05, 0), IMPACT_SCALE, IMPACT_COLORS, -1.0, 1.0, IMPACT_HIDE
		)
	if vfx != null:
		vfx.mark(
			CRACK_KEY + id, BossStrikeFx.crack_mark(), c + Vector3(0, 0.02, 0), radius, CRACK_COLOR
		)

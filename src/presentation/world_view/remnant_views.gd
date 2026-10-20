class_name RemnantViews
extends Node3D
## v0.8.0 RM (owner O91: Threadline, Faultline, Gravity Stitch, Stress Mark, Fracture Bank, Double Exposure, Grand
## Finale, Dodge Imprint, Thermal Break): the remnants the sim keeps (WorldReader.remnants), drawn simply and cheaply:
## - a segment as a thin glowing bar between its two ends: a thread (ENEMY_CROSS) cyan, a crack (ATTACK_CROSS) ember
##   orange, a replay path (DELAY) pale, brightening as its delay runs out;
## - an anchor as a small violet ring on the floor, pulsing;
## - a mark as a small amber diamond over its enemy, pointing its way; fragments as a crimson diamond growing with
##   their count;
## - Dodge Imprint's standing point as a faint ring where the dash began;
## - each activation (REMNANT_ACTIVATE) and each Thermal Break (its STATUS_APPLY) as a short flash ring, sized by the
##   cast's radius (a Thermal Break a white-blue shatter).
## Every mesh is pooled (made once in _init, hidden when not needed; a remnant past its pool isn't drawn), unshaded,
## no shadows. Presentation only (EI-07): the sim decides where, how big and how long; the flashes' fade is the view's.

const SEGMENTS := 48
const ANCHORS := 16
const MARKS := 48
const FLASHES := 24
const FLASH_FRAMES := 14
const THREAD := Color("#5FE3FF")
const CRACK := Color("#FF8A3D")
const PATH := Color("#E8E4FF")
const ANCHOR := Color("#9B6BFF")
const MARK := Color("#FFC24A")
const FRAGMENT := Color("#FF4A6A")
const SHATTER := Color("#CFF4FF")
const IMPRINT := Color("#B9C8FF")
const Y := 0.08

var calm := false
## What the last sync drew (tests read them).
var drawn_segments := 0
var drawn_anchors := 0
var drawn_marks := 0
var flashes_live := 0
var imprint_drawn := false
var _bars: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _gems: Array[MeshInstance3D] = []
var _flashes: Array[MeshInstance3D] = []
var _flash_age := PackedInt32Array()
var _flash_r := PackedFloat32Array()
var _imprint: MeshInstance3D
var _seen := -1
var _next_flash := 0


func _init() -> void:
	name = "Remnants"
	var bar := BoxMesh.new()
	bar.size = Vector3(1.0, 0.05, 0.08)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.5
	ring.rings = 16
	ring.ring_segments = 4
	var gem := PrismMesh.new()
	gem.size = Vector3(0.22, 0.3, 0.22)
	for k in SEGMENTS:
		_bars.append(_make("Bar%d" % k, bar, THREAD))
	for k in ANCHORS:
		_rings.append(_make("Anchor%d" % k, ring, ANCHOR))
	for k in MARKS:
		_gems.append(_make("Mark%d" % k, gem, MARK))
	for k in FLASHES:
		_flashes.append(_make("Flash%d" % k, ring, SHATTER))
		_flash_age.append(FLASH_FRAMES)
		_flash_r.append(1.0)
	_imprint = _make("Imprint", ring, IMPRINT)


func _make(id: String, mesh: Mesh, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = id
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	return m


func sync(reader: WorldReader) -> void:
	calm = ViewPrefs.reduced_motion
	var read := reader.remnants()
	var bars := 0
	var rings := 0
	var gems := 0
	for r: Dictionary in read["remnants"]:
		match int(r["kind"]):
			RemnantRule.Kind.SEGMENT:
				if bars < SEGMENTS:
					_bar(_bars[bars], r)
					bars += 1
			RemnantRule.Kind.ANCHOR:
				if rings < ANCHORS:
					_ring(_rings[rings], r)
					rings += 1
			_:
				if gems < MARKS:
					_gem(_gems[gems], r)
					gems += 1
	for k in SEGMENTS:
		_bars[k].visible = k < bars
	for k in ANCHORS:
		_rings[k].visible = k < rings
	for k in MARKS:
		_gems[k].visible = k < gems
	drawn_segments = bars
	drawn_anchors = rings
	drawn_marks = gems
	imprint_drawn = bool(read["imprint"])
	_imprint.visible = imprint_drawn
	if imprint_drawn:
		var at := SimPlane.to_3d(read["imprint_at"])
		_imprint.position = Vector3(at.x, Y, at.z)
		_imprint.scale = Vector3(0.7, 1.0, 0.7)
	_events(reader)
	_age_flashes()


func _bar(m: MeshInstance3D, r: Dictionary) -> void:
	var a := SimPlane.to_3d(r["a"])
	var b := SimPlane.to_3d(r["b"])
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := maxf(0.05, d.length())
	m.position = Vector3((a.x + b.x) * 0.5, Y, (a.z + b.z) * 0.5)
	m.rotation = Vector3(0.0, atan2(-d.z, d.x), 0.0)
	m.scale = Vector3(length, 1.0, 1.0)
	var color := THREAD
	match int(r["activate"]):
		RemnantRule.Activate.ATTACK_CROSS:
			color = CRACK
		RemnantRule.Activate.DELAY:
			color = PATH
	var life := maxf(1.0, float(r["life"]))
	var fade := clampf(1.0 - float(r["age"]) / life, 0.25, 1.0)
	color.a = fade
	(m.material_override as StandardMaterial3D).albedo_color = color


func _ring(m: MeshInstance3D, r: Dictionary) -> void:
	var at := SimPlane.to_3d(r["a"])
	var pulse := 1.0 if calm else 0.85 + 0.15 * sin(float(r["age"]) * 0.3)
	m.position = Vector3(at.x, Y, at.z)
	m.scale = Vector3(pulse, 1.0, pulse)


func _gem(m: MeshInstance3D, r: Dictionary) -> void:
	var at := SimPlane.to_3d(r["a"])
	var frag := int(r["kind"]) == RemnantRule.Kind.FRAGMENT
	var size := 1.0 + 0.2 * maxi(0, int(r["count"]) - 1) if frag else 1.0
	m.position = Vector3(at.x, 1.3, at.z)
	m.rotation = Vector3(0.0, float(int(r["dir"])) / 4096.0 * TAU, 0.0)
	m.scale = Vector3.ONE * size
	(m.material_override as StandardMaterial3D).albedo_color = FRAGMENT if frag else MARK


## Each new activation and Thermal Break since the last sync starts a flash (the oldest flash reused).
func _events(reader: WorldReader) -> void:
	if _seen < 0:
		_seen = reader.last_event_seq()
		return
	for e in reader.events_since(_seen):
		_seen = e.seq
		if e.kind == SimEvent.Kind.REMNANT_ACTIVATE:
			_flash(e.pos, maxf(0.4, reader.remnant_cast_radius(e.effect_id)), MARK)
		elif e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == Engines.EFFECT_THERMAL_BREAK:
			_flash(e.pos, 0.9, SHATTER)


func _flash(pos: Vector2, radius: float, color: Color) -> void:
	var k := _next_flash
	_next_flash = (_next_flash + 1) % FLASHES
	_flash_age[k] = 0
	_flash_r[k] = radius
	var at := SimPlane.to_3d(pos)
	_flashes[k].position = Vector3(at.x, Y + 0.02, at.z)
	(_flashes[k].material_override as StandardMaterial3D).albedo_color = color


func _age_flashes() -> void:
	flashes_live = 0
	for k in FLASHES:
		var age := _flash_age[k]
		var on := age < FLASH_FRAMES
		_flashes[k].visible = on
		if not on:
			continue
		flashes_live += 1
		var t := float(age) / FLASH_FRAMES
		var grow := 1.0 if calm else 0.5 + 0.5 * t
		var r := _flash_r[k] * grow
		_flashes[k].scale = Vector3(r, 1.0, r)
		var mat := _flashes[k].material_override as StandardMaterial3D
		mat.albedo_color.a = 1.0 - t
		_flash_age[k] = age + 1

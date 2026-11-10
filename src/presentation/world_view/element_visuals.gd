class_name ElementVisuals
extends Node3D
## Arc Field, Frost Nova, Flame Trail and the ability combos' looks in the world (v0.4.0 AB). Reads
## WorldReader.element_fx() and ability_fx() only (EI-07); every size is the sim's own number (nova radius, patch
## radius, bolt ends). Materials are unshaded and transparent, made once; nothing toggles emission at runtime.
## - Arc Field: a jagged pale-blue bolt from the hero to each enemy struck (Superconductor: cyan-white and thicker).
## - Frost Nova: a frost ring and a pale disc out to the nova's radius.
## - Fire patches: flat orange discs that shrink as they burn out. v0.6.0 MX2: Arc Field's
##   shock field is a pale-blue disc, another spec's zone a pale-white one; a growing ring (the RING form: Frost Nova)
##   is a frost torus at its radius now.
## v0.10.5 O1 (owner P1): the ability combos' looks (Storm Bombs, Ember Ward, Blink Charge, Wingman) went with them.

const ARC_COLOR := Color("#9FC8FF")
const SUPER_COLOR := Color("#7CF6FF")
const NOVA_COLOR := Color("#BFF4FF")
const FIRE_COLOR := Color("#FF7A3D")
const GAS_COLOR := Color("#7CD65A")
const GAS_Y := 0.03
const MAX_CLOUDS := 16
const FX_FRAMES := 16
const FIRE_Y := 0.025
const BOLT_SEGMENTS := 4
## v0.10.0 VX3 (VFX_PACK R24, R26): Toxic Fumes' clouds, Frost Nova's ring and Ember Ward's ring are the pack's effects
## (PackFx); false keeps the flat quad and the torus (the before shots). Each also falls back when the pack has no
## room in the effect's family (clouds: cap 4).
const PACK_ELEMENTS := true
## The cloud scene's scale per metre of the sim's gas radius, the rings' per metre of the sim's radius.
const FUMES_PER_M := 0.7
const RING_PER_M := {&"ring_frost": 0.5, &"ring_fire": 0.55}
## v0.10.0 VX6 (VFX_PACK N1): Arc Field and Storm Bombs bolts, and Arc Field shock field, are the pack lightning (the
## ZdBolt, the vx6_field ripple, the VX1 storm spark); false keeps the box bolts and the pale disc, which also draw when
## the pack has no room.
const PACK_STORM := true
const ARC_FIELD_PER_M := 0.5
const ARC_STRIKE_S := 0.4
const BOLT_LIFE_S := 0.2
const BOLT_SPARK_SCALE := 0.09

## v0.6.0 MX3: AttackFormView draws the RING form's rings and every patch that names a spec (WorldViewRoot sets
## it); this view keeps the patches without one (Napalm Drone's).
var forms_drawn := false
## The pack effects (WorldViewRoot sets it); none: the old quads and rings.
var pack_fx: PackFx = null
var _holds := PackHold.new()
var _field_holds := PackHold.new()  # the shock fields (VX6)
var _clock := 0.0  # real seconds, for the fields' re-strikes (cosmetic)
var _fires: Array[MeshInstance3D] = []
var _fx := FxFade.new()
var _template := SkillVisuals._make_template()
var _fire_mat := _template.duplicate() as StandardMaterial3D
var _field_mat := _template.duplicate() as StandardMaterial3D
var _zone_mat := _template.duplicate() as StandardMaterial3D
var _rings: Array[MeshInstance3D] = []
var _ring_mat := _template.duplicate() as StandardMaterial3D
var _disc_mesh := CylinderMesh.new()
## v0.9.5 EE3: Toxic Fumes' clouds (one flat quad each, a soft round alpha).
var _clouds: Array[MeshInstance3D] = []
var _quad := QuadMesh.new()
var _gas_mat := _template.duplicate() as StandardMaterial3D
var _last := {}
var _spec_keys := PackedStringArray()


func _init() -> void:
	name = "ElementVisuals"
	_fire_mat.albedo_color = Color(FIRE_COLOR, 0.55)
	_field_mat.albedo_color = Color(ARC_COLOR, 0.5)
	_zone_mat.albedo_color = Color(Color.WHITE, 0.35)
	_ring_mat.albedo_color = Color(NOVA_COLOR, 0.8)
	_disc_mesh.height = 0.01
	_disc_mesh.top_radius = 1.0
	_disc_mesh.bottom_radius = 1.0
	_disc_mesh.radial_segments = 20
	_quad.size = Vector2(2.0, 2.0)
	var soft := Gradient.new()
	soft.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	soft.offsets = PackedFloat32Array([0.45, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = soft
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_gas_mat.albedo_texture = tex
	_gas_mat.albedo_color = Color(GAS_COLOR, 0.7)
	for k in [&"arc", &"nova"]:
		_last[k] = -1


func sync(reader: WorldReader) -> void:
	var fx := reader.element_fx()
	_spec_keys = reader.fire_spec_keys() if forms_drawn else PackedStringArray()
	_sync_fires(fx)
	_sync_clouds(reader)
	_sync_rings([] if forms_drawn else fx.get("rings", []))
	if _edge(&"arc", fx["arc_tick"]):
		var sup: bool = fx["arc_super"]
		for to: Vector2 in fx["arc_to"]:
			_bolt(
				fx["arc_from"], to, SUPER_COLOR if sup else ARC_COLOR, 0.09 if sup else 0.05, &"arc"
			)
	if _edge(&"nova", fx["nova_tick"]):
		if not _pack_ring(fx["nova_pos"], fx["nova_r"], &"ring_frost", &"frost"):
			_ring(fx["nova_pos"], fx["nova_r"], NOVA_COLOR, &"nova")
			_disc(fx["nova_pos"], fx["nova_r"], NOVA_COLOR, 0.25, &"nova")


# --- Reads (tests) ------------------------------------------------------------------------------------------------
func fx_count_of(kind: StringName) -> int:
	return _fx.count_of(kind)


func _edge(kind: StringName, tick: int) -> bool:
	if tick == _last[kind]:
		return false
	_last[kind] = tick
	return tick >= 0


# --- Fire ---------------------------------------------------------------------------------------------------------
func _sync_fires(fx: Dictionary) -> void:
	var pos: PackedVector2Array = fx["fire_pos"]
	var r: PackedFloat32Array = fx["fire_r"]
	var kind: PackedInt32Array = fx["fire_kind"]
	var left: PackedInt32Array = fx["fire_left"]
	while _fires.size() < pos.size():
		var m := MeshInstance3D.new()
		m.mesh = _disc_mesh
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_fires.append(m)
	_field_holds.fx = pack_fx
	_field_holds.begin()
	for k in _fires.size():
		var f := _fires[k]
		f.visible = k < pos.size() and (k >= _spec_keys.size() or _spec_keys[k] == "")
		if not f.visible:
			continue
		match kind[k]:
			WorldReader.FIRE_FIELD:
				f.material_override = _field_mat
			WorldReader.FIRE_ZONE:
				f.material_override = _zone_mat
			_:
				f.material_override = _fire_mat
		var s := r[k] * (0.55 + 0.45 * left[k] / 1000.0)
		if kind[k] == WorldReader.FIRE_FIELD and _pack_shock_field(pos[k], s):
			f.visible = false  # (the pack's ripple and bolts draw it)
			continue
		f.position = SimPlane.to_3d(pos[k], FIRE_Y + 0.002 * (k % 4))
		f.scale = Vector3(s, 1, s)
	_field_holds.end()


## v0.10.0 VX6 (N1): Arc Field's shock field of radius `r` at `at` as the pack's storm ripple,
## held while the field lasts, with a short bolt striking inside it about every ARC_STRIKE_S. False: no pack room.
func _pack_shock_field(at: Vector2, r: float) -> bool:
	if not PACK_STORM or pack_fx == null:
		return false
	var key := _cloud_key(at) * 4
	var c := SimPlane.to_3d(at, FIRE_Y + 0.03)
	if (
		_field_holds.touch(
			key + 1, StormPack.FIELD, &"area", c, r * ARC_FIELD_PER_M, StormPack.colors()
		)
		== null
	):
		return false
	var strike := int(_clock / ARC_STRIKE_S)
	var phase := fposmod(_clock, ARC_STRIKE_S) / ARC_STRIKE_S
	var bolt := _field_holds.touch(key + 2, StormPack.BOLT, &"bolt", c, 1.0, StormPack.colors())
	if bolt != null:
		var a := TAU * VfxCore.h(strike, key & 0xFFF)
		var a2 := a + (VfxCore.h(strike, 7) - 0.5) * 1.2
		var p := c + Vector3(cos(a), 0.0, sin(a)) * r * 0.2 + Vector3(0, 0.45, 0)
		var q := c + Vector3(cos(a2), 0.0, sin(a2)) * r * (0.55 + 0.3 * VfxCore.h(strike, 3))
		(bolt as ZdBolt).strength = 1.0 - 0.8 * phase
		(bolt as ZdBolt).set_ends(p, q, strike * 31 + (key & 0xFF), 0.09)
	return true


## v0.6.0 MX2: each growing ring as a thin torus at its radius now (the sim's number).
func _sync_rings(rings: Array) -> void:
	while _rings.size() < rings.size():
		var m := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.88
		torus.outer_radius = 1.0
		torus.rings = 40
		m.mesh = torus
		m.material_override = _ring_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_rings.append(m)
	for k in _rings.size():
		var m := _rings[k]
		m.visible = k < rings.size()
		if not m.visible:
			continue
		var r := maxf(0.05, float(rings[k][1]))
		m.position = SimPlane.to_3d(rings[k][0], FIRE_Y + 0.04)
		m.scale = Vector3(r, 0.08, r)


# --- Flashes ------------------------------------------------------------------------------------------------------
## A jagged bolt: BOLT_SEGMENTS boxes through points nudged off the straight line (a fixed zigzag, no randomness).
func _bolt(from: Vector2, to: Vector2, c: Color, thick: float, kind: StringName) -> void:
	var d := to - from
	if d.length() < 0.05:
		return
	if _pack_bolt(from, to, thick):
		return
	var side := Vector2(-d.y, d.x).normalized()
	var pts: Array[Vector2] = [from]
	for k in range(1, BOLT_SEGMENTS):
		var off := 0.25 if k % 2 == 1 else -0.25
		pts.append(from + d * (float(k) / BOLT_SEGMENTS) + side * off)
	pts.append(to)
	for k in BOLT_SEGMENTS:
		var a := pts[k]
		var b := pts[k + 1]
		var seg := b - a
		var n := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		n.mesh = box
		n.position = SimPlane.to_3d((a + b) * 0.5, SimPlane.CORE_HEIGHT + 0.3)
		n.rotation = Vector3(0, atan2(seg.y, seg.x), 0)
		n.scale = Vector3(seg.length(), thick, thick)
		_add(n, c, 0.95, kind)


## v0.10.0 VX6 (N1): the pack bolt from `from` to `to` (a bolt for BOLT_LIFE_S, fading, the storm spark at its
## end), `thick` the old box thickness. False: no PackFx or no room in the bolt family (the boxes draw).
func _pack_bolt(from: Vector2, to: Vector2, thick: float) -> bool:
	if not PACK_STORM or pack_fx == null or not pack_fx.has_room(&"bolt"):
		return false
	var a := SimPlane.to_3d(from, SimPlane.CORE_HEIGHT + 0.3)
	var b := SimPlane.to_3d(to, SimPlane.CORE_HEIGHT + 0.3)
	var n := pack_fx.spawn(StormPack.BOLT, a, 1.0, StormPack.colors(), BOLT_LIFE_S + 0.05) as ZdBolt
	if n == null:
		return false
	n.fade_time = BOLT_LIFE_S
	n.strength = 1.0
	n.set_ends(
		a, b, roundi(from.x * 31.0 + to.y * 17.0 + to.x * 7.0), clampf(thick * 1.6, 0.07, 0.16)
	)
	if pack_fx.has_room(&"hit"):
		pack_fx.spawn(StormPack.SPARK, b, BOLT_SPARK_SCALE, StormPack.colors())
	return true


func _ring(at: Vector2, r: float, c: Color, kind: StringName) -> void:
	var n := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.01, r - 0.14)
	torus.outer_radius = r
	torus.rings = 40
	n.mesh = torus
	n.scale = Vector3(1, 0.08, 1)
	n.position = SimPlane.to_3d(at, FIRE_Y + 0.03)
	_add(n, c, 0.9, kind)


func _disc(
	at: Vector2, r: float, c: Color, alpha: float, kind: StringName, y: float = FIRE_Y + 0.02
) -> void:
	var n := MeshInstance3D.new()
	n.mesh = _disc_mesh
	n.scale = Vector3(r, 1, r)
	n.position = SimPlane.to_3d(at, y)
	_add(n, c, alpha, kind)


## v0.10.0 VX3 (R26): the pack's ring `id` out to the sim's radius `r` at `at`, in the hero's `kind` colours, once
## (Frost Nova: pulse_area_02, Ember Ward: rim_area_04). False: no PackFx or no room, the torus and disc draw.
func _pack_ring(at: Vector2, r: float, id: StringName, kind: StringName) -> bool:
	if not PACK_ELEMENTS or pack_fx == null or not pack_fx.has_room(&"area"):
		return false
	var n := PackHold.play(
		pack_fx,
		id,
		SimPlane.to_3d(at, FIRE_Y + 0.03),
		r * float(RING_PER_M[id]),
		VfxPackViews.kind_colors(kind, true)
	)
	return n != null


func _add(n: MeshInstance3D, c: Color, alpha: float, kind: StringName) -> void:
	_fx.add(self, n, _template, c, alpha, kind, FX_FRAMES)


func _process(delta: float) -> void:
	_clock += delta
	_fx.step(1)


# --- Toxic Fumes (v0.9.5 EE3) --------------------------------------------------------------------------------------
## Each gas cloud is one flat quad with a soft round alpha (a radial gradient), at the sim's radius, fading through its
## last second. A pool of MAX_CLOUDS made once; nothing is spawned per cloud.
func _sync_clouds(reader: WorldReader) -> void:
	var c := reader.pair_clouds()
	var pos: PackedVector2Array = c["pos"]
	var left: PackedInt32Array = c["left"]
	var r: float = c["radius"]
	while _clouds.size() < mini(pos.size(), MAX_CLOUDS):
		var m := MeshInstance3D.new()
		m.mesh = _quad
		m.material_override = _gas_mat
		m.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_clouds.append(m)
	_holds.fx = pack_fx
	_holds.begin()
	for k in _clouds.size():
		var q := _clouds[k]
		q.visible = k < pos.size()
		if not q.visible:
			continue
		var fade := clampf(left[k] / 60.0, 0.0, 1.0)
		# v0.10.0 VX3 (R24): the pack's cloud (cap 4), held while the sim's cloud lasts; past the cap the flat quad
		if PACK_ELEMENTS and pack_fx != null:
			var node := _holds.touch(
				_cloud_key(pos[k]),
				&"fumes_cloud",
				&"cloud",
				SimPlane.to_3d(pos[k], GAS_Y),
				r * (0.7 + 0.3 * fade) * FUMES_PER_M,
				VfxPackViews.kind_colors(&"venom", true)
			)
			if node != null:
				q.visible = false
				continue
		q.position = SimPlane.to_3d(pos[k], GAS_Y + 0.002 * (k % 4))
		q.scale = Vector3(r * (0.7 + 0.3 * fade), r * (0.7 + 0.3 * fade), 1.0)
	_holds.end()


## A cloud's key: where it stands (a cloud does not move).
static func _cloud_key(at: Vector2) -> int:
	return roundi(at.x * 16.0) * 100003 + roundi(at.y * 16.0)


## Clouds drawn now (tests).
func cloud_count() -> int:
	return _clouds.filter(func(q: MeshInstance3D) -> bool: return q.visible).size()

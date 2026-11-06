class_name OverrunDoorViews
extends Node3D
## The Overrun room's doorways (v0.4.0 AB; v0.9.5 DR, owner Q6: "falling bars on every seal; Overrun's doorway has a
## small red floor rune instead of the glowing frame"): a small red rune on the floor just outside each doorway, so
## the room reads as the harder fight before you step in. It gently pulses, and goes dark once the room is cleared.
## The seal itself is the Lockdowns' falling bars (LockdownView). Presentation only: reads WorldReader.overrun() and
## the floor's doorways (EI-07). The rune is a flat quad with a code-drawn glyph (additive, unshaded, fog off, its
## edges masked to nothing).

const RED := Color("#E2321F")
## The rune's brightness (the emission multiplier) while the room is uncleared, and the pulse's swing around it.
const ENERGY := 0.6
const PULSE := 0.15
const PULSE_HZ := 0.45
const SIZE_M := 0.9
## How far past the doorway's wall face the rune's middle stands (m), and its height off the floor.
const OUTSIDE_M := 0.75
const LIFT_M := 0.03
const TEX_PX := 64

var rune_material := StandardMaterial3D.new()
var _runes: Array[MeshInstance3D] = []
var _cleared := false
var _clock := 0.0


func _init() -> void:
	name = "OverrunDoors"
	rune_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rune_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rune_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rune_material.disable_fog = true
	rune_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rune_material.albedo_texture = glyph()
	rune_material.render_priority = 1
	_set_energy(ENERGY)


func setup(reader: WorldReader) -> void:
	var o := reader.overrun()
	if not o["active"]:
		return
	var room: int = o["room"]
	for d: int in o["doors"]:
		var rect := reader.floor_door_rect(d)
		var along_x := reader.floor_door_angle(d) % 2048 == 0  # the rooms face along x: the gap runs along sim y
		var depth := rect.size.x if along_x else rect.size.y
		var out := Kin.dir(reader.floor_door_angle(d))
		if reader.floor_door_rooms(d).y == room:  # the angle runs from .x to .y: flip it to point away from the room
			out = -out
		_runes.append(_rune(rect.get_center() + out * (depth * 0.5 + OUTSIDE_M)))
	_cleared = bool(o["cleared"])
	_apply()


func sync(reader: WorldReader) -> void:
	if _runes.is_empty():
		return
	var cleared: bool = reader.overrun()["cleared"]
	if cleared != _cleared:
		_cleared = cleared
		_apply()


func _process(delta: float) -> void:
	if _cleared or _runes.is_empty():
		return
	_clock += delta
	_set_energy(ENERGY + PULSE * sin(_clock * TAU * PULSE_HZ))


## The number of runes (one a doorway; tests), and whether they glow (false once cleared).
func rune_count() -> int:
	return _runes.size()


func is_lit() -> bool:
	return not _cleared and not _runes.is_empty() and _runes[0].visible


func energy() -> float:
	return rune_material.albedo_color.r / RED.r


func _apply() -> void:
	for r in _runes:
		r.visible = not _cleared
	_set_energy(0.0 if _cleared else ENERGY)


func _set_energy(e: float) -> void:
	rune_material.albedo_color = Color(RED.r * e, RED.g * e, RED.b * e, 1.0)


func _rune(at: Vector2) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "OverrunRune"
	var q := QuadMesh.new()
	q.size = Vector2(SIZE_M, SIZE_M)
	q.orientation = PlaneMesh.FACE_Y  # flat on the floor
	m.mesh = q
	m.position = SimPlane.to_3d(at, LIFT_M)
	m.material_override = rune_material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


## The rune's glyph, drawn in code: a ring round a diamond with a dot at its heart, white on clear (the material tints
## it red); the alpha fades to nothing before the edge so the quad's square never shows.
static func glyph() -> ImageTexture:
	var img := Image.create(TEX_PX, TEX_PX, false, Image.FORMAT_RGBA8)
	for y in TEX_PX:
		for x in TEX_PX:
			var u := (float(x) + 0.5) / TEX_PX * 2.0 - 1.0
			var v := (float(y) + 0.5) / TEX_PX * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var ink := 0.0
			ink = maxf(ink, 1.0 - absf(r - 0.78) / 0.07)  # the ring
			ink = maxf(ink, 1.0 - absf(absf(u) + absf(v) - 0.5) / 0.07)  # the diamond
			ink = maxf(ink, 1.0 - r / 0.1)  # the dot
			var edge := clampf((0.95 - r) / 0.15, 0.0, 1.0)  # masked to nothing at the rim
			var a := clampf(ink, 0.0, 1.0) * edge
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

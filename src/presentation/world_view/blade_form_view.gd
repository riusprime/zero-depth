class_name BladeFormView
extends Node3D
## v0.6.5 WN4 (docs/design/WAND.md, the Blade pool's "You see" column; owner W5: "the slash becomes a spell"): what the
## Blade's cards do to the slash that neither the laser blade (KitView) nor the attack forms (AttackFormView) draw,
## read each sync from WorldReader.blade_forms() and the live projectiles' specs. Presentation only (EI-07): it decides
## nothing, and its timing is sim ticks.
##
## - Wave / Split Wave / Counter: each flying slash (a player bolt whose spec has an arc width) is a crescent, as wide
##   as its arc, bowed forward along its flight (a counter's is the big one);
## - Afterimage, Double Slash, a trigger's slash, a back copy: a ghost slash sweeping its arc (a mirrored echo sweeps
##   the other way, so a Double Slash reads as a criss-cross);
## - Fissure: the crack line growing ahead while it waits, then its eruption;
## - Parry Edge: a white spark star where a shot was cut;
## - Counter: a ring flash round the hero; Finisher+: its big shockwave ring;
## - Orbit Blades: a blade at each orbiting blade's place, turning.
## One ImmediateMesh, rebuilt each sync; flat marks on the floor use the hero's cool core, never a hostile hue.

const HEIGHT := 0.45
const FLOOR := 0.04
const GHOST_TICKS := 14
const GHOST_SWEEP := 6
const LINE_TICKS := 20
const SPARK_TICKS := 10
const RING_TICKS := 14
const ARC_SEGMENTS := 14
## A crescent's bow: its radius past the bolt's own, and the widest it is drawn (radians, half).
const CRESCENT_R := 0.45
const CRESCENT_MAX_HALF := 1.2
const SPARK := Color(1.0, 0.97, 0.85, 1.0)

## What the last sync drew, by kind (the tests read it): crescent, ghost, crack, line, spark, ring, blade.
var drawn := {}
var _mesh := ImmediateMesh.new()
var _node := MeshInstance3D.new()
var _mat := StandardMaterial3D.new()
var _core := ThemePalette.color(&"player_core")
var _looks := {}


func _init() -> void:
	name = "BladeFormView"
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat.vertex_color_use_as_albedo = true
	_node.mesh = _mesh
	_node.material_override = _mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_node.extra_cull_margin = 16.0
	add_child(_node)


func sync(reader: WorldReader) -> void:
	_mesh.clear_surfaces()
	drawn = {}
	var tick := reader.tick()
	var b := reader.blade_forms()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	any = _crescents(reader) or any
	for f: Dictionary in b["fx"]:
		any = _fx(f, tick, reader.player_pos()) or any
	for c: Dictionary in b["cracks"]:
		any = _crack(c) or any
	for p in b["blades"]:
		any = _blade(p, tick) or any
	if not any:  # an empty surface is an error: close it on a degenerate triangle
		for k in 3:
			_mesh.surface_set_color(Color(0, 0, 0, 0))
			_mesh.surface_add_vertex(Vector3.ZERO)
	_mesh.surface_end()


func _count(kind: StringName) -> void:
	drawn[kind] = int(drawn.get(kind, 0)) + 1


## The arc width (1/4096 turns) a player projectile's spec gives its crescent (x; 0: not a flying slash) and its
## radius (y), cached per build digest.
func _crescent_of(reader: WorldReader, key: String) -> Vector2:
	if key == "":
		return Vector2.ZERO
	var sig := reader.attack_digest() + "|" + key
	if not _looks.has(sig):
		if _looks.size() > 64:
			_looks.clear()
		var s := reader.attack_spec_at(key)
		var bolt := int(s.get("form", -1)) == WorldReader.FORM_BOLT
		_looks[sig] = Vector2(
			float(s.get("half_arc", 0)) if bolt else 0.0, float(s.get("radius_m", 0.0))
		)
	return _looks[sig]


func _crescents(reader: WorldReader) -> bool:
	var any := false
	for i in reader.projectile_count():
		if reader.projectile_team(i) != 0:
			continue
		var look := _crescent_of(reader, reader.projectile_spec_key(i))
		if look.x <= 0.0:
			continue
		var p := reader.projectile_pos(i)
		var v := reader.projectile_vel(i)
		var yaw := v.angle() if v.length() > 0.0001 else 0.0
		var half := minf(TAU * look.x / 4096.0, CRESCENT_MAX_HALF)
		var r := CRESCENT_R + look.y
		var centre := p - Vector2(cos(yaw), sin(yaw)) * r * 0.7
		_arc_band(centre, yaw - half, yaw + half, r - 0.12, r + 0.08, HEIGHT, _core, 0.9)
		_count(&"crescent")
		any = true
	return any


func _fx(f: Dictionary, tick: int, hero: Vector2) -> bool:
	var age := tick - int(f["tick"])
	var at: Vector2 = f["pos"]
	var yaw := TAU * float(f["angle"]) / 4096.0
	match int(f["kind"]):
		WorldReader.BLADE_FX_ARC, WorldReader.BLADE_FX_ARC_MIRROR:
			return _ghost(f, age, at, yaw)
		WorldReader.BLADE_FX_LINE:
			return _eruption(f, age, at, yaw)
		WorldReader.BLADE_FX_PARRY:
			return _spark(age, at, yaw)
		WorldReader.BLADE_FX_COUNTER, WorldReader.BLADE_FX_BURST:
			return _ring(f, age, at, hero)
	return false


## A ghost slash sweeping its arc (a mirrored echo the other way: a criss-cross).
func _ghost(f: Dictionary, age: int, at: Vector2, yaw: float) -> bool:
	if age > GHOST_TICKS:
		return false
	var half := minf(TAU * float(f["a"]) / 4096.0, PI)
	var sweep := clampf(float(age + 1) / GHOST_SWEEP, 0.0, 1.0)
	var fade := 1.0 - clampf(float(age - GHOST_SWEEP) / (GHOST_TICKS - GHOST_SWEEP), 0.0, 1.0)
	var reach := 0.45 + float(f["b"])
	var from := yaw - half
	var to := yaw - half + 2.0 * half * sweep
	if int(f["kind"]) == WorldReader.BLADE_FX_ARC_MIRROR:
		from = yaw + half - 2.0 * half * sweep
		to = yaw + half
	_arc_band(at, from, to, reach * 0.45, reach, HEIGHT, _core.lerp(Color.WHITE, 0.3), 0.45 * fade)
	_count(&"ghost")
	return true


## Fissure's eruption: the line lit on the floor and spikes of light rising along it.
func _eruption(f: Dictionary, age: int, at: Vector2, yaw: float) -> bool:
	if age > LINE_TICKS:
		return false
	var fade := 1.0 - float(age) / LINE_TICKS
	var length := float(f["a"])
	var width := float(f["b"])
	var dir := Vector2(cos(yaw), sin(yaw))
	_quad(at, at + dir * length, width * (1.0 + 0.4 * fade), FLOOR, _core, 0.55 * fade)
	for k in int(length / 0.5):
		var c := at + dir * (0.25 + 0.5 * k)
		var side := 0.25 if k % 2 == 0 else -0.25
		var tip := c + Vector2(-dir.y, dir.x) * side * width
		_spike(c, tip, 0.12, (0.4 + 0.9 * fade) * (1.0 if k % 3 else 1.3), _core, fade)
	_count(&"line")
	return true


## Parry Edge's spark: a white star where the shot was cut.
func _spark(age: int, at: Vector2, yaw: float) -> bool:
	if age > SPARK_TICKS:
		return false
	var fade := 1.0 - float(age) / SPARK_TICKS
	var s := 0.2 + 0.35 * (1.0 - fade)
	for k in 4:
		var a := yaw + PI * 0.25 * k
		var d := Vector2(cos(a), sin(a)) * s
		_quad(at - d, at + d, 0.04, HEIGHT, SPARK, fade)
	_count(&"spark")
	return true


## A counter's ring flash round the hero, or Finisher+'s shockwave ring at its radius.
func _ring(f: Dictionary, age: int, at: Vector2, hero: Vector2) -> bool:
	if age > RING_TICKS:
		return false
	var p := float(age) / RING_TICKS
	var big := int(f["kind"]) == WorldReader.BLADE_FX_BURST
	var r := (float(f["a"]) if big else 1.2) * (0.3 + 0.7 * p)
	_arc_band(
		at if big else hero, 0.0, TAU, maxf(r - 0.15, 0.0), r, FLOOR + 0.02, _core, 0.6 * (1.0 - p)
	)
	_count(&"ring")
	return true


## A fissure waiting to erupt: a thin crack that grows ahead until it bursts.
func _crack(c: Dictionary) -> bool:
	var yaw := TAU * float(c["angle"]) / 4096.0
	var grow := 1.0 - clampf(float(c["left"]) / 18.0, 0.0, 1.0)
	var at: Vector2 = c["pos"]
	var to := at + Vector2(cos(yaw), sin(yaw)) * float(c["length"]) * (0.2 + 0.8 * grow)
	_quad(at, to, 0.05, FLOOR, _core.lerp(Color.WHITE, 0.4), 0.5 + 0.4 * grow)
	_count(&"crack")
	return true


## An orbiting blade: a slim diamond turning with the tick.
func _blade(p: Vector2, tick: int) -> bool:
	var yaw := float(tick) * 0.35
	var d := Vector2(cos(yaw), sin(yaw)) * 0.28
	_quad(p - d, p + d, 0.07, HEIGHT, _core.lerp(Color.WHITE, 0.5), 0.9)
	_count(&"blade")
	return true


# --- Mesh pieces (triangles, world space on the sim plane) ----------------------------------------------------------
func _v(p: Vector2, h: float, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(SimPlane.to_3d(p, h))


## A band of an arc round `centre` from angle `a0` to `a1` (radians, sim plane), between radii r0 and r1.
func _arc_band(
	centre: Vector2, a0: float, a1: float, r0: float, r1: float, h: float, c: Color, alpha: float
) -> void:
	var inner := Color(c, alpha * 0.25)
	var outer := Color(c.lerp(Color.WHITE, 0.25), alpha)
	for k in ARC_SEGMENTS:
		var t0 := lerpf(a0, a1, float(k) / ARC_SEGMENTS)
		var t1 := lerpf(a0, a1, float(k + 1) / ARC_SEGMENTS)
		var d0 := Vector2(cos(t0), sin(t0))
		var d1 := Vector2(cos(t1), sin(t1))
		_v(centre + d0 * r0, h, inner)
		_v(centre + d0 * r1, h, outer)
		_v(centre + d1 * r1, h, outer)
		_v(centre + d0 * r0, h, inner)
		_v(centre + d1 * r1, h, outer)
		_v(centre + d1 * r0, h, inner)


## A flat strip from `a` to `b`, `width` wide, at height h.
func _quad(a: Vector2, b: Vector2, width: float, h: float, c: Color, alpha: float) -> void:
	var d := b - a
	if d.length() < 0.0001:
		return
	var n := Vector2(-d.y, d.x).normalized() * width * 0.5
	var col := Color(c, alpha)
	_v(a - n, h, col)
	_v(a + n, h, col)
	_v(b + n, h, col)
	_v(a - n, h, col)
	_v(b + n, h, col)
	_v(b - n, h, col)


## An eruption's spike: a thin upright blade of light from `base` rising to `height`, leaning toward `tip`.
func _spike(
	base: Vector2, tip: Vector2, width: float, height: float, c: Color, alpha: float
) -> void:
	var d := (tip - base).normalized() * width
	var top := SimPlane.to_3d(base.lerp(tip, 0.3), height)
	_mesh.surface_set_color(Color(c, alpha * 0.3))
	_mesh.surface_add_vertex(SimPlane.to_3d(base - d, FLOOR))
	_mesh.surface_set_color(Color(c, alpha * 0.3))
	_mesh.surface_add_vertex(SimPlane.to_3d(base + d, FLOOR))
	_mesh.surface_set_color(Color(c.lerp(Color.WHITE, 0.4), alpha))
	_mesh.surface_add_vertex(top)

class_name RailStreakViews
extends Node3D
## The Siege Engine's rail streak: the owner's streak (fx_rail_streak, four variants of one rail-gun streak in rows:
## thick, thin with a bright knot, medium, thin with a knot near its start) laid flat on the floor behind the shot as
## it runs down its lane, and never stretched (owner: "it should be something that appears as the boss slides and
## not an streching texture").
## - Tiles: each lane is cut into tiles TILE_M long from the boss's edge. A tile shows a quarter of one variant's row
##   at that row's own aspect (the sheet's rows are STRIP_ASPECT times as long as they are tall, ROW_W_M wide on the
##   floor), so a tile is never stretched; the last tile of a lane is shorter and shows as much less of the row.
##   Consecutive tiles show consecutive quarters of the row, so the streak runs on unbroken; each lane draws one
##   variant, picked from the strike's seed and the lane (the same shot looks the same every time it is replayed).
## - When: a tile appears on the tick the shot's front (WorldReader.boss_lane_front, the slice the hit is resolved
##   from) passes its start, burns HOLD ticks, then fades over FADE ticks, so the streak fades tile by tile in the
##   order it was laid. Once the boss leaves the strike, every tile not yet laid is laid at once.
## Reads only (EI-07): the strike dictionaries are BossStrikeViews', this keeps its laid ticks in them ("streak").
## One MultiMesh, one draw, CAP tiles. Without the texture nothing is drawn and the code rail stays (`installed`).

const TEX_ID := "fx_rail_streak"
## The sheet: four rows (variants), each this many times as long as it is tall.
const ROWS := 4
const STRIP_ASPECT := 8.0
## A row's width across the lane on the floor (m): the lane hits 1.2 m wide; the streak's haze reaches a little past.
const ROW_W_M := 1.4
## A tile shows this share of a row: a quarter, so a tile is TILE_M long at the row's aspect.
const WINDOWS := 4
const TILE_M := ROW_W_M * STRIP_ASPECT / WINDOWS
## Ticks a tile burns after it is laid, then ticks it fades over.
const HOLD := 10.0
const FADE := 16.0
## Just over the scorch (BossStrikeShapes' ground quads) so it draws on top of it.
const FLOOR_Y := 0.07
const CAP := 160
const STRENGTH := 0.9

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform float strength = 1.0;
uniform float rows = 4.0;
varying vec4 cd;
void vertex() {
	cd = INSTANCE_CUSTOM;
}
void fragment() {
	float v = clamp(UV.y, 0.004, 0.996);
	vec2 uv = vec2(cd.x + UV.x * cd.y, (cd.z + v) / rows);
	ALBEDO = texture(sheet, uv).rgb * cd.w * strength;
}
"""

var installed := false
var _mm := MultiMesh.new()
var _drawn := 0


func _init() -> void:
	name = "RailStreak"
	var tex := FxTextures.get_tex(TEX_ID)
	installed = tex != null
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = q
	_mm.instance_count = CAP
	_mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = "Tiles"
	node.multimesh = _mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	node.extra_cull_margin = 16384.0  # the tiles spread over the whole room
	if installed:
		var m := ShaderMaterial.new()
		m.shader = FxTextures.shader(SHADER)
		m.set_shader_parameter("sheet", tex)
		m.set_shader_parameter("strength", STRENGTH)
		m.set_shader_parameter("rows", float(ROWS))
		m.render_priority = 2  # over the scorch and the telegraph's fill of the same lane (both transparent)
		node.material_override = m
	add_child(node)


## Lane tiles: [start m, length m, u0, u width] from the lane's start; each tile's length over ROW_W_M equals its u
## width times STRIP_ASPECT (its true aspect).
static func tiles(lane_len: float) -> Array[Vector4]:
	var out: Array[Vector4] = []
	var k := 0
	while k * TILE_M < lane_len - 0.01:
		var start := k * TILE_M
		var len := minf(TILE_M, lane_len - start)
		var w := len / TILE_M / WINDOWS
		out.append(Vector4(start, len, float(k % WINDOWS) / WINDOWS, w))
		k += 1
	return out


## The variant (row) lane `lane` of a strike seeded `seed` draws.
static func row_of(seed: int, lane: int) -> int:
	var h := (seed * 73856093) ^ ((lane + 1) * 19349663)
	return absi(h) % ROWS


## A tile laid `t` ticks ago: full while it burns, then fading out; 0 before it is laid.
static func alpha(t: float) -> float:
	if t < 0.0:
		return 0.0
	return clampf(1.0 - (t - HOLD) / FADE, 0.0, 1.0)


## Ticks from a strike to its last tile gone, at most (the last tile is laid when the shot's active ticks end).
static func span(active_ticks: int) -> float:
	return float(active_ticks) + HOLD + FADE


## Lays strike `s`'s tiles the shot's fronts (m down each lane; INF: the whole lane) have passed, on tick `tick`.
static func lay(s: Dictionary, tick: int, fronts: PackedFloat32Array) -> void:
	var lanes: Array = s.get("lanes", [])
	if not s.has("streak"):
		var laid := []
		for o: Obb in lanes:
			var t := PackedFloat32Array()
			t.resize(tiles(o.half.x * 2.0).size())
			t.fill(-1.0)
			laid.append(t)
		s["streak"] = laid
	var all: Array = s["streak"]
	for li in mini(lanes.size(), fronts.size()):
		var o: Obb = lanes[li]
		var laid: PackedFloat32Array = all[li]
		var ts := tiles(o.half.x * 2.0)
		for k in ts.size():
			if laid[k] < 0.0 and ts[k].x < fronts[li]:
				laid[k] = float(tick)
		all[li] = laid


## Lane `o`'s tile `t` (tiles()) on the floor: the unit quad scaled to the tile's length along the lane and ROW_W_M
## across it.
static func tile_transform(o: Obb, t: Vector4) -> Transform3D:
	var start := o.center - o.axis_u * o.half.x
	var side := Vector3(o.axis_u.y, 0.0, o.axis_u.x)  # across the lane, on the floor
	var b := Basis(SimPlane.to_3d(o.axis_u) * t.y, Vector3.UP, side * ROW_W_M)
	return Transform3D(b, SimPlane.to_3d(start + o.axis_u * (t.x + t.y * 0.5), FLOOR_Y))


## Draws every rail strike's laid tiles at tick `now`.
func draw(strikes: Array[Dictionary], now: float) -> void:
	var n := 0
	for s in strikes:
		if not installed or not s.has("streak"):
			continue
		var lanes: Array = s["lanes"]
		var all: Array = s["streak"]
		var sd := int(s.get("seed", 0))
		for li in lanes.size():
			var o: Obb = lanes[li]
			var laid: PackedFloat32Array = all[li]
			var ts := tiles(o.half.x * 2.0)
			var row := float(row_of(sd, li))
			for k in ts.size():
				var a := alpha(now - laid[k]) if laid[k] >= 0.0 else 0.0
				if a <= 0.0 or n >= CAP:
					continue
				var t := ts[k]
				_mm.set_instance_transform(n, tile_transform(o, t))
				_mm.set_instance_custom_data(n, Color(t.z, t.w, row, a))
				n += 1
	_mm.visible_instance_count = n
	_drawn = n


## Tiles drawn in the last draw (tests).
func drawn() -> int:
	return _drawn


func multimesh() -> MultiMesh:
	return _mm

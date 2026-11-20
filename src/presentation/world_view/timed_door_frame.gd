class_name TimedDoorFrame
extends RefCounted
## The timed door's frame, laid in the floor's own wall blocks so the doorway reads as the wall it stands in, not as a
## piece set into it: two square jambs and a lintel of stone courses on the wall's course lines (ProceduralWall.COURSES,
## its GAP joints), each block a WallPillars stone box in ProceduralWall's vertex format, so the walls' material (the
## owner's face and top textures by biome, ProceduralWall.material) draws them as it draws the walls. Up to the wall's
## height (WALL_H) the jambs square off the wall's ends, as deep as the doorway (the wall's thickness, which between
## two rooms can be 3 m); above it the gate rises only GATE_D deep in the middle of that depth, so the opening is a
## gateway across the passage, not a dark tunnel, and the rooms' floor and light show on both sides of the slab. All
## of it PROUD of the wall's faces and of the doorway's sides so no face lies on a wall's face; the lintel tops out at
## TOP, a gate over walls about ProceduralWall.BASE_H high, not a tower. Every block is a closed box, so from inside
## the secret room the frame's back is solid wall too.
## In the door's frame: +X into the secret room, the wall along Z. Presentation only.

## The opening's height (m): the hero (1.8 m) walks under the lintel.
const OPEN_H := 1.9
## The lintel's top (m).
const TOP := 2.45
## Each jamb's width along the wall (m), standing over the wall's end beside the doorway.
const JAMB := 0.7
## How far the blocks stand out of the wall's faces and into the doorway's sides (m).
const PROUD := 0.03
## The jambs' course lines: the wall's, carried up to the opening's top.
const COURSES: Array[float] = [0.0, 0.36, 0.7, 1.02, 1.4, 1.65, OPEN_H]
## The jambs' courses below this line are as deep as the wall; the gate's above it GATE_D deep (m).
const WALL_H := 1.02
const GATE_D := 1.2
## The lintel's middle block (its keystone): its length along the wall and how much further it stands out (m).
const KEY := 0.8
const KEY_OUT := 0.03
## The heights of the jambs' lit notches (m): on the middle of a course each.
const NOTCH_Y: Array[float] = [0.53, 1.21, 1.775]


## The frame's blocks for a doorway `width` across and `depth` deep, one surface. `face_m`, `top_m`: the walls' texture
## tiles (BiomeMood.wall_texture_m, wall_top_texture_m), so the blocks' stone reads at the walls' scale.
static func mesh(
	width: float,
	depth: float,
	face_m := ProceduralWall.FACE_M_DEFAULT,
	top_m := ProceduralWall.TOP_M_DEFAULT
) -> ArrayMesh:
	var b := ProceduralWall.Buf.new()
	b.face_w = face_m
	b.top_w = top_m
	var wall_x := depth * 0.5 + PROUD
	var x1 := gate_depth(depth) * 0.5 + PROUD
	var x0 := -x1
	var inner := width * 0.5 - PROUD
	var outer := width * 0.5 + JAMB
	for side in [-1.0, 1.0]:
		for k in COURSES.size() - 1:
			var y0 := COURSES[k] + (0.0 if k == 0 else ProceduralWall.GAP * 0.5)
			var y1 := COURSES[k + 1] - ProceduralWall.GAP * 0.5
			var x := wall_x if COURSES[k + 1] <= WALL_H else x1
			_block(b, -x, x, side * inner, side * outer, y0, y1, k == 0, _tint(k, side))
	var y0 := OPEN_H + ProceduralWall.GAP * 0.5
	var half := KEY * 0.5
	var g := ProceduralWall.GAP * 0.5
	for side in [-1.0, 1.0]:  # the lintel's two side blocks, over the jambs and the opening's edges
		_block(b, x0, x1, side * (half + g), side * outer, y0, TOP, false, _tint(7, side))
	_block(b, x0 - KEY_OUT, x1 + KEY_OUT, -half + g, half - g, y0, TOP, false, _tint(8, 0.0))
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.arrays())
	return out


## How deep the gate above the wall's height stands (m): GATE_D, or the doorway's depth when that is less.
static func gate_depth(depth: float) -> float:
	return minf(depth, GATE_D)


## Where each lit notch sits on the jambs' faces toward the side you come from (the door's frame): on the wall-deep
## courses' face low down, on the gate's face above the wall's height.
static func notch_spots(width: float, depth: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		for y in NOTCH_Y:
			var face := (depth if y < WALL_H else gate_depth(depth)) * 0.5 + PROUD + 0.03
			out.append(Vector3(-face, y, side * (width * 0.5 + (JAMB - PROUD) * 0.5)))
	return out


## A stone box from x0..x1 (across the wall), z0..z1 (along it) and y0..y1, in WallPillars' way (no bottom on the
## ground).
static func _block(
	b: ProceduralWall.Buf,
	x0: float,
	x1: float,
	z0: float,
	z1: float,
	y0: float,
	y1: float,
	on_ground: bool,
	col: Color
) -> void:
	# SimPlane.to_3d maps the plane's y to -z: the rect's y runs from -z1 to -z0.
	var r := Rect2(x0, -maxf(z0, z1), x1 - x0, absf(z1 - z0))
	b.u_off = absf(z0) / maxf(b.face_w, 0.01)
	WallPillars._box(b, r, y0, y1, 0.0, on_ground, col)


## A block's stone brightness: a fixed small spread per course and side, as the walls' blocks vary.
static func _tint(k: int, side: float) -> Color:
	var t := lerpf(0.86, 1.0, ProceduralWall._hash(k, int(side) + 2, 4057))
	return Color(t, t, t)

class_name GroundSlamViews
extends Node3D
## A heavy body slamming into the stone floor (the amber Warden's charge's end, ChargeBurstViews), drawn in the
## game's own low-poly look, the way the Gatekeeper's stone spikes are: faceted, flat-shaded stone in the floor's
## colours, lit by the stage's sun and casting its shadows, with no fire, glow or light of its own.
## - Chunks of the floor kicked up out of the impact, a few sizes, tumbling, falling back under gravity and sinking
##   into the floor where they land (all down within about 0.7 s).
## - Floor plates heaved up round the impact, tilted outward, settling back.
## - A short radial spray of grit and a low, flat kick of dust in the floor's colour, gone in 0.35 s (no lingering
##   smoke).
## - The floor fractured: a dark crater and jagged cracks radiating to the edge of the hit, fading within a second.
## Everything is sized to the radius the sim hit. Frame-time animation from the moment ChargeBurstViews saw the burst;
## the outcome is the sim's. Pooled: one MultiMesh for every piece of every slam (one draw), and SLOTS crack meshes
## built once. Reduced motion: the pieces don't tumble.

const SLOTS := 2
## Pieces per slam: rocks thrown up (big, then medium), heaved floor plates, grit and dust puffs.
const BIG := 11
const MID := 16
const PLATES := 7
const GRIT := 26
const DUST := 12
const PIECES := BIG + MID + PLATES + GRIT + DUST
## The radius the pieces' sizes and reaches are made for (the amber Warden's burst); other radii scale them.
const MADE_FOR_M := 3.5
## Gravity (m/s²): heavier than the world's, so the chunks drop back like stone, not float.
const GRAVITY := 26.0
## The crack's life (s): it opens over CRACK_OPEN_S, holds, then fades by CRACK_LIFE_S.
const CRACK_OPEN_S := 0.07
const CRACK_HOLD_S := 0.35
const CRACK_LIFE_S := 1.0
const CRACK := Color(0.09, 0.085, 0.09, 0.85)
const CRATER := Color(0.12, 0.11, 0.115, 0.55)
## A slam is over (its slot free) after this long.
const LIFE_S := 1.05
## The stone's colours when no biome palette is handed over (a view built alone): grey stone.
const STONE := Color(0.5, 0.48, 0.46)
const STONE_DARK := Color(0.28, 0.27, 0.27)
const KIND_ROCK := 0
const KIND_PLATE := 1
const KIND_DUST := 2

static var _rock_mesh: ArrayMesh

## The floor's colour and the darker stone under it (floor_palette).
var stone := STONE
var stone_dark := STONE_DARK
## Live slams: {"at" (Vector3), "radius", "age", "seed", "slot", "pieces": [[kind, from (Vector3), velocity (Vector3),
## size (Vector3), spin axis, spin (rad/s), colour, landed-by (s), gone-by (s), yaw]]}.
var _slams: Array[Dictionary] = []
var _started := 0
var _node := MultiMeshInstance3D.new()
var _cracks: Array[MeshInstance3D] = []
var _shown := 0
## The highest piece drawn this frame (m above the impact; tests: a headless renderer keeps no MultiMesh state).
var _highest := 0.0


func _init() -> void:
	name = "GroundSlams"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = rock_mesh()
	mm.instance_count = SLOTS * PIECES
	mm.visible_instance_count = 0
	_node.name = "Pieces"
	_node.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true  # the palette's colours
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.roughness = 0.95
	mat.metallic_specular = 0.15
	_node.material_override = mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_node.extra_cull_margin = 16384.0  # the pieces of two slams anywhere in the room
	add_child(_node)
	for k in SLOTS:
		var mi := MeshInstance3D.new()
		mi.name = "Cracks%d" % k
		mi.mesh = crack_mesh(k * 131 + 7)
		var cm := StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cm.vertex_color_use_as_albedo = true
		cm.vertex_color_is_srgb = true
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = cm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		_cracks.append(mi)
		add_child(mi)


## The biome's floor colours: the chunks are its floor stone (`ground`), darkened toward its `cover` stone.
func floor_palette(palette: Dictionary) -> void:
	if palette.has("ground"):
		stone = palette["ground"]
	if palette.has("cover"):
		stone_dark = stone.lerp(palette["cover"], 0.7)


## A slam at `at` (ground) hitting `radius` round: its pieces thrown and its cracks opened from now. A third slam
## while two still play replaces the oldest.
func slam(at: Vector3, radius: float) -> void:
	var slot := _free_slot()
	var sd := 977 * (_started + 1) + int(absf(at.x) * 53.0) + int(absf(at.z) * 29.0)
	_started += 1
	var s := {"at": at, "radius": radius, "age": 0.0, "seed": sd, "slot": slot, "pieces": []}
	_pieces(s)
	_slams.append(s)
	var cr := _cracks[slot]
	cr.position = at + Vector3(0, 0.04 + 0.004 * slot, 0)
	cr.rotation = Vector3(0, TAU * VfxCore.h(sd, 1), 0)
	cr.scale = Vector3.ONE * (radius / MADE_FOR_M)
	cr.visible = true


func _free_slot() -> int:
	for k in SLOTS:
		if _slams.all(func(s: Dictionary) -> bool: return int(s["slot"]) != k):
			return k
	var oldest: Dictionary = _slams.pop_front()
	return int(oldest["slot"])


## Every piece's flight, from the seed: where it starts, its launch, its size, its spin and when it lands and goes.
func _pieces(s: Dictionary) -> void:
	var sd: int = s["seed"]
	var f := float(s["radius"]) / MADE_FOR_M
	var out: Array = s["pieces"]
	var counts := [BIG, MID, PLATES, GRIT, DUST]
	for group in counts.size():
		for j in int(counts[group]):
			var id := group * 64 + j
			var ang := TAU * (j + 0.5 * VfxCore.h(sd + id, 2)) / float(counts[group])
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			var hh := VfxCore.h(sd + id, 3)
			var hs := VfxCore.h(sd + id, 4)
			match group:
				0:  # big rocks: from near the middle, high, landing from half way out to the edge
					out.append(
						_rock(
							dir,
							f,
							0.15,
							lerpf(0.6, 1.0, hh),
							lerpf(0.5, 0.6, hs),
							0.45,
							0.7,
							sd + id
						)
					)
				1:  # medium rocks: further, a little lower
					out.append(
						_rock(
							dir,
							f,
							0.25,
							lerpf(0.75, 1.15, hh),
							lerpf(0.4, 0.52, hs),
							0.22,
							0.34,
							sd + id
						)
					)
				2:  # floor plates heaved round the impact
					var at := dir * lerpf(0.25, 0.5, hh) * MADE_FOR_M * f
					var size := Vector3(lerpf(1.0, 1.3, hs), 0.22, lerpf(0.7, 0.9, hh)) * f
					var c := stone.lerp(stone_dark, lerpf(0.2, 0.4, VfxCore.h(sd + id, 5)))
					out.append(
						[
							KIND_PLATE,
							at,
							dir,
							size,
							Vector3.ZERO,
							0.0,
							c,
							0.0,
							lerpf(0.75, 0.9, hs),
							ang
						]
					)
				3:  # grit: a low, fast spray out to the edge
					out.append(
						_rock(
							dir,
							f,
							0.1,
							lerpf(0.85, 1.2, hh),
							lerpf(0.22, 0.32, hs),
							0.07,
							0.12,
							sd + id
						)
					)
				_:  # dust puffs: a low ring kicked out and gone
					var at := dir * 0.3 * MADE_FOR_M * f + Vector3(0, 0.05, 0)
					var size := Vector3(0.95, 0.2, 0.95) * lerpf(0.75, 1.1, hs) * f
					var c := stone.lerp(stone_dark, 0.15)
					out.append(
						[
							KIND_DUST,
							at,
							dir,
							size,
							Vector3.ZERO,
							0.0,
							c,
							0.0,
							lerpf(0.28, 0.35, hh),
							ang
						]
					)


## A thrown rock: it starts `from_f` of the way out, lands `to_f` of the way out after `air` s, is `lo`..`hi` m
## across, tumbles, rests a beat where it lands and sinks into the floor.
func _rock(
	dir: Vector3, f: float, from_f: float, to_f: float, air: float, lo: float, hi: float, sd: int
) -> Array:
	var reach := MADE_FOR_M * f
	var from := dir * from_f * reach * VfxCore.h(sd, 6) + Vector3(0, 0.1, 0)
	var land := dir.rotated(Vector3.UP, 0.4 * (VfxCore.h(sd, 7) - 0.5)) * to_f * reach
	var t := air * sqrt(f)
	var v := (land - from) / t
	v.y = 0.5 * GRAVITY * t - 0.1 / t
	var w := lerpf(lo, hi, VfxCore.h(sd, 8)) * f
	var size := Vector3(
		w, w * lerpf(0.6, 0.9, VfxCore.h(sd, 9)), w * lerpf(0.75, 1.0, VfxCore.h(sd, 10))
	)
	var axis := Vector3(VfxCore.h(sd, 11) - 0.5, 0.3, VfxCore.h(sd, 12) - 0.5).normalized()
	var spin := lerpf(6.0, 14.0, VfxCore.h(sd, 13)) * (1.0 if VfxCore.h(sd, 14) > 0.5 else -1.0)
	var c := stone.lerp(stone_dark, lerpf(0.45, 0.95, VfxCore.h(sd, 15)))
	return [KIND_ROCK, from, v, size, axis, spin, c, t, t + 0.2, TAU * VfxCore.h(sd, 16)]


func busy() -> bool:
	return not _slams.is_empty() or _shown > 0


## Frame-time animation (ChargeBurstViews.advance).
func advance(delta: float) -> void:
	var mm := _node.multimesh
	var n := 0
	_highest = 0.0
	var keep: Array[Dictionary] = []
	for s in _slams:
		s["age"] = float(s["age"]) + delta
		var age: float = s["age"]
		var cr := _cracks[int(s["slot"])]
		if age >= LIFE_S:
			cr.visible = false
			continue
		keep.append(s)
		_crack(cr, age, float(s["radius"]) / MADE_FOR_M)
		var at: Vector3 = s["at"]
		for p: Array in s["pieces"]:
			var t := _place(p, age)
			if t.basis.determinant() == 0.0:
				continue
			mm.set_instance_transform(n, Transform3D(t.basis, at + t.origin))
			mm.set_instance_color(n, p[6])
			_highest = maxf(_highest, t.origin.y)
			n += 1
	_slams = keep
	mm.visible_instance_count = n
	_shown = n


## One piece's transform `age` s into its slam (relative to the impact); a zero basis when it is not drawn.
func _place(p: Array, age: float) -> Transform3D:
	var size: Vector3 = p[3]
	var gone: float = p[8]
	if age >= gone:
		return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	var yaw := Basis(Vector3.UP, float(p[9]))
	match int(p[0]):
		KIND_PLATE:  # up and tilted outward at once, held, then settling back and sinking
			yaw = Basis(Vector3.UP, -float(p[9]))  # its long side pointing out
			var up := minf(age / 0.05, 1.0)
			var settle := clampf((age - 0.4) / (gone - 0.4), 0.0, 1.0)
			var tilt := 0.6 * up * (1.0 - settle)
			var dir: Vector3 = p[2]
			var b := Basis(dir.cross(Vector3.UP).normalized(), tilt) * yaw * Basis.from_scale(size)
			return Transform3D(b, p[1] + Vector3(0, 0.06 * up - 0.2 * settle * settle, 0))
		KIND_DUST:  # kicked out low, swelling then shrinking away
			var u := age / gone
			var dir: Vector3 = p[2]
			var grow := sin(PI * minf(u * 1.4, 1.0)) * (1.0 - u)
			var at: Vector3 = p[1] + dir * float(MADE_FOR_M * 0.6 * (1.0 - (1.0 - u) * (1.0 - u)))
			return Transform3D(yaw * Basis.from_scale(size * (0.3 + 1.6 * grow)), at)
		_:  # a rock: thrown, tumbling, landing, resting a beat and sinking
			var land: float = p[7]
			var t := minf(age, land)
			var v: Vector3 = p[2]
			var pos: Vector3 = p[1] + v * t + Vector3(0, -0.5 * GRAVITY * t * t, 0)
			pos.y = maxf(pos.y, size.y * 0.3)
			var turn := 0.0 if ViewPrefs.reduced_motion else float(p[5]) * t
			var b := Basis(p[4], turn) * yaw
			var shrink := 1.0 - clampf((age - land) / (gone - land), 0.0, 1.0)
			pos.y -= size.y * 0.5 * (1.0 - shrink)
			return Transform3D(b * Basis.from_scale(size * (0.35 + 0.65 * shrink)), pos)


## The crack (`f` times the size it is made for) opening, holding and fading.
func _crack(cr: MeshInstance3D, age: float, f: float) -> void:
	var open := minf(age / CRACK_OPEN_S, 1.0)
	var fade := 1.0 - clampf((age - CRACK_HOLD_S) / (CRACK_LIFE_S - CRACK_HOLD_S), 0.0, 1.0)
	(cr.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, fade * fade)
	cr.scale = Vector3.ONE * f * (0.55 + 0.45 * open)
	cr.visible = age < CRACK_LIFE_S


## Tests and the shot scripts: slams started so far, live now, and the live ones' spots (sim) and radii.
func started() -> int:
	return _started


func live() -> int:
	return _slams.size()


func spots() -> Array:
	var out := []
	for s in _slams:
		out.append([SimPlane.to_sim(s["at"]), float(s["radius"])])
	return out


func pieces_shown() -> int:
	return _shown


func highest() -> float:
	return _highest


func cracks_shown() -> int:
	return _cracks.filter(func(c: MeshInstance3D) -> bool: return c.visible).size()


## A faceted stone chunk about one unit across: two staggered rings of four corners between a low and a high point,
## each corner pushed in or out, so every chunk face is a flat facet.
static func rock_mesh() -> ArrayMesh:
	if _rock_mesh != null:
		return _rock_mesh
	var n := 4
	var lo := []
	var hi := []
	for k in n:
		var a := TAU * k / n
		var rl := 0.5 * (0.7 + 0.5 * VfxCore.h(k, 81))
		var rh := 0.4 * (0.55 + 0.6 * VfxCore.h(k, 82))
		lo.append(Vector3(cos(a) * rl, -0.2 + 0.14 * VfxCore.h(k, 83), sin(a) * rl))
		var ah := a + PI / n
		hi.append(Vector3(cos(ah) * rh, 0.14 + 0.16 * VfxCore.h(k, 84), sin(ah) * rh))
	var top := Vector3(0.14, 0.36, -0.1)
	var bottom := Vector3(-0.06, -0.34, 0.08)
	var tris := []
	for k in n:
		var l0: Vector3 = lo[k]
		var l1: Vector3 = lo[(k + 1) % n]
		var h0: Vector3 = hi[k]
		var h1: Vector3 = hi[(k + 1) % n]
		var hp: Vector3 = hi[(k + n - 1) % n]
		tris.append([l0, l1, h0])
		tris.append([hp, l0, h0])
		tris.append([h0, h1, top])
		tris.append([l1, l0, bottom])
	_rock_mesh = AvatarBase.flat_mesh(tris, Vector3.ZERO)
	return _rock_mesh


## The fractured floor, made for MADE_FOR_M (scaled per slam): a dark, ragged crater and jagged cracks branching out
## from it to the edge of the hit, tapering as they go. Flat, vertex-coloured, on the floor.
static func crack_mesh(sd: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var ring := 9
	var crater := []
	for k in ring:
		var a := TAU * k / ring
		var r := 0.95 * (0.75 + 0.45 * VfxCore.h(sd + k, 21))
		crater.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for k in ring:
		verts.append_array([Vector3.ZERO, crater[k], crater[(k + 1) % ring]])
		cols.append_array([CRATER, CRATER, CRATER])
	var branches := 8
	for b in branches:
		var a := TAU * (b + 0.6 * VfxCore.h(sd + b, 22)) / branches
		var from: Vector3 = crater[int(float(b) / branches * ring) % ring] * 0.85
		_branch(
			verts,
			cols,
			from,
			a,
			0.4,
			4,
			MADE_FOR_M * lerpf(0.85, 1.1, VfxCore.h(sd + b, 23)),
			sd + b * 7
		)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## One crack from `from` heading `ang`, `width` m wide at its root, in `steps` jagged steps out to `reach` m from the
## middle, a thinner side crack off its second step.
static func _branch(
	verts: PackedVector3Array,
	cols: PackedColorArray,
	from: Vector3,
	ang: float,
	width: float,
	steps: int,
	reach: float,
	sd: int
) -> void:
	var p := from
	var step := maxf(reach - from.length(), 0.3) / steps
	var w := width
	for k in steps:
		var a := ang + 0.7 * (VfxCore.h(sd, 30 + k) - 0.5)
		var q := p + Vector3(cos(a), 0.0, sin(a)) * step * lerpf(0.8, 1.15, VfxCore.h(sd, 40 + k))
		var w2 := w * 0.68
		var side := (q - p).normalized().cross(Vector3.UP)
		var a0 := p + side * w * 0.5
		var a1 := p - side * w * 0.5
		var b0 := q + side * w2 * 0.5
		var b1 := q - side * w2 * 0.5
		verts.append_array([a0, a1, b1, a0, b1, b0])
		for i in 6:
			cols.append(CRACK)
		if k == 1 and width > 0.08:
			var off := 0.9 if VfxCore.h(sd, 50) > 0.5 else -0.9
			_branch(verts, cols, q, a + off, w2 * 0.7, 2, q.length() + step * 1.4, sd + 101)
		p = q
		w = w2

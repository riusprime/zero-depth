class_name BossRig
extends RefCounted
## Rigs the owner's single-mesh boss models in code (PLAN v0.3.0 L13 extension): a list of bones with pivots placed
## from the mesh's geometry (measured in our facing frame: +X the front, Y up, metres) and per-vertex weights (up
## to 4 bones, normalised) that blend smoothly between neighbouring regions, so the mesh bends at a seam instead of
## tearing. Built once per boss type by BossModels; the avatar makes a Skeleton3D and a Skin from it.
## Regions (from vertex histograms of each model; evidence/BOSSES.md):
## - Stone Sentinel: torso, head and crown, left and right upper arm and forearm with fist, left and right leg.
## - Crawler Queen: body and hood, egg sac, and eight legs found as clusters of the vertices outside the body.
## - Fortress Turret: hull, main cannon, two mortar tubes, and four legs, each with an upper and a lower bone.
## - Foundry (v0.7.5 BM; owner N14: "you will have to slice foundry's legs"): the body and four legs. Below the
##   belly only the legs reach the ground; each is the vertices outside the body's middle in its corner, blended into
##   the body over the hip band, and swung from a hip found from its own foot.
## - v0.8.0 FB1, the Colossus (owner: "big stone hands"; FINAL_BOSS.md "The models"): its fists are separate pieces of
##   the mesh (no arm joins them), found here as its connected pieces (welded by position): each piece whose centre lies
##   past COLOSSUS_FIST_Z of the height to a side is that side's fist, and the small pieces between it and the body
##   (its cuff crystals: COLOSSUS_CUFF_*) go with it; the halo is the piece above COLOSSUS_HALO_Y; everything else is
##   the body, a lower `body` bone blending into a `chest` over COLOSSUS_CHEST_Y. Each fist hangs from a shoulder pivot
##   above it, so a turn swings it like an arm. The Prism and the Nemesis are one root bone (FB2 and FB3 rig them).

## The Crawler Queen's body centre (x) and its egg sac's centre (x, z), in metres.
const QUEEN_BODY_X := -0.2
const QUEEN_SAC := Vector2(-1.1, 0.0)
## The Fortress Turret's front (1) and back (-1) legs' x, in metres (its feet, from the mesh).
const TURRET_LEG_X := {1: 0.65, -1: -1.95}

## The Foundry's hip band (metres; from the vertex slices in evidence/BOSS_MODELS.md): fully leg below LEG_LOW,
## fully body above LEG_HIGH. A leg is outside the body's middle in both x and z (its inner edges, metres).
const FOUNDRY_LEG_LOW := 0.36
const FOUNDRY_LEG_HIGH := 0.54
const FOUNDRY_LEG_X := Vector2(0.22, 0.36)
const FOUNDRY_LEG_Z := Vector2(0.28, 0.40)
## The Foundry's four legs, in the order of its bones: front left, front right, back left, back right.
const FOUNDRY_LEGS: Array[StringName] = [&"leg_fl", &"leg_fr", &"leg_bl", &"leg_br"]

## v0.8.0 FB1: the Colossus's pieces, as shares of its height: a fist's centre beyond FIST_Z to a side; a cuff piece
## beyond CUFF_Z, in front of CUFF_X and between the CUFF_Y heights; the halo above HALO_Y; the chest blends in over
## CHEST_Y (± CHEST_BLEND); the shoulders (the fists' pivots) at SHOULDER_Y, SHOULDER_Z out.
const COLOSSUS_FIST_Z := 0.3
const COLOSSUS_CUFF_Z := 0.12
const COLOSSUS_CUFF_X := 0.1
const COLOSSUS_CUFF_Y := Vector2(0.3, 0.6)
const COLOSSUS_HALO_Y := 0.86
const COLOSSUS_CHEST_Y := 0.5
const COLOSSUS_CHEST_BLEND := 0.08
const COLOSSUS_SHOULDER_Y := 0.72
const COLOSSUS_SHOULDER_Z := 0.3

## How many rigs were built (tests check it is once per boss type).
static var builds := 0

## Bone records: [name, parent index, pivot (Vector3, in the mesh's frame)].
var bones: Array = []
## Four bone indices and four weights per vertex.
var bone_ids := PackedInt32Array()
var weights := PackedFloat32Array()


static func build(
	id: StringName, verts: PackedVector3Array, indices: PackedInt32Array = PackedInt32Array()
) -> BossRig:
	builds += 1
	var r := BossRig.new()
	match id:
		&"final_boss_colossus":  # v0.8.0 FB1
			r._colossus(verts, indices)
		&"stone_sentinel":
			r._sentinel(verts)
		&"crawler_queen":
			r._queen(verts)
		&"fortress_turret":
			r._turret(verts)
		&"foundry":
			r._foundry(verts)
		_:
			r.bones = [[&"root", -1, Vector3.ZERO]]
			for v in verts:
				r._store({0: 1.0})
	return r


func index_of(bone: StringName) -> int:
	for k in bones.size():
		if bones[k][0] == bone:
			return k
	return -1


func _add(bone: StringName, parent: StringName, pivot: Vector3) -> int:
	bones.append([bone, index_of(parent) if parent != &"" else -1, pivot])
	return bones.size() - 1


## Keeps the 4 strongest weights of a vertex and normalises them.
func _store(scores: Dictionary) -> void:
	var pairs := []
	for k in scores:
		if scores[k] > 0.0001:
			pairs.append([scores[k], k])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	pairs = pairs.slice(0, 4)
	var total := 0.0
	for p in pairs:
		total += p[0]
	for j in 4:
		if j < pairs.size() and total > 0.0:
			bone_ids.append(pairs[j][1])
			weights.append(pairs[j][0] / total)
		else:
			bone_ids.append(0 if j > 0 or total > 0.0 else 0)
			weights.append(0.0 if j > 0 or total > 0.0 else 1.0)


static func _ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x) if a < b else 1.0 - smoothstep(b, a, x)


# --- Stone Sentinel ---------------------------------------------------------------------------------------------


func _sentinel(verts: PackedVector3Array) -> void:
	var root := _add(&"root", &"", Vector3.ZERO)
	var torso := _add(&"torso", &"root", Vector3(0, 0.9, 0))
	var head := _add(&"head", &"torso", Vector3(0.2, 1.95, 0))
	var upper := {}
	var fore := {}
	var legs := {}
	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		upper[side] = _add(StringName("arm_" + tag), &"torso", Vector3(0, 1.62, side * 1.05))
		fore[side] = _add(
			StringName("fist_" + tag), StringName("arm_" + tag), Vector3(0.05, 1.08, side * 1.35)
		)
		legs[side] = _add(StringName("leg_" + tag), &"root", Vector3(0, 0.55, side * 0.55))
	for v in verts:
		var az := absf(v.z)
		var side := -1 if v.z < 0.0 else 1
		# The arms are everything beyond the torso's sides; low down the feet reach a little further out.
		var lo := lerpf(1.12, 0.95, smoothstep(0.45, 0.8, v.y))
		var arm := _ss(lo, lo + 0.18, az)
		var lower := _ss(1.3, 1.0, v.y)
		var rest := 1.0 - arm
		var crown := _ss(1.82, 2.08, v.y) * rest
		var leg := _ss(0.66, 0.42, v.y) * rest * (1.0 - _ss(1.82, 2.08, v.y))
		var leg_l := leg * _ss(0.12, -0.12, v.z)
		var s := {
			upper[side]: arm * (1.0 - lower),
			fore[side]: arm * lower,
			head: crown,
			legs[-1]: leg_l,
			legs[1]: leg - leg_l,
		}
		s[torso] = maxf(0.0, rest - crown - leg)
		s[root] = 0.0
		_store(s)


# --- Crawler Queen ----------------------------------------------------------------------------------------------


## How far a point (in x/z) is outside the body and the sac: under 1 inside, 1 on the edge.
static func _queen_out(v: Vector3) -> float:
	var e := pow((v.x - QUEEN_BODY_X) / 1.75, 2.0) + pow(v.z / 0.85, 2.0)
	var d := Vector2(v.x, v.z).distance_squared_to(QUEEN_SAC)
	return minf(e, d)


func _queen(verts: PackedVector3Array) -> void:
	_add(&"root", &"", Vector3.ZERO)
	var body := _add(&"body", &"root", Vector3(0.3, 0.9, 0))
	var sac := _add(&"sac", &"body", Vector3(-0.85, 1.05, 0))
	# Legs: the far-out vertices (low enough to be legs), clustered by their angle round the body, 4 a side.
	var centres := {}
	for side in [-1, 1]:
		var angs := PackedFloat32Array()
		for v in verts:
			if v.y < 1.4 and _queen_out(v) > 1.4 and (v.z > 0.0) == (side > 0):
				angs.append(atan2(v.z, v.x - QUEEN_BODY_X))
		centres[side] = _kmeans(angs, 4)
	var leg_bone := {}
	for side in [-1, 1]:
		var cs: PackedFloat32Array = centres[side]
		for k in cs.size():
			# The hip: the mean of this leg's vertices nearest the body.
			var near := []
			for v in verts:
				if v.y < 1.4 and (v.z > 0.0) == (side > 0):
					var u := _queen_out(v)
					if u > 1.0 and u < 1.5 and _nearest(cs, atan2(v.z, v.x - QUEEN_BODY_X)) == k:
						near.append(v)
			var hip := Vector3(QUEEN_BODY_X, 0.95, 0) + Vector3(cos(cs[k]), 0, sin(cs[k])) * 0.9
			if not near.is_empty():
				var sum := Vector3.ZERO
				for p: Vector3 in near:
					sum += p
				hip = sum / near.size()
				hip.y = maxf(hip.y, 0.8)
			var tag := "%s%d" % ["l" if side < 0 else "r", k]
			leg_bone[[side, k]] = _add(StringName("leg_" + tag), &"body", hip)
	for v in verts:
		var u := _queen_out(v)
		var leg := _ss(1.0, 1.35, u) * _ss(1.55, 1.3, v.y)
		var s := {}
		if leg > 0.0:
			var side := -1 if v.z < 0.0 else 1
			var k := _nearest(centres[side], atan2(v.z, v.x - QUEEN_BODY_X))
			s[leg_bone[[side, k]]] = leg
		var rest := 1.0 - leg
		var back := _ss(-0.55, -0.9, v.x) * rest
		s[sac] = back
		s[body] = rest - back
		_store(s)


## 1-D k-means of angles (radians, all on one side, so no wrap-around): k centres, sorted.
static func _kmeans(vals: PackedFloat32Array, k: int) -> PackedFloat32Array:
	var sorted := vals.duplicate()
	sorted.sort()
	var cs := PackedFloat32Array()
	if sorted.is_empty():
		for j in k:
			cs.append(0.0)
		return cs
	for j in k:
		cs.append(sorted[int((j + 0.5) / k * (sorted.size() - 1))])
	for _iter in 30:
		var sums := PackedFloat32Array()
		var counts := PackedInt32Array()
		sums.resize(k)
		counts.resize(k)
		for x in sorted:
			var n := _nearest(cs, x)
			sums[n] += x
			counts[n] += 1
		for j in k:
			if counts[j] > 0:
				cs[j] = sums[j] / counts[j]
	cs.sort()
	return cs


static func _nearest(cs: PackedFloat32Array, x: float) -> int:
	var best := 0
	for j in cs.size():
		if absf(cs[j] - x) < absf(cs[best] - x):
			best = j
	return best


## The legs' angles round the body (radians from +X toward +Z), for tests and the pose.
func leg_angle(bone: int) -> float:
	var p: Vector3 = bones[bone][2]
	return atan2(p.z, p.x - QUEEN_BODY_X)


# --- Fortress Turret --------------------------------------------------------------------------------------------


func _turret(verts: PackedVector3Array) -> void:
	var root := _add(&"root", &"", Vector3.ZERO)
	var hull := _add(&"hull", &"root", Vector3(-0.6, 1.3, 0))
	var cannon := _add(&"cannon", &"hull", Vector3(0.95, 1.75, 0))
	var mortar := {}
	var upper := {}
	var lower := {}
	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"
		mortar[side] = _add(StringName("mortar_" + tag), &"hull", Vector3(-1.75, 1.95, side * 0.32))
		for fb in [1, -1]:
			var lt := "%s%s" % ["f" if fb > 0 else "b", tag]
			var x: float = TURRET_LEG_X[fb]
			upper[[fb, side]] = _add(
				StringName("thigh_" + lt), &"root", Vector3(x, 1.2, side * 0.7)
			)
			lower[[fb, side]] = _add(
				StringName("shin_" + lt), StringName("thigh_" + lt), Vector3(x, 0.65, side * 1.1)
			)
	for v in verts:
		var side := -1 if v.z < 0.0 else 1
		var leg := _ss(0.5, 0.72, absf(v.z)) * _ss(1.45, 1.22, v.y)
		var front := _ss(-0.8, -0.5, v.x)
		var low := _ss(0.78, 0.55, v.y)
		var gun := _ss(0.85, 1.05, v.x) * _ss(1.35, 1.5, v.y) * (1.0 - leg)
		var tube := _ss(-1.45, -1.65, v.x) * _ss(1.75, 1.92, v.y) * (1.0 - leg)
		var s := {}
		s[upper[[1, side]]] = leg * front * (1.0 - low)
		s[lower[[1, side]]] = leg * front * low
		s[upper[[-1, side]]] = leg * (1.0 - front) * (1.0 - low)
		s[lower[[-1, side]]] = leg * (1.0 - front) * low
		s[cannon] = gun
		var tube_l := tube * _ss(0.12, -0.12, v.z)
		s[mortar[-1]] = tube_l
		s[mortar[1]] = tube - tube_l
		s[hull] = maxf(0.0, 1.0 - leg - gun - tube)
		s[root] = 0.0
		_store(s)


# --- Foundry ----------------------------------------------------------------------------------------------------


## 0..1: how much of a vertex is leg (outside the body's middle, below the hip band).
static func _foundry_leg(v: Vector3) -> float:
	return (
		_ss(FOUNDRY_LEG_HIGH, FOUNDRY_LEG_LOW, v.y)
		* _ss(FOUNDRY_LEG_X.x, FOUNDRY_LEG_X.y, absf(v.x))
		* _ss(FOUNDRY_LEG_Z.x, FOUNDRY_LEG_Z.y, absf(v.z))
	)


## Which leg a vertex's corner is (an index into FOUNDRY_LEGS).
static func _foundry_corner(v: Vector3) -> int:
	return (0 if v.x >= 0.0 else 2) + (0 if v.z < 0.0 else 1)


func _foundry(verts: PackedVector3Array) -> void:
	var root := _add(&"root", &"", Vector3.ZERO)
	var body := _add(&"body", &"root", Vector3(0, 1.1, 0))
	# Each hip: above the middle of its foot (the leg's vertices near the ground), at the top of the hip band.
	var sums := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var counts := [0, 0, 0, 0]
	for v in verts:
		if v.y < FOUNDRY_LEG_LOW and _foundry_leg(v) > 0.99:
			var c := _foundry_corner(v)
			sums[c] += v
			counts[c] += 1
	var legs := []
	for c in 4:
		var foot: Vector3 = (
			sums[c] / counts[c]
			if counts[c] > 0
			else Vector3(0.75 if c < 2 else -0.75, 0, -0.75 if c % 2 == 0 else 0.75)
		)
		legs.append(_add(FOUNDRY_LEGS[c], &"root", Vector3(foot.x, FOUNDRY_LEG_HIGH, foot.z)))
	for v in verts:
		var leg := _foundry_leg(v)
		var s := {}
		s[legs[_foundry_corner(v)]] = leg
		s[body] = 1.0 - leg
		s[root] = 0.0
		_store(s)


# --- The Colossus (v0.8.0 FB1) ------------------------------------------------------------------------------------


## Each vertex's piece: the connected pieces of the mesh, vertices welded where they share a position (a mesh splits
## a vertex at a UV seam or a hard edge). Pieces are numbered in vertex order.
static func pieces(verts: PackedVector3Array, indices: PackedInt32Array) -> PackedInt32Array:
	var weld := {}
	var parent := PackedInt32Array()
	parent.resize(verts.size())
	for k in verts.size():
		var key := Vector3i((verts[k] * 10000.0).round())
		if weld.has(key):
			parent[k] = weld[key]
		else:
			weld[key] = k
			parent[k] = k
	for t in range(0, indices.size() - 2, 3):
		var a := _root_of(parent, indices[t])
		for j in [1, 2]:
			var b := _root_of(parent, indices[t + j])
			if a != b:
				parent[b] = a
	var out := PackedInt32Array()
	out.resize(verts.size())
	var ids := {}
	for k in verts.size():
		var r := _root_of(parent, k)
		if not ids.has(r):
			ids[r] = ids.size()
		out[k] = ids[r]
	return out


static func _root_of(parent: PackedInt32Array, k: int) -> int:
	var r := k
	while parent[r] != r:
		r = parent[r]
	while parent[k] != r:
		var nxt := parent[k]
		parent[k] = r
		k = nxt
	return r


## Which part each piece is: 0 the body, 1 the left fist (-Z), 2 the right fist (+Z), 3 the halo.
static func colossus_parts(verts: PackedVector3Array, piece: PackedInt32Array) -> PackedInt32Array:
	var n := 0
	for p in piece:
		n = maxi(n, p + 1)
	var sums: Array[Vector3] = []
	var counts := PackedInt32Array()
	sums.resize(n)
	counts.resize(n)
	var top := 0.0
	for k in verts.size():
		sums[piece[k]] += verts[k]
		counts[piece[k]] += 1
		top = maxf(top, verts[k].y)
	var h := maxf(top, 0.0001)
	var out := PackedInt32Array()
	out.resize(n)
	for p in n:
		var c := sums[p] / maxf(1.0, counts[p])
		var side := 1 if c.z < 0.0 else 2
		if absf(c.z) > COLOSSUS_FIST_Z * h:
			out[p] = side
		elif (
			absf(c.z) > COLOSSUS_CUFF_Z * h
			and c.x > COLOSSUS_CUFF_X * h
			and c.y > COLOSSUS_CUFF_Y.x * h
			and c.y < COLOSSUS_CUFF_Y.y * h
		):
			out[p] = side
		elif c.y > COLOSSUS_HALO_Y * h:
			out[p] = 3
		else:
			out[p] = 0
	return out


func _colossus(verts: PackedVector3Array, indices: PackedInt32Array) -> void:
	var top := 0.0
	for v in verts:
		top = maxf(top, v.y)
	var h := maxf(top, 0.0001)
	var root := _add(&"root", &"", Vector3.ZERO)
	var body := _add(&"body", &"root", Vector3(0, 0.3 * h, 0))
	var chest := _add(&"chest", &"body", Vector3(0, COLOSSUS_CHEST_Y * h, 0))
	var halo := _add(&"halo", &"chest", Vector3(0, 0.93 * h, 0))
	var sz := COLOSSUS_SHOULDER_Z * h
	var fist_l := _add(&"fist_l", &"chest", Vector3(0, COLOSSUS_SHOULDER_Y * h, -sz))
	var fist_r := _add(&"fist_r", &"chest", Vector3(0, COLOSSUS_SHOULDER_Y * h, sz))
	var piece := pieces(verts, indices)
	var part := colossus_parts(verts, piece)
	var lo := (COLOSSUS_CHEST_Y - COLOSSUS_CHEST_BLEND) * h
	var hi := (COLOSSUS_CHEST_Y + COLOSSUS_CHEST_BLEND) * h
	for k in verts.size():
		var s := {root: 0.0}
		match part[piece[k]]:
			1:
				s[fist_l] = 1.0
			2:
				s[fist_r] = 1.0
			3:
				s[halo] = 1.0
			_:
				var up := smoothstep(lo, hi, verts[k].y)
				s[chest] = up
				s[body] = 1.0 - up
		_store(s)

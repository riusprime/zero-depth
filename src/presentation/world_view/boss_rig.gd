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

## The Crawler Queen's body centre (x) and its egg sac's centre (x, z), in metres.
const QUEEN_BODY_X := -0.2
const QUEEN_SAC := Vector2(-1.1, 0.0)
## The Fortress Turret's front (1) and back (-1) legs' x, in metres (its feet, from the mesh).
const TURRET_LEG_X := {1: 0.65, -1: -1.95}

## How many rigs were built (tests check it is once per boss type).
static var builds := 0

## Bone records: [name, parent index, pivot (Vector3, in the mesh's frame)].
var bones: Array = []
## Four bone indices and four weights per vertex.
var bone_ids := PackedInt32Array()
var weights := PackedFloat32Array()


static func build(id: StringName, verts: PackedVector3Array) -> BossRig:
	builds += 1
	var r := BossRig.new()
	match id:
		&"stone_sentinel":
			r._sentinel(verts)
		&"crawler_queen":
			r._queen(verts)
		&"fortress_turret":
			r._turret(verts)
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

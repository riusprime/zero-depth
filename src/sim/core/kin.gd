class_name Kin
extends RefCounted
## Deterministic directions without trig (SIM_CONTRACTS §6). Angles are ints, 4096 per turn,
## 0 = +X, counter-clockwise. Only + - * / and sqrt are used on floats.

static var _cos := _decode(TrigLut.COS_HEX)
static var _sin := _decode(TrigLut.SIN_HEX)


## The unit vector for an angle in 1/4096 turns.
static func dir(angle: int) -> Vector2:
	var a := angle & 4095
	var quadrant := a >> 10
	var b := a & 1023
	var c: float
	var s: float
	if b <= 512:
		c = _cos[b]
		s = _sin[b]
	else:
		c = _sin[1024 - b]
		s = _cos[1024 - b]
	match quadrant:
		0:
			return Vector2(c, s)
		1:
			return Vector2(-s, c)
		2:
			return Vector2(-c, -s)
		_:
			return Vector2(s, -c)


## The nearest angle (1/4096 turns) of a vector; 0 for the zero vector. Replaces atan2.
static func angle_of(v: Vector2) -> int:
	var x := float(v.x)
	var y := float(v.y)
	var ax := absf(x)
	var ay := absf(y)
	if ax == 0.0 and ay == 0.0:
		return 0
	var swapped := ay > ax
	if swapped:
		var t := ax
		ax = ay
		ay = t
	var base := _octant_index(ax, ay)
	var a1 := 1024 - base if swapped else base
	var a: int
	if x >= 0.0 and y >= 0.0:
		a = a1
	elif x < 0.0 and y >= 0.0:
		a = 2048 - a1
	elif x < 0.0:
		a = 2048 + a1
	else:
		a = 4096 - a1
	return a & 4095


## Length of a vector using only sqrt.
static func length(v: Vector2) -> float:
	return sqrt(float(v.x) * v.x + float(v.y) * v.y)


## For ax >= ay >= 0: the index i in [0, 512] whose direction (cos i, sin i) is closest to (ax, ay).
static func _octant_index(ax: float, ay: float) -> int:
	var lo := 0
	var hi := 512
	while lo < hi:  # smallest i with sin(i)*ax >= cos(i)*ay
		var mid := (lo + hi) >> 1
		if _sin[mid] * ax >= _cos[mid] * ay:
			hi = mid
		else:
			lo = mid + 1
	if lo == 0:
		return 0
	var err_hi := absf(_sin[lo] * ax - _cos[lo] * ay)
	var err_lo := absf(_sin[lo - 1] * ax - _cos[lo - 1] * ay)
	return lo - 1 if err_lo < err_hi else lo


static func _decode(hex_chunks: Array[String]) -> PackedFloat32Array:
	return "".join(hex_chunks).hex_decode().to_float32_array()

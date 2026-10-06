class_name SimPlane
extends RefCounted
## Sim plane (x, y) in metres <-> 3D (x, height, -y) (ARCHITECTURE §6).

## Height of the "core": mouse rays meet the plane here and projectiles are drawn here.
const CORE_HEIGHT := 0.5


static func to_3d(p: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(p.x, height, -p.y)


static func to_sim(v: Vector3) -> Vector2:
	return Vector2(v.x, -v.z)


## Rotation about Y (radians) that turns 3D +X to the sim direction at `angle` (1/4096 turn).
static func yaw_of(angle: int) -> float:
	return TAU * float(angle) / 4096.0

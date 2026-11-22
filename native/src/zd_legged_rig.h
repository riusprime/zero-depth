#pragma once
// LeggedRig (src/presentation/world_view/legged_rig.gd) on plain numbers: the legs posed by reach, a foot's stride
// cycle, a clip's clock, the idle clips' pseudo-random motions and the facing's turn rate, ported line by line in the
// same order and float width (a GDScript float is a double; a Vector2/Vector3/Basis component a float, every
// operation on them a float one, the engine's float sine, cosine and arc tangent). Presentation only.

#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace zd {
namespace rig {

// The engine's Vector2.angle() (its float atan2) and Vector2.rotated (its float sine and cosine).
float angle(const godot::Vector2 &v);
godot::Vector2 rotated(const godot::Vector2 &v, float by);

// LeggedRig.heading: a leg's turn about the vertical from +X to its rest foot's direction from its hip.
double heading(const godot::Vector3 &hip, const godot::Vector3 &tip);

// LeggedRig.reach: legs 0..n-1 reach for `want` under the body transform `body`; writes d[leg0 + 3 j + 0 / 1 / 2]
// (yaw, hip turn, knee turn).
void reach(float *d, int leg0, const godot::Transform3D &body, const godot::Vector3 *hips,
		const godot::Vector3 *knees, const godot::Vector3 *tips, const godot::Vector3 *want, int n);

// LeggedRig.leg_cycle: (the sweep 1 .. -1, the lift 0..1) at q of the stride, `duty` of it on the ground.
godot::Vector2 leg_cycle(double q, double duty);

// LeggedRig.clip: a clip's clock (-1 not playing) on by dt, back to -1 at its end.
double clip(double t, double dt, double length);

// LeggedRig.scan, twitch, hash01.
double scan(double t, double every, double seed_off);
double twitch(double t, double every, double seed_off);
double hash01(double x);

// LeggedRig.replant: the leg re-planted now (or -1) in `leg`, how far up its step is as the return value.
double replant(double t, double every, int legs, int &leg);

// LeggedRig.turning: the facing's turn rate smoothed by `rate`.
double turning(double omega, double fy, double last, bool have, double dt, double rate);

} // namespace rig
} // namespace zd

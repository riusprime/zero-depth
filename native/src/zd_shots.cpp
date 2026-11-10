#include "zd_world.h"

#include <cmath>

using namespace godot;

namespace zd {

namespace {

// Collide.sweep_vs_circle: the first t in [0, 1] where the segment a..b thickened by r touches the circle (c, cr);
// 0 when it starts inside, NO_HIT otherwise. The vectors in single precision and the products in double, as the
// GDScript function computes them (a Vector2 holds floats, its scalars are doubles).
double sweep_vs_circle(float ax, float ay, float bx, float by, float r, float cx, float cy, float cr) {
	const float dx = bx - ax, dy = by - ay;
	const float fx = ax - cx, fy = ay - cy;
	const double rr = double(r) + double(cr);
	const double qa = double(dx) * dx + double(dy) * dy;
	const double qc = double(fx) * fx + double(fy) * fy - rr * rr;
	if (qc <= 0.0) {
		return 0.0;
	}
	if (qa == 0.0) {
		return NO_HIT;
	}
	const double qb = 2.0 * (double(fx) * dx + double(fy) * dy);
	const double disc = qb * qb - 4.0 * qa * qc;
	if (disc < 0.0) {
		return NO_HIT;
	}
	const double t = (-qb - std::sqrt(disc)) / (2.0 * qa);
	return (t >= 0.0 && t <= 1.0) ? t : NO_HIT;
}

} // namespace

float ShotsScratch::sweep(WallGrid &walls, float ax, float ay, float vx, float vy, float r, int32_t team,
		bool walls_only, int &actor, int &wall) {
	const float ex = ax + vx, ey = ay + vy;
	// The segment's box grown by its radius (walls and bodies count their own extent).
	const float x0 = std::min(ax, ex) - r, x1 = std::max(ax, ex) + r;
	const float y0 = std::min(ay, ey) - r, y1 = std::max(ay, ey) + r;
	double best = double(NONE);
	actor = -1;
	wall = -1;
	const Box *base = walls.boxes.data();
	walls.walls_in(x0, y0, x1, y1, [&](const Box &b) {
		const float t = sweep_vs_obb(ax, ay, ex, ey, r, b);
		if (t < 0.0f) {
			return;
		}
		const int k = int(&b - base);
		// The grid visits walls in its own order: a tie keeps the lower wall index.
		if (double(t) < best || (double(t) == best && k < wall)) {
			best = double(t);
			wall = k;
		}
	});
	if (!walls_only && bodies > 0) {
		const float g = grid.cell * 0.5f; // A small body's centre lies within its radius (at most cell / 2)
		grid.query_rect(x0 - g, y0 - g, x1 + g, y1 + g, cand);
		for (const int k : cand) {
			if (bteam[k] == team || bdead[k] == 1) {
				continue;
			}
			const double reach = double(br[k]) + 0.001;
			if (double(bx[k]) + reach < double(x0) || double(bx[k]) - reach > double(x1) ||
					double(by[k]) + reach < double(y0) || double(by[k]) - reach > double(y1)) {
				continue;
			}
			const double t = sweep_vs_circle(ax, ay, ex, ey, r, bx[k], by[k], br[k]);
			// Ascending bodies and a strict test: a tie keeps the wall, else the lower body.
			if (t >= 0.0 && t < best) {
				best = t;
				actor = k;
			}
		}
	}
	if (actor >= 0) {
		wall = -1; // The body came first: the contact is the body's
	}
	return best <= 1.0 ? float(best) : NONE;
}

int ZdWorld::sweep_shots(Object *projectiles, Object *actors, const PackedByteArray &skip,
		const PackedByteArray &walls_only) {
	ShotsScratch &s = shots_;
	s.events.clear();
	s.event_t.clear();
	if (projectiles == nullptr || actors == nullptr) {
		return -1;
	}
	const PackedFloat32Array px = cols::f32(projectiles, names_.pos_x);
	const PackedFloat32Array py = cols::f32(projectiles, names_.pos_y);
	const PackedFloat32Array vx = cols::f32(projectiles, names_.vel_x);
	const PackedFloat32Array vy = cols::f32(projectiles, names_.vel_y);
	const PackedFloat32Array pr = cols::f32(projectiles, names_.radius);
	const PackedInt32Array team = cols::i32(projectiles, names_.team);
	const PackedInt32Array life = cols::i32(projectiles, names_.life);
	const int64_t n = px.size();
	if (py.size() != n || vx.size() != n || vy.size() != n || pr.size() != n || team.size() != n ||
			life.size() != n || (!skip.is_empty() && skip.size() != n) ||
			(!walls_only.is_empty() && walls_only.size() != n)) {
		return -1;
	}
	if (n == 0) {
		return 0;
	}
	const PackedFloat32Array ax = cols::f32(actors, names_.pos_x);
	const PackedFloat32Array ay = cols::f32(actors, names_.pos_y);
	const PackedFloat32Array ar = cols::f32(actors, names_.radius);
	const PackedInt32Array at = cols::i32(actors, names_.teams);
	const PackedInt32Array ad = cols::i32(actors, names_.dead);
	const int64_t m = ax.size();
	if (ay.size() != m || ar.size() != m || at.size() != m || ad.size() != m) {
		return -1;
	}
	s.bx = ax.ptr();
	s.by = ay.ptr();
	s.br = ar.ptr();
	s.bteam = at.ptr();
	s.bdead = ad.ptr();
	s.bodies = int(m);
	s.grid.build(s.bx, s.by, s.br, s.bodies, ShotsScratch::BIG_R);

	cols::load(px, s.out_x);
	cols::load(py, s.out_y);
	cols::load(life, s.out_life);
	const uint8_t *sk = skip.is_empty() ? nullptr : skip.ptr();
	const uint8_t *wo = walls_only.is_empty() ? nullptr : walls_only.ptr();
	const float *pxp = px.ptr(), *pyp = py.ptr(), *vxp = vx.ptr(), *vyp = vy.ptr(), *prp = pr.ptr();
	const int32_t *tp = team.ptr();
	bool moved = false;
	for (int64_t i = 0; i < n; i++) {
		if (sk != nullptr && sk[i] != 0) { // A Mine disc holding: no sweep, GDScript runs its pulse
			s.events.insert(s.events.end(), { ShotsScratch::HOLD, int32_t(i), -1, -1 });
			s.event_t.push_back(ShotsScratch::NONE);
			continue;
		}
		int actor = -1, wall = -1;
		const float t = s.sweep(walls_, pxp[i], pyp[i], vxp[i], vyp[i], prp[i], tp[i], wo != nullptr && wo[i] != 0,
				actor, wall);
		if (t <= 1.0f) {
			s.events.insert(s.events.end(), { ShotsScratch::CONTACT, int32_t(i), actor, wall });
			s.event_t.push_back(t);
			continue;
		}
		s.out_x[size_t(i)] = pxp[i] + vxp[i];
		s.out_y[size_t(i)] = pyp[i] + vyp[i];
		s.out_life[size_t(i)] -= 1;
		moved = true;
		if (s.out_life[size_t(i)] <= 0) {
			s.events.insert(s.events.end(), { ShotsScratch::END, int32_t(i), -1, -1 });
			s.event_t.push_back(ShotsScratch::NONE);
		}
	}
	if (moved) {
		cols::put_f32(projectiles, names_.pos_x, s.out_x);
		cols::put_f32(projectiles, names_.pos_y, s.out_y);
		cols::put_i32(projectiles, names_.life, s.out_life);
	}
	s.bx = s.by = s.br = nullptr;
	s.bteam = s.bdead = nullptr;
	s.bodies = 0;
	return int(s.event_t.size());
}

PackedInt32Array ZdWorld::shot_events() const {
	PackedInt32Array out;
	out.resize(int64_t(shots_.events.size()));
	if (!shots_.events.empty()) {
		std::copy(shots_.events.begin(), shots_.events.end(), out.ptrw());
	}
	return out;
}

PackedFloat32Array ZdWorld::shot_t() const {
	PackedFloat32Array out;
	out.resize(int64_t(shots_.event_t.size()));
	if (!shots_.event_t.empty()) {
		std::copy(shots_.event_t.begin(), shots_.event_t.end(), out.ptrw());
	}
	return out;
}

PackedFloat32Array ZdWorld::sweep_one(Object *projectiles, Object *actors, int row, bool walls_only) {
	PackedFloat32Array out;
	out.resize(3);
	out.set(0, ShotsScratch::NONE);
	out.set(1, -1.0f);
	out.set(2, -1.0f);
	if (projectiles == nullptr || actors == nullptr) {
		return out;
	}
	const PackedFloat32Array px = cols::f32(projectiles, names_.pos_x);
	const PackedFloat32Array py = cols::f32(projectiles, names_.pos_y);
	const PackedFloat32Array vx = cols::f32(projectiles, names_.vel_x);
	const PackedFloat32Array vy = cols::f32(projectiles, names_.vel_y);
	const PackedFloat32Array pr = cols::f32(projectiles, names_.radius);
	const PackedInt32Array team = cols::i32(projectiles, names_.team);
	if (row < 0 || row >= px.size() || py.size() != px.size() || vx.size() != px.size() ||
			vy.size() != px.size() || pr.size() != px.size() || team.size() != px.size()) {
		return out;
	}
	// The bodies as they stand now (a hit earlier in the phase may have killed or pushed one).
	ShotsScratch &s = shots_;
	const PackedFloat32Array ax = cols::f32(actors, names_.pos_x);
	const PackedFloat32Array ay = cols::f32(actors, names_.pos_y);
	const PackedFloat32Array ar = cols::f32(actors, names_.radius);
	const PackedInt32Array at = cols::i32(actors, names_.teams);
	const PackedInt32Array ad = cols::i32(actors, names_.dead);
	const int64_t m = ax.size();
	if (ay.size() != m || ar.size() != m || at.size() != m || ad.size() != m) {
		return out;
	}
	s.bx = ax.ptr();
	s.by = ay.ptr();
	s.br = ar.ptr();
	s.bteam = at.ptr();
	s.bdead = ad.ptr();
	s.bodies = int(m);
	s.grid.build(s.bx, s.by, s.br, s.bodies, ShotsScratch::BIG_R);
	int actor = -1, wall = -1;
	const float t = s.sweep(walls_, px[row], py[row], vx[row], vy[row], pr[row], team[row], walls_only, actor, wall);
	s.bx = s.by = s.br = nullptr;
	s.bteam = s.bdead = nullptr;
	s.bodies = 0;
	out.set(0, t);
	out.set(1, float(actor));
	out.set(2, float(wall));
	return out;
}

} // namespace zd

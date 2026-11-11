#include "zd_strike.h"

#include <cstring>

#include <godot_cpp/core/class_db.hpp>

#include "zd_ai.h"
#include "zd_kinds.h"
#include "zd_world.h"

using namespace godot;

namespace zd {

namespace {

constexpr int32_t SPELL_RUNE = 2; // EnemyAi.Spell.RUNE

// Whether a wall touches the segment a..b thickened by r (World.walls_along's reach of r x 1.5, then the sweep).
bool wall_between(WallGrid &walls, float ax, float ay, float bx, float by, float r) {
	bool hit = false;
	const float m = r * 1.5f;
	walls.walls_in(std::min(ax, bx) - m, std::min(ay, by) - m, std::max(ax, bx) + m, std::max(ay, by) + m,
			[&](const Box &b) {
				if (!hit && sweep_vs_obb(ax, ay, bx, by, r, b) >= 0.0f) {
					hit = true;
				}
			});
	return hit;
}

// EnemyAi.clear_run: how far a circle of radius r goes from (fx, fy) along `angle`, up to `length`, before a wall.
float clear_run(WallGrid &walls, const Trig &trig, float fx, float fy, int angle, float length, float r) {
	float dx, dy;
	trig.dir(angle, dx, dy);
	const float tx = fx + dx * length;
	const float ty = fy + dy * length;
	float best = 1.0f;
	const float m = r * 1.5f;
	walls.walls_in(std::min(fx, tx) - m, std::min(fy, ty) - m, std::max(fx, tx) + m, std::max(fy, ty) + m,
			[&](const Box &b) {
				const float hit = sweep_vs_obb(fx, fy, tx, ty, r, b);
				if (hit >= 0.0f && hit < best) {
					best = hit;
				}
			});
	return length * best;
}

// AttackShapes.lane: from (sx, sy), `len` metres along `angle`, `half_w` to each side (Obb.make's box).
Box lane(const Trig &trig, float sx, float sy, int angle, float len, float half_w) {
	Box b;
	trig.dir(angle & 4095, b.ux, b.uy);
	b.vx = -b.uy;
	b.vy = b.ux;
	const float h = len * 0.5f;
	b.cx = sx + b.ux * h;
	b.cy = sy + b.uy * h;
	b.hx = h;
	b.hy = half_w;
	const float ex = std::fabs(b.ux) * b.hx + std::fabs(b.vx) * b.hy;
	const float ey = std::fabs(b.uy) * b.hx + std::fabs(b.vy) * b.hy;
	b.x0 = b.cx - ex;
	b.y0 = b.cy - ey;
	b.x1 = b.cx + ex;
	b.y1 = b.cy + ey;
	return b;
}

// Collide.circle_vs_obb(...) != Vector2.ZERO: the circle touches the box.
bool circle_touches(float px, float py, float r, const Box &b) {
	float ox, oy;
	circle_vs_obb(px, py, r, b, ox, oy);
	return ox != 0.0f || oy != 0.0f;
}

// AttackShapes.disc_touches: a circle (px, py, r) touches the disc at (cx, cy) of `radius`.
bool disc_touches(float cx, float cy, float radius, float px, float py, float r) {
	return length(px - cx, py - cy) <= double(radius) + double(r);
}

// EnemyAi.pattern_of: the pattern slot an attack fires (the Arc Caster's by its spell, the others' first); -1 none.
int pattern_slot(const int32_t *ri, int32_t pick) {
	const int k = (ri[kt::K_FLAGS] & kt::SPELLS) != 0 ? pick : 0;
	if (k < 0 || k >= ri[kt::K_PATTERNS] || k >= kt::MAX_PATTERNS) {
		return -1;
	}
	return ri[kt::K_PATTERN + k * kt::PATTERN_KI + kt::P_HAS] != 0 ? k : -1;
}

// BulletPatterns.wave_at: the wave a pattern fires on its active tick st, or -1.
int wave_at(const int32_t *pi, int st) {
	const int gap = std::max(1, int(pi[kt::P_GAP]));
	const int t = st - pi[kt::P_LOB];
	if (t < 0 || t % gap != 0) {
		return -1;
	}
	const int k = t / gap;
	return k < pi[kt::P_WAVES] ? k : -1;
}

// EnemyAi.burst_angle: shot k of a Needle's burst, the first down the middle, then one to each side.
int burst_angle(int aim, int k, int spread) {
	const int off = (k + 1) / 2 * (k % 2 == 1 ? 1 : -1);
	return (aim + off * spread) & 4095;
}

} // namespace

int ZdWorld::strike(Object *actors, const PackedFloat32Array &hero) {
	StrikeScratch &s = strike_;
	s.out_i.clear();
	s.out_f.clear();
	if (actors == nullptr || !trig_.ready || kinds_.ki != kt::KI || kinds_.kf != kt::KF ||
			kinds_.tuning.size() < size_t(kt::TUNING) || hero.size() < HERO_SIZE) {
		return -1;
	}
	const float *h = hero.ptr();
	if (h[H_DEAD] != 0.0f) {
		return 0; // Every table row's strike waits on a live hero
	}
	const float hx = h[H_X], hy = h[H_Y], hr = h[H_RADIUS];
	const PackedInt32Array c_kinds = cols::i32(actors, names_.kinds);
	const PackedInt32Array c_state = cols::i32(actors, names_.state);
	const PackedInt32Array c_st = cols::i32(actors, names_.state_t);
	const PackedInt32Array c_cd = cols::i32(actors, names_.cd);
	const PackedInt32Array c_fire = cols::i32(actors, names_.fire_cd);
	const PackedInt32Array c_frozen = cols::i32(actors, names_.frozen_t);
	const PackedInt32Array c_dead = cols::i32(actors, names_.dead);
	const PackedInt32Array c_lock_a = cols::i32(actors, names_.lock_a);
	const PackedInt32Array c_pick = cols::i32(actors, names_.pick);
	const PackedFloat32Array c_px = cols::f32(actors, names_.pos_x);
	const PackedFloat32Array c_py = cols::f32(actors, names_.pos_y);
	const PackedFloat32Array c_rad = cols::f32(actors, names_.radius);
	const PackedFloat32Array c_lx = cols::f32(actors, names_.lock_x);
	const PackedFloat32Array c_ly = cols::f32(actors, names_.lock_y);
	const int n = int(c_kinds.size());
	if (c_state.size() != n || c_st.size() != n || c_cd.size() != n || c_fire.size() != n || c_frozen.size() != n ||
			c_dead.size() != n || c_lock_a.size() != n || c_pick.size() != n || c_px.size() != n ||
			c_py.size() != n || c_rad.size() != n || c_lx.size() != n || c_ly.size() != n) {
		return -1;
	}
	const int32_t *kinds = c_kinds.ptr();
	const int32_t *state = c_state.ptr();
	const int32_t *state_t = c_st.ptr();
	const int32_t *cd = c_cd.ptr();
	const int32_t *fire_cd = c_fire.ptr();
	const int32_t *frozen = c_frozen.ptr();
	const int32_t *dead = c_dead.ptr();
	const int32_t *lock_a = c_lock_a.ptr();
	const int32_t *pick = c_pick.ptr();
	const float *px = c_px.ptr();
	const float *py = c_py.ptr();
	const float *rad = c_rad.ptr();
	const float *lx = c_lx.ptr();
	const float *ly = c_ly.ptr();
	const float *tu = kinds_.tuning.data();
	const int egg = int(tu[kt::T_EGG_STATE]);
	const float sight_r = tu[kt::T_SIGHT_R];
	const double slop = double(tu[kt::T_CONTACT_SLOP]);
	const double touch = double(tu[kt::T_CRITTER_TOUCH]);

	// EnemyAi._hit_player's sight test: no wall between the hit's origin and the hero.
	auto sees = [&](float ox, float oy) { return !wall_between(walls_, ox, oy, hx, hy, sight_r); };

	for (int i = 1; i < n; i++) {
		const int kind = kinds[i];
		if (!kinds_.has(kind) || kinds_.mode(kind) == kt::SCRIPT || state[i] >= egg || dead[i] != 0) {
			continue;
		}
		if (frozen[i] > 0) { // Engines.frozen
			continue;
		}
		const int32_t *ri = kinds_.row_i(kind);
		const float *rf = kinds_.row_f(kind);
		const int32_t f = ri[kt::K_FLAGS];
		const int32_t damage = ri[kt::K_DAMAGE];
		const int st = state_t[i];
		if ((f & kt::CRITTER) != 0) { // a critter's touch: a walking critter touching the hero
			if (state[i] != S_MOVE || cd[i] > 0 || damage <= 0) {
				continue;
			}
			if (length(hx - px[i], hy - py[i]) > double(rf[kt::KF_RADIUS]) + double(hr) + touch) {
				continue;
			}
			s.emit(O_TOUCH, i, damage, sees(px[i], py[i]) ? 1 : 0);
			continue;
		}
		if (state[i] != S_ACTIVE) {
			continue;
		}
		const int slot = pattern_slot(ri, pick[i]);
		if (slot >= 0) { // EnemyAi._resolve_pattern
			const int32_t *pi = ri + kt::K_PATTERN + slot * kt::PATTERN_KI;
			const float *pf = rf + kt::KF_PATTERN + slot * kt::PATTERN_KF;
			if (pi[kt::P_BURST] != 0 && st == pi[kt::P_LOB]) { // the lobbed fireball lands
				if (disc_touches(lx[i], ly[i], pf[kt::PF_LAND], hx, hy, hr) && sees(lx[i], ly[i])) {
					s.emit(O_HIT, i, damage, ri[kt::K_TAGS], lx[i], ly[i], 1.0f);
				}
			}
			const int k = wave_at(pi, st);
			if (k >= 0) {
				s.emit(O_WAVE, i, k, slot);
			}
			continue;
		}
		switch (ri[kt::K_SHAPE]) {
			case SH_CONTACT: { // the Charger, Hatchling, Swarmer: one hit an attack, by the body
				const double reach = double(rf[kt::KF_RADIUS]) + double(hr) + slop;
				if (fire_cd[i] == 0 && length(hx - px[i], hy - py[i]) <= reach) {
					s.emit(O_CONTACT, i, damage, sees(px[i], py[i]) ? 1 : 0);
				}
			} break;
			case SH_BURST: { // the Needle: a shot each burst_gap_ticks until burst_count
				const int gap = std::max(1, int(ri[kt::K_BURST_GAP]));
				if (fire_cd[i] < ri[kt::K_BURST_COUNT] && st % gap == 0) {
					const int k = fire_cd[i];
					s.emit(O_BOLT, i, burst_angle(lock_a[i], k, ri[kt::K_BURST_SPREAD]), k);
				}
			} break;
			case SH_PATTERN: // the Arc Caster's rune (its bolt and spread are patterns, above)
			case SH_RUNE_DISC:
				if ((f & kt::SPELLS) != 0 && st == 0 && pick[i] == SPELL_RUNE &&
						disc_touches(lx[i], ly[i], rf[kt::KF_RUNE_RADIUS], hx, hy, hr) && sees(lx[i], ly[i])) {
					s.emit(O_HIT, i, damage, ri[kt::K_TAGS], lx[i], ly[i], 1.0f);
				}
				break;
			default: // EnemyAi._resolve_horde, on the active tick
				if (st != 0) {
					break;
				}
				if ((ri[kt::K_HOOKS] & kt::HOOK_ACTIVE) != 0) {
					s.emit(O_ACTIVE_HOOK, i, 0, 0);
					break;
				}
				bool touched = false;
				switch (ri[kt::K_SHAPE]) {
					case SH_LOCKED_DISC: // the Warden's slam, the Splitter's swipe
						touched = disc_touches(lx[i], ly[i], rf[kt::KF_SLAM_RADIUS], hx, hy, hr);
						break;
					case SH_BASH_LANE: // the Shield Bearer: from its centre along its locked facing
						touched = circle_touches(hx, hy, hr,
								lane(trig_, lx[i], ly[i], lock_a[i], rad[i] + rf[kt::KF_REACH], rf[kt::KF_LANE_HALF]));
						break;
					case SH_SNIPE_LANE: { // the Sniper: reach_m from its muzzle along its aim, cut short by walls
						float dx, dy;
						trig_.dir(lock_a[i], dx, dy);
						const float sx = lx[i] + dx * rad[i], sy = ly[i] + dy * rad[i];
						const float half = rf[kt::KF_LANE_HALF];
						const float run = clear_run(walls_, trig_, sx, sy, lock_a[i], rf[kt::KF_REACH], half);
						touched = circle_touches(hx, hy, hr, lane(trig_, sx, sy, lock_a[i], std::max(run, 0.01f), half));
					} break;
					default:
						break;
				}
				if (touched && sees(px[i], py[i])) {
					s.emit(O_HIT, i, damage, ri[kt::K_TAGS]);
				}
				break;
		}
	}
	return int(s.out_i.size() / 4);
}

PackedInt32Array ZdWorld::strike_out_i() const {
	PackedInt32Array out;
	out.resize(int64_t(strike_.out_i.size()));
	if (!strike_.out_i.empty()) {
		std::memcpy(out.ptrw(), strike_.out_i.data(), strike_.out_i.size() * sizeof(int32_t));
	}
	return out;
}

PackedFloat32Array ZdWorld::strike_out_f() const {
	PackedFloat32Array out;
	out.resize(int64_t(strike_.out_f.size()));
	if (!strike_.out_f.empty()) {
		std::memcpy(out.ptrw(), strike_.out_f.data(), strike_.out_f.size() * sizeof(float));
	}
	return out;
}

PackedInt32Array ZdWorld::strike_layout() const {
	PackedInt32Array out;
	for (const int32_t c : { O_HIT, O_CONTACT, O_TOUCH, O_BOLT, O_WAVE, O_ACTIVE_HOOK }) {
		out.push_back(c);
	}
	for (const int32_t c : { SH_NONE, SH_CONTACT, SH_LOCKED_DISC, SH_BASH_LANE, SH_SNIPE_LANE, SH_RUNE_DISC, SH_BURST,
				 SH_PATTERN, SH_HOOK }) {
		out.push_back(c);
	}
	return out;
}

} // namespace zd

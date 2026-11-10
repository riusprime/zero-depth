#include "zd_ai.h"

#include <cmath>
#include <cstring>

#include <godot_cpp/core/class_db.hpp>

#include "zd_kinds.h"
#include "zd_world.h"

using namespace godot;

namespace zd {

namespace {

constexpr int32_t UNREACHED = 1 << 30; // NavField.UNREACHED
constexpr float BIG_R = 1.0f; // bodies past this radius stay out of the spread grid's cells (always candidates)

// Whether a wall touches the segment a..b thickened by r. The reach of the cells is r x 1.5, as World.walls_along:
// a turned wall grown by r along its own axes reaches up to r x 1.41 along the world's.
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

// NavField.direction: the unit step from (px, py) toward the neighbouring cell nearest the goal; false for none.
bool nav_direction(const NavGrid &g, float px, float py, float &ox, float &oy) {
	if (!g.ready || g.dist.size() != size_t(g.w) * size_t(g.h)) {
		return false;
	}
	const int cx = int(std::floor((double(px) - double(g.ox)) / double(g.cell)));
	const int cy = int(std::floor((double(py) - double(g.oy)) / double(g.cell)));
	if (cx < 0 || cy < 0 || cx >= g.w || cy >= g.h) {
		return false;
	}
	const int k = cy * g.w + cx;
	const int32_t here = g.dist[size_t(k)];
	int pick = -1;
	if (g.blocked[size_t(k)] == 0) {
		int32_t best = UNREACHED, best_d = UNREACHED;
		for (int j = g.adj_start[size_t(k)]; j < g.adj_start[size_t(k) + 1]; j++) {
			const int nk = g.adj[size_t(j)];
			const int32_t d = g.dist[size_t(nk)];
			if (d >= here) {
				continue;
			}
			const int32_t via = d + int32_t(g.adj_w[size_t(j)]);
			if (via < best || (via == best && d < best_d)) {
				best = via;
				best_d = d;
				pick = nk;
			}
		}
	} else {
		static const int STEPS[8][2] = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 },
			{ -1, -1 } };
		int32_t best = here;
		for (const auto &s : STEPS) {
			const int nx = cx + s[0], ny = cy + s[1];
			if (nx < 0 || ny < 0 || nx >= g.w || ny >= g.h) {
				continue;
			}
			const int32_t d = g.dist[size_t(ny * g.w + nx)];
			if (d < best) {
				best = d;
				pick = ny * g.w + nx;
			}
		}
	}
	if (pick < 0) {
		return false;
	}
	const float tx = g.ox + (float(pick % g.w) + 0.5f) * g.cell - px;
	const float ty = g.oy + (float(pick / g.w) + 0.5f) * g.cell - py;
	const double l = length(tx, ty);
	if (l <= 0.0001) {
		return false;
	}
	ox = tx / float(l);
	oy = ty / float(l);
	return true;
}

// The table rows' shared reads: the tuning and the hero.
struct Ctx {
	const float *tu = nullptr;
	float hx = 0, hy = 0, hvx = 0, hvy = 0, hr = 0, land_x = 0, land_y = 0;
	bool dead = false, dashing = false;
	bool flow_native = false;

	void read_hero(const PackedFloat32Array &hero) {
		const float *h = hero.ptr();
		hx = h[H_X];
		hy = h[H_Y];
		hvx = h[H_VX];
		hvy = h[H_VY];
		hr = h[H_RADIUS];
		dead = h[H_DEAD] != 0.0f;
		dashing = h[H_DASHING] != 0.0f;
		land_x = h[H_LAND_X];
		land_y = h[H_LAND_Y];
	}
};

bool unit(float x, float y, float &ox, float &oy) {
	const double l = length(x, y);
	if (l > 0.0001) {
		ox = x / float(l);
		oy = y / float(l);
		return true;
	}
	ox = 0.0f;
	oy = 0.0f;
	return false;
}

// The pattern slot an attack fires (EnemyAi.pattern_of): the Arc Caster's by its spell, the others' first; -1 none.
int pattern_slot(const int32_t *ri, int32_t pick) {
	const int k = (ri[kt::K_FLAGS] & kt::SPELLS) != 0 ? pick : 0;
	if (k < 0 || k >= ri[kt::K_PATTERNS] || k >= kt::MAX_PATTERNS) {
		return -1;
	}
	return ri[kt::K_PATTERN + k * kt::PATTERN_KI + kt::P_HAS] != 0 ? k : -1;
}

} // namespace

// ---------------------------------------------------------------------------------------------------------------
// think (phase 3)

int ZdWorld::think(Object *actors, const PackedFloat32Array &hero, int tick, const PackedByteArray &held,
		const PackedInt32Array &mine_owners, bool flow_native) {
	AiScratch &s = ai_;
	s.out_i.clear();
	s.out_f.clear();
	if (actors == nullptr || !trig_.ready || kinds_.ki != kt::KI || kinds_.kf != kt::KF ||
			kinds_.tuning.size() < size_t(kt::TUNING) || hero.size() < HERO_SIZE) {
		return -1;
	}
	const PackedInt32Array c_ids = cols::i32(actors, names_.ids);
	const PackedInt32Array c_kinds = cols::i32(actors, names_.kinds);
	const PackedInt32Array c_state = cols::i32(actors, names_.state);
	const PackedInt32Array c_st = cols::i32(actors, names_.state_t);
	const PackedInt32Array c_cd = cols::i32(actors, names_.cd);
	const PackedInt32Array c_fire = cols::i32(actors, names_.fire_cd);
	const PackedInt32Array c_facing = cols::i32(actors, names_.facing);
	const PackedInt32Array c_lock_a = cols::i32(actors, names_.lock_a);
	const PackedInt32Array c_windup = cols::i32(actors, names_.windup);
	const PackedInt32Array c_pick = cols::i32(actors, names_.pick);
	const PackedInt32Array c_block = cols::i32(actors, names_.plan_block);
	const PackedInt32Array c_frozen = cols::i32(actors, names_.frozen_t);
	const PackedFloat32Array c_px = cols::f32(actors, names_.pos_x);
	const PackedFloat32Array c_py = cols::f32(actors, names_.pos_y);
	const PackedFloat32Array c_rad = cols::f32(actors, names_.radius);
	const PackedInt32Array c_dead = cols::i32(actors, names_.dead);
	const PackedFloat32Array c_lx = cols::f32(actors, names_.lock_x);
	const PackedFloat32Array c_ly = cols::f32(actors, names_.lock_y);
	const PackedFloat32Array c_len = cols::f32(actors, names_.lock_len);
	const PackedFloat32Array c_planx = cols::f32(actors, names_.plan_x);
	const PackedFloat32Array c_plany = cols::f32(actors, names_.plan_y);
	const int n = int(c_kinds.size());
	if (c_ids.size() != n || c_state.size() != n || c_px.size() != n || c_planx.size() != n || c_block.size() != n ||
			c_windup.size() != n || c_frozen.size() != n || c_dead.size() != n || c_rad.size() != n) {
		return -1;
	}
	cols::load(c_state, s.state);
	cols::load(c_st, s.state_t);
	cols::load(c_cd, s.cd);
	cols::load(c_fire, s.fire_cd);
	cols::load(c_facing, s.facing);
	cols::load(c_lock_a, s.lock_a);
	cols::load(c_windup, s.windup);
	cols::load(c_pick, s.pick);
	cols::load(c_block, s.plan_block);
	cols::load(c_lx, s.lock_x);
	cols::load(c_ly, s.lock_y);
	cols::load(c_len, s.lock_len);
	cols::load(c_planx, s.plan_x);
	cols::load(c_plany, s.plan_y);
	const int32_t *ids = c_ids.ptr();
	const int32_t *kinds = c_kinds.ptr();
	const int32_t *frozen = c_frozen.ptr();
	const int32_t *dead = c_dead.ptr();
	const float *px = c_px.ptr();
	const float *py = c_py.ptr();
	const bool holds = held.size() == n;
	const uint8_t *hold = holds ? held.ptr() : nullptr;

	Ctx c;
	c.read_hero(hero);
	c.flow_native = flow_native;
	const float *tu = kinds_.tuning.data();
	const int period = std::max(1, int(tu[kt::T_PLAN_PERIOD]));
	const int egg = int(tu[kt::T_EGG_STATE]);
	const int spawn_in = int(tu[kt::T_SPAWN_IN]);
	const float spread = tu[kt::T_SPREAD_RADIUS];
	const float spread_w = tu[kt::T_SPREAD_WEIGHT];
	const float strafe = tu[kt::T_STRAFE_PERMILLE] / 1000.0f;
	const float flank = tu[kt::T_FLANK_PERMILLE] / 1000.0f;
	const float flank_min = tu[kt::T_FLANK_MIN];
	const float flank_range = tu[kt::T_FLANK_RANGE];
	const float sight_r = tu[kt::T_SIGHT_R];
	const int phase = posmod(tick, period);
	bool grid_built = false;
	bool changed_state = false, changed_plan = false, changed_lock = false, changed_aim = false;

	// EnemyAi._aim: the shot's aim at where the hero will be (or stands, for a lob), facing it.
	auto aim = [&](int i, const int32_t *ri, const float *rf) {
		changed_aim = true;
		if ((ri[kt::K_FLAGS] & kt::AIM_NO_LEAD) != 0) {
			s.lock_x[size_t(i)] = c.hx;
			s.lock_y[size_t(i)] = c.hy;
			s.lock_a[size_t(i)] = trig_.angle_of(c.hx - px[i], c.hy - py[i]);
			s.facing[size_t(i)] = s.lock_a[size_t(i)];
			changed_lock = true;
			return;
		}
		float speed = s.pick[size_t(i)] == 1 ? rf[kt::KF_SPREAD_SPEED] : rf[kt::KF_BOLT_SPEED];
		const int slot = pattern_slot(ri, s.pick[size_t(i)]);
		if (slot >= 0) {
			speed = rf[kt::KF_PATTERN + slot * kt::PATTERN_KF + kt::PF_SPEED];
		}
		int a;
		if (c.dashing && !c.dead) { // EnemyAi.lead_angle: a dash is aimed at where it ends
			a = trig_.angle_of(c.land_x - px[i], c.land_y - py[i]);
		} else {
			int ticks = 0;
			const int lead_max = ri[kt::K_LEAD_MAX];
			if (speed > 0.0f) {
				const double q = length(c.hx - px[i], c.hy - py[i]) / double(speed);
				ticks = q >= double(lead_max) ? lead_max : std::min(int(q), lead_max);
			}
			const float ft = float(ticks);
			a = trig_.angle_of(c.hx + c.hvx * ft - px[i], c.hy + c.hvy * ft - py[i]);
		}
		s.lock_a[size_t(i)] = a;
		s.facing[size_t(i)] = a;
	};

	for (int i = 1; i < n; i++) {
		const int kind = kinds[i];
		if (!kinds_.has(kind) || kinds_.mode(kind) == kt::SCRIPT || s.state[size_t(i)] >= egg) {
			continue;
		}
		const int32_t *ri = kinds_.row_i(kind);
		const float *rf = kinds_.row_f(kind);
		const int32_t f = ri[kt::K_FLAGS];
		const int32_t hooks = ri[kt::K_HOOKS];
		const bool critter = (f & kt::CRITTER) != 0;
		const bool planning = posmod(ids[i], period) == phase;
		const float ax = px[i], ay = py[i];
		const float radius_m = rf[kt::KF_RADIUS];

		// 1. The staggered walk plan (before the frozen check: a thawed enemy has a fresh one).
		if (planning) {
			changed_plan = true;
			float dx = 0.0f, dy = 0.0f;
			const float tx = c.hx - ax, ty = c.hy - ay;
			const double dist = length(tx, ty);
			if (dist > 0.0001 && !c.dead) {
				const float fd = float(dist);
				dx = tx / fd;
				dy = ty / fd;
				const float side = ids[i] % 2 == 0 ? 1.0f : -1.0f;
				if ((f & kt::FLEES_THEN_STRAFES) != 0) {
					if (dist < double(rf[kt::KF_FLEE])) {
						dx = -dx;
						dy = -dy;
					} else if (dist <= double(rf[kt::KF_KEEP_DISTANCE]) + 1.0) {
						const float ox = -dy * side * strafe, oy = dx * side * strafe;
						dx = ox;
						dy = oy;
					}
				} else if ((f & kt::KEEPS_AWAY) != 0) {
					if (dist < double(rf[kt::KF_KEEP_MIN])) {
						dx = -dx;
						dy = -dy;
					} else if (dist <= double(rf[kt::KF_KEEP_DISTANCE])) {
						const float ox = -dy * side * strafe, oy = dx * side * strafe;
						dx = ox;
						dy = oy;
					}
				} else if (dist <= double(radius_m) + double(c.hr) + 0.1) {
					dx = 0.0f;
					dy = 0.0f;
				} else if (!critter && dist > double(flank_min) && dist < double(flank_range)) {
					unit(dx + -dy * side * flank, dy + dx * side * flank, dx, dy);
				}
			}
			if (dx != 0.0f || dy != 0.0f) {
				// The push off the enemies within the spread radius, summed in ascending index.
				if (!grid_built) {
					s.grid.build(px, py, c_rad.ptr(), n, BIG_R);
					grid_built = true;
				}
				s.grid.query_rect(ax - spread, ay - spread, ax + spread, ay + spread, s.near);
				float pushx = 0.0f, pushy = 0.0f;
				for (const int j : s.near) {
					if (j == 0 || j == i || dead[j] == 1 || kinds[j] < 2) { // ActorStore.Kind.CHARGER
						continue;
					}
					const float ddx = ax - px[j], ddy = ay - py[j];
					if (std::fabs(ddx) >= spread || std::fabs(ddy) >= spread) {
						continue;
					}
					const double l = length(ddx, ddy);
					if (l >= double(spread)) {
						continue;
					}
					if (l <= 0.0001) { // stacked exactly: the higher id steps aside, along +x or -x
						pushx += ids[i] > ids[j] ? 1.0f : -1.0f;
						continue;
					}
					const float k = float(1.0 - l / double(spread));
					pushx += ddx / float(l) * k;
					pushy += ddy / float(l) * k;
				}
				const float len = critter ? 1.0f : float(length(dx, dy));
				float ux, uy;
				unit(dx + pushx * spread_w, dy + pushy * spread_w, ux, uy);
				dx = critter ? ux : ux * len;
				dy = critter ? uy : uy * len;
				// EnemyAi._blocked: the whole line to the hero when walking toward it, else the next metre.
				const float hx = c.hx - ax, hy = c.hy - ay;
				const bool toward = length(hx, hy) > 0.0 && hx * dx + hy * dy > 0.0f;
				const float qx = toward ? c.hx : ax + dx * 1.0f;
				const float qy = toward ? c.hy : ay + dy * 1.0f;
				bool blocked = wall_between(walls_, ax, ay, qx, qy, radius_m);
				for (size_t k = 0; !blocked && k < solids_.size(); k++) {
					blocked = sweep_vs_obb(ax, ay, qx, qy, radius_m, solids_[k]) >= 0.0f;
				}
				s.plan_block[size_t(i)] = blocked ? 1 : 0;
				if (blocked) {
					float fx, fy;
					if (!flow_native) {
						s.emit(I_FLOW, i, 0, len);
					} else if (nav_direction(nav_, ax, ay, fx, fy)) {
						dx = fx * len;
						dy = fy * len;
					}
				}
			}
			s.plan_x[size_t(i)] = dx;
			s.plan_y[size_t(i)] = dy;
		}
		if ((hooks & kt::HOOK_THINK_TICK) != 0) {
			s.emit(I_THINK_TICK, i);
		}
		// 2. Frozen, or held still by a spell.
		if (frozen[i] > 0 || (holds && hold[i] != 0)) {
			continue;
		}
		// 3. The clocks.
		changed_state = true;
		int32_t &st = s.state_t[size_t(i)];
		int32_t &state = s.state[size_t(i)];
		st += 1;
		if (s.cd[size_t(i)] > 0) {
			s.cd[size_t(i)] -= 1;
		}
		// 4. The state machine.
		if (critter || (f & kt::STATIONARY) != 0) { // rises in, then only walks (a node holds its spot)
			if (state == S_SPAWN && st >= spawn_in) {
				state = S_MOVE;
				st = 0;
			} else if (critter && state == S_MOVE && planning) {
				s.facing[size_t(i)] = trig_.angle_of(c.hx - ax, c.hy - ay);
			}
			continue;
		}
		const bool alive = !c.dead;
		switch (state) {
			case S_SPAWN:
				if (st >= spawn_in) {
					state = S_MOVE;
					st = 0;
				}
				break;
			case S_MOVE: {
				const float tx = c.hx - ax, ty = c.hy - ay;
				const double dist = length(tx, ty);
				const bool too_close = (f & kt::FLEES_THEN_STRAFES) != 0 && dist < double(rf[kt::KF_FLEE]);
				bool attack = alive && s.cd[size_t(i)] == 0 && dist <= double(rf[kt::KF_ATTACK_RANGE]) && !too_close;
				attack = attack && !wall_between(walls_, ax, ay, c.hx, c.hy, sight_r); // EnemyAi.sees_player
				const int want = trig_.angle_of(tx, ty);
				if ((f & kt::TURNS_SLOWLY) != 0) {
					s.facing[size_t(i)] = turn_toward(s.facing[size_t(i)], want, ri[kt::K_TURN_RATE]);
				} else if (attack || planning) {
					s.facing[size_t(i)] = want;
				}
				if ((hooks & kt::HOOK_MOVE_TICK) != 0) { // the Mender heals instead of attacking
					s.emit(I_MOVE_TICK, i);
					break;
				}
				if ((f & kt::RELOCATES) != 0 && s.pick[size_t(i)] == 1) { // EnemyAi._end_relocation
					const bool near = length(s.lock_x[size_t(i)] - ax, s.lock_y[size_t(i)] - ay) <=
							double(tu[kt::T_RELOCATE_DONE]);
					if (near || st >= int(tu[kt::T_RELOCATE_MAX])) {
						s.pick[size_t(i)] = 0;
					}
				}
				if (!attack) {
					break;
				}
				bool may = true; // EnemyAi._may_attack
				if ((f & kt::GUARDS_FRONT) != 0) {
					may = angle_diff(want, s.facing[size_t(i)]) <= ri[kt::K_FRONT_HALF_ARC];
				} else if ((f & kt::NEEDS_MAY) != 0) {
					int mines = 0;
					for (int64_t k = 0; k < mine_owners.size(); k++) {
						mines += mine_owners[k] == ids[i] ? 1 : 0;
					}
					may = mines < ri[kt::K_MAX_MINES];
				} else if ((f & kt::RELOCATES) != 0) {
					may = s.pick[size_t(i)] == 0;
				}
				if (!may) {
					break;
				}
				// EnemyAi._start_windup: everything that needs no draw; WINDUP_START for the rest.
				state = S_WINDUP;
				st = 0;
				changed_lock = true;
				changed_aim = true;
				s.lock_x[size_t(i)] = ax;
				s.lock_y[size_t(i)] = ay;
				s.lock_a[size_t(i)] = want;
				s.lock_len[size_t(i)] = 0.0f;
				s.pick[size_t(i)] = 0;
				s.windup[size_t(i)] = ri[kt::K_WINDUP];
				if ((f & kt::CHARGES) != 0) {
					s.lock_len[size_t(i)] =
							clear_run(walls_, trig_, ax, ay, want, rf[kt::KF_CHARGE_DISTANCE], radius_m);
				} else if ((f & kt::AIM_AT_START) != 0) {
					aim(i, ri, rf);
				} else if ((f & kt::LOCKS_AHEAD) != 0) {
					float dx, dy;
					trig_.dir(want, dx, dy);
					s.lock_x[size_t(i)] = ax + dx * rf[kt::KF_REACH];
					s.lock_y[size_t(i)] = ay + dy * rf[kt::KF_REACH];
				} else if ((f & kt::LOCKS_FACING) != 0) {
					s.lock_a[size_t(i)] = s.facing[size_t(i)];
				}
				if (ri[kt::K_WINDUP_MAX] > ri[kt::K_WINDUP] || (f & kt::SPELLS) != 0 ||
						(hooks & kt::HOOK_WINDUP_START) != 0) {
					s.emit(I_WINDUP_START, i, want);
				}
			} break;
			case S_WINDUP: {
				const bool sniper = (f & kt::RELOCATES) != 0;
				const int commit = int(tu[sniper ? kt::T_SNIPE_COMMIT : kt::T_COMMIT]);
				const bool rune = (f & kt::SPELLS) != 0 && s.pick[size_t(i)] == 2; // Spell.RUNE: no tracking
				if ((f & kt::TRACKS) != 0 && !rune && st < s.windup[size_t(i)] - commit && alive) {
					aim(i, ri, rf);
				}
				if (st >= s.windup[size_t(i)]) {
					if ((hooks & kt::HOOK_WINDUP_END) != 0) {
						s.emit(I_WINDUP_END, i);
					} else {
						state = S_ACTIVE;
						st = 0;
						s.fire_cd[size_t(i)] = 0;
					}
				}
			} break;
			case S_ACTIVE: {
				const int slot = pattern_slot(ri, s.pick[size_t(i)]);
				bool done;
				if (slot >= 0) { // a pattern attack runs until its last wave
					const int dur = ri[kt::K_PATTERN + slot * kt::PATTERN_KI + kt::P_DURATION];
					done = st >= std::max(ri[kt::K_ACTIVE], dur);
				} else if ((f & kt::CHARGES) != 0) {
					done = s.lock_len[size_t(i)] <= 0.0f;
				} else if ((f & kt::FLEES_THEN_STRAFES) != 0) {
					done = s.fire_cd[size_t(i)] >= ri[kt::K_BURST_COUNT] && st >= ri[kt::K_ACTIVE];
				} else {
					done = st >= ri[kt::K_ACTIVE];
				}
				if (done) {
					state = S_RECOVER;
					st = 0;
				}
			} break;
			case S_RECOVER:
				if (st >= ri[kt::K_RECOVER]) {
					state = S_MOVE;
					st = 0;
					s.cd[size_t(i)] = ri[kt::K_COOLDOWN];
					if ((f & kt::RELOCATES) != 0) {
						s.emit(I_RELOCATE, i);
					}
				}
				break;
			default:
				break;
		}
	}

	if (changed_state) {
		cols::put_i32(actors, names_.state, s.state);
		cols::put_i32(actors, names_.state_t, s.state_t);
		cols::put_i32(actors, names_.cd, s.cd);
		cols::put_i32(actors, names_.fire_cd, s.fire_cd);
		cols::put_i32(actors, names_.pick, s.pick);
		cols::put_i32(actors, names_.windup, s.windup);
	}
	if (changed_aim || changed_state) { // the aim, and the facing that turns with it
		cols::put_i32(actors, names_.lock_a, s.lock_a);
		cols::put_i32(actors, names_.facing, s.facing);
	}
	if (changed_lock) {
		cols::put_f32(actors, names_.lock_x, s.lock_x);
		cols::put_f32(actors, names_.lock_y, s.lock_y);
		cols::put_f32(actors, names_.lock_len, s.lock_len);
	}
	if (changed_plan) {
		cols::put_f32(actors, names_.plan_x, s.plan_x);
		cols::put_f32(actors, names_.plan_y, s.plan_y);
		cols::put_i32(actors, names_.plan_block, s.plan_block);
	}
	return int(s.out_i.size() / 4);
}

// ---------------------------------------------------------------------------------------------------------------
// move (phase 5): the steering; the collision passes follow (resolve_actors)

int ZdWorld::move(Object *actors, const PackedFloat32Array &hero, const PackedFloat32Array &slow,
		float slow_permille, bool flow_native) {
	AiScratch &s = ai_;
	s.out_i.clear();
	s.out_f.clear();
	if (actors == nullptr || !trig_.ready || kinds_.ki != kt::KI || kinds_.kf != kt::KF ||
			kinds_.tuning.size() < size_t(kt::TUNING) || hero.size() < HERO_SIZE) {
		return -1;
	}
	const PackedInt32Array c_kinds = cols::i32(actors, names_.kinds);
	const PackedInt32Array c_state = cols::i32(actors, names_.state);
	const PackedInt32Array c_pick = cols::i32(actors, names_.pick);
	const PackedInt32Array c_frozen = cols::i32(actors, names_.frozen_t);
	const PackedInt32Array c_slow_t = cols::i32(actors, names_.slow_t);
	const PackedInt32Array c_facing = cols::i32(actors, names_.facing);
	const PackedInt32Array c_lock_a = cols::i32(actors, names_.lock_a);
	const PackedFloat32Array c_px = cols::f32(actors, names_.pos_x);
	const PackedFloat32Array c_py = cols::f32(actors, names_.pos_y);
	const PackedFloat32Array c_lx = cols::f32(actors, names_.lock_x);
	const PackedFloat32Array c_ly = cols::f32(actors, names_.lock_y);
	const PackedFloat32Array c_len = cols::f32(actors, names_.lock_len);
	const PackedFloat32Array c_planx = cols::f32(actors, names_.plan_x);
	const PackedFloat32Array c_plany = cols::f32(actors, names_.plan_y);
	const int n = int(c_kinds.size());
	if (c_state.size() != n || c_px.size() != n || c_planx.size() != n || c_frozen.size() != n ||
			c_slow_t.size() != n || c_len.size() != n) {
		return -1;
	}
	cols::load(c_px, s.pos_x);
	cols::load(c_py, s.pos_y);
	cols::load(c_lx, s.lock_x);
	cols::load(c_ly, s.lock_y);
	cols::load(c_len, s.lock_len);
	cols::load(c_facing, s.facing);
	cols::load(c_lock_a, s.lock_a);
	const int32_t *kinds = c_kinds.ptr();
	const int32_t *state = c_state.ptr();
	const int32_t *pick = c_pick.ptr();
	const int32_t *frozen = c_frozen.ptr();
	const int32_t *slow_t = c_slow_t.ptr();
	const float *plan_x = c_planx.ptr();
	const float *plan_y = c_plany.ptr();
	const bool has_slow = slow.size() == n;
	Ctx c;
	c.read_hero(hero);
	const float *tu = kinds_.tuning.data();
	const int egg = int(tu[kt::T_EGG_STATE]);
	const double slowed = double(slow_permille) / 1000.0; // ItemProcs.slow_factor with no pair or spell
	bool moved = false, aimed = false, anchored = false;

	for (int i = 1; i < n; i++) {
		const int kind = kinds[i];
		if (!kinds_.has(kind) || kinds_.mode(kind) == kt::SCRIPT || state[i] >= egg) {
			continue;
		}
		const int32_t *ri = kinds_.row_i(kind);
		const float *rf = kinds_.row_f(kind);
		const int32_t f = ri[kt::K_FLAGS];
		float &x = s.pos_x[size_t(i)];
		float &y = s.pos_y[size_t(i)];
		if ((f & kt::STATIONARY) != 0) { // StarfallKinds.hold: its first move takes its spot, then keeps it
			if (s.lock_len[size_t(i)] <= 0.0f) {
				s.lock_x[size_t(i)] = x;
				s.lock_y[size_t(i)] = y;
				s.lock_len[size_t(i)] = 1.0f;
			} else {
				x = s.lock_x[size_t(i)];
				y = s.lock_y[size_t(i)];
				moved = true;
			}
			anchored = true;
			continue;
		}
		double factor = 1.0;
		if (has_slow) {
			factor = double(slow[i]);
		} else if (frozen[i] > 0) {
			factor = 0.0;
		} else if (slow_t[i] > 0) {
			factor = slowed;
		}
		const int st = state[i];
		if (st == S_MOVE && (f & kt::RELOCATES) != 0 && pick[i] == 1) { // EnemyAi._relocate
			if (!flow_native) {
				s.emit(I_RELOCATE_STEP, i);
				continue;
			}
			const float tx = s.lock_x[size_t(i)] - x, ty = s.lock_y[size_t(i)] - y;
			const double d = length(tx, ty);
			if (d <= 0.0001) {
				continue;
			}
			const double reloc = double(tu[kt::T_RELOCATE_SPEED_PERMILLE]);
			const float step = float(std::min(double(rf[kt::KF_SPEED]) * factor * reloc / 1000.0, d));
			float dx = tx / float(d), dy = ty / float(d);
			const float hx = c.hx - x, hy = c.hy - y;
			const bool toward = length(hx, hy) > 0.0 && hx * dx + hy * dy > 0.0f;
			const float qx = toward ? c.hx : x + dx, qy = toward ? c.hy : y + dy;
			bool blocked = wall_between(walls_, x, y, qx, qy, rf[kt::KF_RADIUS]);
			for (size_t k = 0; !blocked && k < solids_.size(); k++) {
				blocked = sweep_vs_obb(x, y, qx, qy, rf[kt::KF_RADIUS], solids_[k]) >= 0.0f;
			}
			float fx, fy;
			if (blocked && nav_direction(nav_, x, y, fx, fy)) {
				const float l = float(length(dx, dy));
				dx = fx * l;
				dy = fy * l;
			}
			x += dx * step;
			y += dy * step;
			moved = true;
			continue;
		}
		const bool hovering = (f & kt::HOVERS) != 0 && st == S_WINDUP;
		if (st == S_MOVE || hovering) { // the walk follows the last plan
			const float dx = plan_x[i], dy = plan_y[i];
			if ((dx == 0.0f && dy == 0.0f) || c.dead) {
				continue;
			}
			if ((f & kt::MELEE_STOP) != 0 &&
					length(c.hx - x, c.hy - y) <= double(rf[kt::KF_RADIUS]) + double(c.hr) + 0.1) {
				continue; // a melee walker stops the tick it touches the hero
			}
			const float k = float(double(rf[kt::KF_SPEED]) * factor);
			x += dx * k;
			y += dy * k;
			moved = true;
		} else if (st == S_ACTIVE && (f & kt::CHARGES) != 0 && s.lock_len[size_t(i)] > 0.0f) {
			if (ri[kt::K_CHARGE_TURN] > 0 && !c.dead) { // the charge bends toward the hero
				const int want = trig_.angle_of(c.hx - x, c.hy - y);
				s.lock_a[size_t(i)] = turn_toward(s.lock_a[size_t(i)], want, ri[kt::K_CHARGE_TURN]);
				s.facing[size_t(i)] = s.lock_a[size_t(i)];
				aimed = true;
			}
			const float step =
					float(std::min(double(rf[kt::KF_CHARGE_SPEED]) * factor, double(s.lock_len[size_t(i)])));
			s.lock_len[size_t(i)] -= step;
			float dx, dy;
			trig_.dir(s.lock_a[size_t(i)], dx, dy);
			x += dx * step;
			y += dy * step;
			moved = true;
			anchored = true;
			if ((ri[kt::K_HOOKS] & kt::HOOK_CHARGE_STEP) != 0) {
				s.emit(I_CHARGE_STEP, i);
			}
		}
	}
	if (moved) {
		cols::put_f32(actors, names_.pos_x, s.pos_x);
		cols::put_f32(actors, names_.pos_y, s.pos_y);
	}
	if (anchored) {
		cols::put_f32(actors, names_.lock_x, s.lock_x);
		cols::put_f32(actors, names_.lock_y, s.lock_y);
		cols::put_f32(actors, names_.lock_len, s.lock_len);
	}
	if (aimed) {
		cols::put_i32(actors, names_.lock_a, s.lock_a);
		cols::put_i32(actors, names_.facing, s.facing);
	}
	return int(s.out_i.size() / 4);
}

PackedInt32Array ZdWorld::ai_intents_i() const {
	PackedInt32Array out;
	out.resize(int64_t(ai_.out_i.size()));
	if (!ai_.out_i.empty()) {
		std::memcpy(out.ptrw(), ai_.out_i.data(), ai_.out_i.size() * sizeof(int32_t));
	}
	return out;
}

PackedFloat32Array ZdWorld::ai_intents_f() const {
	PackedFloat32Array out;
	out.resize(int64_t(ai_.out_f.size()));
	if (!ai_.out_f.empty()) {
		std::memcpy(out.ptrw(), ai_.out_f.data(), ai_.out_f.size() * sizeof(float));
	}
	return out;
}

PackedInt32Array ZdWorld::kind_layout() const {
	PackedInt32Array out;
	out.resize(kt::LAYOUT_SIZE);
	for (int k = 0; k < kt::LAYOUT_SIZE; k++) {
		out.set(k, kt::LAYOUT[k]);
	}
	return out;
}

PackedInt32Array ZdWorld::ai_hero_layout() const {
	PackedInt32Array out;
	out.push_back(HERO_SIZE);
	out.push_back(I_FLOW);
	out.push_back(I_THINK_TICK);
	out.push_back(I_MOVE_TICK);
	out.push_back(I_WINDUP_START);
	out.push_back(I_WINDUP_END);
	out.push_back(I_RELOCATE);
	out.push_back(I_CHARGE_STEP);
	out.push_back(I_RELOCATE_STEP);
	return out;
}

} // namespace zd

#include "zd_nav.h"

#include <algorithm>
#include <cmath>
#include <cstring>

#include "zd_world.h"

using namespace godot;

namespace zd {
namespace nav {

FloodOut flood(NavGrid &g, Scratch &s, const int32_t *seeds, int64_t seed_count, int64_t max_steps,
		const int32_t *targets, int64_t target_count) {
	FloodOut out;
	const int32_t n = g.w * g.h;
	g.dist.assign(size_t(std::max(0, n)), UNREACHED);
	if (n <= 0) {
		return out;
	}
	if (s.ring.size() < size_t(RING) * size_t(n)) {
		s.ring.resize(size_t(RING) * size_t(n));
	}
	if (s.want.size() < size_t(n)) {
		s.want.assign(size_t(n), 0);
	}
	int32_t *d = g.dist.data();
	int32_t *ring = s.ring.data();
	uint8_t *want = s.want.data();
	const int32_t *adj_start = g.adj_start.data();
	const int32_t *adj = g.adj.data();
	const uint8_t *adj_w = g.adj_w.data();
	const bool open = g.extra.size() != size_t(n);
	const uint8_t *extra = open ? nullptr : g.extra.data();
	int32_t lens[RING] = { 0 };
	// mini(max_steps, UNREACHED / ORTHO - 1) * ORTHO
	const int64_t cap = UNREACHED / ORTHO - 1;
	const int32_t bound = int32_t(std::min<int64_t>(max_steps, cap) * ORTHO);
	int32_t last_seed = -1;
	for (int64_t k = 1; k < seed_count; k += 2) {
		last_seed = std::max(last_seed, seeds[k]);
	}
	int32_t left = 0;
	for (int64_t t = 0; t < target_count; t++) {
		const int32_t k = targets[t];
		if (k >= 0 && k < n && want[k] == 0) {
			want[k] = 1;
			left++;
		}
	}
	int32_t stop = UNREACHED;
	int32_t cur = 0;
	int64_t queued = 0;
	int64_t work = 0;
	while ((queued > 0 || cur <= last_seed) && cur <= bound && cur <= stop) {
		const int32_t b = cur % RING;
		int32_t *bucket = ring + size_t(b) * size_t(n);
		if (cur <= last_seed) {
			for (int64_t k = 0; k + 1 < seed_count; k += 2) {
				const int32_t sk = seeds[k];
				if (seeds[k + 1] == cur && sk >= 0 && sk < n && cur < d[sk]) {
					d[sk] = cur;
					bucket[lens[b]++] = sk;
					queued++;
				}
			}
		}
		const int32_t count = lens[b];
		work += count;
		for (int32_t q = 0; q < count; q++) {
			const int32_t k = bucket[q];
			if (d[k] != cur) {
				continue; // a stale entry: the cell was reached shorter after it was queued
			}
			if (left > 0 && want[k] == 1) {
				want[k] = 0;
				left--;
				if (left == 0) {
					stop = cur + TARGET_MARGIN;
				}
			}
			// The same steps in the same order as NavField._run (its plain branch takes them by offset in this
			// order too, and needs nd <= bound and no extra cells, which this test then always passes).
			const int32_t a1 = adj_start[k + 1];
			for (int32_t j = adj_start[k]; j < a1; j++) {
				const int32_t nk = adj[j];
				const int32_t nd = cur + int32_t(adj_w[j]);
				if (nd < d[nk] && nd <= bound && (open || extra[nk] == 0)) {
					d[nk] = nd;
					const int32_t nb = nd % RING;
					ring[size_t(nb) * size_t(n) + size_t(lens[nb]++)] = nk;
					queued++;
				}
			}
		}
		queued -= count;
		lens[b] = 0;
		cur++;
	}
	if (left > 0) {
		for (int64_t t = 0; t < target_count; t++) {
			const int32_t k = targets[t];
			if (k >= 0 && k < n) {
				want[k] = 0;
			}
		}
	} else if (stop < UNREACHED && queued > 0 && cur <= bound) {
		out.stopped = true;
	}
	out.work = int32_t(work);
	return out;
}

void direction(const NavGrid &g, float px, float py, float &dx, float &dy) {
	dx = 0.0f;
	dy = 0.0f;
	if (!g.ready || g.dist.size() != size_t(g.w) * size_t(g.h)) {
		return;
	}
	// cell_of: floor((p - origin) / CELL) in GDScript's doubles.
	const double fx = std::floor((double(px) - double(g.ox)) / 0.5);
	const double fy = std::floor((double(py) - double(g.oy)) / 0.5);
	if (fx < 0.0 || fy < 0.0 || fx >= double(g.w) || fy >= double(g.h)) {
		return;
	}
	const int32_t cx = int32_t(fx), cy = int32_t(fy);
	const int32_t sx = g.w;
	const int32_t k = cy * sx + cx;
	const int32_t *dist = g.dist.data();
	const int32_t here = dist[k];
	int32_t pick = -1;
	if (g.blocked[size_t(k)] == 0) {
		int32_t best = UNREACHED, best_d = UNREACHED;
		for (int32_t j = g.adj_start[size_t(k)]; j < g.adj_start[size_t(k) + 1]; j++) {
			const int32_t nk = g.adj[size_t(j)];
			const int32_t dn = dist[nk];
			if (dn >= here) {
				continue;
			}
			const int32_t via = dn + int32_t(g.adj_w[size_t(j)]);
			if (via < best || (via == best && dn < best_d)) {
				best = via;
				best_d = dn;
				pick = nk;
			}
		}
	} else {
		static const int32_t STEPS[8][2] = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 },
			{ -1, 1 }, { -1, -1 } };
		int32_t best = here;
		for (const auto &st : STEPS) {
			const int32_t nx = cx + st[0], ny = cy + st[1];
			if (nx < 0 || ny < 0 || nx >= g.w || ny >= g.h) {
				continue;
			}
			const int32_t dn = dist[ny * sx + nx];
			if (dn < best) {
				best = dn;
				pick = ny * sx + nx;
			}
		}
	}
	if (pick < 0) {
		return;
	}
	// center(): origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL, in single precision as Vector2 is.
	const float ccx = g.ox + (float(pick % sx) + 0.5f) * CELL;
	const float ccy = g.oy + (float(pick / sx) + 0.5f) * CELL;
	const float tx = ccx - px;
	const float ty = ccy - py;
	// Kin.length in doubles; Vector2 / float divides in single precision.
	const double l = std::sqrt(double(tx) * double(tx) + double(ty) * double(ty));
	if (l > 0.0001) {
		const float lf = float(l);
		dx = tx / lf;
		dy = ty / lf;
	}
}

} // namespace nav

void ZdWorld::set_nav_extra(const PackedByteArray &extra) {
	nav_.extra.assign(extra.ptr(), extra.ptr() + extra.size());
}

int64_t ZdWorld::nav_flood(const PackedInt32Array &seeds, int64_t max_steps, const PackedInt32Array &targets) {
	if (!nav_.ready || nav_.adj_start.size() != size_t(nav_.w) * size_t(nav_.h) + 1) {
		return 0;
	}
	const nav::FloodOut r =
			nav::flood(nav_, nav_scratch_, seeds.ptr(), seeds.size(), max_steps, targets.ptr(), targets.size());
	return r.stopped ? -1 - int64_t(r.work) : int64_t(r.work);
}

PackedInt32Array ZdWorld::nav_dist() const {
	PackedInt32Array out;
	out.resize(int64_t(nav_.dist.size()));
	if (!nav_.dist.empty()) {
		std::memcpy(out.ptrw(), nav_.dist.data(), nav_.dist.size() * sizeof(int32_t));
	}
	return out;
}

PackedFloat32Array ZdWorld::nav_directions(const PackedFloat32Array &xy) const {
	PackedFloat32Array out;
	out.resize(xy.size() / 2 * 2);
	float *w = out.ptrw();
	for (int64_t i = 0; i < xy.size() / 2; i++) {
		nav::direction(nav_, xy[i * 2], xy[i * 2 + 1], w[i * 2], w[i * 2 + 1]);
	}
	return out;
}

} // namespace zd

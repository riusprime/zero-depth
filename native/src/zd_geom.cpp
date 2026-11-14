#include "zd_geom.h"

using namespace godot;

namespace zd {

void read_boxes(const PackedFloat32Array &obbs, std::vector<Box> &out) {
	out.clear();
	const float *s = obbs.ptr();
	const int64_t n = obbs.size() / 8;
	out.reserve(size_t(n));
	for (int64_t i = 0; i < n; i++) {
		const float *o = s + i * 8;
		Box b{ o[0], o[1], o[2], o[3], o[4], o[5], o[6], o[7], 0, 0, 0, 0 };
		const float ex = std::fabs(b.ux) * b.hx + std::fabs(b.vx) * b.hy;
		const float ey = std::fabs(b.uy) * b.hx + std::fabs(b.vy) * b.hy;
		b.x0 = b.cx - ex;
		b.x1 = b.cx + ex;
		b.y0 = b.cy - ey;
		b.y1 = b.cy + ey;
		out.push_back(b);
	}
}

void WallGrid::set(const PackedFloat32Array &obbs) {
	read_boxes(obbs, boxes);
	stamp.assign(boxes.size(), 0u);
	query = 0;
	w = h = 0;
	start.clear();
	items.clear();
	if (boxes.empty()) {
		return;
	}
	float x0 = boxes[0].x0, y0 = boxes[0].y0, x1 = boxes[0].x1, y1 = boxes[0].y1;
	for (const Box &b : boxes) {
		x0 = std::min(x0, b.x0);
		y0 = std::min(y0, b.y0);
		x1 = std::max(x1, b.x1);
		y1 = std::max(y1, b.y1);
	}
	cell = CELL;
	while ((x1 - x0) / cell + 1.0f > float(MAX_SIDE) || (y1 - y0) / cell + 1.0f > float(MAX_SIDE)) {
		cell *= 2.0f;
	}
	ox = x0;
	oy = y0;
	w = int((x1 - x0) / cell) + 1;
	h = int((y1 - y0) / cell) + 1;
	const int cells = w * h;
	std::vector<int> count(size_t(cells) + 1, 0);
	auto span = [&](const Box &b, int &c0, int &r0, int &c1, int &r1) {
		c0 = std::clamp(int((b.x0 - ox) / cell), 0, w - 1);
		c1 = std::clamp(int((b.x1 - ox) / cell), 0, w - 1);
		r0 = std::clamp(int((b.y0 - oy) / cell), 0, h - 1);
		r1 = std::clamp(int((b.y1 - oy) / cell), 0, h - 1);
	};
	for (const Box &b : boxes) {
		int c0, r0, c1, r1;
		span(b, c0, r0, c1, r1);
		for (int r = r0; r <= r1; r++) {
			for (int c = c0; c <= c1; c++) {
				count[size_t(r * w + c)]++;
			}
		}
	}
	start.assign(size_t(cells) + 1, 0);
	for (int i = 0; i < cells; i++) {
		start[size_t(i) + 1] = start[size_t(i)] + count[size_t(i)];
	}
	items.assign(size_t(start[size_t(cells)]), 0);
	std::vector<int> at(start.begin(), start.end() - 1);
	for (int k = 0; k < int(boxes.size()); k++) {
		int c0, r0, c1, r1;
		span(boxes[size_t(k)], c0, r0, c1, r1);
		for (int r = r0; r <= r1; r++) {
			for (int c = c0; c <= c1; c++) {
				items[size_t(at[size_t(r * w + c)]++)] = k;
			}
		}
	}
}

float WallGrid::first_hit(float ax, float ay, float bx, float by, float r) {
	float t = 1.0f;
	walls_in(std::min(ax, bx) - r, std::min(ay, by) - r, std::max(ax, bx) + r, std::max(ay, by) + r,
			[&](const Box &b) {
				const float hit = sweep_vs_obb(ax, ay, bx, by, r, b);
				if (hit >= 0.0f && hit < t) {
					t = hit;
				}
			});
	return t;
}

void BodyGrid::build(const float *x, const float *y, const float *r, int n, float big_r) {
	big.clear();
	cell_of.assign(size_t(n), -1);
	float rmax = 0.0f;
	float x0 = 0.0f, y0 = 0.0f, x1 = 0.0f, y1 = 0.0f;
	bool any = false;
	for (int i = 0; i < n; i++) {
		const float ri = r[i];
		if (ri > big_r) {
			big.push_back(i);
			continue;
		}
		rmax = std::max(rmax, ri);
		const float xi = x[i], yi = y[i];
		if (!any) {
			x0 = x1 = xi;
			y0 = y1 = yi;
			any = true;
		} else {
			x0 = std::min(x0, xi);
			x1 = std::max(x1, xi);
			y0 = std::min(y0, yi);
			y1 = std::max(y1, yi);
		}
	}
	cell = std::max(2.0f * rmax, 0.25f);
	while ((x1 - x0) / cell + 1.0f > 512.0f || (y1 - y0) / cell + 1.0f > 512.0f) {
		cell *= 2.0f;
	}
	ox = x0;
	oy = y0;
	w = any ? int((x1 - x0) / cell) + 1 : 1;
	h = any ? int((y1 - y0) / cell) + 1 : 1;
	const int cells = w * h;
	start.assign(size_t(cells) + 1, 0);
	for (int i = 0; i < n; i++) {
		if (r[i] > big_r) {
			continue;
		}
		const int c = std::min(int((x[i] - ox) / cell), w - 1);
		const int rr = std::min(int((y[i] - oy) / cell), h - 1);
		const int k = rr * w + c;
		cell_of[size_t(i)] = k;
		start[size_t(k) + 1]++;
	}
	for (int i = 0; i < cells; i++) {
		start[size_t(i) + 1] += start[size_t(i)];
	}
	items.assign(size_t(start[size_t(cells)]), 0);
	fill.assign(start.begin(), start.end() - 1);
	for (int i = 0; i < n; i++) {
		const int k = cell_of[size_t(i)];
		if (k >= 0) {
			items[size_t(fill[size_t(k)]++)] = i;
		}
	}
}

void BodyGrid::query_rect(float x0, float y0, float x1, float y1, std::vector<int> &out) const {
	out.clear();
	if (start.empty()) {
		return;
	}
	const int c0 = std::clamp(int(std::floor((x0 - ox) / cell)), 0, w - 1);
	const int c1 = std::clamp(int(std::floor((x1 - ox) / cell)), 0, w - 1);
	const int r0 = std::clamp(int(std::floor((y0 - oy) / cell)), 0, h - 1);
	const int r1 = std::clamp(int(std::floor((y1 - oy) / cell)), 0, h - 1);
	for (int r = r0; r <= r1; r++) {
		for (int c = c0; c <= c1; c++) {
			const int k1 = start[size_t(r * w + c) + 1];
			for (int k = start[size_t(r * w + c)]; k < k1; k++) {
				out.push_back(items[size_t(k)]);
			}
		}
	}
	out.insert(out.end(), big.begin(), big.end());
	std::sort(out.begin(), out.end()); // Distinct indices: the order is fully determined
}

bool Trig::set(const PackedFloat32Array &c, const PackedFloat32Array &s) {
	if (c.size() != SIZE || s.size() != SIZE) {
		return false;
	}
	std::copy(c.ptr(), c.ptr() + SIZE, cos_t);
	std::copy(s.ptr(), s.ptr() + SIZE, sin_t);
	ready = true;
	return true;
}

void Trig::dir(int angle, float &x, float &y) const {
	const int a = angle & 4095;
	const int quadrant = a >> 10;
	const int b = a & 1023;
	float c, s;
	if (b <= 512) {
		c = cos_t[b];
		s = sin_t[b];
	} else {
		c = sin_t[1024 - b];
		s = cos_t[1024 - b];
	}
	switch (quadrant) {
		case 0:
			x = c;
			y = s;
			break;
		case 1:
			x = -s;
			y = c;
			break;
		case 2:
			x = -c;
			y = -s;
			break;
		default:
			x = s;
			y = -c;
			break;
	}
}

int Trig::octant_index(double ax, double ay) const {
	int lo = 0;
	int hi = 512;
	while (lo < hi) { // The smallest i with sin(i) * ax >= cos(i) * ay
		const int mid = (lo + hi) >> 1;
		if (double(sin_t[mid]) * ax >= double(cos_t[mid]) * ay) {
			hi = mid;
		} else {
			lo = mid + 1;
		}
	}
	if (lo == 0) {
		return 0;
	}
	const double err_hi = std::fabs(double(sin_t[lo]) * ax - double(cos_t[lo]) * ay);
	const double err_lo = std::fabs(double(sin_t[lo - 1]) * ax - double(cos_t[lo - 1]) * ay);
	return err_lo < err_hi ? lo - 1 : lo;
}

int Trig::angle_of(float xf, float yf) const {
	const double x = double(xf);
	const double y = double(yf);
	double ax = std::fabs(x);
	double ay = std::fabs(y);
	if (ax == 0.0 && ay == 0.0) {
		return 0;
	}
	const bool swapped = ay > ax;
	if (swapped) {
		std::swap(ax, ay);
	}
	const int base = octant_index(ax, ay);
	const int a1 = swapped ? 1024 - base : base;
	int a;
	if (x >= 0.0 && y >= 0.0) {
		a = a1;
	} else if (x < 0.0 && y >= 0.0) {
		a = 2048 - a1;
	} else if (x < 0.0) {
		a = 2048 + a1;
	} else {
		a = 4096 - a1;
	}
	return a & 4095;
}

} // namespace zd

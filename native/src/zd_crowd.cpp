#include "zd_crowd.h"

#include <cmath>
#include <cstdint>
#include <limits>
#include <vector>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

using namespace godot;

namespace zd {

namespace {

// GDScript's lerpf (Math::lerp in doubles).
inline double lerpd(double from, double to, double weight) {
	return from + (to - from) * weight;
}

} // namespace

Array ZdCrowd::write_furniture(const Array &slots, const PackedInt32Array &set_parts, const PackedInt32Array &set_caps,
		double fraction, bool interp_on, bool synced_now, bool ticked, const PackedFloat64Array &heights) const {
	Array out;
	if (slots.size() != SLOT_COLUMNS || heights.size() < 3 || set_caps.size() != set_parts.size()) {
		ERR_PRINT("ZdCrowd.write_furniture: wrong columns");
		return out;
	}
	const PackedFloat32Array x0 = slots[X0], y0 = slots[Y0], z0 = slots[Z0];
	const PackedFloat32Array x1 = slots[X1], y1 = slots[Y1], z1 = slots[Z1];
	const PackedByteArray interp = slots[INTERP], bar_on = slots[BAR_ON], dazed_on = slots[DAZED_ON];
	const PackedByteArray blob_on = slots[BLOB_ON], shown = slots[SHOWN];
	const PackedFloat32Array bar_y = slots[BAR_Y], dazed_y = slots[DAZED_Y], blob_s = slots[BLOB_S];
	const PackedInt32Array disc = slots[DISC], ring = slots[RING];
	const PackedFloat64Array fill = slots[FILL];
	const PackedFloat32Array s0_in = slots[S0], s1_in = slots[S1];
	const int64_t n = x0.size();
	if (y0.size() != n || z0.size() != n || x1.size() != n || y1.size() != n || z1.size() != n ||
			interp.size() != n || bar_on.size() != n || dazed_on.size() != n || blob_on.size() != n ||
			shown.size() != n || bar_y.size() != n || dazed_y.size() != n || blob_s.size() != n ||
			disc.size() != n || ring.size() != n || fill.size() != n || s0_in.size() != n || s1_in.size() != n) {
		ERR_PRINT("ZdCrowd.write_furniture: columns of different lengths");
		return out;
	}
	const float *X0p = x0.ptr(), *Y0p = y0.ptr(), *Z0p = z0.ptr();
	const float *X1p = x1.ptr(), *Y1p = y1.ptr(), *Z1p = z1.ptr();
	const uint8_t *IP = interp.ptr(), *BO = bar_on.ptr(), *DO = dazed_on.ptr(), *LO = blob_on.ptr();
	const uint8_t *SH = shown.ptr();
	const float *BY = bar_y.ptr(), *DY = dazed_y.ptr(), *LS = blob_s.ptr();
	const int32_t *DI = disc.ptr(), *RI = ring.ptr();
	const double *FI = fill.ptr();
	const float *S0i = s0_in.ptr(), *S1i = s1_in.ptr();

	PackedFloat32Array px, py, pz, sx, s0, s1;
	PackedVector3Array bo;
	px.resize(n);
	py.resize(n);
	pz.resize(n);
	sx.resize(n);
	s0.resize(n);
	s1.resize(n);
	bo.resize(n);
	float *PX = px.ptrw(), *PY = py.ptrw(), *PZ = pz.ptrw(), *SX = sx.ptrw(), *S0 = s0.ptrw(), *S1 = s1.ptrw();
	Vector3 *BOp = bo.ptrw();
	const float inf = std::numeric_limits<float>::infinity();
	for (int64_t k = 0; k < n; k++) {
		const double ff = IP[k] == 1 ? fraction : 1.0;
		PX[k] = float(lerpd(X0p[k], X1p[k], ff));
		PY[k] = float(lerpd(Y0p[k], Y1p[k], ff));
		PZ[k] = float(lerpd(Z0p[k], Z1p[k], ff));
		// The bar's fill: the trail's, as it scaled a node bar's pivot, interpolated as the engine did
		const double now = FI[k] > 0.001 ? FI[k] : 0.001;
		if (BO[k] == 0) {
			S0[k] = float(now);
		} else if (ticked) {
			S0[k] = S1i[k];
		} else {
			S0[k] = S0i[k];
		}
		S1[k] = float(now);
		SX[k] = float(lerpd(double(S0[k]), now, ff));
		// Where VatCrowd draws its body this frame (INF: hidden)
		if (SH[k] == 0) {
			BOp[k] = Vector3(inf, inf, inf);
		} else if (IP[k] == 0 || !interp_on) {
			BOp[k] = Vector3(X1p[k], Y1p[k], Z1p[k]);
		} else if (synced_now) {
			BOp[k] = Vector3(X0p[k], Y0p[k], Z0p[k]);
		} else {
			BOp[k] = Vector3(PX[k], PY[k], PZ[k]);
		}
	}

	const int64_t sets = set_parts.size();
	PackedInt32Array counts, caps;
	counts.resize(sets);
	caps.resize(sets);
	Array bufs;
	const double disc_y = heights[0], ring_y = heights[1], blob_y = heights[2];
	std::vector<int64_t> pick;
	pick.reserve(size_t(n));
	for (int64_t j = 0; j < sets; j++) {
		const int part = set_parts[j];
		pick.clear();
		for (int64_t k = 0; k < n; k++) {
			bool on = false;
			switch (part) {
				case DISC_PART:
					on = DI[k] == j;
					break;
				case RING_PART:
					on = RI[k] == j;
					break;
				case DAZED_PART:
					on = DO[k] != 0;
					break;
				case BAR_PART:
					on = BO[k] != 0;
					break;
				default:
					on = LO[k] != 0;
					break;
			}
			if (on) {
				pick.push_back(k);
			}
		}
		const int64_t c = int64_t(pick.size());
		// The capacity as the GDScript writer grows it: doubled from max(it, START_CAPACITY) while too small
		int64_t cap = set_caps[j];
		if (c > cap) {
			cap = cap > START_CAPACITY ? cap : START_CAPACITY;
			while (cap < c) {
				cap *= 2;
			}
		}
		PackedFloat32Array buf;
		buf.resize(cap * STRIDE);
		float *B = buf.ptrw();
		for (int64_t q = 0; q < c; q++) {
			const int64_t k = pick[size_t(q)];
			float bx = 1.0f, by = 1.0f, bz = 1.0f;
			double y = PY[k];
			switch (part) {
				case DISC_PART:
					y += disc_y;
					break;
				case RING_PART:
					y += ring_y;
					break;
				case DAZED_PART:
					y += DY[k];
					break;
				case BAR_PART:
					y += BY[k];
					bx = SX[k];
					break;
				default:
					y += blob_y;
					bx = LS[k];
					by = bx;
					bz = bx;
					break;
			}
			float *o = B + q * STRIDE;
			o[0] = bx;
			o[1] = 0.0f;
			o[2] = 0.0f;
			o[3] = PX[k];
			o[4] = 0.0f;
			o[5] = by;
			o[6] = 0.0f;
			o[7] = float(y);
			o[8] = 0.0f;
			o[9] = 0.0f;
			o[10] = bz;
			o[11] = PZ[k];
		}
		for (int64_t q = c * STRIDE; q < cap * STRIDE; q++) {
			B[q] = 0.0f;
		}
		counts.set(j, int32_t(c));
		caps.set(j, int32_t(cap));
		bufs.append(buf);
	}
	out.append(px);
	out.append(py);
	out.append(pz);
	out.append(sx);
	out.append(s0);
	out.append(s1);
	out.append(bo);
	out.append(counts);
	out.append(caps);
	out.append(bufs);
	return out;
}

void ZdCrowd::_bind_methods() {
	ClassDB::bind_method(D_METHOD("write_furniture", "slots", "set_parts", "set_caps", "fraction", "interp_on",
								 "synced_now", "ticked", "heights"),
			&ZdCrowd::write_furniture);
}

} // namespace zd

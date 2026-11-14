// ZdCrowd's avatar calls (zd_crowd.h): the batched enemies' sync, frame step and body instances, over the rows
// zd_avatar.h lays out. One call a sync, one a frame, one for VatCrowd's sets: no call per enemy.

#include "zd_avatar.h"
#include "zd_crowd.h"

#include <algorithm>
#include <cmath>
#include <vector>

#include <godot_cpp/core/error_macros.hpp>

using namespace godot;

namespace zd {

namespace {

// The frame columns (BatchAvatars.frame_columns), read once a call.
struct FrameCols {
	const float *rx = nullptr, *ry = nullptr, *rz = nullptr, *yaw = nullptr, *fx = nullptr;
	const uint8_t *mode = nullptr;
	PackedFloat32Array a, b, c, d, f;
	PackedByteArray m;
	int64_t n = 0;

	bool load(const Array &frame, int64_t slots) {
		if (frame.size() != 6) {
			return false;
		}
		a = frame[0];
		b = frame[1];
		c = frame[2];
		d = frame[3];
		m = frame[4];
		f = frame[5];
		n = slots;
		if (a.size() != n || b.size() != n || c.size() != n || d.size() != n || m.size() != n || f.size() != n * 12) {
			return false;
		}
		rx = a.ptr();
		ry = b.ptr();
		rz = c.ptr();
		yaw = d.ptr();
		mode = m.ptr();
		fx = f.ptr();
		return true;
	}

	av::Frame at(int64_t k) const {
		av::Frame out;
		out.root = Vector3(rx[k], ry[k], rz[k]);
		out.facing_yaw = yaw[k];
		if (mode[k] != 0) {
			const float *o = fx + k * 12;
			out.facing.basis.rows[0] = Vector3(o[0], o[1], o[2]);
			out.facing.basis.rows[1] = Vector3(o[4], o[5], o[6]);
			out.facing.basis.rows[2] = Vector3(o[8], o[9], o[10]);
			out.facing.origin = Vector3(o[3], o[7], o[11]);
		} else { // A facing turned by its rotation only (Node3D: from_euler(rotation) x its unit scale)
			out.facing = Transform3D(av::euler_yxz(Vector3(0.0f, yaw[k], 0.0f)), Vector3());
		}
		return out;
	}
};

bool load_ctx(const PackedFloat64Array &consts, av::Ctx &c) {
	if (consts.size() < 6) {
		return false;
	}
	c.calm = consts[0] != 0.0;
	c.st.spawn = int(consts[1]);
	c.st.move = int(consts[2]);
	c.st.windup = int(consts[3]);
	c.st.active = int(consts[4]);
	c.st.recover = int(consts[5]);
	return true;
}

} // namespace

PackedFloat64Array ZdCrowd::apply_sync(const PackedFloat64Array &state, const PackedInt32Array &cls,
		const Array &frame, const PackedByteArray &pending, int64_t tick, const PackedInt32Array &in_state,
		const PackedByteArray &in_heal, const PackedFloat64Array &in_windup, const PackedFloat32Array &in_x,
		const PackedFloat32Array &in_y, const PackedByteArray &warm, const PackedFloat64Array &consts) const {
	const int64_t n = cls.size();
	FrameCols fc;
	av::Ctx cx;
	if (state.size() != n * av::STRIDE || !fc.load(frame, n) || !load_ctx(consts, cx) || pending.size() != n ||
			in_state.size() != n || in_heal.size() != n || in_windup.size() != n || in_x.size() != n ||
			in_y.size() != n || warm.size() != n) {
		ERR_PRINT("ZdCrowd.apply_sync: wrong columns");
		return state;
	}
	PackedFloat64Array out = state;
	double *S = out.ptrw();
	const int32_t *C = cls.ptr();
	for (int64_t k = 0; k < n; k++) {
		double *s = S + k * av::STRIDE;
		if (pending[k] != 0) {
			av::apply(s, C[k], tick, in_state[k], in_heal[k] != 0, in_windup[k], in_x[k], in_y[k], cx);
		}
		if (warm[k] != 0) {
			const av::Frame f = fc.at(k);
			for (int q = 0; q < 4; q++) {
				av::advance(s, C[k], 0.05, f, cx);
			}
		}
	}
	return out;
}

PackedFloat64Array ZdCrowd::step_avatars(const PackedFloat64Array &state, const PackedInt32Array &cls,
		const Array &frame, const PackedByteArray &proc, const PackedInt32Array &born, int64_t frame_no, double delta,
		const PackedFloat64Array &consts) const {
	const int64_t n = cls.size();
	FrameCols fc;
	av::Ctx cx;
	if (state.size() != n * av::STRIDE || !fc.load(frame, n) || !load_ctx(consts, cx) || proc.size() != n ||
			born.size() != n) {
		ERR_PRINT("ZdCrowd.step_avatars: wrong columns");
		return state;
	}
	PackedFloat64Array out = state;
	double *S = out.ptrw();
	const int32_t *C = cls.ptr();
	const uint8_t *R = proc.ptr();
	const int32_t *B = born.ptr();
	for (int64_t k = 0; k < n; k++) {
		if (R[k] != 0 && B[k] != frame_no) {
			av::process(S + k * av::STRIDE, C[k], delta, fc.at(k), cx);
		}
	}
	return out;
}

Array ZdCrowd::write_bodies(const PackedFloat64Array &state, const PackedInt32Array &cls, const Array &frame,
		const PackedInt32Array &body_of, const PackedInt32Array &shadow_of, const PackedInt64Array &seq,
		const PackedVector3Array &bo, const PackedInt32Array &set_index, const PackedByteArray &body,
		const PackedFloat64Array &period, const PackedInt32Array &dn, const PackedInt32Array &caps,
		const PackedFloat64Array &consts) const {
	Array out;
	const int64_t n = cls.size();
	const int64_t sets = set_index.size();
	FrameCols fc;
	av::Ctx cx;
	if (state.size() != n * av::STRIDE || !fc.load(frame, n) || !load_ctx(consts, cx) || body_of.size() != n ||
			shadow_of.size() != n || seq.size() != n || bo.size() != n || body.size() != sets ||
			period.size() != sets || dn.size() != sets || caps.size() != sets) {
		ERR_PRINT("ZdCrowd.write_bodies: wrong columns");
		return out;
	}
	const double *S = state.ptr();
	const int32_t *C = cls.ptr();
	const int64_t *Q = seq.ptr();
	const Vector3 *BO = bo.ptr();
	// The slots in their add order (VatCrowd's entries are in it)
	std::vector<int64_t> order(static_cast<size_t>(n));
	for (int64_t k = 0; k < n; k++) {
		order[size_t(k)] = k;
	}
	std::sort(order.begin(), order.end(), [Q](int64_t a, int64_t b) { return Q[a] < Q[b]; });
	std::vector<int64_t> pick;
	pick.reserve(size_t(n));
	float d[12];
	for (int64_t j = 0; j < sets; j++) {
		const bool is_body = body[j] != 0;
		const int32_t want = set_index[j];
		const int32_t *of = is_body ? body_of.ptr() : shadow_of.ptr();
		pick.clear();
		int64_t members = 0; // its live entries, drawn or hidden
		for (int64_t k : order) {
			if (of[k] != want) {
				continue;
			}
			members++;
			if (C[k] != av::NONE && !std::isinf(BO[k].x)) {
				pick.push_back(k);
			}
		}
		const int64_t c = int64_t(pick.size());
		const int64_t stride = is_body ? 20 : 12;
		// The capacity as VatCrowd grows it: doubled from max(it, START_CAPACITY) until it holds every live entry
		int64_t cap = caps[j];
		if (members > cap) {
			cap = cap > 32 ? cap : 32;
			while (cap < members) {
				cap *= 2;
			}
		}
		const int64_t dnj = is_body ? dn[j] : 0;
		PackedFloat32Array buf;
		buf.resize(cap * stride);
		float *B = buf.ptrw();
		std::fill(B, B + cap * stride, 0.0f);
		PackedFloat32Array dbuf;
		if (dnj > 0) {
			dbuf.resize(cap * dnj);
			std::fill(dbuf.ptrw(), dbuf.ptrw() + cap * dnj, 0.0f);
		}
		for (int64_t q = 0; q < c; q++) {
			const int64_t k = pick[size_t(q)];
			const double *s = S + k * av::STRIDE;
			const av::Frame f = fc.at(k);
			const Transform3D at(Basis(), BO[k]);
			Transform3D xf = at * f.facing * av::get_xf(s, av::XF);
			if (is_body) {
				xf = av::body_offset(s, C[k], xf);
			}
			float *o = B + q * stride;
			for (int r = 0; r < 3; r++) {
				o[r * 4] = xf.basis.rows[r].x;
				o[r * 4 + 1] = xf.basis.rows[r].y;
				o[r * 4 + 2] = xf.basis.rows[r].z;
			}
			o[3] = xf.origin.x;
			o[7] = xf.origin.y;
			o[11] = xf.origin.z;
			if (!is_body) {
				continue;
			}
			// VatLooks.instance_color(hit_look, glow_energy)
			const double g0 = av::glow_energy(s, C[k]);
			const double g = g0 > 0.0 ? g0 : 0.0;
			const float hw = float(s[av::HIT + 3]);
			o[12] = float(s[av::HIT]);
			o[13] = float(s[av::HIT + 1]);
			o[14] = float(s[av::HIT + 2]);
			o[15] = float(hw > 0.5f ? -1.0 - g : g);
			const int nd = av::drives(s, C[k], period[j], cx, d);
			for (int e = 0; e < 4; e++) {
				o[16 + e] = e < nd ? d[e] : 0.0f;
			}
			float *db = dnj > 0 ? dbuf.ptrw() + q * dnj : nullptr;
			for (int64_t e = 0; e < dnj; e++) {
				db[e] = 4 + e < nd ? d[4 + e] : 0.0f;
			}
		}
		Array one;
		one.append(c);
		one.append(cap);
		one.append(buf);
		one.append(dbuf);
		out.append(one);
	}
	return out;
}

} // namespace zd

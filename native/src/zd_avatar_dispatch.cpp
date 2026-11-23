// The per-class dispatch of a batch row: which avatar's code steps (advance), syncs (apply), lights (glow_energy),
// lifts (body_offset) and drives (drives) a slot, and the height its flinch leans about (flinch_pivot). Each solo
// model kind's own code is its zd_avatar_<kind>.cpp; the horde kinds' and the Chargers' is zd_avatar.cpp.

#include "zd_avatar.h"

using namespace godot;

namespace zd {
namespace av {

namespace {

inline float f32(double v) {
	return float(v);
}

} // namespace

// _flinch_pivot(): the height the flinch leans about (a hovering body about itself: the Lens Drone's 1.3, the
// Bomb Drone's HOVER_Y; 0 for the others).
float flinch_pivot(int cls) {
	return cls == LENS_DRONE ? 1.3f : (cls == BOMB_DRONE ? 1.8f : 0.0f);
}

void advance(double *s, int cls, double delta, const Frame &f, const Ctx &c) {
	if (cls == STONE_THROWER) {
		s_advance(s, delta, c);
	} else if (cls == NEEDLE) {
		n_advance(s, delta, f, c);
	} else if (cls == ROCK_LURKER) {
		l_advance(s, delta, c);
	} else if (cls == WARDEN) {
		w_advance(s, delta, f, c);
	} else if (cls == SNIPER_MODEL) {
		sn_advance(s, delta, f, c);
	} else if (cls == ARC_CASTER) {
		ac_advance(s, delta, f, c);
	} else if (cls == LENS_DRONE) {
		ld_advance(s, delta, c);
	} else if (cls == BOMB_DRONE) {
		bd_advance(s, delta, f, c);
	} else if (cls == SCRAP_HOUND) {
		sh_advance(s, delta, f, c);
	} else if (cls == KILN_BEETLE) {
		kb_advance(s, delta, f, c);
	} else if (cls == CINDER_PRIEST) {
		cp_advance(s, delta, c);
	} else if (cls == FROST_SPITTER) {
		fs_advance(s, delta, f, c);
	} else if (cls == GLACIER_TURTLE) {
		gt_advance(s, delta, f, c);
	} else if (cls == WIRE_WEAVER) {
		ww_advance(s, delta, f, c);
	} else if (cls == GRAVITY_NODE) {
		gn_advance(s, delta, f, c);
	} else if (cls == STAR_WARPER) {
		sw_advance(s, delta, f, c);
	} else if (is_charger(cls)) {
		c_advance(s, delta, c);
	} else if (cls != NONE) {
		h_advance(s, cls, delta, f, c);
	}
}

void apply(double *s, int cls, int64_t tick, int state, bool healing, double windup, float pos_x, float pos_y,
		const double *more, const Ctx &c) {
	if (cls == STONE_THROWER) {
		s_apply(s, tick, state, pos_x, pos_y, more, c);
		return;
	}
	if (cls == NEEDLE) {
		n_apply(s, tick, state, windup, pos_x, pos_y, more, c);
		return;
	}
	if (cls == ROCK_LURKER) {
		l_apply(s, tick, state, windup, pos_x, pos_y, more, c);
		return;
	}
	if (cls == WARDEN) {
		w_apply(s, tick, state, windup, pos_x, pos_y, more, c);
		return;
	}
	if (cls == SNIPER_MODEL) {
		sn_apply(s, tick, state, windup, pos_x, pos_y, more, c);
		return;
	}
	if (cls == ARC_CASTER) {
		ac_apply(s, tick, state, windup, pos_x, pos_y, c);
		return;
	}
	if (cls == LENS_DRONE) {
		ld_apply(s, state, c);
		return;
	}
	if (cls == BOMB_DRONE) {
		bd_apply(s, tick, state, pos_x, pos_y, more, c);
		return;
	}
	if (cls == SCRAP_HOUND) {
		sh_apply(s, tick, state, windup, pos_x, pos_y, more, c);
		return;
	}
	if (cls == KILN_BEETLE) {
		kb_apply(s, tick, state, windup, pos_x, pos_y, more, c);
		return;
	}
	if (cls == CINDER_PRIEST) {
		cp_apply(s, tick, state, pos_x, pos_y, more, c);
		return;
	}
	if (cls == FROST_SPITTER) {
		fs_apply(s, tick, state, windup, pos_x, pos_y, more, c);
		return;
	}
	if (cls == GLACIER_TURTLE) {
		gt_apply(s, tick, state, windup, pos_x, pos_y, more, c);
		return;
	}
	if (cls == WIRE_WEAVER) {
		ww_apply(s, tick, state, windup, pos_x, pos_y, more, c);
		return;
	}
	if (cls == GRAVITY_NODE) {
		gn_apply(s, state, more, c);
		return;
	}
	if (cls == STAR_WARPER) {
		sw_apply(s, tick, state, windup, pos_x, pos_y, more, c);
		return;
	}
	if (is_charger(cls)) {
		c_apply(s, tick, state, windup, pos_x, pos_y, c);
		return;
	}
	if (cls == NONE) {
		return;
	}
	h_apply(s, cls, tick, state, healing, windup, c);
}

double glow_energy(const double *s, int cls) {
	if (cls == STONE_THROWER) {
		return s[S_VISOR];
	}
	if (cls == NEEDLE) {
		return s[N_GEM];
	}
	if (cls == ROCK_LURKER) {
		return s[L_VISOR];
	}
	if (cls == WARDEN) {
		return s[W_CRACK];
	}
	if (cls == SNIPER_MODEL) {
		return s[SN_LENS];
	}
	if (cls == ARC_CASTER) {
		return s[AC_CRYSTAL];
	}
	if (cls == LENS_DRONE) {
		return s[LD_EYE];
	}
	if (cls == BOMB_DRONE) {
		return s[BD_VISOR];
	}
	if (cls == SCRAP_HOUND) {
		return s[SH_GLOW];
	}
	if (cls == KILN_BEETLE) {
		return s[KB_HEAT_GLOW];
	}
	if (cls == CINDER_PRIEST) {
		return s[CP_CRYSTAL];
	}
	if (cls == FROST_SPITTER) {
		return s[FS_SAC_GLOW];
	}
	if (cls == GLACIER_TURTLE) {
		return s[GT_VISOR];
	}
	if (cls == WIRE_WEAVER) {
		return s[WW_SPARK];
	}
	if (cls == GRAVITY_NODE) {
		return s[GN_CORE_GLOW];
	}
	if (cls == STAR_WARPER) {
		return s[SW_SHARD_GLOW];
	}
	return is_charger(cls) ? s[C_VISOR] : s[H_GLOW];
}

Transform3D body_offset(const double *s, int cls, const Transform3D &xf) {
	if (cls == STONE_THROWER) {
		return xf.translated_local(Vector3(0.0f, f32(s[S_LIFT]), 0.0f));
	}
	if (cls == NEEDLE) {
		return xf.translated_local(Vector3(0.0f, f32(s[N_LIFT]), 0.0f));
	}
	if (cls == ROCK_LURKER) {
		return xf.translated_local(Vector3(0.0f, f32(s[L_LIFT]), 0.0f));
	}
	if (cls == WARDEN) {
		return xf.translated_local(Vector3(0.0f, f32(s[W_LIFT]), 0.0f));
	}
	if (cls == SNIPER_MODEL) {
		return xf.translated_local(Vector3(0.0f, f32(s[SN_LIFT]), 0.0f));
	}
	if (cls == ARC_CASTER) {
		return xf.translated_local(Vector3(0.0f, f32(s[AC_LIFT]), 0.0f));
	}
	if (cls == LENS_DRONE) {
		return xf.translated_local(Vector3(0.0f, f32(s[LD_LIFT]), 0.0f));
	}
	if (cls == BOMB_DRONE) {
		return xf.translated_local(Vector3(0.0f, f32(s[BD_LIFT]), 0.0f));
	}
	if (cls == SCRAP_HOUND) {
		return xf.translated_local(Vector3(0.0f, f32(s[SH_LIFT]), 0.0f));
	}
	if (cls == KILN_BEETLE) {
		return xf.translated_local(Vector3(0.0f, f32(s[KB_LIFT]), 0.0f));
	}
	if (cls == CINDER_PRIEST) {
		return xf.translated_local(Vector3(0.0f, f32(s[CP_LIFT]), 0.0f));
	}
	if (cls == FROST_SPITTER) {
		return xf.translated_local(Vector3(0.0f, f32(s[FS_LIFT]), 0.0f));
	}
	if (cls == GLACIER_TURTLE) {
		return xf.translated_local(Vector3(0.0f, f32(s[GT_LIFT]), 0.0f));
	}
	if (cls == WIRE_WEAVER) {
		return xf.translated_local(Vector3(0.0f, f32(s[WW_LIFT]), 0.0f));
	}
	if (cls == GRAVITY_NODE) {
		return xf.translated_local(Vector3(0.0f, f32(s[GN_LIFT]), 0.0f));
	}
	if (cls == STAR_WARPER) {
		return xf.translated_local(Vector3(0.0f, f32(s[SW_LIFT]), 0.0f));
	}
	if (is_charger(cls)) {
		return xf.translated_local(Vector3(0.0f, f32(s[C_LIFT]), 0.0f));
	}
	if (cls == SWARMER && s[H_IS_MODEL] == 0.0) {
		return xf * Transform3D(Basis(), Vector3(0.0f, f32(s[H_LIFT]), 0.0f));
	}
	return xf * get_xf(s, H_BODY);
}

int drives(const double *s, int cls, double period, const Ctx &c, float *out) {
	if (cls == STONE_THROWER) {
		return s_drives(s, out);
	}
	if (cls == NEEDLE) {
		return n_drives(s, out);
	}
	if (cls == ROCK_LURKER) {
		return l_drives(s, out);
	}
	if (cls == WARDEN) {
		return w_drives(s, out);
	}
	if (cls == SNIPER_MODEL) {
		return sn_drives(s, out);
	}
	if (cls == ARC_CASTER) {
		return ac_drives(s, out);
	}
	if (cls == LENS_DRONE) {
		return ld_drives(s, out);
	}
	if (cls == BOMB_DRONE) {
		return bd_drives(s, out);
	}
	if (cls == SCRAP_HOUND) {
		return sh_drives(s, out);
	}
	if (cls == KILN_BEETLE) {
		return kb_drives(s, out);
	}
	if (cls == CINDER_PRIEST) {
		return cp_drives(s, out);
	}
	if (cls == FROST_SPITTER) {
		return fs_drives(s, out);
	}
	if (cls == GLACIER_TURTLE) {
		return gt_drives(s, out);
	}
	if (cls == WIRE_WEAVER) {
		return ww_drives(s, out);
	}
	if (cls == GRAVITY_NODE) {
		return gn_drives(s, out);
	}
	if (cls == STAR_WARPER) {
		return sw_drives(s, out);
	}
	if (is_charger(cls)) {
		return c_drives(s, out);
	}
	return h_drives(s, cls, period, c, out);
}

} // namespace av
} // namespace zd

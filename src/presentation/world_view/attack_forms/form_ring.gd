class_name FormRing
extends RefCounted
## One ring of the RING form as AttackFormCanvas draws it, at its radius now (the RING runner's linear growth: the
## drawn front is the hit front): an element ring through the effects layer (VfxLayer.ring), else the pack's pulse
## held under `key`, else the flat look (a ground-safe fill and a raised front in the heat edge). Presentation only.


## The ring at `c`, radius `r`, `fade` 0..1; the flat look's particle points go into `points`. `go`: a travelling
## ring, so its element effects are held by `key` and follow it as it flies (VfxLayer.ring's `follow`).
static func draw(
	cv: AttackFormCanvas,
	c: Vector3,
	r: float,
	look: Dictionary,
	fade: float,
	points: Array[Vector3],
	key := 0,
	go := false
) -> void:
	r = maxf(r, 0.05)
	var kind := cv._vfx_kind(look)
	if kind != &"":
		var sd := key if go else int(c.x * 97.0) * 31 + int(c.z * 89.0)
		cv.vfx.ring(kind, c, r, fade, cv.vfx.now(), sd, go)
		return
	if key != 0 and cv.forms_pack.ground(key, &"vx2_ring_pulse", c, r * FormPack.RING_PER_M, look):
		return  # (no element here, so no particles: the layer draws every element's)
	cv._put(
		&"ring_fill",
		Transform3D(Basis.from_scale(Vector3(r, 1, r)), c),
		AttackFormCanvas.lit_color(look["ground"], 0.55 * fade, look["energy"])
	)
	cv._put(
		&"ring_front",
		Transform3D(Basis.from_scale(Vector3(r, 0.35 * float(look["width"]), r)), c),
		AttackFormCanvas.lit_color(look["edge"], 0.75 * fade, look["energy"])
	)
	for j in 8:
		points.append(c + Vector3(cos(TAU * j / 8.0), 0.1, sin(TAU * j / 8.0)) * r)

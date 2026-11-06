class_name GapPack
extends RefCounted
## v0.10.0 VX7 (docs/roadmap/v0.9.5/VFX_PACK.md "Gaps built in the pack's style", N2 and N5): the VfxLayer's bleed
## status and void patches in the VFX pack's style (PackFx, data/vfx/pack_fx_vx7.tres). The layer asks first; the old
## sprites draw when there is no PackFx, no room in the effect's family, or the const for the area is false.
## - Bleed (N2): drips held on a bleeding enemy (assets/vfx_zd/bleed/drips.tscn: the poison bubble's splat particles,
##   dark red, falling); the old floor decal under it. v0.10.0 FX (owner: "remove residual ground effects"): the pack's
##   splatter laid on the decal every 2 s is gone (two ground looks for one splat).
## - Void (N5): the rift (a flickering sprite in a patch, tearing open in a blast) is the pack's pulse ring in the void
##   violet. The tendrils keep their sprites; the rift torn along a beam keeps its ribbon.
## Also here: the helpers the views use to find the pack and to draw a pack material on our own meshes. Cosmetic only.

## false: the old look (bleed drips and splash; void rifts).
const PACK_BLEED := true
const PACK_RIFT := false  # v0.10.0 FX: the Void as before VX7 (VoidView.PACK_VOID)
const DRIPS_ID := &"vx7_bleed_drips"
const RIFT_ID := &"vx7_void_rift"
## How often the old floor splat is laid (ticks).
const SPLAT_TICKS := 120.0
## The rift's scale per metre of the patch or blast radius (a pulse ring grows to about 2.2 m).
const RIFT_PER_M := 0.45

## The pack's materials our own meshes wear (copied per use; the vendor files are never edited): the Wave crest's pillar
## sheet and the Nemesis crescent's rim glow.
const MAT_DIR := "res://assets/BinbunVFX/magic_areas/src/material/"
const PILLAR_MAT := MAT_DIR + "pillar_area/pillar_area_01/pillar_area_01_pillar_01.tres"
const RIM_MAT := MAT_DIR + "rim_area/rim_area_04/rim_area_04_upward.tres"

var layer: VfxLayer


func _init(p_layer: VfxLayer) -> void:
	layer = p_layer


## The PackFx of the nearest ancestor that has one (WorldViewRoot's), or null (a view not in a world: the old look).
static func pack_of(node: Node) -> PackFx:
	var n := node
	while n != null:
		var v: Variant = n.get(&"pack_fx")
		if v is PackFx:
			return v as PackFx
		n = n.get_parent()
	return null


## A copy of the pack's material at `path` (a ShaderMaterial of the pack's transparent shader) in `colors` (`primary`,
## `secondary`, `tertiary`), its vertex displacement off (our meshes have the normals of a flat sheet); null without it.
static func material_copy(path: String, colors: Dictionary) -> ShaderMaterial:
	var src := load(path) as ShaderMaterial
	if src == null:
		return null
	var m := src.duplicate() as ShaderMaterial
	m.set_shader_parameter(&"displacement_scale", 0.0)
	colour(m, colors)
	return m


## `colors` (`primary`, `secondary`, `tertiary`) on a pack material.
static func colour(m: ShaderMaterial, colors: Dictionary) -> void:
	for key: StringName in [&"primary", &"secondary", &"tertiary"]:
		if colors.has(key):
			m.set_shader_parameter(StringName(String(key) + "_color"), colors[key])


## A copy of `mesh` (one surface) with its UV's v turned (1 - v): a sheet that is 0 at its foot and 1 at its top runs
## the way the pack's cylinders do (0 at the top).
static func flip_v(mesh: ArrayMesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for k in uvs.size():
		uvs[k] = Vector2(uvs[k].x, 1.0 - uvs[k].y)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## A copy of `mesh` (one surface, no UVs) with UVs from where each vertex lies on the floor: u across z (-1..1), v along
## x (`x0`..`x1`), so a pack material's masks lay over a flat shape (the Nemesis crescent).
static func planar_uv(mesh: Mesh, x0: float, x1: float) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	for k in verts.size():
		uvs[k] = Vector2(
			clampf(0.5 + verts[k].z * 0.5, 0.0, 1.0),
			clampf((verts[k].x - x0) / maxf(x1 - x0, 0.001), 0.0, 1.0)
		)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## The bleed colours of the drips and the splatter: Bleed's core, with its deep red in the shadows.
static func bleed_colors() -> Dictionary:
	var c := ElementLooks.core(&"bleed")
	return {&"primary": c, &"secondary": c, &"tertiary": ElementLooks.deep(&"bleed")}


# --- Bleed (N2) --------------------------------------------------------------------------------------------------
## A bleeding enemy at `p` (its feet), radius `r`, body height `top`: drips running off it (held), the floor splat and
## (each cycle).
func bleed_status(p: Vector3, r: float, top: float, age: float, sd: int, bleed: int) -> void:
	var fx := layer.pack_fx if PACK_BLEED else null
	var packed := false
	if fx != null:
		var at := layer._views.front(p, r * 0.5) + Vector3(0, top * 0.75, 0)
		packed = (
			layer._views.status_holds.touch(
				VfxPackViews.skey(sd, 20), DRIPS_ID, &"status", at, 1.0, bleed_colors()
			)
			!= null
		)
	if not packed:
		layer._drips(p, r, top, age, sd, mini(3, 1 + bleed / 3), VfxLayer.BLOOD)
	var slot := int(age / SPLAT_TICKS)
	var size := 0.35 + r * 0.6
	layer.mark(
		VfxLayer._status_key(sd, 1, slot), VfxLayer._splat(sd + slot), p, size, VfxLayer.BLOOD_MARK
	)


# --- Void (N5) ---------------------------------------------------------------------------------------------------
## A void patch: dark tendrils curling up out of it, a rift flickering open in its middle, a violet glow.
func void_field(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var n := clampi(int(round((2.0 + r * r * 1.5) * layer.density)), 2, 12)
	for k in n:
		var a := TAU * VfxLayer.h(sd, k)
		var d := sqrt(VfxLayer.h(sd + 1, k)) * r * 0.8
		tendril(
			c + Vector3(cos(a) * d, 0, sin(a) * d),
			age,
			sd + k * 3,
			0.9 + 0.6 * VfxLayer.h(sd + 2, k),
			fade,
			60.0
		)
	if not _rift_held(c, r, fade, sd):
		var open := 0.75 + 0.25 * sin(age * 0.2 + sd)
		layer._put(
			&"rift",
			layer._facing(c + Vector3(0, 0.1, 0), r * 0.5 * open, r * 1.1, false),
			Color(VfxLayer.VOID_GLOW * 1.6, fade),
			int(age / 20.0 + sd) % 4,
			0.0,
			VfxLayer.h(sd, 9)
		)
	layer._light(c + Vector3(0, 0.7, 0), VfxLayer.VOID_GLOW, 1.4 * fade, r + 2.5)
	layer.mark(sd * VfxLayer.MARK_KINDS + 4, &"scorch", c, r * 1.1, VfxLayer.VOID_MARK)


## Tendrils curling up along a ring's front.
func void_ring(c: Vector3, r: float, fade: float, age: float, sd: int) -> void:
	var n := clampi(int(r * 3.0 * layer.density), 6, 18)
	for k in n:
		var a := TAU * (k + 0.4 * VfxLayer.h(sd, k)) / n
		tendril(c + Vector3(cos(a), 0, sin(a)) * r, age, sd + k, 0.7, fade, 30.0)
	layer._light(c + Vector3(0, 0.5, 0), VfxLayer.VOID_GLOW, 1.2 * fade, r + 2.0)


## A rift torn along a beam, tendrils where it ends.
func void_line(a: Vector3, b: Vector3, fade: float, age: float, sd: int) -> void:
	var w := 0.8 * (0.85 + 0.15 * sin(age * 0.5 + sd))
	layer._put(
		&"rift",
		layer._ribbon_tall(a, b, w),
		Color(VfxLayer.VOID_GLOW * 1.6, fade),
		int(age / 8.0 + sd) % 4,
		0.0,
		VfxLayer.h(sd, 1)
	)
	for k in 2:
		tendril(Vector3(b.x, 0, b.z), age, sd + k, 0.8, fade, 40.0)
	layer._light(a.lerp(b, 0.5), VfxLayer.VOID_GLOW, 1.5 * fade, a.distance_to(b) * 0.5 + 2.0)


## A void blast: a rift tears open and closes, tendrils lash out, a violet flash, a dark mark.
func void_burst(c: Vector3, r: float, u: float, sd: int) -> void:
	var packed := _rift_shot(c, r, sd)
	var open := clampf(u / 0.15, 0.0, 1.0) * (1.0 - clampf((u - 0.45) / 0.35, 0.0, 1.0))
	if open > 0.0 and not packed:
		layer._put(
			&"rift",
			layer._facing(c, r * 0.6 * open, r * 1.6, false),
			Color(VfxLayer.VOID_GLOW * 2.0, 1.0),
			sd % 4,
			0.0,
			VfxLayer.h(sd, 1)
		)
	var n := int(round(6 * layer.density))
	for k in n:
		var a := TAU * (k + VfxLayer.h(sd + 2, k)) / maxf(n, 1)
		var t := clampf(u * 1.5, 0.0, 1.0)
		var p := c + Vector3(cos(a), 0, sin(a)) * r * 0.9 * t
		tendril(p, u * 70.0, sd + k, 1.1 * (1.0 - u * 0.5), 1.0 - u, 70.0)
	layer._light(
		c + Vector3(0, 0.9, 0), VfxLayer.VOID_GLOW, 5.0 * (1.0 - u) * (1.0 - u), r * 2.5 + 1.5
	)
	layer.mark(sd * VfxLayer.MARK_KINDS + 4, &"scorch", c, r * 1.25, VfxLayer.VOID_MARK)


## A dark tendril curling up from `p` on a `period`-tick cycle, `size` tall.
func tendril(p: Vector3, age: float, sd: int, size: float, fade: float, period: float) -> void:
	var u := fposmod(age + VfxLayer.h(sd, 1) * period, period) / period
	var s := size * (0.7 + 0.5 * u)
	var flip := 1.0 if VfxLayer.h(sd, 5) < 0.5 else -1.0
	var xf := layer._facing(p, s * 0.6 * flip, s, false, (VfxLayer.h(sd, 4) - 0.5) * 0.4)
	layer._put(
		&"tendril",
		xf,
		Color(VfxLayer.VOID_TENDRIL, fade * sin(PI * u)),
		int(VfxLayer.h(sd, 3) * 4.0),
		u * 0.3,
		VfxLayer.h(sd, 6)
	)


## The patch's rift as a held pulse ring; false: no pack or no room (the sprite draws).
func _rift_held(c: Vector3, r: float, fade: float, sd: int) -> bool:
	if not PACK_RIFT or layer.pack_fx == null:
		return false
	var held := layer._views.zone_holds.touch(
		VfxPackViews.zkey(sd, 20, c),
		RIFT_ID,
		&"area",
		Vector3(c.x, 0.05, c.z),
		r * RIFT_PER_M * (0.6 + 0.4 * fade),
		VfxPackViews.kind_colors(&"void", false)
	)
	return held != null


## The blast's rift as a one-shot pulse ring (the first frame its seed is drawn); false: the sprite draws.
func _rift_shot(c: Vector3, r: float, sd: int) -> bool:
	if not PACK_RIFT or layer.pack_fx == null:
		return false
	var views := layer._views
	var mode := views.once(VfxPackViews.bkey(sd, 7), &"area")
	if mode == VfxPackViews.ONCE_OLD:
		return false
	if mode == VfxPackViews.ONCE_SPAWN:
		PackHold.play(
			layer.pack_fx,
			RIFT_ID,
			Vector3(c.x, 0.05, c.z),
			r * RIFT_PER_M,
			VfxPackViews.kind_colors(&"void", false)
		)
	return true

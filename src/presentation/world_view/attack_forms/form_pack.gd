class_name FormPack
extends RefCounted
## v0.10.0 VX2 (VFX_PACK R9, R12, R13): what AttackFormCanvas draws with the pack instead of meshes, split out so the
## canvas stays under the file-length rule: the zones, rings, orbiters and the bomb in flight (held effects named by a
## key, kept on the form each frame: PackHold), the crit and bounce flashes (vfx_hit_04 / vfx_hit_02, once) and the
## trigger cast's sigil (a MagicArea holy circle). Every method returns false when the pack is off or has no room, and
## the canvas then draws the old look. Presentation only (EI-07).

## The pack draws these (false: the old looks, for before/after shots).
const ENABLED := true
## The pack scenes' size per metre: a zone's or ring's radius to the scene's, an orbiter's orb per metre of its
## thickness, the bomb's fire ball, a hit flash per unit of the old flash's size.
const ZONE_PER_M := 1.0
const RING_PER_M := 1.0
const ORBITER_PER_THICK := 5.0
const LOB_SCALE := 0.35
const HIT_PER_SIZE := 0.5
## The trigger sigil: a holy MagicArea circle (pale gold) of this radius (m) holding this long (s); at most this many.
const SIGIL_RADIUS_M := 0.9
const SIGIL_S := 0.3
const SIGILS_MAX := 6

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v if ENABLED else null
var hold := PackHold.new()
var sigils := 0

var _canvas: Node3D


func _init(canvas: Node3D) -> void:
	_canvas = canvas


## A crit's (kind &"crit") or a bounce's (&"bounce") hit flash at `at`, or the trigger cast's sigil (&"sigil").
func flash(at: Vector2, c: Color, size: float, kind: StringName) -> bool:
	if not ENABLED or pack_fx == null or kind == &"":
		return false
	if kind == &"sigil":
		return _sigil(at)
	if not pack_fx.has_room(&"hit"):
		return false
	var crit := kind == &"crit"
	var colors := {
		&"primary": Color.WHITE if crit else c,
		&"secondary": c if crit else c.lerp(Color.WHITE, 0.5),
		&"tertiary": c.darkened(0.25),
	}
	var id := &"vx2_hit_crit" if crit else &"vx2_hit_bounce"
	pack_fx.spawn(id, SimPlane.to_3d(at, AttackFormCanvas.BOLT_H), size * HIT_PER_SIZE, colors)
	return true


## A holy circle on the floor where a trigger casts (each frees itself).
func _sigil(at: Vector2) -> bool:
	if sigils >= SIGILS_MAX:
		return false
	var area := (
		MagicArea
		. add(
			_canvas,
			"holy_circle",
			{
				&"position": SimPlane.to_3d(at, AttackFormCanvas.GROUND_H),
				&"radius": SIGIL_RADIUS_M,
				&"one_shot": true,
				&"duration": SIGIL_S,
				&"appear": 0.1,
				&"light": false,
				&"particles": false,
			}
		)
	)
	sigils += 1
	area.finished.connect(_on_sigil_done)
	return true


func _on_sigil_done() -> void:
	sigils = maxi(0, sigils - 1)


## A pack area effect `id` of `look` held at `c` (the ground), `s` times the scene's size, kept under `key` while it is
## drawn each frame. The colours are the look's elements' (PackLooks), each through ground_safe, so no ground mark leans
## toward the telegraphs' hostile hues.
func ground(seed_key: int, id: StringName, c: Vector3, s: float, look: Dictionary) -> bool:
	if not hold.active():
		return false
	var key := seed_key * 8 + (1 if id == &"vx2_ring_pulse" else 2)
	var cols := {}
	if not hold.has(key):
		cols = PackLooks.colors(PackedStringArray(look["elements"]))
		for k: StringName in cols:
			cols[k] = AttackFormLooks.ground_safe(cols[k])
	return (
		hold.put(key, id, &"area", Transform3D(Basis.from_scale(Vector3.ONE * s), c), cols) != null
	)


## One orbiting body at `p` (thickness `thick`) as the pack's small orb of the look's element, held under `slot`.
func orbiter(slot: int, p: Vector3, thick: float, look: Dictionary) -> bool:
	if slot == 0 or not hold.active():
		return false
	slot = slot * 8 + 3
	var els := PackedStringArray(look["elements"])
	var xf := Transform3D(Basis.from_scale(Vector3.ONE * thick * ORBITER_PER_THICK), p)
	var cols := {} if hold.has(slot) else PackLooks.colors(els)
	var id := PackLooks.id_of("small", ElementLooks.first(els))
	return hold.put(slot, id, &"projectile", xf, cols) != null


## The bomb thrown `from` to `target`, in flight at `p`, as the pack's fire ball (held under where it was thrown).
func lob(from: Vector2, target: Vector2, p: Vector3) -> bool:
	if not hold.active():
		return false
	var key := (
		(roundi(from.x * 50.0) * 31 + roundi(from.y * 50.0) + roundi(target.x * 13.0)) * 8 + 4
	)
	var xf := Transform3D(Basis.from_scale(Vector3.ONE * LOB_SCALE), p)
	return hold.put(key, &"vx2_lob_body", &"projectile", xf) != null

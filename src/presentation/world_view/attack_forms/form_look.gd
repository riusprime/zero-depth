class_name FormLook
extends RefCounted
## v0.9.0 VX V48 (VFX_AUDIT.md: "every view rebuilds a PackedStringArray from the attack spec" each sync): the Gun
## shot's look for a form view, read once per build (WorldReader.attack_digest) instead of every tick. It holds the
## shot's elements, its BeamLooks look, the V2 colours (ElementLooks.pair: the first element's centre, the second's
## edge), the first element and its effects-layer kind (the accents use the first element, V2), and the pattern's
## direction (Halo, Backfire). Presentation only (EI-07).

var digest := ""
var read_once := false
var elements := PackedStringArray()
var look := &"default"
var core := ElementLooks.DEFAULT_HOT
var edge := ElementLooks.DEFAULT_CORE
## The first element (&"" for none), its effects-layer kind (&"" for none) and its deep tone.
var element := &""
var kind := &""
var deep := ElementLooks.DEFAULT_DEEP
## AttackFormLooks.DIR_* of the shot's pattern, and its count and spread (1/4096 turns).
var directions := AttackFormLooks.DIR_FORWARD
var count := 1
var spread := 0


## Reads the Gun shot's look again when the build changed (true when it did).
func refresh(reader: WorldReader) -> bool:
	var d := reader.attack_digest()
	if read_once and d == digest:
		return false
	read_once = true
	digest = d
	var spec := reader.attack_spec(WorldReader.ATTACK_BOLT)
	set_elements(PackedStringArray(spec.get("elements", PackedStringArray())))
	directions = AttackFormLooks.directions_of(spec)
	count = maxi(1, int(spec.get("count", 1)))
	spread = int(spec.get("spread", 0))
	return true


## Sets the look from `els` (the Laser's beam elements; tests).
func set_elements(els: PackedStringArray) -> void:
	elements = els
	look = BeamLooks.look_of(els)
	var p := ElementLooks.pair(els)
	core = p[0]
	edge = p[1]
	element = ElementLooks.first(els)
	kind = ElementLooks.kind(element)
	deep = ElementLooks.deep(element)

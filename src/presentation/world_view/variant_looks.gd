class_name VariantLooks
extends RefCounted
## ENEMIES.md V1-V5: how a biome variant looks. Each is its base's body (WorldReader.body_kind: the
## Rubble Warden the Warden's rock golem, the Dim Needle the Needle's turret, the Ember and Frost Chargers the Charger's
## crawler, the Split Sniper the Sniper's) in its biome's colours over the whole body: its plates, frame and eye
## (EnemyPalettes.VERSIONS, worn through AvatarBase.look_kind), and its other grey parts (legs, fists, joints) cast in
## its body colour (VERSION_CAST) in place of the floor's, so no part keeps its base's look; never drawn by the VAT
## crowd (VatCrowd.supports is false for them). The Rubble Warden also wears its crust: three of the kit's small
## boulders (KitModels boulder_small) on its back and shoulders while WorldReader.crust_on (dress, show_crust). The
## new owner models replace these looks when they come (OWNER_TODO §3.2). Presentation only (EI-07).

## How far a variant's grey parts are pulled toward its body colour (ActorViews.grey_tinted: their light kept).
const VERSION_CAST := 0.8
const CRUST_MODEL := &"boulder_small"
## The crust's rocks on the Warden's body (facing frame: +X front, metres; Warden height 1.25), and their sizes.
const CRUST_SPOTS: Array[Vector3] = [
	Vector3(-0.22, 1.0, 0.0), Vector3(0.05, 0.95, 0.36), Vector3(0.05, 0.95, -0.36)
]
const CRUST_SIZE := 0.42


static func is_variant(kind: int) -> bool:
	return EnemyPalettes.VERSIONS.has(kind)


## The cast a fresh actor of `kind` takes on its grey parts: a variant's body colour, else the floor's (`floor_tint`).
static func cast(kind: int, floor_tint: Color) -> Color:
	if not is_variant(kind):
		return floor_tint
	return Color(EnemyPalettes.color(kind, &"body"), VERSION_CAST)


## Adds the Rubble Warden's crust under `facing` (a node the actor's root keeps as meta "crust"); nothing for any
## other kind, or without the kit's boulder.
static func dress(root: Node3D, facing: Node3D, kind: int) -> void:
	if kind != WorldReader.KIND_RUBBLE_WARDEN:
		return
	var piece := KitModels.get_piece(CRUST_MODEL)
	if piece.is_empty():
		return
	var crust := Node3D.new()
	crust.name = "Crust"
	for k in CRUST_SPOTS.size():
		var mi := MeshInstance3D.new()
		mi.mesh = piece["mesh"]
		mi.material_override = piece["material"]
		mi.position = CRUST_SPOTS[k]
		mi.scale = Vector3.ONE * CRUST_SIZE * (1.0 - 0.12 * k)
		mi.rotation.y = 1.3 * k
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crust.add_child(mi)
	facing.add_child(crust)
	root.set_meta(&"crust", crust)


## Shows or hides actor i's crust as the sim has it (a node without one is left alone).
static func show_crust(node: Node3D, reader: WorldReader, i: int) -> void:
	if node.has_meta(&"crust"):
		(node.get_meta(&"crust") as Node3D).visible = reader.crust_on(i)

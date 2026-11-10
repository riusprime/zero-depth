class_name VariantLooks
extends RefCounted
## ENEMIES.md V1-V5: how a biome variant looks. Each is its base's body (WorldReader.body_kind: the
## Rubble Warden the Warden's rock golem, the Dim Needle the Needle's turret, the Ember and Frost Chargers the Charger's
## crawler, the Split Sniper the Sniper's) with its biome's cast on the grey plates in place of the floor's own
## (ActorViews.tint_greys' rule; the shared-material avatars pick their materials by it), never drawn by the VAT crowd
## (VatCrowd.supports is false for them). The Rubble Warden also wears its crust: three of the kit's small boulders
## (KitModels boulder_small) on its back and shoulders while WorldReader.crust_on (dress, show_crust). The new owner
## models replace these looks when they come (OWNER_TODO §3.2). Presentation only (EI-07).

## Each variant's cast (rgb toward which its grey plates are pulled, by alpha): the Ruins' dust, the Night Rocks' dusk,
## the Red Canyon's embers, the Frozen Shore's ice, the Starfall's violet.
const CASTS := {
	WorldReader.KIND_RUBBLE_WARDEN: Color(0.66, 0.5, 0.34, 0.7),
	WorldReader.KIND_DIM_NEEDLE: Color(0.2, 0.15, 0.32, 0.8),
	WorldReader.KIND_EMBER_CHARGER: Color(1.0, 0.42, 0.16, 0.7),
	WorldReader.KIND_FROST_CHARGER: Color(0.56, 0.82, 1.0, 0.75),
	WorldReader.KIND_SPLIT_SNIPER: Color(0.66, 0.52, 1.0, 0.7),
}
const CRUST_MODEL := &"boulder_small"
## The crust's rocks on the Warden's body (facing frame: +X front, metres; Warden height 1.25), and their sizes.
const CRUST_SPOTS: Array[Vector3] = [
	Vector3(-0.22, 1.0, 0.0), Vector3(0.05, 0.95, 0.36), Vector3(0.05, 0.95, -0.36)
]
const CRUST_SIZE := 0.42


static func is_variant(kind: int) -> bool:
	return CASTS.has(kind)


## The cast a fresh actor of `kind` takes: a variant's own, else the floor's (`floor_tint`).
static func cast(kind: int, floor_tint: Color) -> Color:
	return CASTS.get(kind, floor_tint)


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

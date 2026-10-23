class_name RuneMarkingsView
extends Node3D
## v0.9.0 DX (owner Q29b "Hidden rune markings": "hidden rune markings near secrets go in"; W §5 "Clues to secrets";
## docs/art/requests/v0.9.0_ART_LIST.md §3.2 `rune_marking`): a faint scratched rune on the floor beside each secret's
## doorway (WorldReader.secret_doors: the timed door's, the rune puzzle's, the cracked wall's), on the side you come
## from, that an attentive player notices. Presentation only, placed from the sim's positions: AWAY_M out from the
## wall face and SIDE_M past the doorway's edge. The owner's PNG (TEXTURE) is drawn as a decal when it is installed;
## until then a RuneGlyphs symbol, flat on the floor, nearly transparent (ALPHA).
## v0.9.0 BV (W71): the scratch takes the biome's colour (InteractionLooks "marking"; set `biome` before setup): pale
## on Ruins' sand, a faint mint glow on Night Rocks, soot on Red Canyon, dark blue on Frozen Shore's snow (where a pale
## one vanished), a faint violet glow on Starfall. Still faint: the same ALPHA.

const TEXTURE := "res://assets/textures/decals/rune_marking.png"
const AWAY_M := 1.0
const SIDE_M := 0.7
const SIZE_M := 0.6
const ALPHA := 0.22

## Each marking's spot on the sim plane (tests read them).
var spots := PackedVector2Array()
## v0.9.0 BV: the floor's biome (WorldViewRoot sets it), and the scratch colour drawn.
var biome := &""
var tint := Color(0.92, 0.95, 1.0)


func setup(reader: WorldReader) -> void:
	name = "RuneMarkings"
	var tex: Texture2D = load(TEXTURE) if ResourceLoader.exists(TEXTURE) else null
	tint = InteractionLooks.color(biome, "marking")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint, ALPHA)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var doors := reader.secret_doors()
	for k in doors.size():
		var d: Dictionary = doors[k]
		var into := Kin.dir(int(d["angle"]))
		var side := Vector2(-into.y, into.x)
		var at: Vector2 = (
			d["center"]
			- into * (float(d["depth"]) * 0.5 + AWAY_M)
			+ side * (float(d["width"]) * 0.5 + SIDE_M)
		)
		spots.append(at)
		var node: Node3D
		if tex != null:
			var decal := Decal.new()
			decal.texture_albedo = tex
			decal.size = Vector3(SIZE_M, 0.4, SIZE_M)
			decal.modulate = Color(tint, ALPHA * 2.0)
			node = decal
		else:
			node = RuneGlyphs.build(k % RuneGlyphs.COUNT, SIZE_M, mat)
			node.rotation.x = -PI * 0.5  # flat on the floor, facing up
		node.name = "Marking%d" % k
		node.position = SimPlane.to_3d(at, 0.03)
		add_child(node)

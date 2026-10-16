class_name EmberStone
extends RefCounted
## v0.8.0 MU (owner O14: "we're just throwing away the shard cards"; G2 pick "menu style B", evidence
## docs/roadmap/v0.8.0/evidence/MENU_G2.md): the menus' and the cards' look, "Ember stone". Dark carved stone slabs
## with chipped edges, lit warm from below by embers (StoneBox draws one), a glowing inlay in an element's colour
## (InlaySocket, StoneBox's inlay line and ring), a carved rarity gem (CardMark) and a gold rim inlay on epic and
## legendary things. It matches the HUD's own Ember stone plates (HudStyle.EMBER, v0.5.5 A5) and the world's fire
## light. One table of tokens here; StoneBox, InlaySocket, MenuStyle and the cards read it.
## Presentation only (EI-07): nothing here decides an outcome.

## The warm type, the dim type and the key hints.
const TEXT := Color("#F3E9DD")
const DIM := Color(0.8, 0.72, 0.63, 0.86)
const HINT := Color(0.8, 0.72, 0.63, 0.62)
## The ember glow: the focus, the under-glow, the menus' accent and lines. Kept apart from the heat meter's Hot colour
## (HeatLooks.HOT #FFA63A, saturation 0.77) by its saturation (0.51) and value (MENU_G2 "Known limits": the mockup's
## #F28A3A was too close to it); tests/unit/presentation/test_ember_stone.gd checks the distance.
const EMBER := Color("#EBAE72")
## The stone's fill (before the grain and the light).
const STONE := Color(0.118, 0.104, 0.096)
## The gold rim inlay of an epic or legendary card (and an achievement).
const GOLD := Color("#E8C870")
## The groove's dark (cracks, the socket, the outer edge).
const GROOVE := Color(0.025, 0.018, 0.013)
## The grain texture's size (px); a slab larger than this stretches it.
const GRAIN_PX := 512
## v0.8.0 TX3: the owner's textures (docs/art/requests/v0.8.0_textures.md; scripts/assets/tx3_prep.py): the slabs'
## carved stone grain (`tex_menu_stone`, grey, multiplied in) and the main menu's ember-lit wall
## (`tex_menu_stone_wall`, MenuBackdrop). Without them the code-made looks stay (the grain from noise, the shader's
## stone floor).
const STONE_TEX := "res://assets/textures/ui/tex_menu_stone.png"
const WALL_TEX := "res://assets/textures/ui/tex_menu_stone_wall.png"

static var _grain: Texture2D
static var _wall: Texture2D
static var _wall_tried := false


## The shared stone grain the slabs multiply their colour by (about 0.6 .. 1): the owner's carved stone
## (`tex_menu_stone`) when it is installed, otherwise made once from noise in code (a soft mottle with fine grit).
static func grain() -> Texture2D:
	if _grain != null:
		return _grain
	if ResourceLoader.exists(STONE_TEX):
		_grain = load(STONE_TEX) as Texture2D
		if _grain != null:
			return _grain
	_grain = code_grain()
	return _grain


## Whether the slabs wear the owner's stone (false: the code-made grain).
static func owner_grain() -> bool:
	return grain().resource_path == STONE_TEX


## The code-made grain (the fallback): a grey noise texture, 0.6 .. 1.
static func code_grain() -> Texture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = 20261014
	n.frequency = 0.022
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 7
	n.fractal_lacunarity = 2.4
	n.fractal_gain = 0.62
	var img := n.get_seamless_image(GRAIN_PX, GRAIN_PX)
	img.convert(Image.FORMAT_RGB8)
	img.adjust_bcs(1.6, 0.36, 0.0)
	return ImageTexture.create_from_image(img)


## The main menu's stone wall (null: not installed; MenuBackdrop draws its code-made floor).
static func wall() -> Texture2D:
	if not _wall_tried:
		_wall_tried = true
		if ResourceLoader.exists(WALL_TEX):
			_wall = load(WALL_TEX) as Texture2D
	return _wall


## A stable 0..1 hash of two integers (the slabs' chips and cracks: the same slab looks the same every frame).
static func hash01(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263 + 1442695041) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


## The ember glow's colour at strength `k` (0..1), lighter toward the core.
static func ember(k: float, a: float = 1.0) -> Color:
	return Color(EMBER.lerp(Color("#FFE2BC"), clampf(k, 0.0, 1.0) * 0.35), a)

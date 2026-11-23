class_name GraphicsSettings
extends RefCounted
## The rendering options Options -> Graphics sets: the resolution, the 3D upscaler, the shadow quality, ambient
## occlusion, glow, anti-aliasing and texture filtering. Each default is what the game drew before they existed.
## Engine calls on the window are skipped when headless, so tests never resize one. The look-only flags (shadows,
## ambient occlusion, glow) are read by StageView, which applies them on every change of its lighting.

## Resolutions offered (16:9 and 16:10), smallest first; only those that fit the monitor are listed.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1366, 768),
	Vector2i(1440, 900),
	Vector2i(1600, 900),
	Vector2i(1680, 1050),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(2560, 1440),
	Vector2i(2560, 1600),
	Vector2i(3840, 2160),
]
const NATIVE := "native"
## The size a window takes when "native" is chosen after another size (the project's start size).
const DEFAULT_WINDOW := Vector2i(1600, 900)
const UPSCALERS: Array[String] = ["bilinear", "fsr1", "fsr2"]
const SHADOW_LEVELS: Array[String] = ["off", "low", "medium", "high"]
const ANTI_ALIASING: Array[String] = ["off", "fxaa", "msaa2", "msaa4", "taa"]
const TEXTURE_FILTERS: Array[String] = ["off", "2x", "4x", "8x", "16x"]
## Shadow atlases and soft-shadow filters per level below "high" (high keeps the project's own values).
const SHADOW_TABLE := {
	"low":
	{
		"sun_atlas": 1024,
		"sun_filter": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		"lamp_atlas": 1024,
		"lamp_filter": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	},
	"medium":
	{
		"sun_atlas": 2048,
		"sun_filter": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"lamp_atlas": 2048,
		"lamp_filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	},
}
const ANISOTROPY := {
	"off": Viewport.ANISOTROPY_DISABLED,
	"2x": Viewport.ANISOTROPY_2X,
	"4x": Viewport.ANISOTROPY_4X,
	"8x": Viewport.ANISOTROPY_8X,
	"16x": Viewport.ANISOTROPY_16X,
}

## Read by StageView (the sun's and the torches' shadows, SSAO, glow).
static var shadows := "high"
static var ambient_occlusion := true
static var glow := true
## The anti-aliasing the root window carries; RenderSwitches.apply_viewport re-applies it when the world view builds.
static var anti_aliasing := "off"
## False while the cheap-sun render switch owns the sun's shadow atlas and filter (RenderSwitches.apply_sun).
static var sun_atlas_managed := true
## The resolution the window last took, so "native" resizes only after another size was chosen.
static var _last_resolution := NATIVE


## "1920x1080" as a size, or (0, 0) for "native" and anything unreadable.
static func parse_resolution(value: String) -> Vector2i:
	var parts := value.split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


## The values the resolution row offers on a monitor of `screen` px: "native", then every size that fits, and
## `current` too when it is a saved size this monitor lacks (so the row never silently changes it).
static func resolution_choices(screen: Vector2i, current: String = NATIVE) -> Array[String]:
	var out: Array[String] = [NATIVE]
	for r in RESOLUTIONS:
		if screen.x <= 0 or (r.x <= screen.x and r.y <= screen.y):
			out.append("%dx%d" % [r.x, r.y])
	if current != "" and not out.has(current):
		out.append(current)
	return out


static func screen_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


## Resolution, render scale and upscaler together. Windowed: the window takes the chosen size, centred. Fullscreen:
## the window stays at the monitor's size and the 3D view renders at the chosen one (the 3D scale), so the menus and
## the HUD, drawn in 2D at the monitor's size, stay crisp.
static func apply_display(profile: ProfileStore) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var res := String(GameSettings.get_value(profile, "resolution"))
	var size := parse_resolution(res)
	var scale := float(GameSettings.get_value(profile, "render_scale")) / 100.0
	var upscaler := String(GameSettings.get_value(profile, "upscaler"))
	var fullscreen := String(GameSettings.get_value(profile, "window_mode")) == "fullscreen"
	var screen := screen_size()
	if fullscreen and size != Vector2i.ZERO and screen.x > 0:
		scale *= minf(1.0, minf(float(size.x) / screen.x, float(size.y) / screen.y))
	tree.root.scaling_3d_scale = clampf(scale, 0.25, 1.0)
	tree.root.scaling_3d_mode = _scaling_mode(upscaler)
	if DisplayServer.get_name() == "headless" or fullscreen or res == _last_resolution:
		return
	_last_resolution = res
	var want := size if size != Vector2i.ZERO else DEFAULT_WINDOW
	if screen.x > 0:
		want = Vector2i(mini(want.x, screen.x), mini(want.y, screen.y))
	var screen_id := DisplayServer.window_get_current_screen()
	DisplayServer.window_set_size(want)
	DisplayServer.window_set_position(
		DisplayServer.screen_get_position(screen_id) + (screen - want) / 2
	)


## The stage's environment and sun under the graphics switches: SSAO and SSIL need the lighting quality high and
## ambient occlusion on, glow follows its switch, the sun's shadow follows the shadow level.
static func apply_to_stage(
	env: Environment, sun: DirectionalLight3D, high: bool, mood: BiomeMood
) -> void:
	env.ssao_enabled = high and ambient_occlusion
	env.ssil_enabled = high and mood != null and mood.ssil_enabled and ambient_occlusion
	env.glow_enabled = glow
	if sun != null:
		sun.shadow_enabled = shadows != "off"


## Whether the torches cast shadows: the lighting quality is high and the shadow level is not off.
static func torch_shadows(lighting: String) -> bool:
	return lighting == "high" and shadows != "off"


static func _scaling_mode(upscaler: String) -> Viewport.Scaling3DMode:
	match upscaler:
		"fsr1":
			return Viewport.SCALING_3D_MODE_FSR
		"fsr2":
			return Viewport.SCALING_3D_MODE_FSR2
	return Viewport.SCALING_3D_MODE_BILINEAR


## The shadow level: the engine's atlases and filters here, the lights themselves in StageView.
static func apply_shadows(value: String) -> void:
	shadows = value if SHADOW_LEVELS.has(value) else "high"
	var tree := Engine.get_main_loop() as SceneTree
	var table: Dictionary = SHADOW_TABLE.get(shadows, {})
	var bits16 := bool(
		ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true)
	)
	if sun_atlas_managed:
		RenderingServer.directional_shadow_atlas_set_size(
			table.get("sun_atlas", _project_int("directional_shadow/size", 4096)), bits16
		)
		RenderingServer.directional_soft_shadow_filter_set_quality(
			table.get(
				"sun_filter", _project_int("directional_shadow/soft_shadow_filter_quality", 2)
			)
		)
	RenderingServer.positional_soft_shadow_filter_set_quality(
		table.get("lamp_filter", _project_int("positional_shadow/soft_shadow_filter_quality", 2))
	)
	if tree != null:
		tree.root.positional_shadow_atlas_size = table.get(
			"lamp_atlas", _project_int("positional_shadow/atlas_size", 4096)
		)


static func _project_int(setting: String, fallback: int) -> int:
	return int(ProjectSettings.get_setting("rendering/lights_and_shadows/" + setting, fallback))


## Anti-aliasing on the 3D view of `vp` (the root window only: a tool's own SubViewport keeps its own).
static func apply_anti_aliasing(vp: Viewport) -> void:
	if vp == null or not vp.is_inside_tree() or vp != vp.get_tree().root:
		return
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	match anti_aliasing:
		"fxaa":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"msaa2":
			vp.msaa_3d = Viewport.MSAA_2X
		"msaa4":
			vp.msaa_3d = Viewport.MSAA_4X
		"taa":
			vp.use_taa = true


static func set_anti_aliasing(value: String) -> void:
	anti_aliasing = value if ANTI_ALIASING.has(value) else "off"
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		apply_anti_aliasing(tree.root)


static func apply_texture_filtering(value: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.anisotropic_filtering_level = ANISOTROPY.get(value, Viewport.ANISOTROPY_4X)

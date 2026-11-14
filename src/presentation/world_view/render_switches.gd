class_name RenderSwitches
extends RefCounted
## v0.8.0 HR (owner O89: "optimize performance at maximum without losing the game vibe … if not I'll tell you what to
## discard"): the look-changing performance switches, one each, so the owner can turn any of them off after a
## playtest. Each defaults ON but switch 4 (off: see it); set one to false (and, for the two project settings, the
## line named) to get the old look back. What each changes on screen: docs/roadmap/v0.8.0/evidence/PERF_GRAPHICS.md
## "## HR".
## The same-pixels work of HR (the shared X-ray pass, the shared enemy materials) has no switch: it draws the same.
## Presentation only (EI-07).

## 1. The torches' shadows (StageKit._add_light): dual-paraboloid instead of the six-face cube (2 shadow renders per
## shadowed torch instead of 6). Their shadows can stretch a little near the paraboloid seam. false: the cube again.
const TORCH_DUAL_PARABOLOID := true
## 2. The small floor scatter (rubble, tufts, debris, drifts: the dresser's decoration, all under
## SCATTER_SHADOW_MAX_M tall) casts no shadow (StageKit._add_decor). Walls, cover and props keep theirs. false: the
## scatter casts shadows again.
const SCATTER_NO_SHADOW := true
## Pieces at least this tall (m) keep their shadow even with SCATTER_NO_SHADOW (the dresser caps decoration at 0.4 m).
const SCATTER_SHADOW_MAX_M := 0.6
## 3. No MSAA on the 3D view (the ink pass draws the edges): set on the game's window at run time (apply_viewport)
## and in project.godot (rendering/anti_aliasing/quality/msaa_3d=0). false: 2x MSAA again (the old setting; the
## run-time line restores it without editing project.godot).
const MSAA_OFF := true
## 4. The renderer on its own thread (project.godot rendering/driver/threads/thread_model=2, "Separate"). A project
## setting read at start-up only, so this constant only documents it. OFF (thread_model=1, "Safe"): with it on, the
## horde e2e (tests/e2e/test_e2e_horde_enemies.gd) logged 15 'Parameter "material" is null' engine errors
## (material_get_instance_shader_parameters: an instance reached a material the render thread had not made yet) and
## 0 with it off, the same tree; Godot 4.7.2 also prints at every start that the mode is experimental and "can lead
## to project crashes or instability". The game path has no synchronous read-back of the renderer (VfxCore's one
## get_image cuts the floor marks once, on the load's worker), so that was not the blocker. To try it again: set
## thread_model=2 and this to true (docs/roadmap/v0.8.0/evidence/PERF_GRAPHICS.md "## HR").
const RENDER_THREAD := false
## 5. Every effect, enemy and attack shader drawn once, tiny, behind the loading cover (ShaderWarmup), so the first
## shot, spawn or effect of a floor never compiles one mid-fight. Same pixels. false: compiled on first use again.
const SHADER_WARMUP := true
## 6. No particle system casts a shadow (ParticleShadowOff, under WorldViewRoot and HubView): sparks, smoke, motes
## and the VFX pack's effects stop drawing into the sun's and the torches' shadow passes. false: the scenes' own.
const PARTICLES_NO_SHADOW := true
## 7. Two torches cast shadows at once, not four (StageKit.SHADOW_LIGHTS; set it back to 4 for the old look).
## 8. A cheaper sun shadow, OFF by default so the owner can pick from shots: the project setting CHEAP_SUN_SETTING
## (project.godot [game] render/cheap_sun_shadow=true), or `-- --cheap-sun` on the command line. On, the shadow
## covers only the depth the iso view can show (the camera's near plane CHEAP_SUN_NEAR_M instead of 0.1, the ground
## being 48-72 m away; the shadow's max distance CHEAP_SUN_MAX_M instead of 80), in a CHEAP_SUN_ATLAS atlas (4096
## in project.godot) with CHEAP_SUN_FILTER soft filtering (project.godot: 4, high). Off: the project's values.
const CHEAP_SUN_SETTING := "game/render/cheap_sun_shadow"
const CHEAP_SUN_ARG := "--cheap-sun"
const CHEAP_SUN_NEAR_M := 30.0
const CHEAP_SUN_MAX_M := 76.0
const CHEAP_SUN_ATLAS := 2048
const CHEAP_SUN_FILTER := RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
## The sun's shadow max distance without the cheap sun (StageView._build_light).
const SUN_MAX_M := 80.0
## The iso camera's near plane without the cheap sun (IsoRig).
const CAMERA_NEAR_M := 0.1

## The MSAA the 3D view had before HR (project.godot msaa_3d=2).
const OLD_MSAA := Viewport.MSAA_2X

## Switch 8, read once at start-up (the tests may set it).
static var cheap_sun: bool = (
	bool(ProjectSettings.get_setting(CHEAP_SUN_SETTING, false))
	or OS.get_cmdline_user_args().has(CHEAP_SUN_ARG)
)


## The sun's shadow range under switch 8, and with it on the renderer's directional atlas and soft filter.
static func apply_sun(light: DirectionalLight3D) -> void:
	light.directional_shadow_max_distance = CHEAP_SUN_MAX_M if cheap_sun else SUN_MAX_M
	if not cheap_sun:
		return
	var bits16 := bool(
		ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true)
	)
	RenderingServer.directional_shadow_atlas_set_size(CHEAP_SUN_ATLAS, bits16)
	RenderingServer.directional_soft_shadow_filter_set_quality(CHEAP_SUN_FILTER)


## The iso camera's near plane under switch 8 (the orthographic camera's sun shadow covers near..max distance).
static func camera_near() -> float:
	return CHEAP_SUN_NEAR_M if cheap_sun else CAMERA_NEAR_M


## The game window's 3D MSAA under MSAA_OFF. Only the root window: a tool's own SubViewport keeps the MSAA it set.
static func apply_viewport(vp: Viewport) -> void:
	if vp == null or not vp.is_inside_tree() or vp != vp.get_tree().root:
		return
	vp.msaa_3d = Viewport.MSAA_DISABLED if MSAA_OFF else OLD_MSAA

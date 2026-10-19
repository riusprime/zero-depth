class_name RenderSwitches
extends RefCounted
## v0.8.0 HR (owner O89: "optimize performance at maximum without losing the game vibe … if not I'll tell you what to
## discard"): the look-changing performance switches, one each, so the owner can turn any of them off after a
## playtest. Each defaults ON; set one to false (and, for the two project settings, the line named) to get the old
## look back. What each changes on screen: docs/roadmap/v0.8.0/evidence/PERF_GRAPHICS.md "## HR".
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
## setting read at start-up only, so this constant only documents it: to turn it off set thread_model=1 ("Safe").
## Godot 4.7.2 prints at every start that this mode is experimental and "can lead to project crashes or
## instability"; the game path has no synchronous read-back of the renderer (VfxCore's one get_image cuts the floor
## marks once, on the load's worker). The first switch to drop if the game ever crashes or hitches oddly.
const RENDER_THREAD := true
## 5. Every effect, enemy and attack shader drawn once, tiny, behind the loading cover (ShaderWarmup), so the first
## shot, spawn or effect of a floor never compiles one mid-fight. Same pixels. false: compiled on first use again.
const SHADER_WARMUP := true

## The MSAA the 3D view had before HR (project.godot msaa_3d=2).
const OLD_MSAA := Viewport.MSAA_2X


## The game window's 3D MSAA under MSAA_OFF. Only the root window: a tool's own SubViewport keeps the MSAA it set.
static func apply_viewport(vp: Viewport) -> void:
	if vp == null or not vp.is_inside_tree() or vp != vp.get_tree().root:
		return
	vp.msaa_3d = Viewport.MSAA_DISABLED if MSAA_OFF else OLD_MSAA

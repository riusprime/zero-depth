class_name PerfSceneCensus
extends RefCounted
## What the scene holds, for the perf log's `sc` column (docs/process/PERF_LOG.md): the lights by type and how many
## cast shadows, the particle systems emitting and their particles, the MultiMesh instances, the geometry in the
## tree, how much of it is (probably) transparent, the materials and shaders it uses, the memory, physics and
## navigation, and the views' own counts. One census costs no single frame much: begin() reads the monitors and the
## views; step() walks the tree for at most SLICE_US a frame (a node freed meanwhile is skipped, one added meanwhile
## may be missed); when the walk ends, result() holds the row's value with the census's own cost (`census_us`, summed
## over its frames; `census_begin_us` and `census_slice_max_us` its largest single parts).
##
## Visible means visible in the tree; the camera's culling is not known here. "Transparent" is an estimate: a
## GeometryInstance3D with a transparency, or a material on the alpha pass (a BaseMaterial3D blending alpha, a shader
## that writes ALPHA, blends or reads the screen), or a Sprite3D or Label3D without an alpha cut.

const SLICE_US := 300
const ALPHA_HINTS: Array[String] = [
	"blend_add",
	"blend_sub",
	"blend_mul",
	"blend_premul",
	"hint_screen_texture",
	"depth_draw_always"
]

var busy := false
var _stack: Array[Node] = []
var _c := {}
var _mats := {}
var _shaders := {}
var _shader_alpha := {}
var _cost := 0
var _slice_max := 0
var _result := ""


## Starts a census of `root`'s tree; `view` (may be null) adds the views' counts.
func begin(root: Node, view: WorldViewRoot) -> void:
	var t := Time.get_ticks_usec()
	busy = true
	_c = {}
	_mats = {}
	_shaders = {}
	_result = ""
	for key in ["dir", "omni", "spot"]:
		_c["l_" + key] = 0
		_c["sh_" + key] = 0
	_c["cascades"] = 0
	_stack.clear()
	_stack.append(root)
	_monitors()
	if view != null:
		_views(view)
	_cost = Time.get_ticks_usec() - t
	_c["census_begin_us"] = _cost
	_slice_max = 0


## Works through the list for at most SLICE_US; true when the census is done (result() then holds it).
func step() -> bool:
	if not busy:
		return true
	var t := Time.get_ticks_usec()
	var k := 0
	while not _stack.is_empty():
		var x: Variant = _stack.pop_back()
		if not is_instance_valid(x):
			continue
		var node := x as Node
		_stack.append_array(node.get_children())
		var v := node as VisualInstance3D
		if v != null and v.is_visible_in_tree():
			_visit(v)
		k += 1
		if (k & 15) == 0 and Time.get_ticks_usec() - t >= SLICE_US:
			break
	var dt := Time.get_ticks_usec() - t
	_cost += dt
	_slice_max = maxi(_slice_max, dt)
	if not _stack.is_empty():
		return false
	busy = false
	_c["mats"] = _mats.size()
	_c["shaders"] = _shaders.size()
	_c["census_us"] = _cost
	_c["census_slice_max_us"] = _slice_max
	var parts := PackedStringArray()
	for key: String in _c:
		parts.append("%s=%s" % [key, str(_c[key])])
	_result = ";".join(parts)
	return true


func result() -> String:
	return _result


func _add(key: String, n: int = 1) -> void:
	_c[key] = int(_c.get(key, 0)) + n


func _visit(v: VisualInstance3D) -> void:
	var g := v as GeometryInstance3D
	if g != null:
		_geometry(g)
		return
	var l := v as Light3D
	if l != null:
		_light(l)
	elif v is Decal:
		_add("decals")
	elif v is FogVolume:
		_add("fog_vol")


func _light(l: Light3D) -> void:
	var key := "omni" if l is OmniLight3D else ("spot" if l is SpotLight3D else "dir")
	_add("l_" + key)
	if not l.shadow_enabled:
		return
	_add("sh_" + key)
	var d := l as DirectionalLight3D
	if d != null:
		var splits: int = [1, 2, 4][clampi(d.directional_shadow_mode, 0, 2)]
		_c["cascades"] = maxi(int(_c["cascades"]), splits)
		_c["dir_dist"] = int(d.directional_shadow_max_distance)


func _geometry(g: GeometryInstance3D) -> void:
	_add("geo")
	var alpha := g.transparency > 0.0
	if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		_add("geo_shadow")
	var mesh: Mesh = null
	var gp := g as GPUParticles3D
	var cp := g as CPUParticles3D
	if gp != null:
		if gp.emitting:
			_add("gpup")
			_add("gpup_n", roundi(gp.amount * gp.amount_ratio))
		mesh = gp.draw_pass_1
		_material(gp.process_material)
	elif cp != null:
		if cp.emitting:
			_add("cpup")
			_add("cpup_n", cp.amount)
		mesh = cp.mesh
	elif g is MultiMeshInstance3D:
		var mm := (g as MultiMeshInstance3D).multimesh
		if mm != null:
			_add("mm")
			var shown := mm.visible_instance_count
			_add("mm_n", mm.instance_count if shown < 0 else shown)
			mesh = mm.mesh
	elif g is MeshInstance3D:
		var mi := g as MeshInstance3D
		_add("mesh")
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				alpha = _material(mi.get_active_material(s)) or alpha
		mesh = null
	elif g is SpriteBase3D:
		_add("sprite3d")
		alpha = alpha or (g as SpriteBase3D).alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED
	elif g is Label3D:
		_add("label3d")
		alpha = alpha or (g as Label3D).alpha_cut == Label3D.ALPHA_CUT_DISABLED
	if g.material_override != null:
		alpha = _material(g.material_override) or alpha
	elif mesh != null:
		for s in mesh.get_surface_count():
			alpha = _material(mesh.surface_get_material(s)) or alpha
	if alpha:
		_add("alpha")


## Counts `m` among the materials (and its shader among the shaders); true when it draws on the alpha pass.
func _material(m: Material) -> bool:
	if m == null:
		return false
	_mats[m.get_instance_id()] = true
	var base := m as BaseMaterial3D
	if base != null:
		return (
			base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
			or base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			or base.blend_mode != BaseMaterial3D.BLEND_MODE_MIX
		)
	var sm := m as ShaderMaterial
	if sm == null or sm.shader == null:
		return false
	var sid := sm.shader.get_instance_id()
	_shaders[sid] = true
	if not _shader_alpha.has(sid):
		var code := sm.shader.code
		var a := code.contains("ALPHA =") or code.contains("ALPHA=")
		for h in ALPHA_HINTS:
			a = a or code.contains(h)
		_shader_alpha[sid] = a
	return bool(_shader_alpha[sid])


func _monitors() -> void:
	var mb := 1048576.0
	_c["tex_mb"] = "%.1f" % (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / mb)
	_c["buf_mb"] = "%.1f" % (Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / mb)
	_c["vid_mb"] = "%.1f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / mb)
	_c["static_mb"] = "%.1f" % (Performance.get_monitor(Performance.MEMORY_STATIC) / mb)
	_c["objects"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_c["resources"] = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	_c["orphans"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_c["phys3d"] = int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	_c["phys2d"] = int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
	_c["nav_maps"] = int(Performance.get_monitor(Performance.NAVIGATION_ACTIVE_MAPS))
	_c["nav_us"] = roundi(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1e6)
	_c["pipe_compiles"] = int(
		(
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)
		)
	)
	# The ones made on the main thread when a surface, a mesh or a 2D item first needs its pipeline (a mid-fight one
	# is a 40-160 ms frame, and up to a second with cold caches): counted apart, since pipe_compiles leaves them out.
	_c["pipe_surface"] = int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE))
	_c["pipe_mesh"] = int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))
	_c["pipe_canvas"] = int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))


## The views' counts that explain their sync time: actors drawn as nodes or batched, the critters, the pack effects
## alive per family and the effect layer's pooled sprites in use.
func _views(view: WorldViewRoot) -> void:
	if view.actors != null:
		_c["actor_nodes"] = view.actors.node_count()
		_c["actor_batched"] = view.actors.batched_count()
		_c["critters"] = view.actors.critters.count() if view.actors.critters != null else 0
	if view.pack_fx != null:
		_c["pack"] = view.pack_fx.live_count()
		for f: StringName in PackFx.CAPS:
			var n := view.pack_fx.live_count(f)
			if n > 0:
				_c["pack." + String(f)] = n
	if view.attack_forms != null:
		_c["forms_meshes"] = view.attack_forms.meshes_drawn()
		_c["forms_particles"] = view.attack_forms.particles_drawn()
		var layer: VfxLayer = view.attack_forms.vfx
		if layer != null:
			var used := 0
			for id: StringName in layer.pools:
				used += layer.used(id)
			_c["vfx_used"] = used


## The display and Graphics options in force, for the `cfg` column (written when it changes): the window and the 3D
## render size and scaler, vsync and the frame cap, the anti-aliasing, the shadow atlases, the environment's effects
## (SSAO, SSIL, SSR, glow, SDFGI, fog, volumetric fog), the renderer and adapter, and the player's Graphics options.
static func config_string(root: Window, gpu_passes: bool) -> String:
	var c := {}
	c["window"] = "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	c["viewport"] = "%dx%d" % [root.size.x, root.size.y]
	c["scale3d"] = "%.2f" % root.scaling_3d_scale
	c["scaler"] = ["bilinear", "fsr", "fsr2", "metalfx_spatial", "metalfx_temporal"][clampi(
		root.scaling_3d_mode, 0, 4
	)]
	c["render3d"] = (
		"%dx%d"
		% [roundi(root.size.x * root.scaling_3d_scale), roundi(root.size.y * root.scaling_3d_scale)]
	)
	c["vsync"] = ["off", "on", "adaptive", "mailbox"][clampi(
		DisplayServer.window_get_vsync_mode(), 0, 3
	)]
	c["max_fps"] = Engine.max_fps
	c["refresh"] = "%.0f" % DisplayServer.screen_get_refresh_rate()
	c["msaa3d"] = root.msaa_3d
	c["fxaa"] = int(root.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA)
	c["taa"] = int(root.use_taa)
	c["aniso"] = root.anisotropic_filtering_level
	c["pos_atlas"] = root.positional_shadow_atlas_size
	c["dir_atlas"] = int(
		GraphicsSettings.SHADOW_TABLE.get(GraphicsSettings.shadows, {}).get(
			"sun_atlas",
			ProjectSettings.get_setting(
				"rendering/lights_and_shadows/directional_shadow/size", 4096
			)
		)
	)
	var env := _environment(root)
	if env != null:
		c["ssao"] = int(env.ssao_enabled)
		c["ssil"] = int(env.ssil_enabled)
		c["ssr"] = int(env.ssr_enabled)
		c["glow"] = int(env.glow_enabled)
		c["sdfgi"] = int(env.sdfgi_enabled)
		c["fog"] = int(env.fog_enabled)
		c["vfog"] = int(env.volumetric_fog_enabled)
		c["tonemap"] = env.tonemap_mode
	c["method"] = RenderingServer.get_current_rendering_method()
	c["adapter"] = RenderingServer.get_video_adapter_name().replace(",", " ").replace(";", " ")
	c["gpu_passes"] = int(gpu_passes)
	var profile := ProfileStore.shared()
	for key in [
		"window_mode",
		"resolution",
		"render_scale",
		"upscaler",
		"shadows",
		"ambient_occlusion",
		"glow",
		"anti_aliasing",
		"texture_filtering",
		"vsync",
		"frame_cap",
		"lighting",
		"outline",
		"effects_density",
		"enemy_shadows",
		"enemy_vat"
	]:
		c["opt." + key] = str(GameSettings.get_value(profile, key))
	var parts := PackedStringArray()
	for k: String in c:
		parts.append("%s=%s" % [k, str(c[k])])
	return ";".join(parts)


## The 3D world's environment (a WorldEnvironment's), or the current camera's own.
static func _environment(root: Window) -> Environment:
	var world := root.find_world_3d()
	if world != null and world.environment != null:
		return world.environment
	var cam := root.get_camera_3d()
	if cam != null and cam.environment != null:
		return cam.environment
	return world.fallback_environment if world != null else null

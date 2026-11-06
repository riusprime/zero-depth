extends SceneTree
## v0.10.5 W3-V1 (the enemy VAT pilot): bakes the pilot kind's pose code (VatBake, as the game does) and measures how
## far the baked pose is from the live one: over SAMPLES random drive sets (the windup raise, the strike, the crouch,
## the clock, the rise-in) the real avatar is posed by its own code (HordeAvatar.pose_at) and every vertex compared,
## in metres, with the same vertex posed through the baked texture the way the shader samples it (VatBake.eval_*,
## the shader's arithmetic on the CPU). Run twice: normal and reduced motion. Headless is fine (no renderer needed):
##   APPDATA=<temp> godot --headless --path . -s scripts/checks/vat_bake_report.gd [-- --samples=4000]
## Writes build/vat/<sha>_bake.txt (never into docs) and prints it. The GPU's own sampling is checked by the
## side-by-side shots (scripts/shots/vat_sheet.gd), not here.

const OUT_DIR := "res://build/vat/"
const SEED := 4404

var _samples := 4000


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--samples="):
			_samples = int(a.trim_prefix("--samples="))
	var sha := "nosha"
	var git: Array = []
	if OS.execute("git", ["rev-parse", "--short", "HEAD"], git) == 0 and git.size() > 0:
		sha = String(git[0]).strip_edges()
	var lines: PackedStringArray = []
	lines.append("vat bake report  sha=%s  godot=%s" % [sha, Engine.get_version_info()["string"]])
	lines.append(
		(
			"grids: stance %s (wind x strike x crouch), gait %d samples a loop"
			% [VatBake.STANCE_N, VatBake.GAIT_N]
		)
	)
	for kind: int in VatCrowd.KINDS:
		lines.append_array(_report(kind))
	var text := "\n".join(lines) + "\n"
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f := FileAccess.open(
		ProjectSettings.globalize_path(OUT_DIR + "%s_bake.txt" % sha), FileAccess.WRITE
	)
	if f != null:
		f.store_string(text)
		f.close()
	quit(0)


func _report(kind: int) -> PackedStringArray:
	var out: PackedStringArray = []
	VatBake.clear_cache()
	var t0 := Time.get_ticks_usec()
	var pose := VatBake.pose_for(kind)
	var t_pose := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var mesh := VatBake.mesh_for(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var t_mesh := (Time.get_ticks_usec() - t0) / 1000.0
	var img: Image = pose["image"]
	var live := VatBake.reference(kind, Color(0, 0, 0, 0), 0.0, Color.BLACK)
	var vat := HordeAvatar.new()
	vat.vat = true
	vat.setup(kind, Color.BLACK)
	var js := VatBake.joints(live)
	(
		out
		. append(
			(
				"kind %d: %d joints, %d vertices, %d triangles, pose texture %dx%d RGBAF (%d KiB)"
				% [
					kind,
					js.size(),
					mesh.surface_get_array_len(0),
					mesh.surface_get_array_index_len(0) / 3,
					img.get_width(),
					img.get_height(),
					img.get_data().size() / 1024,
				]
			)
		)
	)
	out.append("  bake ms (this machine, once a session): poses %.1f, mesh %.1f" % [t_pose, t_mesh])
	for calm: bool in [false, true]:
		ViewPrefs.reduced_motion = calm
		var e := VatBake.pose_error(live, vat, pose, mesh, _samples, SEED)
		(
			out
			. append(
				(
					"  reduced_motion=%s samples=%d vertices/sample=%d  max_error_m=%.6f  mean_error_m=%.7f"
					% [calm, e["samples"], e["vertices"], e["max_m"], e["mean_m"]]
				)
			)
		)
		out.append("    worst at %s" % [e["worst"]])
	ViewPrefs.reduced_motion = false
	live.free()
	vat.free()
	return out

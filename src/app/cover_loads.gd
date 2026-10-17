class_name CoverLoads
extends RefCounted
## v0.8.0 N3 (owner O45: "we have to add loading screens so the game does not freeze when you start the game and take a
## portal"; docs/roadmap/v0.8.0/evidence/N3_RING_AND_LOADING.md): how Main runs a floor load behind the LoadingCover.
## - behind(): a load from a menu (a new run, Continue, Restart): the screen goes black with the corner mark at once,
##   COVER_FRAMES frames draw it, then the work (the floor build) runs and the cover fades out on what it built;
## - closing(): each tick of the hero's way into a portal that leads to another floor, the portal's iris closes;
## - portal(): the portal was taken: the iris closes all the way, the old floor holds, one frame draws the closed
##   cover, then the next floor loads under it (Main._floor_live opens it on the new floor).
## A load asked while another waits or runs is dropped (a second press of Play, Continue or Restart).
## v0.8.0 N12 (owner O70: "the loading screens still freeze the game … it should be like a surely animation where
## things move and then open it, but never stop moving or freezing"; evidence/LOADS_NO_FREEZE.md): the work never
## holds a frame: on_worker() runs the World's build on a WorkerThreadPool task and build_view() runs the view's
## build in slices of VIEW_BUDGET_MS a frame (ViewBuildQueue), so the cover and its mark are drawn moving on every
## frame of the load. `phases` keeps the last load's timings (ms) and `frames` its frames, for the load probe.

## v0.8.0 N12: a load behind the cover finished (the new floor is live, its first tick not yet stepped).
signal finished

const COVER_FRAMES := 2
## The iris starts closing at this part of the hero's way in (BossFlow's enter progress).
const PORTAL_COVER_FROM := 0.55
## v0.8.0 N12: the view's build takes about this much of each frame (a job is never cut; the longest are ~30-45 ms).
const VIEW_BUDGET_MS := 6.0
## v0.8.0 N12: an old floor's view (thousands of nodes; ~100 ms to free in one frame) is freed this long a frame.
const FREE_BUDGET_MS := 4.0

var cover := LoadingCover.new()
var waiting := false
## v0.8.0 N12: the last load's timings in ms (the World on its worker, each view job, the longest view job) and the
## frames drawn while it ran.
var phases := {}
var frames := 0
var _running := false


## A load waits for its cover or is running.
func busy() -> bool:
	return waiting or _running


## Covers the screen black now, lets COVER_FRAMES frames draw it, then runs `work` (awaited: a load over frames) and
## fades out over `fade_s`.
func behind(tree: SceneTree, ui: Node, work: Callable, fade_s: float) -> void:
	if busy():
		return
	waiting = true
	cover.cover_now(LoadingCover.Style.BLACK)
	ui.move_child(cover, ui.get_child_count() - 1)
	for k in COVER_FRAMES:
		await tree.process_frame
	waiting = false
	await _run(work)
	cover.unveil(fade_s)  # a floor that started has begun its unveil already; a failed Continue's menu shows too


## The hero's way into a portal (one tick): the iris closes in the portal's style, when a floor load follows.
func closing(reader: WorldReader) -> void:
	var going := reader.portal_enter_progress()
	if going >= 0.0 and reader.portal_loads():
		cover.set_closing(
			LoadingCover.portal_style(reader),
			(going - PORTAL_COVER_FROM) / (1.0 - PORTAL_COVER_FROM)
		)


## The portal was taken: closes the cover, holds `driver`, waits one drawn frame, then runs `next` (the next floor,
## awaited) unless the floor was left meanwhile (`still` false).
func portal(tree: SceneTree, ui: Node, driver: SimDriver, next: Callable, still: Callable) -> void:
	if busy():
		return
	waiting = true
	driver.paused = true
	cover.set_closing(LoadingCover.portal_style(driver.reader), 1.0)
	ui.move_child(cover, ui.get_child_count() - 1)
	await tree.process_frame
	waiting = false
	if still.call():
		await _run(next)


## v0.8.0 N12: runs `job` (pure work: FloorPlan.build) on a WorkerThreadPool task; the frames go on until it is done.
func on_worker(tree: SceneTree, job: Callable, label: String) -> void:
	var from := Time.get_ticks_usec()
	var id := WorkerThreadPool.add_task(job, true, label)
	while not WorkerThreadPool.is_task_completed(id):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(id)
	phases[label] = (Time.get_ticks_usec() - from) / 1000.0


## v0.8.0 N12: runs the view's build queue VIEW_BUDGET_MS a frame until it is done, then lets one frame draw before
## the floor goes live (the HUD and the input are made in a frame of their own).
func build_view(tree: SceneTree, q: ViewBuildQueue) -> void:
	var from := Time.get_ticks_usec()
	while not q.step(VIEW_BUDGET_MS):
		await tree.process_frame
	await tree.process_frame
	for k: String in q.ms:
		phases["view:" + k] = q.ms[k]
	phases["view_longest_job"] = q.longest_ms
	phases["view_longest_step"] = q.longest_step_ms
	phases["view_frames"] = q.steps
	phases["view"] = (Time.get_ticks_usec() - from) / 1000.0


## v0.8.0 N12: frees `root` (out of the tree already) FREE_BUDGET_MS a frame, its deepest nodes first.
func free_slowly(tree: SceneTree, root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var from := Time.get_ticks_usec()
		while not stack.is_empty() and (Time.get_ticks_usec() - from) / 1000.0 < FREE_BUDGET_MS:
			var n: Node = stack.back()
			if n.get_child_count() > 0:
				var c := n.get_child(n.get_child_count() - 1)
				n.remove_child(c)
				stack.append(c)
			else:
				stack.pop_back()
				n.free()
		await tree.process_frame


func _run(work: Callable) -> void:
	_running = true
	phases = {}
	var from := Time.get_ticks_usec()
	var start_frame := Engine.get_process_frames()
	await work.call()
	frames = Engine.get_process_frames() - start_frame
	phases["total"] = (Time.get_ticks_usec() - from) / 1000.0
	_running = false
	finished.emit()

class_name CoverLoads
extends RefCounted
## v0.8.0 N3 (owner O45: "we have to add loading screens so the game does not freeze when you start the game and take a
## portal"; docs/roadmap/v0.8.0/evidence/N3_RING_AND_LOADING.md): how Main runs a floor load behind the LoadingCover.
## - behind(): a load from a menu (a new run, Continue, Restart): the screen goes black with the corner mark at once,
##   COVER_FRAMES frames draw it, then the work (the floor build) runs and the cover fades out on what it built;
## - closing(): each tick of the hero's way into a portal that leads to another floor, the portal's iris closes;
## - portal(): the portal was taken: the iris closes all the way, the old floor holds, one frame draws the closed
##   cover, then the next floor loads under it (Main._start_floor opens it on the new floor).
## A load asked while another waits is dropped (a second press of Play, Continue or Restart).

const COVER_FRAMES := 2
## The iris starts closing at this part of the hero's way in (BossFlow's enter progress).
const PORTAL_COVER_FROM := 0.55

var cover := LoadingCover.new()
var waiting := false


## Covers the screen black now, lets COVER_FRAMES frames draw it, then runs `work` and fades out over `fade_s`.
func behind(tree: SceneTree, ui: Node, work: Callable, fade_s: float) -> void:
	if waiting:
		return
	waiting = true
	cover.cover_now(LoadingCover.Style.BLACK)
	ui.move_child(cover, ui.get_child_count() - 1)
	for k in COVER_FRAMES:
		await tree.process_frame
	waiting = false
	work.call()
	cover.unveil(fade_s)  # a floor that started has begun its unveil already; a failed Continue's menu shows too


## The hero's way into a portal (one tick): the iris closes in the portal's style, when a floor load follows.
func closing(reader: WorldReader) -> void:
	var going := reader.portal_enter_progress()
	if going >= 0.0 and reader.portal_loads():
		cover.set_closing(
			LoadingCover.portal_style(reader),
			(going - PORTAL_COVER_FROM) / (1.0 - PORTAL_COVER_FROM)
		)


## The portal was taken: closes the cover, holds `driver`, waits one drawn frame, then runs `next` (the next floor)
## unless the floor was left meanwhile (`still` false).
func portal(tree: SceneTree, ui: Node, driver: SimDriver, next: Callable, still: Callable) -> void:
	if waiting:
		return
	waiting = true
	driver.paused = true
	cover.set_closing(LoadingCover.portal_style(driver.reader), 1.0)
	ui.move_child(cover, ui.get_child_count() - 1)
	await tree.process_frame
	waiting = false
	if still.call():
		next.call()

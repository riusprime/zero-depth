class_name ViewBuildQueue
extends RefCounted
## v0.8.0 N12 (owner O70: "the loading screens still freeze the game … it should be like a surely animation where
## things move and then open it, but never stop moving or freezing"; docs/roadmap/v0.8.0/evidence/LOADS_NO_FREEZE.md):
## a floor's view built as a queue of jobs, so a load can spread it over frames while the loading cover keeps moving.
## - add(): a main-thread job (it may make nodes); add_worker(): pure work (no node, no scene tree, nothing a frame
##   reads) that runs on a WorkerThreadPool task while the frames go on; the next job waits for it.
## - add_next(): from inside a running job, a job that runs right after it (a build that learns its own parts as it
##   goes: each room's crystals, each piece of a wall mesh), in the order added.
## - step(budget_ms): runs main-thread jobs until the budget is spent (a job is never cut: one longer than the budget
##   runs alone in its frame), or starts / waits on a worker job; true when the queue is done. CoverLoads calls it
##   once a frame behind the cover.
## - run_all(): every job now, in order, on the calling thread (a worker job too): the one-call build the tools, the
##   tests and WorldViewRoot.setup() use. The jobs and their order are the same either way, so a view built in slices
##   is the view built in one call.
## Any view builder can join the queue (StageView's parts, a wall-mesh builder): it only adds jobs.

## v0.8.0 MI (the load probe's frame breakdown): the frame the last step() ran on, how long it took and which jobs
## ran in it (a tool reads them; nothing in the game does).
static var probe_frame := -1
static var probe_step_ms := 0.0
static var probe_jobs := PackedStringArray()

## Milliseconds per job name (summed when a name repeats), and the longest single main-thread job.
var ms := {}
var longest_ms := 0.0
var longest := ""
## Frames step() was called on (the frames the build was spread over), and the longest time one call took.
var steps := 0
var longest_step_ms := 0.0
var _jobs: Array[Dictionary] = []
var _next := 0
var _insert_at := -1
var _task := -1
var _task_from := 0
var _task_name := ""


func add(job_name: String, job: Callable) -> void:
	_push({"name": job_name, "job": job, "worker": false})


func add_worker(job_name: String, job: Callable) -> void:
	_push({"name": job_name, "job": job, "worker": true})


## From inside a running job: `job` runs right after it (after any added before it the same way).
func add_next(job_name: String, job: Callable) -> void:
	_insert(job_name, job, false)


func add_next_worker(job_name: String, job: Callable) -> void:
	_insert(job_name, job, true)


func done() -> bool:
	return _next >= _jobs.size() and _task < 0


func size() -> int:
	return _jobs.size()


## Runs jobs for about `budget_ms` of this frame; true when every job ran.
func step(budget_ms: float) -> bool:
	steps += 1
	var from := Time.get_ticks_usec()
	probe_jobs = PackedStringArray()
	var out := _step(budget_ms, from)
	var took := (Time.get_ticks_usec() - from) / 1000.0
	longest_step_ms = maxf(longest_step_ms, took)
	probe_frame = Engine.get_process_frames()
	probe_step_ms = took
	return out


func _step(budget_ms: float, from: int) -> bool:
	while true:
		if _task >= 0:  # a worker job may still be adding jobs: the list is not read until it is done
			if not WorkerThreadPool.is_task_completed(_task):
				probe_jobs.append("wait:" + _task_name)
				return false
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
			_insert_at = -1
			_note(_task_name, _task_from, false)
			_next += 1
			continue
		if _next >= _jobs.size():
			break
		var j := _jobs[_next]
		if j["worker"]:
			_task_from = Time.get_ticks_usec()
			_task_name = j["name"]
			_insert_at = _next + 1
			_task = WorkerThreadPool.add_task(j["job"], true, j["name"])
			return false
		_run(j)
		if (Time.get_ticks_usec() - from) / 1000.0 >= budget_ms:
			break
	return done()


## Every job left, now and on this thread.
func run_all() -> void:
	while _next < _jobs.size():
		_run(_jobs[_next])


func _run(j: Dictionary) -> void:
	var t := Time.get_ticks_usec()
	_insert_at = _next + 1
	(j["job"] as Callable).call()
	_insert_at = -1
	_note(j["name"], t, not j["worker"])
	probe_jobs.append("%s:%.0f" % [j["name"], (Time.get_ticks_usec() - t) / 1000.0])
	_next += 1


func _push(j: Dictionary) -> void:
	_jobs.append(j)


func _insert(job_name: String, job: Callable, worker: bool) -> void:
	if _insert_at < 0:  # not inside a job: at the end
		_push({"name": job_name, "job": job, "worker": worker})
		return
	_jobs.insert(_insert_at, {"name": job_name, "job": job, "worker": worker})
	_insert_at += 1


func _note(job_name: String, since: int, main_thread: bool) -> void:
	var took := (Time.get_ticks_usec() - since) / 1000.0
	ms[job_name] = float(ms.get(job_name, 0.0)) + took
	if main_thread and took > longest_ms:
		longest_ms = took
		longest = job_name

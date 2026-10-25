class_name HubPortalWalk
extends RefCounted
## v0.9.0 HB2 (owner: "there is no animation when taking the portal, you should click, choose weapon and then the
## character walks upstairs towards the portal and crosses it"): the hero's short scripted walk from where it stands
## at the Portal Machine, round to the front of its steps if needed, up the steps and through the ring. The portal
## flares as the hero reaches the dais; the hero shrinks into the light as it crosses. About 2-3 s: the walk's speed
## rises so it never takes more than MAX_WALK_S, the crossing and the flare's hold are fixed.
## Presentation and app flow only (EI-07): a path sampled in frame time (HubView moves the hero's node along it while
## the hub's World holds); nothing here reaches the sim, and the run starts as before once the hero is through.

## The hero's walking pace up the steps (m/s; a little under the run's walk, a deliberate climb) and the longest the
## walk may take (s; a hero far round the machine walks faster).
const SPEED := 2.6
const MAX_WALK_S := 2.2
## The crossing: the hero shrinks into the ring over CROSS_S, then the flare holds HOLD_S before the run's load.
const CROSS_S := 0.35
const HOLD_S := 0.35
## How long the flare takes to rise (s, before the hero reaches the ring).
const FLARE_RISE_S := 0.5
## Round the machine: a hero north of this plan y walks round its side at this distance from the centre (m).
const ROUND_Y := -2.2
const ROUND_M := 3.6

## The path: plan points with their height (x, y: plan m; z: m up), from the hero to just past the ring.
var points: Array[Vector3] = []
## Where along the path (m) each point lies, and the walk's length to the ring's plane (m).
var marks: Array[float] = []
var to_ring := 0.0
var speed := SPEED
## Seconds since the walk began.
var t := 0.0


## `from`: the hero's plan point; `climb`: HubMachine.walk_points() (the steps' foot, their top, the ring, past it).
func _init(from: Vector2, climb: Array[Vector3]) -> void:
	points.append(Vector3(from.x, from.y, 0.0))
	var round_it := from.y > ROUND_Y
	if round_it:  # north of the steps: round the machine's nearer side first
		var side := 1.0 if from.x >= 0.0 else -1.0
		if from.y > 0.5:
			points.append(Vector3(side * ROUND_M, 0.0, 0.0))
		points.append(Vector3(side * ROUND_M * 0.75, climb[0].y - 0.3, 0.0))
	for k in climb.size():
		if k == 0 and not round_it and from.y > climb[0].y and absf(from.x) < 1.0:
			continue  # already on the steps' line: straight up
		points.append(climb[k])
	marks.append(0.0)
	for k in range(1, points.size()):
		marks.append(marks[k - 1] + _flat(points[k - 1]).distance_to(_flat(points[k])))
	to_ring = marks[points.size() - 2]
	speed = maxf(SPEED, to_ring / MAX_WALK_S)


## The whole walk's length (s): the walk to the ring, the crossing, the hold.
func duration() -> float:
	return to_ring / speed + CROSS_S + HOLD_S


func done() -> bool:
	return t >= duration()


## The hero's plan point now.
func plan_point() -> Vector2:
	return _flat(_at(_dist()))


## The hero's height over the floor now (m).
func height() -> float:
	return _at(_dist()).z


## The way the hero walks now (plan, unit).
func heading() -> Vector2:
	var d := _dist()
	var ahead := _flat(_at(minf(d + 0.2, marks[marks.size() - 1])))
	var here := _flat(_at(maxf(d - 0.05, 0.0)))
	var v := ahead - here
	return v.normalized() if v.length() > 0.0001 else Vector2(0, 1)


## How far the hero has shrunk into the light (0 whole .. 1 gone).
func shrink() -> float:
	return clampf((t - to_ring / speed) / CROSS_S, 0.0, 1.0)


## The portal's flare (0 .. 1): it rises over FLARE_RISE_S as the hero nears the ring and stays up.
func flare() -> float:
	var rise_at := to_ring / speed - FLARE_RISE_S
	return clampf((t - rise_at) / FLARE_RISE_S, 0.0, 1.0)


## The walk's progress for the camera's ease (0 .. 1, eased in and out).
func ease_k() -> float:
	return smoothstep(0.0, 1.0, clampf(t / maxf(0.01, duration() - HOLD_S), 0.0, 1.0))


## How far along the path (m) the hero is now: walking to the ring, then on through it while it shrinks.
func _dist() -> float:
	var walked := t * speed
	if walked <= to_ring:
		return walked
	return minf(to_ring + (marks[marks.size() - 1] - to_ring) * shrink(), marks[marks.size() - 1])


## The path's point `d` m along.
func _at(d: float) -> Vector3:
	for k in range(1, points.size()):
		if d <= marks[k] or k == points.size() - 1:
			var span := maxf(0.0001, marks[k] - marks[k - 1])
			return points[k - 1].lerp(points[k], clampf((d - marks[k - 1]) / span, 0.0, 1.0))
	return points[points.size() - 1]


static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.y)

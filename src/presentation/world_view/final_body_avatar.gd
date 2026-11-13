class_name FinalBodyAvatar
extends BossAvatar
## The base of the final boss's three bodies (the Colossus, the Prism,
## the Nemesis). What they share is the change from one body to the next.
## The shatter: while the sim holds a body in WorldReader.STATE_SHATTER (1.5 s, invulnerable) it cracks: it glows from
## inside (the glow overlay) and trembles harder and harder; then the sim removes it and it leaves at once (no fall:
## die() refuses), where FinalBossViews bursts it into shards. A body whose model file acts the break out plays that
## animation over the shatter and holds its last pose until it is removed: the clip named SHATTER_CLIP, which the
## body's _owner_plays() points at the file's animation ({&"shatter": {"anim": &"break"}}). The animation sinks and
## shakes the body itself, so the base then adds no sink and only a light tremble. A body without one sinks a little
## as it trembles.
## The rise: a body whose file has the animation of its "rise" clip is on the floor from the intro's first frame and
## gathers itself up there (the file's animation starts low), so it does not also come up through the floor.
## A body the sim removes any other way (the last one beaten, a lone summon in the Playground) plays its death clip.
## Reads only (EI-07).

## The shatter's glow at its end (the overlay's alpha over the windup's), its tremble (m) and its sink (m).
const SHATTER_GLOW := 0.5
const SHATTER_SHAKE := 0.09
const SHATTER_SINK := 0.25
## The clip a file's break animation replaces, played 0..1 over the shatter; the share of the shatter it blends in
## over (an attack cut short by the last hit eases into it); the tremble left under it (a share of SHATTER_SHAKE).
const SHATTER_CLIP := &"shatter"
const SHATTER_BLEND := 0.07
const BREAK_SHAKE := 0.35
## The share of a file's rise animation that plays over the intro; the rest plays over the rise's flourish.
const RISE_INTRO_SHARE := 0.55

var _shatter := 0.0
var _shattered := false
var _spawn_secs := 0.0


func sync(reader: WorldReader, i: int) -> void:
	super(reader, i)
	_shattered = reader.actor_state(i) == WorldReader.STATE_SHATTER
	_shatter = reader.final_shatter_permille() / 1000.0 if _shattered else 0.0


## Plain values (tests, renders): "shatter" 0..1 while the body shatters.
func apply_state(s: Dictionary) -> void:
	super(s)
	if s.has("shatter"):
		_shatter = float(s["shatter"])
		_shattered = _shatter > 0.0


## 0..1 through the shatter (0 when the body isn't shattering).
func shatter_amount() -> float:
	return _shatter


## True when the body's file acts its break out (its animation plays over the shatter).
func plays_break() -> bool:
	return animator != null and animator.owner_has(SHATTER_CLIP)


## A body that shattered leaves at once (FinalBossViews draws its shards); any other plays its fall.
func die() -> bool:
	if _shattered:
		return false
	return super()


func _extra_glow() -> float:
	return SHATTER_GLOW * _shatter * _shatter


## The file's break over the shatter, in the layer the death clip uses (a shattering body never plays its fall): the
## last layer, so nothing shows over it.
func _animate(dt: float) -> void:
	super(dt)
	if _shatter > 0.0 and plays_break():
		animator.set_layer(
			BossAnimator.DEATH, SHATTER_CLIP, _shatter, minf(1.0, _shatter / SHATTER_BLEND)
		)


## A body whose file plays its rise stays on the floor it gathers itself up from: the base's climb out of the ground
## is left out, and the animation's time follows the intro (_rise_intro_share() of it, the rest over the flourish).
func _advance_clips(dt: float, spawning: bool) -> void:
	var before := _rise_t
	super(dt, spawning)
	if not _rises_in_place():
		return
	_rise = 1.0
	var share := _rise_intro_share()
	if spawning:
		_spawn_secs += dt
		var intro := _intro if _intro >= 0.0 else minf(1.0, _spawn_secs / RISE_SECONDS)
		_rise_t = share * intro
		return
	_spawn_secs = 0.0
	if before >= 1.0 or share >= 1.0:
		_rise_t = 1.0
	else:
		_rise_t = minf(1.0, before + dt / RISE_FLOURISH_SECONDS * (1.0 - share))


## True when the body gathers itself up on the floor instead of climbing out of it (its file has the rise).
func _rises_in_place() -> bool:
	return animator != null and animator.owner_has(&"rise")


## The share of the file's rise that plays over the intro (1: all of it, the body stands as the intro ends).
func _rise_intro_share() -> float:
	return RISE_INTRO_SHARE


## Each body's own pose layer runs first (_pose_final); then the shatter's tremble on the whole body, and its sink
## where no animation sinks it.
func _pose_rig(dt: float) -> void:
	_pose_final(dt)
	if _shatter <= 0.0 or pivot == null:
		return
	var k := _shatter * _shatter
	var acted := plays_break()
	if not acted:
		pivot.position.y -= SHATTER_SINK * k
	if not ViewPrefs.reduced_motion:
		var shake := SHATTER_SHAKE * (BREAK_SHAKE if acted else 1.0)
		pivot.position += Vector3(sin(_t * 53.0), 0.0, cos(_t * 47.0)) * shake * k


## The body's own layer after the clips (subclasses).
func _pose_final(_dt: float) -> void:
	pass

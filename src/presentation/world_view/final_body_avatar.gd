class_name FinalBodyAvatar
extends BossAvatar
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F3): the base of the final boss's three bodies (the Colossus, the Prism,
## the Nemesis). What they share is the shatter: while the sim holds a body in WorldReader.STATE_SHATTER (1.5 s,
## invulnerable) it cracks: it trembles harder and harder and glows from inside (the glow overlay), sinking a little;
## then the sim removes it and it leaves at once (no fall: die() refuses), where FinalBossViews bursts it into shards.
## A body the sim removes any other way (the last one beaten, a lone summon in the Playground) plays its death clip.
## Reads only (EI-07).

## The shatter's glow at its end (the overlay's alpha over the windup's), its tremble (m) and its sink (m).
const SHATTER_GLOW := 0.5
const SHATTER_SHAKE := 0.09
const SHATTER_SINK := 0.25

var _shatter := 0.0
var _shattered := false


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


## A body that shattered leaves at once (FinalBossViews draws its shards); any other plays its fall.
func die() -> bool:
	if _shattered:
		return false
	return super()


func _extra_glow() -> float:
	return SHATTER_GLOW * _shatter * _shatter


## Each body's own pose layer runs first (_pose_final); then the shatter's tremble and sink on the whole body.
func _pose_rig(dt: float) -> void:
	_pose_final(dt)
	if _shatter <= 0.0 or pivot == null:
		return
	var k := _shatter * _shatter
	pivot.position.y -= SHATTER_SINK * k
	if not ViewPrefs.reduced_motion:
		pivot.position += Vector3(sin(_t * 53.0), 0.0, cos(_t * 47.0)) * SHATTER_SHAKE * k


## The body's own layer after the clips (subclasses).
func _pose_final(_dt: float) -> void:
	pass

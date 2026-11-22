class_name BatchScriptSync
extends RefCounted
## A batched avatar's noted sync (BatchAvatars.note_sync) run by its own GDScript: the inputs the native apply_sync
## would take, given back to the avatar's apply_state as its kind reads them. BatchAvatars uses it when the rows are
## turned off with syncs not yet applied. Presentation only (EI-07).


## The sync of avatar `a` of native class `cls` at `tick`: its root `pos`, `state`, `windup`, whether it heals
## (`heal`), and its kind's further inputs at `more[o]` (BatchAvatars.MORE of them).
static func apply(
	a: AvatarBase,
	cls: int,
	tick: int,
	pos: Vector2,
	state: int,
	windup: float,
	heal: bool,
	more: PackedFloat64Array,
	o: int
) -> void:
	if cls == BatchAvatars.STONE_THROWER_CLASS:
		(
			(a as StoneThrowerAvatar)
			. apply_state(
				{
					"tick": tick,
					"pos": pos,
					"state": state,
					"state_ticks": int(more[o]),
					"facing": Vector2(more[o + 1], more[o + 2]),
					"ticks": Vector3i(int(more[o + 3]), int(more[o + 4]), int(more[o + 5])),
				}
			)
		)
	elif cls == BatchAvatars.NEEDLE_CLASS:
		(
			(a as NeedleAvatar)
			. apply_state(
				{
					"tick": tick,
					"pos": pos,
					"state": state,
					"windup": windup,
					"hp": int(more[o]),
				}
			)
		)
	elif cls == BatchAvatars.ROCK_LURKER_CLASS:
		(
			(a as RockLurkerAvatar)
			. apply_state(
				{
					"tick": tick,
					"pos": pos,
					"state": state,
					"windup": windup,
					"hidden": more[o] != 0.0,
					"rumbling": more[o + 1] != 0.0,
				}
			)
		)
	elif cls == BatchAvatars.WARDEN_CLASS:
		BatchWarden.apply_in_script(a as WardenAvatar, tick, pos, state, windup, more, o)
	elif cls == BatchAvatars.SNIPER_CLASS:
		(
			(a as SniperAvatar)
			. apply_state(
				{
					"tick": tick,
					"pos": pos,
					"state": state,
					"windup": windup,
					"hp": int(more[o]),
				}
			)
		)
	elif cls == BatchAvatars.LENS_DRONE_CLASS:
		BatchLensDrone.apply_in_script(a as LensDroneAvatar, tick, state)
	elif cls == BatchAvatars.KILN_BEETLE_CLASS:
		BatchKilnBeetle.apply_in_script(a as KilnBeetleAvatar, tick, pos, state, windup, more, o)
	elif cls == BatchAvatars.FROST_SPITTER_CLASS:
		BatchFrostSpitter.apply_in_script(
			a as FrostSpitterAvatar, tick, pos, state, windup, more, o
		)
	elif cls == BatchAvatars.GRAVITY_NODE_CLASS:
		BatchGravityNode.apply_in_script(a as GravityNodeAvatar, state, more, o)
	elif cls == BatchAvatars.ARC_CASTER_CLASS:
		(
			(a as ArcCasterAvatar)
			. apply_state(
				{
					"tick": tick,
					"pos": pos,
					"state": state,
					"windup": windup,
				}
			)
		)
	elif cls == BatchAvatars.BOMB_DRONE_CLASS:
		BatchBombDrone.apply_in_script(a as BombDroneAvatar, tick, pos, state, more, o)
	elif cls == BatchAvatars.SCRAP_HOUND_CLASS:
		BatchScrapHound.apply_in_script(a as ScrapHoundAvatar, tick, pos, state, windup, more, o)
	elif cls == BatchAvatars.CINDER_PRIEST_CLASS:
		BatchCinderPriest.apply_in_script(a as CinderPriestAvatar, tick, pos, state, more, o)
	elif cls == BatchAvatars.GLACIER_TURTLE_CLASS:
		BatchGlacierTurtle.apply_in_script(
			a as GlacierTurtleAvatar, tick, pos, state, windup, more, o
		)
	elif cls >= BatchAvatars.CHARGER_CLASS:
		(
			(a as ChargerAvatar)
			. apply_state(
				{
					"tick": tick,
					"pos": pos,
					"state": state,
					"windup": windup,
				}
			)
		)
	else:
		(
			(a as HordeAvatar)
			. apply_state(
				{
					"tick": tick,
					"state": state,
					"healing": heal,
					"windup": windup,
				}
			)
		)

class_name EnemyFall
extends RefCounted
## v0.11.0 O17d: ActorViews' drop of an enemy whose body plays a fall when the sim drops it (it was ActorViews' own
## branch for the HordeAvatar, v0.8.0 MI: an owner's enemy model falls, the Splitter's halves part), now with the Cinder
## Priest crumpling into its robe: its death starts, it keeps animating, its bar goes and the node is freed when the
## fall is over. Presentation only (EI-07): the sim already dropped the actor; this only draws its going.


## Starts `avatar`'s fall (the actor `node`'s enemy avatar) under `views`; false when it has none (the node goes now).
static func start(avatar: Variant, node: Node3D, views: Node) -> bool:
	if not views.is_inside_tree():
		return false
	var seconds := -1.0
	if avatar is HordeAvatar and (avatar as HordeAvatar).die():
		seconds = HordeAvatar.DEATH_SECONDS
	elif avatar is CinderPriestAvatar and (avatar as CinderPriestAvatar).die():
		seconds = CinderPriestAvatar.DEATH_SECONDS
	if seconds < 0.0:
		return false
	(avatar as Node).set_process(true)
	if node.has_meta(&"bar"):
		(node.get_meta(&"bar") as Node3D).visible = false
	views.get_tree().create_timer(seconds).timeout.connect(node.queue_free)
	return true

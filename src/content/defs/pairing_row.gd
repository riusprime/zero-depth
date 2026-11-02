class_name PairingRow
extends Resource
## One duo of the enemy pairings (v0.10.5 O15, docs/roadmap/v0.10.5/O15_PAIRINGS.md): when a pack of the lead enemy
## arrives on or after `from_floor` and the partner enemy is already unlocked, then with `chance_permille` the pack
## is joined by `partners` partners standing where `placement` puts them. Every number is a starting value.

## Where the partners stand (PairingTable.Place, same order).
const PLACEMENTS: Array[StringName] = [
	&"behind", &"far_side", &"flanking", &"in_front", &"above_behind"
]

@export var lead_id: StringName
@export var partner_id: StringName
@export var from_floor := 1
@export_range(0, 1000) var chance_permille := 250
@export var partners := 1
@export_enum("behind", "far_side", "flanking", "in_front", "above_behind") var placement := 0
## The duo's name (locale key), announced the first time it appears in a run ("New: Shield wall").
@export var name_key: StringName

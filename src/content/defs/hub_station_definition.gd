class_name HubStationDefinition
extends Resource
## v0.9.0 HB (owner Q27, HUB_MOCKUPS option A "Rune Ring"): one station of the hub (CONTENT_SCHEMA §11). A solid
## footprint on the plaza, a name, the prompt shown when the hero stands at it, and the panel its interact opens.
## Positions are on the hub's plan: metres from the plaza's centre, +y the plan's north (the top of the screen in the
## iso view), +x its east (the screen's right).

## What the interact opens (Main wires each one): the run's build pick, the Codex, the Codex on its Achievements page,
## the Runic Stone (v0.9.5 RS1: it speaks in runes; HubSession handles it), or a stand-in panel (the Wardrobe,
## the Progression Station).
const PANELS: Array[StringName] = [
	&"portal", &"codex", &"achievements", &"runic", &"wardrobe", &"progression"
]

@export var id: StringName
@export var name_key: StringName
@export var prompt_key: StringName
@export var panel: StringName
## The footprint's centre and half size on the plan (m); it blocks the hero.
@export var at := Vector2.ZERO
@export var half := Vector2(1.0, 1.0)
## How tall its stand-in is drawn (m; a look only).
@export var height_m := 2.0
## How near the footprint's edge the hero must stand for the prompt (m).
@export var reach_m := 1.4

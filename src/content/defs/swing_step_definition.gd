class_name SwingStepDefinition
extends Resource
## One step of the melee combo (v0.3.0 PLAN L11, owner: "sword should be a 4 moment combo, composed of 4 different
## kind of slashes the 4th being stronger"). Times in seconds, compiled to ticks once. Starting values.
##
## The swing hits once, `active_seconds` after it starts, everything inside its arc (`arc_degrees` wide, centred on
## the aim, out to `reach_m` beyond the wanderer's edge; 360 = all around). It ends `recovery_seconds` after the
## hit, then the combo window opens. The lunge carries the wanderer `lunge_m` along the aim on the ticks before
## the hit. `motion` and `sweep_seconds` only tell the view how to move the blade through that same arc.

## How the blade moves through the arc (the view's choice; the hit is the arc either way).
enum Motion { SLASH_RIGHT_TO_LEFT, SLASH_LEFT_TO_RIGHT, THRUST, SPIN }

@export var motion := Motion.SLASH_RIGHT_TO_LEFT
@export var active_seconds := 2.0 / 60.0
@export var recovery_seconds := 12.0 / 60.0
@export var arc_degrees := 120.0
@export var reach_m := 1.6
@export var damage := 10
@export var hitstop_seconds := 3.0 / 60.0
@export var lunge_m := 0.0
## How long the blade takes to cross the arc (presentation timing).
@export var sweep_seconds := 5.0 / 60.0

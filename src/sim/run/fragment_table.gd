class_name FragmentTable
extends RefCounted
## v0.9.0 MP (PLAN W49-W50, Q28): the Rune Fragments a run earns, compiled from RuneFragmentsDefinition
## (data/meta/rune_fragments.tres; MetaProgress.compile_table). Starting values, not decided by the owner yet
## (OWNER_QUESTIONS). RuneFragments counts them; RunState keeps the tally.

## A floor cleared (its portal taken).
var floor_cleared := 2
## A floor's boss beaten (the final boss has its own).
var boss := 3
## Each secret found on a floor: the timed door opened, the rune puzzle solved, the cracked wall broken, the purple
## runes awakened.
var secret := 2
## The Purple Portal travelled (the Deep gate taken).
var purple_portal := 3
## The final boss beaten.
var final_boss := 10
## Each collectible found (CL's hook: RuneFragments.add_collectibles).
var collectible := 1

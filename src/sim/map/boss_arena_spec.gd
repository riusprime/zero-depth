class_name BossArenaSpec
extends RefCounted
## What a floor's boss room needs from its boss (v0.3.0 PLAN "Boss room and portal"): the room's size in grid cells,
## its interior template (FloorLayout.Template) and which compiled boss to spawn. C's BossDefinition.arena fills it;
## until then every floor uses the default, a 3 x 3 open room and boss 0.

var cells := Vector2i(3, 3)
var template := FloorLayout.Template.OPEN
var boss_index := 0


static func make(
	p_cells: Vector2i = Vector2i(3, 3),
	p_template: int = FloorLayout.Template.OPEN,
	p_boss_index: int = 0
) -> BossArenaSpec:
	var s := BossArenaSpec.new()
	s.cells = p_cells
	s.template = p_template
	s.boss_index = p_boss_index
	return s

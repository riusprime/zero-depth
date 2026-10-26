class_name AchievementDefinition
extends ContentDef
## v0.7.5 AC (owner N7: "the local achievements"): one achievement, or (kind CODEX_EACH) one achievement per entry of
## a Codex page, so a new boss or biome in the data gets its own without a new file. Kept in the profile, outside
## the run and the sim; the app layer evaluates the condition (AchievementBook, AchievementTracker) from the Codex's
## counters (CodexStore) and its own run counters (`stat`, recorded from WorldReader and SimEvents). The kinds:
## - STAT: the profile's run counter `stat` (STATS) has reached `target`.
## - CODEX_TOTAL: a Codex counter summed over a page (`page`, `counter`) has reached `target` (e.g. 100 kills).
## - CODEX_MAX: the highest value of a Codex counter on any entry of a page (e.g. a card's level 5).
## - CODEX_EACH: one achievement per Codex entry of `page` (and `section`, when set): that entry's `counter` has
##   reached `target` (an empty `counter`: the entry is met). Its name and sentence keys take the entry's name as %s.
## - CODEX_EVERY: every Codex entry of `page` (and `section`) has `counter` >= `target` (empty: every entry met).
## The Codex pages and counters are repeated here (content can't read the application layer); a test checks they
## match CodexStore.PAGES and CodexStore.COUNTERS.

enum Kind { STAT, CODEX_TOTAL, CODEX_MAX, CODEX_EACH, CODEX_EVERY }

## The run counters the app records (AchievementTracker), and the one the Ascension portal reports
## (`runs:ascended`, v0.7.5 AP: AchievementTracker.report). A STAT achievement names one of these.
const STATS: Array[StringName] = [
	&"floors:cleared_1",
	&"floors:cleared_2",
	&"floors:cleared_3",
	&"runs:won",
	&"runs:won_gun",
	&"runs:won_blade",
	&"runs:ascended",
	&"wand:cards_max",
	&"kills:child_spell",
	&"rooms:no_hit",
	&"rooms:sealed_cleared",
	&"overruns:cleared",
	&"curses:chest_card",
	&"cores:stolen",
	&"shards:spent",
	&"final:won",  # v0.8.0 FB1 (FINAL_BOSS.md F8): the final boss beaten,
	&"final:no_hit_phase",  # a body beaten without a hit,
	&"final:won_looped",  # and beaten after an Ascension loop
	&"final:won_gun",  # v0.9.5 SL: beaten with the Gun (unlocks the Blade)
]
const CODEX_COUNTERS := {
	&"cards": [&"offered", &"taken", &"level"],
	&"enemies": [&"kills", &"deaths"],
	&"bosses": [&"fights", &"kills", &"deaths"],
	&"biomes": [&"visits"],
}
## The page's groups, in order (the Achievements page's sections).
const GROUPS: Array[StringName] = [
	&"run", &"bosses", &"biomes", &"build", &"combat", &"risk", &"codex", &"ascension"
]
## The code-drawn pictures (AchievementGlyphs).
const GLYPHS: Array[StringName] = [
	&"floor",
	&"crown",
	&"skull",
	&"compass",
	&"globe",
	&"wand",
	&"star",
	&"chain",
	&"blade",
	&"shield",
	&"gate",
	&"wave",
	&"curse",
	&"core",
	&"shard",
	&"book",
	&"eye",
	&"ascend",
]

@export var name_key: StringName
@export var desc_key: StringName
@export var glyph: StringName = &"star"
@export var group: StringName = &"run"
## Its place inside its group (lower first; ties by id).
@export var order := 0
## A hidden achievement shows as "???" until it unlocks; any other locked one shows dimmed with its sentence.
@export var hidden := false
@export var kind: Kind = Kind.STAT
## STAT: the run counter (STATS).
@export var stat: StringName
## The CODEX_* kinds: the page, an optional section of it (CodexCatalog.SECTIONS), and the counter.
@export var page: StringName
@export var section: StringName
@export var counter: StringName
@export var target := 1


func category() -> StringName:
	return &"achievements"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	for p in problems():
		issues.append(ValidationIssue.new(&"achievement", resource_path, p))
	return issues


## Problems as "field: why" strings.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if name_key == &"" or desc_key == &"":
		out.append("name_key / desc_key: both are needed")
	if not glyph in GLYPHS:
		out.append("glyph: unknown '%s'" % glyph)
	if not group in GROUPS:
		out.append("group: unknown '%s'" % group)
	if target < 1:
		out.append("target: %d must be >= 1" % target)
	if kind == Kind.STAT:
		if not stat in STATS:
			out.append("stat: unknown run counter '%s'" % stat)
		return out
	if not CODEX_COUNTERS.has(page):
		out.append("page: unknown Codex page '%s'" % page)
		return out
	var counters: Array = CODEX_COUNTERS[page]
	var may_be_empty := kind == Kind.CODEX_EACH or kind == Kind.CODEX_EVERY
	if counter == &"" and not may_be_empty:
		out.append("counter: needed for this kind")
	elif counter != &"" and not counter in counters:
		out.append("counter: '%s' is not a counter of %s" % [counter, page])
	if section != &"" and not may_be_empty:
		out.append("section: only CODEX_EACH and CODEX_EVERY read a section")
	return out

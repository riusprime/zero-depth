class_name FinalBossDefinition
extends BossDefinition
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F3-F8): one body of the final boss (the Colossus, the Prism, the Nemesis):
## a boss in every field (BossDefinition, CONTENT_SCHEMA §4), kept in its own category so the floors' boss indices
## (ContentCompiler.compile_bosses, saved in every run save) stay what they were. The run names its bodies in order
## (RunDefinition.final_bosses); data/final_boss/.


func category() -> StringName:
	return &"final_bosses"

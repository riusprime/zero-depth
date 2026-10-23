class_name BossKinds
extends RefCounted
## Bosses (v0.3.0 C): boss ids to actor kinds (ContentCompiler.BOSS_KINDS; a test matches BossSchemas.KINDS). Moved
## out of ContentCompiler in v0.9.0 NB4 (its line limit) unchanged, with the Lantern Shade added.

const ALL := {
	&"gatekeeper": ActorStore.Kind.GATEKEEPER,
	&"brood_mother": ActorStore.Kind.BROOD_MOTHER,
	&"siege_engine": ActorStore.Kind.SIEGE_ENGINE,
	&"warlord": ActorStore.Kind.WARLORD,
	&"hive_lens": ActorStore.Kind.HIVE_LENS,
	&"foundry": ActorStore.Kind.FOUNDRY,
	&"colossus": ActorStore.Kind.COLOSSUS,  # v0.8.0 FB1: the final boss's bodies (data/final_boss)
	&"prism": ActorStore.Kind.PRISM,
	&"nemesis": ActorStore.Kind.NEMESIS,
	&"tidecaller": ActorStore.Kind.TIDECALLER,  # v0.9.0 NB1
	&"twin_wardens": ActorStore.Kind.TWIN_WARDEN,  # v0.9.0 NB2 (its twin's: PatternCompiler)
	&"clockwork_judge": ActorStore.Kind.CLOCKWORK_JUDGE,  # v0.9.0 NB3
	&"lantern_shade": ActorStore.Kind.LANTERN_SHADE,  # v0.9.0 NB4
}

class_name SecretRules
extends RefCounted
## v0.9.0 DX (owner W §4 C, §5; Q23): the destructibles' numbers for one floor's setup (Breakables.setup), from
## SecretsDefinition (data/secrets/secrets.tres; FloorPlan copies them here). The defaults equal the data's starting
## values, so a world built without content gets the same floor. Setup copies the numbers play needs into Breakables
## itself (they ride the save with it); this object is not kept.

## The share of floors with a cracked wall before a dead end (per mille), and the Skill hits it takes.
var crack_permille := 250
var crack_hits := 3
## Breakable containers (crates, urns, barrels): at most this many a room, and the chance (per mille) one breaks open on
## a few shards or a heal orb; of those, the share (per mille) that are a heal; the shards' range.
var containers_max := 2
var container_drop_permille := 150
var container_heal_permille := 500
var container_shards_min := 2
var container_shards_max := 5
## Explosive barrels: the chance (per mille) a room holds one (at most barrels_max), the fuse (ticks) a hit lights, the
## blast's radius (m) and its damage to enemies and to the hero.
var barrel_room_permille := 200
var barrels_max := 1
var barrel_fuse_ticks := 60
var barrel_radius_m := 2.0
var barrel_damage := 40
var barrel_hero_damage := 15

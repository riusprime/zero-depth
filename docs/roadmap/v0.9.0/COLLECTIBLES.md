# v0.9.0 CL: collectibles (G1, waiting for the owner)

Drafted by the lead's agent while the owner was away (2026-10-23). Answer per row: approve, change: …, drop.
**Nothing is built until approved.**

The owner's decision (PLAN "Owner decisions" Q29, 2026-10-22): *"I draft 16, you edit (Recommended)"*. The feedback
asks for 12–20 distinctive collectibles that "feel like discoveries rather than a repetitive checklist" (W40), kept
permanently in an archive (W39), some found in the hub itself (W47).

**How they work (proposal, for the CL step).** Each collectible is a typed `.tres` definition (id, name and lore keys,
shelf, discovery condition) and is recorded once in a new `collectibles` section of `user://profile.json` (profile
version 2, migrated with nothing lost; W39). A run never depends on them. Each shows on a shelf of the Rune Archive
in the hub (HB): uncollected ones show as a dark silhouette with "?" and no hint text beyond the shelf name.

**Where the sources stand.** Several rows depend on Wave 3–4 systems that are planned in PLAN (DX hidden rooms and
cracked walls, RA rune alignment, TD timed doors, LK lockdowns, SH shrines, HF healing fountains, DP the Purple Portal);
the Crown shelf uses the final boss's three bodies, which exist today (`data/final_boss/`). This draft does not claim any of them is built; each row names the step it rides on.

**Style.** One short line, no numbers, like the Codex lines (`BOSS_FOUNDRY_DESC` "A walking furnace.",
`BOSS_BROOD_MOTHER_DESC` "Mother of the swarm."). Boss names stay in English in `es`, as in `locale/strings.csv`.

## Shelf 1: Stone (one per biome)

Found in a **hidden room** (DX: a cracked wall broken with the Skill) of that biome; at most one collectible a run, so
the five spread over several runs.

| # | Name | Nombre | Found | Lore (en / es) | Approve? |
|---|---|---|---|---|---|
| 1 | Cold Lantern | Farol Frío | A hidden room in the **Ruins** (DX) | It still lights halls that fell long ago. / Aún alumbra salones que cayeron hace mucho. | ☐ |
| 2 | Starless Map | Mapa sin Estrellas | A hidden room in **Night Rocks** (DX) | Someone charted the dark and found nothing. / Alguien trazó la oscuridad y no halló nada. | ☐ |
| 3 | Sunbaked Idol | Ídolo Tostado | A hidden room in the **Red Canyon** (DX) | It smiles at the heat. / Sonríe al calor. | ☐ |
| 4 | Frozen Bell | Campana Helada | A hidden room on the **Frozen Shore** (DX) | It rang once. The sea froze to listen. / Sonó una vez. El mar se heló para escuchar. | ☐ |
| 5 | Star Splinter | Astilla de Estrella | A hidden room in **Starfall** (DX) | Still warm from the fall. / Aún tibia de la caída. | ☐ |

## Shelf 2: Sealed (secrets and special rooms)

| # | Name | Nombre | Found | Lore (en / es) | Approve? |
|---|---|---|---|---|---|
| 6 | Aligned Key | Llave Alineada | Solving a **rune alignment** (RA) on floor 4 or 5 | Turn it right and the walls remember. / Gírala bien y los muros recuerdan. | ☐ |
| 7 | Sand Shell | Concha de Arena | Behind a **timed door** (TD) on floor 3 or deeper, reached before the last beep | It runs out, then starts again. / Se agota y vuelve a empezar. | ☐ |
| 8 | Broken Shackle | Grillete Roto | Clearing a **Hazard Lockdown** (LK) | The bars gave way. So did this. / Los barrotes cedieron. Esto también. | ☐ |
| 9 | Violet Eye | Ojo Violeta | The first walk through the **Purple Portal** (DP) | It saw the deep road before you did. / Vio el camino profundo antes que tú. | ☐ |
| 10 | Blood Coin | Moneda de Sangre | Taking a **Blood Shrine**'s deal (SH) | Paid in full. Paid in you. / Pagada entera. Pagada contigo. | ☐ |
| 11 | Dry Chalice | Cáliz Seco | Drinking from a **healing fountain** (HF) on the last floor | The last drink was yours. / El último trago fue tuyo. | ☐ |
| 12 | Rune Rubbing | Calco de Runas | Finding three **hidden rune markings** (DX) in one run | Old marks. Someone wanted them found. / Marcas viejas. Alguien quería que las hallaras. | ☐ |

## Shelf 3: Crown (the Hollow Crown's bodies)

Dropped once, the first time each body falls (`data/final_boss/`: The Colossus, The Prism, The Fallen).

| # | Name | Nombre | Found | Lore (en / es) | Approve? |
|---|---|---|---|---|---|
| 13 | Colossus Tooth | Diente del Colossus | The first time **The Colossus** falls | Bigger than your head. Still hungry. / Más grande que tu cabeza. Aún con hambre. | ☐ |
| 14 | Prism Shard | Esquirla del Prism | The first time **The Prism** falls | Every colour, none of them kind. / Todos los colores, ninguno amable. | ☐ |
| 15 | Mirror Mask | Máscara Espejo | The first time **The Fallen** falls | It wears your face better than you. / Lleva tu cara mejor que tú. | ☐ |

## Shelf 4: Hub (found in the hub itself, W47)

| # | Name | Nombre | Found | Lore (en / es) | Approve? |
|---|---|---|---|---|---|
| 16 | Keystone | Piedra Angular | In the hub's sealed room (the "?" in every HUB_MOCKUPS option), which opens once 12 of the other 15 are on the shelves | The first stone. It waited for the rest. / La primera piedra. Esperaba a las demás. | ☐ |

## Open points for the owner

| # | Question | Draft answer | Approve? |
|---|---|---|---|
| P1 | The six floor bosses have no collectible (they are in the Trophy Area and the Codex). Swap some Sealed rows for boss drops? | No: bosses already show in two places | ☐ |
| P2 | Does finding a collectible give Rune Fragments (MP)? | A small one-time amount, set in `UNLOCKS.md` with MP | ☐ |
| P3 | A toast when one is found? | A short line in the HUD the first time ("Added to the Rune Archive"); the hub's changes stay silent (W46) | ☐ |
| P4 | Show "?" silhouettes for uncollected ones? | Yes, with the shelf name only, no hint | ☐ |

## Decisions (owner, date)

| # | Answer | Built in |
|---|---|---|
| | | |

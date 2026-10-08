# Second bosses: image prompts (v0.4.0 BO)

The second boss of each floor pool ([`../roadmap/v0.4.0/PLAN.md`](../roadmap/v0.4.0/PLAN.md) "Bosses (BO)"). Until
the owner sends reference sheets or models, the game draws code-built bodies (`WarlordAvatar`, `HiveLensAvatar`,
`FoundryAvatar`, `LensDroneAvatar`) read from the descriptions in [`ART_DIRECTION.md`](ART_DIRECTION.md) §4.

These prompts are written so the owner can generate reference sheets in the same layout as
[`first-three-bosses-concept.png`](first-three-bosses-concept.png): one row per boss, an in-game iso shot on the
left (with the small hooded hero for scale), then FRONT, RIGHT-FRONT and RIGHT views. A model sent later goes to
`assets/models/bosses/<id>.glb` (`warlord`, `hive_lens`, `foundry`) and replaces the code body by that id; it moves
as a whole body until it is rigged like the first three (BossRig).

Shared style line (append to each prompt): *low-poly faceted 3D game asset, flat-shaded planes, matte, a red
(#D23E35) and warm grey (#6A6462) palette with near-black (#2B2C31) trim and glowing red-orange (#FF2A22 / #FF5A26)
emissive accents, clean dark outlines, isometric action-roguelike, plain light background, character turnaround
reference sheet with labelled views FRONT, RIGHT-FRONT, RIGHT and one in-game isometric shot beside a small hooded
wanderer (off-white hood, cyan visor) for scale, no text other than the view labels.*

## 1. The Warlord (floor 1 pool)

> A towering armoured knight boss, about 2.7 m tall, built from chunky faceted grey armour plates over short heavy
> armoured legs. A closed boxy grey great-helm with a glowing red T-shaped visor slit, crowned by a crest of three
> swept-back red crystal blades. Broad red faceted pauldrons and a red tabard hanging front and back. On its left
> arm a tall red tower shield almost as tall as its body, rimmed in grey metal, with a glowing red faceted emblem in
> its centre. In its right hand a long grey spear (twice its height) with a red leaf-shaped crystal spearhead and a
> dark butt cap. In the in-game shot it braces behind the shield with the spear couched, three straight lines of red
> spearheads bursting up out of the sandy floor in front of it. Show one extra small inset of it with the shield
> lifted high and aside, baring a glowing gold core on its chest (its weak point).

Gameplay notes for the sheet (not for the image): the shield faces the player and takes 35 % off; planting the spears
or dashing lifts it (the weak point). Moves: shield bash, spear lines (3, then 5), lunge dash, javelin rain.

## 2. The Hive Lens (floor 2 pool)

> A floating eye boss, a faceted grey armoured sphere about 1.9 m across, hovering at head height over a soft dark
> shadow on the ground. One great glowing red iris fills its front, with a black slit pupil, ringed by eight short red
> crystal spikes like lashes. A darker grey band runs round its middle. Three red faceted drone pods (each a chunky
> box with a red eye slit) are docked on its rim at equal spacing, like petals. Three grey segmented cable tails hang
> beneath it, each tipped with a glowing red crystal. In the in-game shot it sweeps a wide red beam across the floor
> toward the hero. Show one extra small inset of the split: the three pods breaking off the rim as small hovering
> drones, each a red pod with a grey cap, a red eye slit and a thin grey ring turning round it.

Gameplay notes: beams that sweep (rail), prism bolt fans, a glare ring up close, a dive at a runaway; at 50 % the
three pods split off as Lens Drones.

## 3. The Foundry (floor 3 pool)

> A walking furnace boss, about 2.6 m tall: a squat, broad block of faceted grey iron with a red sloped hood on top,
> standing on four short, heavy grey legs with wide flat feet. In its front a glowing red-orange furnace grate behind
> a dark iron door frame, with a hinged slatted door; a short pouring spout under the grate. Two grey chimneys rise
> from the hood, glowing red inside. Rows of thin glowing vent slits along its flanks. On its back a red launcher
> tube angled up and back, with a small glowing round charge at its mouth. In the in-game shot it tips forward and
> pours: parallel lanes of molten orange metal run across the floor toward the hero, and a small red quad-rotor bomb
> drone lifts off its back. Show one extra small inset with the grate door swung wide open on a glowing gold core
> (its weak point).

Gameplay notes: molten lanes that burn for 2 s, slag mortar, a vent blast ring up close, launches Bomb Drones (the
existing enemy), a firestorm of seven lanes at a kiter.

## Status

| id | kind | needed by step | fallback in use | status |
|---|---|---|---|---|
| `boss_warlord_sheet` | reference sheet (1536 x ~340 row) | v0.4.0 BO | code-built `WarlordAvatar` | requested |
| `boss_hive_lens_sheet` | reference sheet | v0.4.0 BO | code-built `HiveLensAvatar` | requested |
| `boss_foundry_sheet` | reference sheet | v0.4.0 BO | code-built `FoundryAvatar` | requested |

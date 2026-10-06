# Sound effects needs

The starter sound list, cut to the fewest sounds that still read clearly. Cue hooks and captions arrive in
v0.1.0, before any real audio. A missing file plays nothing but still shows its caption. Music and voice are out
of scope until the owner asks.

## Rules (kept from Deathventory's audio pass)

- **One file per sound.** Variety comes from the ported `SfxMixer`: a few percent of pitch jitter (from the
  `cosmetic` stream), softer quick repeats, lane caps and a voice limit. There are no variant files.
- **One sound, many uses.** A cue lists everything it covers; a different `pitch_scale` stands in for a smaller or
  bigger version.
- **Attacks are two layers:** the attack (fire, swing, charge), then the hit on what it struck. There is no sound
  per enemy and target pair.
- **Readability first.**
  - Every hostile **windup** has a sound, so an off-screen telegraph can be heard.
  - A hit on the player is the loudest, highest-priority cue in its lane.
- **Captions.** Every gameplay cue has a `caption_key` in `locale/strings.csv` (en and es), shown when captions
  are on.
- **Sources and licences are recorded on delivery.** Deathventory's audio READMEs said "license not recorded" for
  a long time. Here a cue without a recorded source and licence fails the asset test.
- **Cue data:** each cue is a typed resource (`data/audio/cues/<id>.tres`) with the file, volume dB, pitch, lane,
  priority, cooldown, duck and `caption_key`.

## The list

**P1** is what the combat loop needs to feel right. **P2** is polish.

| # | Cue | Covers | Lane | P |
|---|---|---|---|---|
| 1 | `ui_move` | focus moves in menus | ui | P1 |
| 2 | `ui_confirm` | confirm, pick a reward, start | ui | P1 |
| 3 | `ui_back` | back, cancel, close | ui | P1 |
| 4 | `player_fire` | primary attack (pitched per weapon family later) | world | P1 |
| 5 | `player_dash` | dash | world | P1 |
| 6 | `player_guard` | guard raised; a guarded hit plays `hit_guard` | world | P1 |
| 7 | `player_skill` | mobile skill | world | P1 |
| 8 | `hit_player` | the player takes damage | world | P1 |
| 9 | `hit_enemy` | an enemy takes damage (pitched by enemy size) | world | P1 |
| 10 | `hit_guard` | a hit absorbed by guard or barrier | world | P1 |
| 11 | `hit_cover` | a projectile stops on cover | world | P2 |
| 12 | `enemy_windup` | any hostile telegraph starts (pitched by attack size) | world | P1 |
| 13 | `enemy_fire` | hostile projectile fired | world | P1 |
| 14 | `enemy_charge` | a charging attack's active phase | world | P2 |
| 15 | `enemy_death` | an enemy dies (pitched by size) | world | P1 |
| 16 | `player_death` | the player dies | world | P1 |
| 17 | `status_bleed` | bleed applied; ticks are silent | world | P2 |
| 18 | `status_stagger` | stagger, including boss stagger (pitched down) | world | P1 |
| 19 | `pickup` | item or reward picked up | reward | P1 |
| 20 | `reward_reveal` | reward choice opens | reward | P2 |
| 21 | `room_clear` | last enemy of a room dies; doors open | reward | P1 |
| 22 | `threat_up` | the player chooses a threat cost (T rises) | reward | P2 |
| 23 | `boss_phase` | a boss changes phase | world | P2 |
| 24 | `explosion` | a barrel or explosive payoff | world | P2 |

The totals are **24 cues: 17 P1, 7 P2**. Each version's PLAN adds rows only when a new mechanic can't reuse one of
these.

# SPELLS_DPS: do the 15 spells hit their damage budget against the wand (O12, PLAN E5)?

- **Status:** RUN (two runs: before and after one tuning pass of the spells' own numbers)
- **Build:** base `c090d114` on `v0110-o12`, working tree with this step's `scripts/balance/spells_dps.gd`; run 1 with
  the shipped spell data, run 2 with this step's `data/spells/*.tres` changes (both committed in the Step O12 commit).
  Godot `4.7.2.stable.official.ed1daf0bf`; OS Windows 11 Pro 10.0.26200 (owner's PC, i7-10700K)
- **Date:** 2026-11-07
- **Who ran it:** agent

## Command
Eight processes side by side (one per wand and part), each with its own `APPDATA`:
```
godot --headless --path . -s scripts/balance/spells_dps.gd -- --wand=<orbs|laser|glaive|blade> --part=<spells|builds>
```
Each writes `build/balance/spells_dps_<wand>_<part>.txt` (kept as `build/balance/run1/` and `build/balance/run2/`).

What the script counts (its header has the full rule): ticks [0, 3600) (60 s); crit off; 1 000 000 HP dummies put back
each tick; the wand and the element cards of the spells held. **Spell damage** = DAMAGE events on the dummies whose
effect id starts with the spell's id (hits, zone pulses, Frost Nova's shatter, Hemorrhage's cash-in); statuses
(burn/venom/bleed/frost ticks) not counted. **Wand damage** = the player's other DAMAGE events on the dummies that
aren't damage over time (forms_dps's rule), in the same run. Scenes: FAR = forms_dps's (4 m; 2..8 m line; 3 m arc at
4 m), NEAR = forms_dps's near (2.5 m; 1..3 m; 2.5 m arc), Blade = 1.5 m; 1..2 m; 1.5 m arc. Frost Nova, Burning Ground,
Static Field, Toxic Cloud and Blood Thorns are measured NEAR, the rest FAR.

## Target bands
Fixed before the first full run (written to `build/balance/o12_bands_fixed_before_run.txt` before it started):

| Metric | Target | Band | Source |
|---|---|---|---|
| Per spell, Lv 1 share = mean over its 3 home scenes of spell dmg / wand dmg, plain orbs | 15 % | 10–20 % | SPELLS.md "Starting values", owner-approved |
| Per spell, Lv 5 / Lv 1 = summed home-scene spell dmg, plain orbs | 2.5 | 2.0–3.0 | same |
| 4-spell builds at Lv 1, plain orbs: mean added share over the 6 scenes (FAR + NEAR) | +60 % | +40 … +80 % | same |
| Laser, Glaive, Blade | — | reported, not judged | — |

## Raw output

### Run 1 (shipped data), plain orbs
```
wand orbs, window 3600 ticks (60 s)
spell | scenes | Lv | share single | share line | share pack | mean share | spell dmg s/l/p | wand dmg s/l/p | Lv5/Lv1
spell_blizzard | far | 1 | 0.060 | 0.300 | 0.301 | 0.220 | 120/600/600 | 1995/2000/1995 | -
spell_blizzard | far | 5 | 0.090 | 0.450 | 0.451 | 0.330 | 180/900/900 | 1995/2000/1995 | 1.50
spell_frost_nova | near | 1 | 0.050 | 0.250 | 0.250 | 0.183 | 100/500/500 | 2000/2000/2000 | -
spell_frost_nova | near | 5 | 0.684 | 0.924 | 0.924 | 0.844 | 1368/1848/1848 | 2000/2000/2000 | 4.60
spell_ice_lances | far | 1 | 0.033 | 0.292 | 0.098 | 0.141 | 65/585/195 | 1995/2000/1995 | -
spell_ice_lances | far | 5 | 0.035 | 0.525 | 0.175 | 0.245 | 70/1050/350 | 1995/2000/1995 | 1.74
spell_fireball | far | 1 | 0.050 | 0.250 | 0.251 | 0.184 | 100/500/500 | 1995/2000/1995 | -
spell_fireball | far | 5 | 0.125 | 0.625 | 0.627 | 0.459 | 250/1250/1250 | 1995/2000/1995 | 2.50
spell_burning_ground | near | 1 | 0.060 | 0.240 | 0.300 | 0.200 | 120/480/600 | 2000/2000/2000 | -
spell_burning_ground | near | 5 | 0.096 | 0.480 | 0.480 | 0.352 | 192/960/960 | 2000/2000/2000 | 1.76
spell_meteor | far | 1 | 0.032 | 0.160 | 0.160 | 0.117 | 64/320/320 | 1995/2000/1995 | -
spell_meteor | far | 5 | 0.072 | 0.360 | 0.361 | 0.264 | 144/720/720 | 1995/2000/1995 | 2.25
spell_sky_strike | far | 1 | 0.075 | 0.083 | 0.084 | 0.081 | 150/300/300 | 1995/3600/3591 | -
spell_sky_strike | far | 5 | 0.180 | 0.200 | 0.201 | 0.194 | 360/720/720 | 1995/3600/3591 | 2.40
spell_ball_lightning | far | 1 | 0.100 | 0.090 | 0.056 | 0.082 | 200/325/200 | 1995/3600/3591 | -
spell_ball_lightning | far | 5 | 0.150 | 0.222 | 0.167 | 0.180 | 300/800/600 | 1995/3600/3591 | 2.34
spell_static_field | near | 1 | 0.002 | 0.133 | 0.179 | 0.105 | 4/480/644 | 2000/3600/3600 | -
spell_static_field | near | 5 | 0.090 | 0.250 | 0.250 | 0.197 | 180/900/900 | 2000/3600/3600 | 1.76
spell_venom_orb | far | 1 | 0.050 | 0.250 | 0.251 | 0.184 | 100/500/500 | 1995/2000/1995 | -
spell_venom_orb | far | 5 | 0.070 | 0.350 | 0.351 | 0.257 | 140/700/700 | 1995/2000/1995 | 1.40
spell_toxic_cloud | near | 1 | 0.000 | 0.338 | 0.000 | 0.113 | 0/675/0 | 2000/2000/2000 | -
spell_toxic_cloud | near | 5 | 0.150 | 0.600 | 0.750 | 0.500 | 300/1200/1500 | 2000/2000/2000 | 4.44
spell_spitter_vine | far | 1 | 0.175 | 0.175 | 0.175 | 0.175 | 350/350/350 | 1995/2000/1995 | -
spell_spitter_vine | far | 5 | 0.150 | 0.900 | 0.301 | 0.450 | 300/1800/600 | 1995/2000/1995 | 2.57
spell_blood_thorns | near | 1 | 0.050 | 0.150 | 0.250 | 0.150 | 100/300/500 | 2000/2000/2000 | -
spell_blood_thorns | near | 5 | 0.120 | 0.360 | 0.600 | 0.360 | 240/720/1200 | 2000/2000/2000 | 2.40
spell_hemorrhage | far | 1 | 0.261 | 0.148 | 0.120 | 0.176 | 520/296/240 | 1995/2000/1995 | -
spell_hemorrhage | far | 5 | 0.286 | 0.362 | 0.311 | 0.319 | 570/724/620 | 1995/2000/1995 | 1.81
spell_leech | far | 1 | 0.060 | 0.060 | 0.060 | 0.060 | 120/120/120 | 1995/2000/1995 | -
spell_leech | far | 5 | 0.099 | 0.178 | 0.259 | 0.179 | 197/357/517 | 1995/2000/1995 | 2.98
wand orbs, window 3600 ticks (60 s), spells at Lv 1
build | n | added share per scene (far single, far line, far pack, near single, near line, near pack) | mean added | spells dmg | wand dmg
(none) | 0 | 0.000 0.000 0.000 0.000 0.000 0.000 | 0.000 | 0 | 11990
fireball | 1 | 0.050 0.250 0.251 0.050 0.250 0.250 | 0.183 | 2200 | 11990
fireball+sky_strike | 2 | 0.125 0.222 0.223 0.125 0.222 0.222 | 0.190 | 3700 | 18386
fireball+sky_strike+frost_nova | 3 | 0.125 0.278 0.223 0.175 0.361 0.361 | 0.254 | 5000 | 18386
fireball+sky_strike+frost_nova+venom_orb | 4 | 0.175 0.417 0.362 0.225 0.500 0.500 | 0.363 | 7200 | 18386
blizzard+meteor+ball_lightning+hemorrhage | 4 | 0.453 0.428 0.379 0.452 0.400 0.378 | 0.415 | 7510 | 18386
ice_lances+burning_ground+static_field+spitter_vine | 4 | 0.208 0.338 0.152 0.270 0.526 0.497 | 0.332 | 6398 | 18386
toxic_cloud+blood_thorns+leech+fireball | 4 | 0.160 0.509 0.802 0.160 0.976 0.800 | 0.568 | 6810 | 11990
```
(Run 1's Laser, Glaive and Blade files are in `build/balance/run1/`; they are not quoted below, so no number here comes
from them.)

### Run 2 (after the tuning pass), plain orbs
```
wand orbs, window 3600 ticks (60 s)
spell | scenes | Lv | share single | share line | share pack | mean share | spell dmg s/l/p | wand dmg s/l/p | Lv5/Lv1
spell_blizzard | far | 1 | 0.040 | 0.200 | 0.201 | 0.147 | 80/400/400 | 1995/2000/1995 | -
spell_blizzard | far | 5 | 0.090 | 0.450 | 0.451 | 0.330 | 180/900/900 | 1995/2000/1995 | 2.25
spell_frost_nova | near | 1 | 0.050 | 0.250 | 0.250 | 0.183 | 100/500/500 | 2000/2000/2000 | -
spell_frost_nova | near | 5 | 0.320 | 0.560 | 0.560 | 0.480 | 640/1120/1120 | 2000/2000/2000 | 2.62
spell_ice_lances | far | 1 | 0.033 | 0.292 | 0.098 | 0.141 | 65/585/195 | 1995/2000/1995 | -
spell_ice_lances | far | 5 | 0.035 | 0.525 | 0.175 | 0.245 | 70/1050/350 | 1995/2000/1995 | 1.74
spell_fireball | far | 1 | 0.050 | 0.250 | 0.251 | 0.184 | 100/500/500 | 1995/2000/1995 | -
spell_fireball | far | 5 | 0.125 | 0.625 | 0.627 | 0.459 | 250/1250/1250 | 1995/2000/1995 | 2.50
spell_burning_ground | near | 1 | 0.060 | 0.240 | 0.300 | 0.200 | 120/480/600 | 2000/2000/2000 | -
spell_burning_ground | near | 5 | 0.144 | 0.720 | 0.720 | 0.528 | 288/1440/1440 | 2000/2000/2000 | 2.64
spell_meteor | far | 1 | 0.032 | 0.160 | 0.160 | 0.117 | 64/320/320 | 1995/2000/1995 | -
spell_meteor | far | 5 | 0.072 | 0.360 | 0.361 | 0.264 | 144/720/720 | 1995/2000/1995 | 2.25
spell_sky_strike | far | 1 | 0.075 | 0.083 | 0.084 | 0.081 | 150/300/300 | 1995/3600/3591 | -
spell_sky_strike | far | 5 | 0.180 | 0.200 | 0.201 | 0.194 | 360/720/720 | 1995/3600/3591 | 2.40
spell_ball_lightning | far | 1 | 0.100 | 0.090 | 0.056 | 0.082 | 200/325/200 | 1995/3600/3591 | -
spell_ball_lightning | far | 5 | 0.150 | 0.222 | 0.167 | 0.180 | 300/800/600 | 1995/3600/3591 | 2.34
spell_static_field | near | 1 | 0.002 | 0.133 | 0.179 | 0.105 | 4/480/644 | 2000/3600/3600 | -
spell_static_field | near | 5 | 0.120 | 0.333 | 0.333 | 0.262 | 240/1200/1200 | 2000/3600/3600 | 2.34
spell_venom_orb | far | 1 | 0.050 | 0.250 | 0.251 | 0.184 | 100/500/500 | 1995/2000/1995 | -
spell_venom_orb | far | 5 | 0.140 | 0.700 | 0.702 | 0.514 | 280/1400/1400 | 1995/2000/1995 | 2.80
spell_toxic_cloud | near | 1 | 0.000 | 0.338 | 0.000 | 0.113 | 0/675/0 | 2000/2000/2000 | -
spell_toxic_cloud | near | 5 | 0.150 | 0.600 | 0.750 | 0.500 | 300/1200/1500 | 2000/2000/2000 | 4.44
spell_spitter_vine | far | 1 | 0.175 | 0.175 | 0.175 | 0.175 | 350/350/350 | 1995/2000/1995 | -
spell_spitter_vine | far | 5 | 0.150 | 0.900 | 0.301 | 0.450 | 300/1800/600 | 1995/2000/1995 | 2.57
spell_blood_thorns | near | 1 | 0.050 | 0.150 | 0.250 | 0.150 | 100/300/500 | 2000/2000/2000 | -
spell_blood_thorns | near | 5 | 0.120 | 0.360 | 0.600 | 0.360 | 240/720/1200 | 2000/2000/2000 | 2.40
spell_hemorrhage | far | 1 | 0.261 | 0.148 | 0.120 | 0.176 | 520/296/240 | 1995/2000/1995 | -
spell_hemorrhage | far | 5 | 0.286 | 0.362 | 0.311 | 0.319 | 570/724/620 | 1995/2000/1995 | 1.81
spell_leech | far | 1 | 0.060 | 0.060 | 0.060 | 0.060 | 120/120/120 | 1995/2000/1995 | -
spell_leech | far | 5 | 0.099 | 0.178 | 0.259 | 0.179 | 197/357/517 | 1995/2000/1995 | 2.98
wand orbs, window 3600 ticks (60 s), spells at Lv 1
build | n | added share per scene (far single, far line, far pack, near single, near line, near pack) | mean added | spells dmg | wand dmg
(none) | 0 | 0.000 0.000 0.000 0.000 0.000 0.000 | 0.000 | 0 | 11990
fireball | 1 | 0.050 0.250 0.251 0.050 0.250 0.250 | 0.183 | 2200 | 11990
fireball+sky_strike | 2 | 0.125 0.222 0.223 0.125 0.222 0.222 | 0.190 | 3700 | 18386
fireball+sky_strike+frost_nova | 3 | 0.125 0.278 0.223 0.175 0.361 0.361 | 0.254 | 5000 | 18386
fireball+sky_strike+frost_nova+venom_orb | 4 | 0.175 0.417 0.362 0.225 0.500 0.500 | 0.363 | 7200 | 18386
blizzard+meteor+ball_lightning+hemorrhage | 4 | 0.433 0.373 0.323 0.432 0.345 0.322 | 0.371 | 6630 | 18386
ice_lances+burning_ground+static_field+spitter_vine | 4 | 0.208 0.338 0.152 0.270 0.526 0.497 | 0.332 | 6398 | 18386
toxic_cloud+blood_thorns+leech+fireball | 4 | 0.160 0.509 0.802 0.160 0.976 0.800 | 0.568 | 6810 | 11990
```

### Run 2, Laser, Glaive, Blade (reported, not judged)
```
wand laser, window 3600 ticks (60 s)
spell | scenes | Lv | share single | share line | share pack | mean share | spell dmg s/l/p | wand dmg s/l/p | Lv5/Lv1
spell_blizzard | far | 1 | 0.027 | 0.036 | 0.133 | 0.065 | 80/400/400 | 3000/11080/3000 | -
spell_blizzard | far | 5 | 0.060 | 0.081 | 0.300 | 0.147 | 180/900/900 | 3000/11080/3000 | 2.25
spell_frost_nova | near | 1 | 0.033 | 0.045 | 0.167 | 0.082 | 100/500/500 | 3000/11080/3000 | -
spell_frost_nova | near | 5 | 0.048 | 0.065 | 0.208 | 0.107 | 145/725/625 | 3000/11080/3000 | 1.36
spell_ice_lances | far | 1 | 0.022 | 0.053 | 0.065 | 0.046 | 65/585/195 | 3000/11080/3000 | -
spell_ice_lances | far | 5 | 0.023 | 0.095 | 0.117 | 0.078 | 70/1050/350 | 3000/11080/3000 | 1.74
spell_fireball | far | 1 | 0.033 | 0.045 | 0.167 | 0.082 | 100/500/500 | 3000/11080/3000 | -
spell_fireball | far | 5 | 0.083 | 0.113 | 0.417 | 0.204 | 250/1250/1250 | 3000/11080/3000 | 2.50
spell_burning_ground | near | 1 | 0.040 | 0.043 | 0.200 | 0.094 | 120/480/600 | 3000/11080/3000 | -
spell_burning_ground | near | 5 | 0.096 | 0.130 | 0.480 | 0.235 | 288/1440/1440 | 3000/11080/3000 | 2.64
spell_meteor | far | 1 | 0.021 | 0.029 | 0.107 | 0.052 | 64/320/320 | 3000/11080/3000 | -
spell_meteor | far | 5 | 0.048 | 0.065 | 0.240 | 0.118 | 144/720/720 | 3000/11080/3000 | 2.25
spell_sky_strike | far | 1 | 0.050 | 0.012 | 0.051 | 0.037 | 150/300/300 | 3000/25705/5925 | -
spell_sky_strike | far | 5 | 0.120 | 0.028 | 0.122 | 0.090 | 360/720/720 | 3000/25705/5925 | 2.40
spell_ball_lightning | far | 1 | 0.067 | 0.013 | 0.034 | 0.038 | 200/325/200 | 3000/25705/5925 | -
spell_ball_lightning | far | 5 | 0.100 | 0.031 | 0.101 | 0.077 | 300/800/600 | 3000/25705/5925 | 2.34
spell_static_field | near | 1 | 0.053 | 0.019 | 0.135 | 0.069 | 160/480/800 | 3000/25705/5925 | -
spell_static_field | near | 5 | 0.080 | 0.047 | 0.203 | 0.110 | 240/1200/1200 | 3000/25705/5925 | 1.83
spell_venom_orb | far | 1 | 0.033 | 0.045 | 0.167 | 0.082 | 100/500/500 | 3000/11080/3000 | -
spell_venom_orb | far | 5 | 0.093 | 0.126 | 0.467 | 0.229 | 280/1400/1400 | 3000/11080/3000 | 2.80
spell_toxic_cloud | near | 1 | 0.000 | 0.061 | 0.000 | 0.020 | 0/675/0 | 3000/11080/3000 | -
spell_toxic_cloud | near | 5 | 0.100 | 0.108 | 0.500 | 0.236 | 300/1200/1500 | 3000/11080/3000 | 4.44
spell_spitter_vine | far | 1 | 0.117 | 0.032 | 0.117 | 0.088 | 350/350/350 | 3000/11080/3000 | -
spell_spitter_vine | far | 5 | 0.100 | 0.162 | 0.200 | 0.154 | 300/1800/600 | 3000/11080/3000 | 2.57
spell_blood_thorns | near | 1 | 0.033 | 0.027 | 0.167 | 0.076 | 100/300/500 | 3000/11080/3000 | -
spell_blood_thorns | near | 5 | 0.080 | 0.065 | 0.400 | 0.182 | 240/720/1200 | 3000/11080/3000 | 2.40
spell_hemorrhage | far | 1 | 0.171 | 0.046 | 0.080 | 0.099 | 512/512/240 | 3000/11080/3000 | -
spell_hemorrhage | far | 5 | 0.187 | 0.102 | 0.207 | 0.165 | 562/1132/620 | 3000/11080/3000 | 1.83
spell_leech | far | 1 | 0.040 | 0.032 | 0.040 | 0.037 | 120/360/120 | 3000/11080/3000 | -
spell_leech | far | 5 | 0.067 | 0.054 | 0.173 | 0.098 | 200/600/520 | 3000/11080/3000 | 2.20
wand laser, window 3600 ticks (60 s), spells at Lv 1
build | n | added share per scene (far single, far line, far pack, near single, near line, near pack) | mean added | spells dmg | wand dmg
(none) | 0 | 0.000 0.000 0.000 0.000 0.000 0.000 | 0.000 | 0 | 34160
fireball | 1 | 0.033 0.045 0.167 0.033 0.045 0.167 | 0.082 | 2200 | 34160
fireball+sky_strike | 2 | 0.083 0.031 0.135 0.083 0.031 0.135 | 0.083 | 3700 | 69260
fireball+sky_strike+frost_nova | 3 | 0.083 0.039 0.135 0.117 0.051 0.219 | 0.107 | 5000 | 69260
fireball+sky_strike+frost_nova+venom_orb | 4 | 0.117 0.058 0.219 0.150 0.070 0.304 | 0.153 | 7200 | 69260
blizzard+meteor+ball_lightning+hemorrhage | 4 | 0.285 0.061 0.196 0.285 0.057 0.196 | 0.180 | 7046 | 69260
ice_lances+burning_ground+static_field+spitter_vine | 4 | 0.138 0.047 0.092 0.232 0.074 0.328 | 0.152 | 6710 | 69260
toxic_cloud+blood_thorns+leech+fireball | 4 | 0.107 0.116 0.533 0.107 0.187 0.533 | 0.264 | 7200 | 34160
wand glaive, window 3600 ticks (60 s)
spell | scenes | Lv | share single | share line | share pack | mean share | spell dmg s/l/p | wand dmg s/l/p | Lv5/Lv1
spell_blizzard | far | 1 | 0.039 | 0.037 | 0.195 | 0.090 | 80/384/400 | 2052/10320/2052 | -
spell_blizzard | far | 5 | 0.088 | 0.087 | 0.439 | 0.205 | 180/900/900 | 2052/10320/2052 | 2.29
spell_frost_nova | near | 1 | 0.049 | 0.054 | 0.244 | 0.116 | 100/500/500 | 2052/9240/2052 | -
spell_frost_nova | near | 5 | 0.139 | 0.150 | 0.373 | 0.221 | 285/1385/765 | 2052/9240/2052 | 2.21
spell_ice_lances | far | 1 | 0.032 | 0.057 | 0.095 | 0.061 | 65/585/195 | 2052/10320/2052 | -
spell_ice_lances | far | 5 | 0.034 | 0.102 | 0.171 | 0.102 | 70/1050/350 | 2052/10320/2052 | 1.74
spell_fireball | far | 1 | 0.049 | 0.043 | 0.244 | 0.112 | 100/440/500 | 2052/10320/2052 | -
spell_fireball | far | 5 | 0.122 | 0.109 | 0.609 | 0.280 | 250/1129/1250 | 2052/10320/2052 | 2.53
spell_burning_ground | near | 1 | 0.058 | 0.052 | 0.292 | 0.134 | 120/480/600 | 2052/9240/2052 | -
spell_burning_ground | near | 5 | 0.140 | 0.156 | 0.702 | 0.333 | 288/1440/1440 | 2052/9240/2052 | 2.64
spell_meteor | far | 1 | 0.031 | 0.031 | 0.156 | 0.073 | 64/320/320 | 2052/10320/2052 | -
spell_meteor | far | 5 | 0.070 | 0.070 | 0.351 | 0.164 | 144/720/720 | 2052/10320/2052 | 2.25
spell_sky_strike | far | 1 | 0.073 | 0.015 | 0.073 | 0.054 | 150/300/300 | 2052/20640/4104 | -
spell_sky_strike | far | 5 | 0.175 | 0.035 | 0.175 | 0.129 | 360/720/720 | 2052/20640/4104 | 2.40
spell_ball_lightning | far | 1 | 0.097 | 0.016 | 0.049 | 0.054 | 200/325/200 | 2052/20640/4104 | -
spell_ball_lightning | far | 5 | 0.146 | 0.039 | 0.146 | 0.110 | 300/800/600 | 2052/20640/4104 | 2.34
spell_static_field | near | 1 | 0.078 | 0.026 | 0.195 | 0.100 | 160/480/800 | 2052/18480/4104 | -
spell_static_field | near | 5 | 0.117 | 0.065 | 0.292 | 0.158 | 240/1200/1200 | 2052/18480/4104 | 1.83
spell_venom_orb | far | 1 | 0.049 | 0.042 | 0.244 | 0.111 | 100/434/500 | 2052/10320/2052 | -
spell_venom_orb | far | 5 | 0.136 | 0.130 | 0.682 | 0.316 | 280/1344/1400 | 2052/10320/2052 | 2.92
spell_toxic_cloud | near | 1 | 0.000 | 0.073 | 0.000 | 0.024 | 0/675/0 | 2052/9240/2052 | -
spell_toxic_cloud | near | 5 | 0.146 | 0.130 | 0.731 | 0.336 | 300/1200/1500 | 2052/9240/2052 | 4.44
spell_spitter_vine | far | 1 | 0.171 | 0.034 | 0.171 | 0.125 | 350/350/350 | 2052/10320/2052 | -
spell_spitter_vine | far | 5 | 0.146 | 0.174 | 0.292 | 0.204 | 300/1800/600 | 2052/10320/2052 | 2.57
spell_blood_thorns | near | 1 | 0.049 | 0.032 | 0.244 | 0.108 | 100/300/500 | 2052/9240/2052 | -
spell_blood_thorns | near | 5 | 0.117 | 0.078 | 0.585 | 0.260 | 240/720/1200 | 2052/9240/2052 | 2.40
spell_hemorrhage | far | 1 | 0.246 | 0.049 | 0.117 | 0.137 | 504/504/240 | 2052/10320/2052 | -
spell_hemorrhage | far | 5 | 0.270 | 0.109 | 0.302 | 0.227 | 554/1124/620 | 2052/10320/2052 | 1.84
spell_leech | far | 1 | 0.058 | 0.034 | 0.058 | 0.050 | 120/354/120 | 2052/10320/2052 | -
spell_leech | far | 5 | 0.096 | 0.057 | 0.252 | 0.135 | 197/591/517 | 2052/10320/2052 | 2.20
wand glaive, window 3600 ticks (60 s), spells at Lv 1
build | n | added share per scene (far single, far line, far pack, near single, near line, near pack) | mean added | spells dmg | wand dmg
(none) | 0 | 0.000 0.000 0.000 0.000 0.000 0.000 | 0.000 | 0 | 27768
fireball | 1 | 0.049 0.043 0.244 0.049 0.054 0.244 | 0.114 | 2140 | 27768
fireball+sky_strike | 2 | 0.122 0.036 0.195 0.122 0.043 0.195 | 0.119 | 3640 | 51432
fireball+sky_strike+frost_nova | 3 | 0.122 0.045 0.195 0.171 0.070 0.317 | 0.153 | 4920 | 51432
fireball+sky_strike+frost_nova+venom_orb | 4 | 0.171 0.066 0.317 0.219 0.097 0.439 | 0.218 | 7054 | 51432
blizzard+meteor+ball_lightning+hemorrhage | 4 | 0.413 0.074 0.283 0.413 0.078 0.283 | 0.257 | 6998 | 51432
ice_lances+burning_ground+static_field+spitter_vine | 4 | 0.202 0.059 0.133 0.339 0.103 0.474 | 0.218 | 6710 | 51432
toxic_cloud+blood_thorns+leech+fireball | 4 | 0.156 0.115 0.780 0.156 0.224 0.780 | 0.368 | 7098 | 27768
wand blade, window 3600 ticks (60 s)
spell | scenes | Lv | share single | share line | share pack | mean share | spell dmg s/l/p | wand dmg s/l/p | Lv5/Lv1
spell_blizzard | blade | 1 | 0.027 | 0.027 | 0.039 | 0.031 | 74/370/370 | 2769/13845/9541 | -
spell_blizzard | blade | 5 | 0.057 | 0.057 | 0.083 | 0.066 | 159/795/795 | 2769/13845/9541 | 2.15
spell_frost_nova | blade | 1 | 0.036 | 0.036 | 0.052 | 0.042 | 100/500/500 | 2769/13845/9541 | -
spell_frost_nova | blade | 5 | 0.126 | 0.126 | 0.132 | 0.128 | 350/1750/1260 | 2769/13845/9541 | 3.05
spell_ice_lances | blade | 1 | 0.023 | 0.042 | 0.057 | 0.041 | 65/585/546 | 2769/13845/9541 | -
spell_ice_lances | blade | 5 | 0.025 | 0.076 | 0.094 | 0.065 | 70/1050/896 | 2769/13845/9541 | 1.69
spell_fireball | blade | 1 | 0.036 | 0.036 | 0.052 | 0.042 | 100/500/500 | 2769/13845/9541 | -
spell_fireball | blade | 5 | 0.089 | 0.089 | 0.129 | 0.102 | 246/1230/1230 | 2769/13845/9541 | 2.46
spell_burning_ground | blade | 1 | 0.036 | 0.036 | 0.052 | 0.042 | 100/500/500 | 2769/13845/9541 | -
spell_burning_ground | blade | 5 | 0.087 | 0.087 | 0.126 | 0.100 | 240/1200/1200 | 2769/13845/9541 | 2.40
spell_meteor | blade | 1 | 0.023 | 0.023 | 0.034 | 0.027 | 64/320/320 | 2769/13845/9541 | -
spell_meteor | blade | 5 | 0.048 | 0.048 | 0.070 | 0.056 | 134/670/670 | 2769/13845/9541 | 2.09
spell_sky_strike | blade | 1 | 0.054 | 0.011 | 0.016 | 0.027 | 150/300/300 | 2769/27345/18857 | -
spell_sky_strike | blade | 5 | 0.130 | 0.026 | 0.038 | 0.065 | 360/720/720 | 2769/27345/18857 | 2.40
spell_ball_lightning | blade | 1 | 0.058 | 0.008 | 0.008 | 0.025 | 160/225/160 | 2769/27345/18857 | -
spell_ball_lightning | blade | 5 | 0.074 | 0.018 | 0.021 | 0.038 | 205/505/405 | 2769/27345/18857 | 2.05
spell_static_field | blade | 1 | 0.053 | 0.022 | 0.039 | 0.038 | 148/612/740 | 2769/27345/18857 | -
spell_static_field | blade | 5 | 0.077 | 0.039 | 0.056 | 0.057 | 212/1060/1060 | 2769/27345/18857 | 1.55
spell_venom_orb | blade | 1 | 0.033 | 0.033 | 0.047 | 0.037 | 90/450/450 | 2769/13845/9541 | -
spell_venom_orb | blade | 5 | 0.088 | 0.088 | 0.128 | 0.101 | 244/1220/1220 | 2769/13845/9541 | 2.71
spell_toxic_cloud | blade | 1 | 0.091 | 0.073 | 0.132 | 0.099 | 252/1008/1260 | 2769/13845/9541 | -
spell_toxic_cloud | blade | 5 | 0.121 | 0.118 | 0.176 | 0.139 | 336/1640/1680 | 2769/13845/9541 | 1.45
spell_spitter_vine | blade | 1 | 0.108 | 0.022 | 0.031 | 0.054 | 300/300/300 | 2769/13845/9541 | -
spell_spitter_vine | blade | 5 | 0.091 | 0.109 | 0.138 | 0.113 | 252/1512/1320 | 2769/13845/9541 | 3.43
spell_blood_thorns | blade | 1 | 0.000 | 0.014 | 0.000 | 0.005 | 0/200/0 | 2769/13845/9541 | -
spell_blood_thorns | blade | 5 | 0.000 | 0.035 | 0.000 | 0.012 | 0/480/4 | 2769/13845/9541 | 2.42
spell_hemorrhage | blade | 1 | 0.150 | 0.030 | 0.041 | 0.074 | 416/416/392 | 2769/13845/9541 | -
spell_hemorrhage | blade | 5 | 0.165 | 0.066 | 0.093 | 0.108 | 456/912/888 | 2769/13845/9541 | 1.84
spell_leech | blade | 1 | 0.040 | 0.040 | 0.058 | 0.046 | 111/555/555 | 2769/13845/9541 | -
spell_leech | blade | 5 | 0.066 | 0.066 | 0.095 | 0.076 | 182/910/910 | 2769/13845/9541 | 1.64
wand blade, window 3600 ticks (60 s), spells at Lv 1
build | n | added share per scene (single, line, pack) | mean added | spells dmg | wand dmg
(none) | 0 | 0.000 0.000 0.000 | 0.000 | 0 | 26155
fireball | 1 | 0.036 0.036 0.052 | 0.042 | 1100 | 26155
fireball+sky_strike | 2 | 0.090 0.029 0.042 | 0.054 | 1850 | 48971
fireball+sky_strike+frost_nova | 3 | 0.126 0.048 0.069 | 0.081 | 2950 | 48971
fireball+sky_strike+frost_nova+venom_orb | 4 | 0.159 0.064 0.093 | 0.105 | 3940 | 48971
blizzard+meteor+ball_lightning+hemorrhage | 4 | 0.258 0.049 0.066 | 0.124 | 3287 | 48971
ice_lances+burning_ground+static_field+spitter_vine | 4 | 0.221 0.073 0.111 | 0.135 | 4696 | 48971
toxic_cloud+blood_thorns+leech+fireball | 4 | 0.167 0.163 0.243 | 0.191 | 5032 | 26155
```

## Result (plain orbs, judged)

The tuning pass (one, the spells' own damage numbers only; no enemy HP, no wand change):

| Spell | Change | Why plain |
|---|---|---|
| Blizzard | damage 3,3,3,3,3 → 2,2,2,3,3 | Lv 1 22.0 % over the band from its own pulse damage; Lv 5 1.50 from a flat pulse (only the 4 → 6 s length grows in the scenes) |
| Frost Nova | Lv 5 shatter bonus_damage 12 → 5 | Lv 5 / Lv 1 4.60: the shatter is the spell's own number ((1368 - 5 x 24) / 12 = 104 shatters in 60 s on the single orbs target; frost_core freezes it too) |
| Burning Ground | damage 2,2,2,2,2 → 2,2,2,3,3 | Lv 5 1.76 from a flat pulse |
| Static Field | damage 4,4,3,3,3 → 4,4,4,4,4 | Lv 5 1.76; the pulse fell at Lv 3 |
| Venom Orb | damage 2,2,2,2,2 → 2,2,3,3,4 | Lv 5 1.40 from a flat pulse |

| Spell | Lv 1 share run 1 | Lv 1 share run 2 | In band (10–20 %)? | Lv5/Lv1 run 1 | Lv5/Lv1 run 2 | In band (2.0–3.0)? |
|---|---|---|---|---|---|---|
| Blizzard | 22.0 % | 14.7 % | yes | 1.50 | 2.25 | yes |
| Frost Nova | 18.3 % | 18.3 % | yes | 4.60 | 2.62 | yes |
| Ice Lances | 14.1 % | 14.1 % | yes | 1.74 | 1.74 | **no** |
| Fireball | 18.4 % | 18.4 % | yes | 2.50 | 2.50 | yes |
| Burning Ground | 20.0 % | 20.0 % | yes (edge) | 1.76 | 2.64 | yes |
| Meteor | 11.7 % | 11.7 % | yes | 2.25 | 2.25 | yes |
| Sky Strike | 8.1 % | 8.1 % | **no** | 2.40 | 2.40 | yes |
| Ball Lightning | 8.2 % | 8.2 % | **no** | 2.34 | 2.34 | yes |
| Static Field | 10.5 % | 10.5 % | yes (edge) | 1.76 | 2.34 | yes |
| Venom Orb | 18.4 % | 18.4 % | yes | 1.40 | 2.80 | yes |
| Toxic Cloud | 11.3 % | 11.3 % | yes | 4.44 | 4.44 | **no** |
| Spitter Vine | 17.5 % | 17.5 % | yes | 2.57 | 2.57 | yes |
| Blood Thorns | 15.0 % | 15.0 % | yes | 2.40 | 2.40 | yes |
| Hemorrhage | 17.6 % | 17.6 % | yes | 1.81 | 1.81 | **no** |
| Leech | 6.0 % | 6.0 % | **no** | 2.98 | 2.98 | yes (edge) |

Builds at Lv 1, plain orbs (mean added share over the 6 scenes; band +40 … +80 % for 4 spells):

| Build | n | Run 1 | Run 2 | In band? |
|---|---|---|---|---|
| (none) | 0 | 0.0 % | 0.0 % | — |
| Fireball | 1 | 18.3 % | 18.3 % | — |
| + Sky Strike | 2 | 19.0 % | 19.0 % | — |
| + Frost Nova | 3 | 25.4 % | 25.4 % | — |
| + Venom Orb | 4 | 36.3 % | 36.3 % | **no** |
| Blizzard + Meteor + Ball Lightning + Hemorrhage | 4 | 41.5 % | 37.1 % | run 1 yes, **run 2 no** |
| Ice Lances + Burning Ground + Static Field + Spitter Vine | 4 | 33.2 % | 33.2 % | **no** |
| Toxic Cloud + Blood Thorns + Leech + Fireball | 4 | 56.8 % | 56.8 % | yes |

Determinism: every row the tuning didn't touch (all spells but the five tuned; every build without Blizzard) is
identical in run 1 and run 2 (`diff` of the untouched rows: no difference).

## Interpretation
- **Three of the four 4-spell builds are under +40 % after the pass (36.3 %, 37.1 %, 33.2 %).** Per the owner rule, the
  numbers are reported and the step stops here: no enemy HP change, no second tuning pass. The tuning moved one build
  out of the band: Blizzard's Lv 1 cut (22.0 % → 14.7 %) took the Blizzard build from 41.5 % to 37.1 %.
- Why the 4-spell builds read under 4 × 15 %: each build's added share is the mean over 6 scenes, and every spell is
  weak in some of them: area spells deal about 5 % on one target (Fireball, Frost Nova, Venom Orb, Blizzard: 4–6 %
  single), near spells deal nothing in the FAR scenes (the Frost Nova build: FAR 0.125 / 0.278 / 0.223 vs NEAR 0.175 / 0.361 / 0.361), and Storm's
  card doubles the wand column on lines and packs (orbs wand dmg 2000 → 3600; build wand total 11990 → 18386 with
  `storm_core`), which halves every share in those builds.
- **Misses not fixable with the spells' own numbers (left, for the lead/owner):**
  - Sky Strike 8.1 %, Ball Lightning 8.2 % (Lv 1): the wand column holds `storm_core`'s non-DoT damage (3600 vs 2000 on
    line and pack). Against the same orbs without the Storm card's damage (≈ 2000) the same spell damage would be (arithmetic on the raw rows: 150, 300, 300 and 200, 325, 200 over 2000)
    7.5/15/15 % and 10/16/10 %. A rule question (what "the wand's DPS" includes), not a number.
  - Leech 6.0 % (Lv 1): it drains bleeding enemies only, and the orbs bleed one target at a time (120/120/120 on single,
    line and pack). Its damage scales with how many enemies bleed, i.e. the wand.
  - Ice Lances Lv 5 1.74: its levels add shards (3 → 6) and kill-splits; the scenes hold 5 undying dummies (pack: 3 hits
    a cast at Lv 1, 5 at Lv 5).
  - Hemorrhage Lv 5 1.81: most of its damage is the bleed it cashes in (the element card's), and Lv 5's second mark has
    one target in the single scene.
  - Toxic Cloud (Lv 1 0 % single and pack, Lv 5 4.44): it trails a moving hero; the scenes stand still, so its numbers
    here measure geometry, not the spell.
- What this doesn't measure: radius growth (every scene's dummies are inside Lv 1's radius, so Blizzard's, Burning
  Ground's, Venom Orb's and Static Field's Lv 5 radius buys nothing here; in bigger packs their Lv 5 is above what's
  shown), moving enemies, kills (Ice Lances' splits, Venom Orb's death pools), the dash (Static Field Lv 5), crit and the
  damage stat. The other wands are much stronger on lines and packs (Laser, Glaive), so the same spells are a smaller
  share of them (raw output above); they were reported, not judged.
- Frost Nova's Lv 5 shatter depends on how often the build freezes (with `frost_core` the orbs freeze one target about
  104 times a minute): run 2 reads 2.62 on the orbs, 1.36 on the Laser and 2.21 on the Glaive.

---

# O12b: the spells against the wand alone, with moving and dying enemies (owner E5-b, measure only)

- **Status:** RUN (one run; no tuning in this step; no data file changed)
- **Build:** base `f3267563` on `v0110-o12b`, working tree with this step's `scripts/balance/spells_dps.gd` (committed in
  the Step O12b commit). Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200 (owner's PC, i7-10700K)
- **Date:** 2026-11-07
- **Who ran it:** agent
- **What else ran:** 8 processes of this script side by side (4 wands x 2 parts, one `APPDATA` each), 21:25:32 to
  21:28:32; before them an import and the 4 `--part=effects` runs. Other agents may have been working on the same PC;
  no timing is used here.

## Command
```
godot --headless --path . -s scripts/balance/spells_dps.gd -- --wand=<orbs|laser|glaive|blade> --part=effects --out=balance/o12b
godot --headless --path . -s scripts/balance/spells_dps.gd -- --wand=<orbs|laser|glaive|blade> --part=spells_b --out=balance/o12b
godot --headless --path . -s scripts/balance/spells_dps.gd -- --wand=<orbs|laser|glaive|blade> --part=builds_b --out=balance/o12b
```
Raw output: `build/balance/o12b/spells_dps_<wand>_<part>.txt`; the band method `build/balance/o12b/bands.txt` (written
before the `spells_b` / `builds_b` runs started).

## What changed in the measure
- **Wand only.** The `effects` part lists the player's non-spell damage on the dummies by effect id, for the plain wand
  with no element card and with each card alone. The wand's own hits carry an empty effect id. Two element cards add
  direct damage under their own id: **`storm_core`** (Storm Core's jumps: orbs FAR line 1600, dying 1544) and
  **`ember_core`** (Ember Core's burst on a kill: orbs dying 42, Laser dying 2228). Those two ids are left out of
  "wand only". The others (`ember_edge`, `venom`, `bleed`) are DoT, already outside O12's column. Frost Core adds no
  direct damage.
- **Damage = HP taken** (`amount_applied`): equal to the amount on the 1 000 000 HP dummies, and no overkill on the
  dying ones. Check: on the orbs, every spell's summed old-scene damage at Lv 1 and Lv 5 and every old-scene "wand all"
  cell match O12 run 2.
- **New scenes.** The world's dummy steering, seeded: each dummy walks 2.4 m/s toward the hero plus the world's ±3 m
  jitter re-rolled from `rng_ai`, held 2.0 m off the hero (Blade 1.0 m). The hero aims at the nearest dummy each tick
  and can't die (`player_hp_floor`); the dummies don't shoot. Steered dummies stand in for enemy AI, so that nothing
  attacks and nothing else differs between runs.
  - **moving**: six 1 000 000 HP dummies (they live the whole window) start on a 4 m ring. The hero walks a circle at
    half stick, one lap per 6 s, so the pack chases and circles it and Toxic Cloud trails.
  - **dying**: 144 HP dummies (base 40, an arc caster's or mine layer's, x floor 5's `enemy_hp_floor_permille` 3610 of
    `five_floors`, tier 0) in waves of 5 every 3 s on a 7 m ring (turned 0.7 rad a wave), at most 10 alive. The hero
    stands. Kills are reported.
- O12's scenes are kept. Every spell now has five scenes (its home three + moving + dying), every build eight.

## Band method (as fixed in `bands.txt` before the run)
| Metric | Band | Judged reading | Also reported |
|---|---|---|---|
| Lv 1 share (spell / wand only), plain orbs | 10–20 % | mean of the 5 per-scene shares | old 3, new 2 |
| Lv 5 / Lv 1, plain orbs | 2.0–3.0 | summed spell dmg over the 5 scenes, Lv 5 / Lv 1 | old 3, new 2 |
| 4-spell builds at Lv 1, plain orbs | +40 … +80 % | mean of the 8 per-scene added shares | old 6, new 2 |
| Laser, Glaive, Blade | — | reported, not judged | — |

## Raw output excerpts (plain orbs)
`build/balance/o12b/spells_dps_orbs_spells_b.txt`, the summary lines:
```
sum | spell | Lv | mean share old3 | mean share new2 | mean share all5 | spell dmg old3/new2/all5 | Lv5/Lv1 old3 | Lv5/Lv1 new2 | Lv5/Lv1 all5
sum | spell_blizzard | 1 | 0.147 | 0.235 | 0.182 | 880/936/1816 | - | - | -
sum | spell_blizzard | 5 | 0.330 | 0.587 | 0.433 | 1980/2328/4308 | 2.25 | 2.49 | 2.37
sum | spell_frost_nova | 1 | 0.183 | 0.277 | 0.221 | 1100/1103/2203 | - | - | -
sum | spell_frost_nova | 5 | 0.480 | 0.619 | 0.536 | 2880/2457/5337 | 2.62 | 2.23 | 2.42
sum | spell_ice_lances | 1 | 0.141 | 0.180 | 0.156 | 845/715/1560 | - | - | -
sum | spell_ice_lances | 5 | 0.245 | 0.413 | 0.312 | 1470/1649/3119 | 1.74 | 2.31 | 2.00
sum | spell_fireball | 1 | 0.184 | 0.211 | 0.195 | 1100/840/1940 | - | - | -
sum | spell_fireball | 5 | 0.459 | 0.551 | 0.496 | 2750/2189/4939 | 2.50 | 2.61 | 2.55
sum | spell_burning_ground | 1 | 0.200 | 0.269 | 0.227 | 1200/1054/2254 | - | - | -
sum | spell_burning_ground | 5 | 0.528 | 0.879 | 0.669 | 3168/3463/6631 | 2.64 | 3.29 | 2.94
sum | spell_meteor | 1 | 0.117 | 0.190 | 0.147 | 704/758/1462 | - | - | -
sum | spell_meteor | 5 | 0.264 | 0.416 | 0.325 | 1584/1647/3231 | 2.25 | 2.17 | 2.21
sum | spell_sky_strike | 1 | 0.125 | 0.138 | 0.130 | 750/550/1300 | - | - | -
sum | spell_sky_strike | 5 | 0.300 | 0.324 | 0.310 | 1800/1286/3086 | 2.40 | 2.34 | 2.37
sum | spell_ball_lightning | 1 | 0.121 | 0.106 | 0.115 | 725/420/1145 | - | - | -
sum | spell_ball_lightning | 5 | 0.284 | 0.236 | 0.265 | 1700/939/2639 | 2.34 | 2.24 | 2.30
sum | spell_static_field | 1 | 0.188 | 0.262 | 0.218 | 1128/1033/2161 | - | - | -
sum | spell_static_field | 5 | 0.440 | 0.715 | 0.550 | 2640/2819/5459 | 2.34 | 2.73 | 2.53
sum | spell_venom_orb | 1 | 0.184 | 0.182 | 0.183 | 1100/722/1822 | - | - | -
sum | spell_venom_orb | 5 | 0.514 | 0.709 | 0.592 | 3080/2787/5867 | 2.80 | 3.86 | 3.22
sum | spell_toxic_cloud | 1 | 0.113 | 0.174 | 0.137 | 675/689/1364 | - | - | -
sum | spell_toxic_cloud | 5 | 0.500 | 0.515 | 0.506 | 3000/2041/5041 | 4.44 | 2.96 | 3.70
sum | spell_spitter_vine | 1 | 0.175 | 0.177 | 0.176 | 1050/695/1745 | - | - | -
sum | spell_spitter_vine | 5 | 0.450 | 0.571 | 0.499 | 2700/2255/4955 | 2.57 | 3.24 | 2.84
sum | spell_blood_thorns | 1 | 0.150 | 0.342 | 0.227 | 900/1360/2260 | - | - | -
sum | spell_blood_thorns | 5 | 0.360 | 0.748 | 0.515 | 2160/2968/5128 | 2.40 | 2.18 | 2.27
sum | spell_hemorrhage | 1 | 0.176 | 0.181 | 0.178 | 1056/719/1775 | - | - | -
sum | spell_hemorrhage | 5 | 0.319 | 0.501 | 0.392 | 1914/1986/3900 | 1.81 | 2.76 | 2.20
sum | spell_leech | 1 | 0.060 | 0.222 | 0.125 | 360/882/1242 | - | - | -
sum | spell_leech | 5 | 0.179 | 0.486 | 0.302 | 1071/1940/3011 | 2.98 | 2.20 | 2.42
```
Some per-scene rows (spell dmg | wand all | wand only | share | kills):
```
row | spell_sky_strike | 1 | far single | 150 | 1995 | 1995 | 0.075 | 0
row | spell_sky_strike | 1 | far line | 300 | 3600 | 2000 | 0.150 | 0
row | spell_sky_strike | 1 | far pack | 300 | 3591 | 1995 | 0.150 | 0
row | spell_sky_strike | 1 | moving | 300 | 3592 | 2000 | 0.150 | 0
row | spell_sky_strike | 1 | dying | 250 | 3512 | 1973 | 0.127 | 23
row | spell_ball_lightning | 1 | moving | 245 | 3592 | 2000 | 0.123 | 0
row | spell_ball_lightning | 1 | dying | 175 | 3518 | 1975 | 0.089 | 20
row | spell_leech | 1 | moving | 426 | 2000 | 2000 | 0.213 | 0
row | spell_leech | 1 | dying | 456 | 1972 | 1972 | 0.231 | 29
row | spell_venom_orb | 1 | dying | 232 | 1957 | 1957 | 0.119 | 67
row | spell_venom_orb | 5 | dying | 1359 | 1928 | 1928 | 0.705 | 72
row | spell_ice_lances | 5 | dying | 669 | 1988 | 1988 | 0.337 | 14
```
`build/balance/o12b/spells_dps_orbs_builds_b.txt`:
```
build | n | added share per scene (far single, far line, far pack, near single, near line, near pack, moving, dying) | mean old6 | mean new2 | mean all8 | spells dmg | wand all | wand only | kills dying
(none) | 0 | 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 | 0.000 | 0.000 | 0.000 | 0 | 15981 | 15981 | 9
fireball | 1 | 0.050 0.250 0.251 0.050 0.250 0.250 0.250 0.173 | 0.183 | 0.211 | 0.190 | 3040 | 16022 | 15958 | 36
fireball+sky_strike | 2 | 0.125 0.400 0.401 0.125 0.400 0.400 0.400 0.303 | 0.309 | 0.351 | 0.319 | 5098 | 25679 | 15966 | 47
fireball+sky_strike+frost_nova | 3 | 0.125 0.500 0.401 0.175 0.650 0.650 0.600 0.498 | 0.417 | 0.549 | 0.450 | 7185 | 25716 | 15966 | 63
fireball+sky_strike+frost_nova+venom_orb | 4 | 0.175 0.750 0.652 0.225 0.900 0.900 0.843 0.371 | 0.600 | 0.607 | 0.602 | 9602 | 25369 | 15919 | 92
blizzard+meteor+ball_lightning+hemorrhage | 4 | 0.433 0.670 0.581 0.432 0.621 0.580 0.701 0.488 | 0.553 | 0.594 | 0.563 | 8985 | 25774 | 15943 | 71
ice_lances+burning_ground+static_field+spitter_vine | 4 | 0.208 0.608 0.273 0.270 0.948 0.894 0.705 0.475 | 0.533 | 0.590 | 0.547 | 8714 | 25368 | 15901 | 93
toxic_cloud+blood_thorns+leech+fireball | 4 | 0.160 0.509 0.802 0.160 0.976 0.800 1.152 0.780 | 0.568 | 0.966 | 0.667 | 10602 | 15933 | 15898 | 82
```

## Result (plain orbs, judged)

| Spell | Lv 1 O12 run 2 (old 3, wand all) | old 3, wand only | new 2 | **all 5 (judged)** | In 10–20 %? | Lv5/Lv1 O12 run 2 | new 2 | **all 5 (judged)** | In 2.0–3.0? |
|---|---|---|---|---|---|---|---|---|---|
| Blizzard | 14.7 % | 14.7 % | 23.5 % | **18.2 %** | yes | 2.25 | 2.49 | **2.37** | yes |
| Frost Nova | 18.3 % | 18.3 % | 27.7 % | **22.1 %** | **no (over)** | 2.62 | 2.23 | **2.42** | yes |
| Ice Lances | 14.1 % | 14.1 % | 18.0 % | **15.6 %** | yes | 1.74 | 2.31 | **2.00** (3119 / 1560 = 1.9994) | **no (under by 0.0006)** |
| Fireball | 18.4 % | 18.4 % | 21.1 % | **19.5 %** | yes | 2.50 | 2.61 | **2.55** | yes |
| Burning Ground | 20.0 % | 20.0 % | 26.9 % | **22.7 %** | **no (over)** | 2.64 | 3.29 | **2.94** | yes |
| Meteor | 11.7 % | 11.7 % | 19.0 % | **14.7 %** | yes | 2.25 | 2.17 | **2.21** | yes |
| Sky Strike | 8.1 % | 12.5 % | 13.8 % | **13.0 %** | yes | 2.40 | 2.34 | **2.37** | yes |
| Ball Lightning | 8.2 % | 12.1 % | 10.6 % | **11.5 %** | yes | 2.34 | 2.24 | **2.30** | yes |
| Static Field | 10.5 % | 18.8 % | 26.2 % | **21.8 %** | **no (over)** | 2.34 | 2.73 | **2.53** | yes |
| Venom Orb | 18.4 % | 18.4 % | 18.2 % | **18.3 %** | yes | 2.80 | 3.86 | **3.22** | **no (over)** |
| Toxic Cloud | 11.3 % | 11.3 % | 17.4 % | **13.7 %** | yes | 4.44 | 2.96 | **3.70** | **no (over)** |
| Spitter Vine | 17.5 % | 17.5 % | 17.7 % | **17.6 %** | yes | 2.57 | 3.24 | **2.84** | yes |
| Blood Thorns | 15.0 % | 15.0 % | 34.2 % | **22.7 %** | **no (over)** | 2.40 | 2.18 | **2.27** | yes |
| Hemorrhage | 17.6 % | 17.6 % | 18.1 % | **17.8 %** | yes | 1.81 | 2.76 | **2.20** | yes |
| Leech | 6.0 % | 6.0 % | 22.2 % | **12.5 %** | yes | 2.98 | 2.20 | **2.42** | yes |

On the old scenes only Sky Strike, Ball Lightning and Static Field change between "wand all" and "wand only": they hold
Storm Core, whose jumps were in O12's column. Ember Core's on-kill burst only happens where dummies die.

Builds at Lv 1, plain orbs (added share = spells / wand only):

| Build | n | O12 run 2 (old 6, wand all) | old 6, wand only | new 2 | **all 8 (judged)** | In +40…+80 %? |
|---|---|---|---|---|---|---|
| (none) | 0 | 0.0 % | 0.0 % | 0.0 % | 0.0 % | — |
| Fireball | 1 | 18.3 % | 18.3 % | 21.1 % | 19.0 % | — |
| + Sky Strike | 2 | 19.0 % | 30.9 % | 35.1 % | 31.9 % | — |
| + Frost Nova | 3 | 25.4 % | 41.7 % | 54.9 % | 45.0 % | — |
| + Venom Orb | 4 | 36.3 % | 60.0 % | 60.7 % | **60.2 %** | yes |
| Blizzard + Meteor + Ball Lightning + Hemorrhage | 4 | 37.1 % | 55.3 % | 59.4 % | **56.3 %** | yes |
| Ice Lances + Burning Ground + Static Field + Spitter Vine | 4 | 33.2 % | 53.3 % | 59.0 % | **54.7 %** | yes |
| Toxic Cloud + Blood Thorns + Leech + Fireball | 4 | 56.8 % | 56.8 % | 96.6 % | **66.7 %** | yes |

### What is inside, what misses (judged readings)
- **Inside:** all four 4-spell builds (60.2 / 56.3 / 54.7 / 66.7 %). Lv 1 share: 11 of 15 (Blizzard, Ice Lances,
  Fireball, Meteor, Sky Strike, Ball Lightning, Venom Orb, Toxic Cloud, Spitter Vine, Hemorrhage, Leech). Lv 5 / Lv 1:
  12 of 15.
- **Misses, Lv 1 share over 20 %:** Frost Nova 22.1 %, Burning Ground 22.7 %, Static Field 21.8 %, Blood Thorns
  22.7 %. All four are NEAR spells; their new-scene means are 27.7 / 26.9 / 26.2 / 34.2 % (the pack, held 2 m off the
  hero, sits inside their reach).
- **Misses, Lv 5 / Lv 1:** Venom Orb 3.22 (its dying share goes 0.119 at Lv 1 → 0.705 at Lv 5: the Lv 5 pools a kill
  leaves), Toxic Cloud 3.70 (the old scenes still read 4.44; the new two 2.96), Ice Lances 1.9994 (prints as 2.00 but
  is under 2.0).
- No tuning was done (the owner's rule for this step). The misses are reported for the lead and the owner.

## Laser, Glaive, Blade (reported, not judged)
From `build/balance/o12b/spells_dps_<wand>_spells_b.txt` (sum lines, all 5) and `_builds_b.txt`:

| Spell | Laser Lv 1 | Laser Lv5/Lv1 | Glaive Lv 1 | Glaive Lv5/Lv1 | Blade Lv 1 | Blade Lv5/Lv1 |
|---|---|---|---|---|---|---|
| Blizzard | 7.9 % | 2.47 | 8.4 % | 2.33 | 18.3 % | 2.22 |
| Frost Nova | 10.3 % | 1.40 | 10.9 % | 2.05 | 11.7 % | 2.59 |
| Ice Lances | 6.3 % | 1.86 | 5.8 % | 1.99 | 21.0 % | 1.90 |
| Fireball | 9.3 % | 2.44 | 9.6 % | 2.51 | 21.7 % | 2.39 |
| Burning Ground | 11.9 % | 2.99 | 11.5 % | 2.96 | 11.3 % | 3.30 |
| Meteor | 7.1 % | 2.10 | 6.8 % | 2.15 | 15.3 % | 2.01 |
| Sky Strike | 6.4 % | 2.40 | 6.7 % | 2.41 | 14.0 % | 2.35 |
| Ball Lightning | 4.9 % | 2.39 | 5.9 % | 2.26 | 9.5 % | 2.17 |
| Static Field | 14.2 % | 2.11 | 13.4 % | 2.28 | 8.1 % | 2.09 |
| Venom Orb | 9.6 % | 3.11 | 9.1 % | 3.34 | 17.9 % | 3.31 |
| Toxic Cloud | 5.3 % | 3.61 | 3.5 % | 3.75 | 26.0 % | 1.76 |
| Spitter Vine | 10.1 % | 2.87 | 10.3 % | 2.80 | 17.0 % | 3.47 |
| Blood Thorns | 10.4 % | 2.48 | 11.1 % | 2.33 | 23.2 % | 2.62 |
| Hemorrhage | 8.4 % | 1.97 | 10.5 % | 2.05 | 14.4 % | 2.09 |
| Leech | 3.5 % | 2.97 | 6.6 % | 2.00 | 10.6 % | 1.89 |

| 4-spell build (Lv 1; mean all 8, the Blade all 5) | Laser | Glaive | Blade |
|---|---|---|---|
| Fireball + Sky Strike + Frost Nova + Venom Orb | 29.5 % | 35.1 % | 51.7 % |
| Blizzard + Meteor + Ball Lightning + Hemorrhage | 27.5 % | 33.7 % | 57.3 % |
| Ice Lances + Burning Ground + Static Field + Spitter Vine | 29.1 % | 32.7 % | 59.1 % |
| Toxic Cloud + Blood Thorns + Leech + Fireball | 33.5 % | 35.5 % | 101.2 % |

The Blade's new-scene readings are not like-for-like. In the moving scene the Blade hits little while the hero walks
its loop (the Fireball Lv 1 rows: wand only 551 in moving, 6600 in dying), so its moving shares are large (Fireball
0.907).

## Interpretation
- Counting the wand alone moves the two Storm spells into the band (Sky Strike 8.1 → 13.0 %, Ball Lightning
  8.2 → 11.5 %). It also moves the orbs' 4-spell builds from 33–37 % to 53–60 % on the old scenes alone.
- The new scenes raise most shares. The moving pack crowds the area and NEAR spells, while the orbs hit one target at a
  time (wand only 2000 in every moving row and 1921–1991 in every dying row). Leech reads 22.2 % in the new scenes
  against 6.0 % on the old ones. The kills raise Venom Orb's and Ice Lances' Lv 5 / Lv 1 (new 3.86 and 2.31).
- The dying stream is bounded by the enemies the window spawns and by kills: a spell that kills early takes HP the
  wand would have taken. On the orbs the effect on the wand column is small (the 1921–1991 range above).
- What this doesn't measure: real enemy AI (attacks, dodges, ranged kinds), crit and the damage stat, the dash
  (Static Field Lv 5), rooms with walls.

# S13 room density (theory audit P8, Swink's spatial context)

Measure only: no room was changed.

- **Build SHA:** `6035194a` (branch `v0105-s13`; the script was untracked when run, then formatted by `gdformat` with whitespace-only changes and not re-run).
- **Machine:** the owner's PC (Windows 11), Godot 4.7.2 headless. Run time 11 min 37 s (a timing on this machine, not a target).
- **Command:** `godot --headless --path . -s scripts/checks/room_density.gd` (output also written to `build/room_density.txt`).
- **Method:** `FloorGenerator.generate` with the shipped tables (`RunSaver.floor_tables(null, repo)`), 50 seeds x 3 floor numbers (seed = `9001 + s*7919 + floor*1000003`). The generator takes no floor number, so floors differ by seed only and every template has "all floors" as its range. Rooms are grouped by their designed layout; `rule_tN` is the rule-built interior (start hall, portal room, and sizes with no layout: 1x4, 2x4). Each room is sampled on a 0.25 m grid; a point is blocked when it is within 0.35 m (player radius) of any wall or piece, the room's own walls included. "circle" is the largest distance from any wall or piece (largest open circle radius). `cover` is the mean count of interior pieces per room. `wgt` is the draw weight among its size (0 = not a layout). `bad` counts individual rooms under a threshold. In the `rule_t` rows, `size` is the first room's size and `area_m2` is the mean over mixed sizes.
- **Thresholds (starting values, not measurements):** cramped = open < 55 % or largest circle < 2.5 m; empty = open > 92 % and no cover. A template is flagged on its mean.

## Raw output

```
room density: 50 seeds x 3 floor numbers, step 0.25 m, player radius 0.35 m
thresholds (starting values): cramped = open < 55 % or circle < 2.5 m; empty = open > 92 % and no cover
floor range: all floors (the generator takes no floor number); weight = draw weight among its size
template     size wgt rooms  area_m2   open% minopen circle_m  mincirc  cover   bad  flag
room_1x1_2   1x1    1   200    124.0    75.9    67.5     2.92     2.03    8.6    67  
room_2x1_2   1x2    1   211    281.2    77.1    69.3     3.82     2.37   12.5     1  
room_2x2_2   2x2    1    61    626.8    77.5    70.5     4.71     3.78   32.3     0  
room_3x2_2   3x2    1    70    971.7    78.4    73.9     5.55     4.54   60.6     0  
room_3x2_3   2x3    1    79    972.1    79.0    73.1     5.40     3.97   46.4     0  
room_2x2_1   2x2    1    78    616.5    79.1    69.8     4.72     3.84   32.1     0  
room_3x1_2   1x3    1   107    435.3    79.1    70.6     3.95     2.87   19.1     0  
room_1x1_3   1x1    1   231    124.1    79.3    68.5     3.77     2.63    9.5     0  
room_3x3_3   3x3    1    27   1525.4    79.4    75.5     5.31     4.51   88.3     0  
room_2x1_3   1x2    1   234    281.6    79.7    69.6     4.76     3.06   16.4     0  
room_3x2_1   2x3    1    72    974.8    79.7    74.2     5.73     4.90   57.8     0  
room_3x3_1   3x3    1    18   1533.9    79.7    75.6     6.12     5.49   82.2     0  
room_4x3_3   4x3    1    17   2061.3    79.7    77.0     6.49     5.45  105.9     0  
room_4x4_1   4x4    1     6   2619.3    80.3    79.6     7.02     6.70  140.3     0  
room_3x3_2   3x3    1    27   1517.8    80.5    76.5     4.78     4.01   74.1     0  
room_1x1_1   1x1    1   224    122.3    80.6    68.2     4.77     3.45    6.3     0  
room_2x2_3   2x2    1    69    626.4    80.6    70.1     5.11     3.28   33.0     0  
room_4x3_2   4x3    1    15   2096.5    80.6    77.4     7.00     5.98  107.5     0  
room_3x1_3   3x1    1   115    435.8    80.9    74.9     4.88     3.41   24.7     0  
room_4x3_1   4x3    1    14   2036.0    81.1    77.7     7.32     6.37   97.3     0  
room_4x4_3   4x4    1     7   2808.0    81.7    79.9     7.88     5.95  135.7     0  
room_2x1_1   2x1    1   235    278.7    83.2    76.0     5.43     3.62   12.5     0  
room_3x1_1   1x3    1   117    431.6    83.7    78.7     5.34     3.72   18.8     0  
room_4x4_2   4x4    1     8   2755.0    84.3    81.2     8.43     7.08  106.5     0  
rule_t11     1x1    0    50    890.9    86.8    73.1     7.63     4.03   18.3     0  
rule_t12     1x1    0    70    925.1    86.9    73.9     7.74     3.94   18.4     0  
rule_t9      3x3    0    96   1029.7    88.3    78.9     8.60     3.68   18.7     0  
rule_t10     3x3    0    79    996.7    88.5    75.8     7.47     4.13   20.4     0  
rule_t0      1x1    0     5    189.2    89.4    87.8     5.05     4.74    0.0     0  
templates: 29
```

## Flagged templates (on the mean)

- Cramped: none. The lowest mean open share is 75.9 % (`room_1x1_2`); the lowest mean circle is 2.92 m (`room_1x1_2`).
- Empty: none. The highest mean open share is 89.4 % (`rule_t0`, 5 rooms, 0.0 cover; below the 92 % line).

## Individual rooms under a threshold (not flagged by mean)

- `room_1x1_2`: 67 of 200 rooms have a largest circle under 2.5 m (minimum 2.03 m); minimum open share 67.5 %.
- `room_2x1_2`: 1 of 211 rooms (minimum circle 2.37 m).
- No room is under 55 % open (lowest 67.5 %, `room_1x1_2`).

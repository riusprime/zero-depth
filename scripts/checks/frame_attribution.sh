#!/bin/bash
# The frame probe's attribution set for one scene, back to back: the baseline three times (the spread), then every
# switch twice, each followed by a baseline. Every report goes to build/attribution/<scene>/<sha>/; the summary table
# is printed and saved there as summary.txt. Needs a quiet machine: differences smaller than the baselines' spread
# mean nothing, and the table says which ones are.
#   bash scripts/checks/frame_attribution.sh swarm120|heavy60|enemies20 [secs]
# Environment: GODOT (default godot), SWITCHES (a space-separated list overriding the default set below).
set -u
scene=${1:-swarm120}
secs=${2:-20}
case $scene in
	swarm120) args="--enemies=120 --only=swarmer" ;;
	heavy60) args="--enemies=60 --heavy --fx" ;;
	enemies20) args="" ;;
	*)
		echo "unknown scene $scene (swarm120, heavy60, enemies20)"
		exit 2
		;;
esac
godot=${GODOT:-godot}
cd "$(dirname "$0")/../.." || exit 2
sha=$(git rev-parse --short HEAD)
out="build/attribution/$scene/$sha"
mkdir -p "$out"
# ab:<flag> is --ab=<flag> (frame_probe.gd and frame_spans.gd); size:<WxH> renders a tiny window (the GPU's share).
default="ab:no_fti ab:hide_actors ab:detach_actors ab:no_anim ab:no_particles ab:no_hud ab:no_sun_shadow ab:no_omni"
default="$default ab:no_3d ab:no_viewport size:320x180"
switches=${SWITCHES:-$default}

run() { # run <label> <switch|base>
	local label=$1 sw=$2 res=1920x1080 extra=""
	case $sw in
		ab:*) extra="--ab=${sw#ab:}" ;;
		size:*)
			res=${sw#size:}
			extra="--size=$res"
			;;
	esac
	APPDATA="$PWD/build/attribution/appdata" "$godot" --path . --resolution "$res" --windowed \
		--position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon $args \
		--secs="$secs" --spans $extra >"$out/$label.txt" 2>&1
	echo "$label $sw $(grep -m1 '^frames=' "$out/$label.txt")"
}

n=0
order=()
for i in 1 2 3; do
	n=$((n + 1))
	run "$(printf %02d $n)_base" base
	order+=("$(printf %02d $n)_base")
done
for round in 1 2; do
	for sw in $switches; do
		n=$((n + 1))
		run "$(printf %02d $n)_${sw//[:x]/_}" "$sw"
		order+=("$(printf %02d $n)_${sw//[:x]/_}")
		n=$((n + 1))
		run "$(printf %02d $n)_base" base
		order+=("$(printf %02d $n)_base")
	done
done

# The table: the baseline is every base run (the first three and the interleaved ones); its spread is max - min.
for label in "${order[@]}"; do
	f="$out/$label.txt"
	avg=$(grep -m1 -o 'avg_ms=[0-9.]*' "$f" | cut -d= -f2)
	p50=$(grep -m1 -o 'p50_ms=[0-9.]*' "$f" | cut -d= -f2)
	echo "$label ${avg:-NA} ${p50:-NA}"
done | awk -v scene="$scene" -v sha="$sha" -v secs="$secs" '
	{ lab[NR] = $1; avg[NR] = $2; p50[NR] = $3
	  if ($1 ~ /_base$/ && $2 != "NA") { nb++; sb += $2; sp += $3
		if (nb == 1 || $2 < lo) lo = $2; if (nb == 1 || $2 > hi) hi = $2 } }
	END {
		mb = sb / nb; mp = sp / nb; spread = hi - lo
		printf "frame attribution  scene=%s  sha=%s  secs=%s\n", scene, sha, secs
		printf "baseline: %d runs, mean avg_ms %.3f, mean p50_ms %.3f, spread (max - min avg_ms) %.3f\n", nb, mb, mp, spread
		printf "%-28s %9s %9s %11s %s\n", "experiment", "avg_ms", "p50_ms", "diff_ms", "beyond_spread"
		for (i = 1; i <= NR; i++) {
			if (avg[i] == "NA") { printf "%-28s %9s %9s %11s %s\n", lab[i], "NA", "NA", "-", "run failed"; continue }
			d = avg[i] - mb; a = d < 0 ? -d : d
			printf "%-28s %9.3f %9.3f %+11.3f %s\n", lab[i], avg[i], p50[i], d, (lab[i] ~ /_base$/ ? "(baseline)" : (a > spread ? "yes" : "no"))
			if (lab[i] !~ /_base$/) { k = substr(lab[i], 4); if (!(k in cnt)) keys[++nk] = k; cnt[k]++; sa[k] += avg[i]; spp[k] += p50[i] }
		}
		printf "per switch, mean of its runs:\n"
		for (j = 1; j <= nk; j++) {
			k = keys[j]; m = sa[k] / cnt[k]; d = m - mb; a = d < 0 ? -d : d
			printf "%-28s %9.3f %9.3f %+11.3f %s\n", k, m, spp[k] / cnt[k], d, (a > spread ? "yes" : "no")
		}
	}' | tee "$out/summary.txt"

#!/usr/bin/env python3
"""Summarize one perf-log CSV (the game's `-- --perf-log`, docs/process/PERF_LOG.md) into a short markdown report.

    python scripts/perf/summarize_perf.py <perf_....csv> [--out build/perf/<name>_summary.md]
    python scripts/perf/summarize_perf.py --self-check

The report goes to build/perf/<csv name>_summary.md (never into docs) and is at most about 150 lines: the totals per
scene and floor, the 50 worst frames with their top costs and load, the stutter clusters (over 33 ms and over 50 ms),
the frame time against enemies and against projectiles, the top costs over the run (sim / views / listeners / other
script / unaccounted engine+draw), and a window of +-2 s round each F9 mark. A light log (no breakdown columns) gets
everything but the costs. Python 3 standard library only.
"""

import argparse
import bisect
import csv
import os
import random
import shutil
import sys
import tempfile
import time
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLAY_SCENES = {"run", "stage", "playground", "training"}
# Buckets that only sum others (PerfRecorder's split columns cover them); left out of the "top costs" lists.
PARENTS = {"step_once", "ticked_all", "frame_synced", "sync_all"}
CATS = [
    ("sim", "sim_us"),
    ("views", "views_us"),
    ("listeners", "listeners_us"),
    ("other script", "other_script_us"),
    ("engine+draw (unaccounted)", "engine_us"),
]
ENEMY_BUCKETS = [(0, 0), (1, 10), (11, 20), (21, 40), (41, 60), (61, 100), (101, 10**9)]
PROJ_BUCKETS = [(0, 0), (1, 50), (51, 100), (101, 200), (201, 400), (401, 10**9)]
WORST_N = 50
CLUSTER_GAP_S = 0.25  # bad frames this close belong to one cluster
MARK_WINDOW_S = 2.0


def _num(s, default=0.0):
    try:
        return float(s) if s != "" else default
    except ValueError:
        return default


def pct(sorted_vals, q):
    if not sorted_vals:
        return 0.0
    k = max(0, min(len(sorted_vals) - 1, int(-(-q * len(sorted_vals) // 1)) - 1))
    return sorted_vals[k]


def _is_parent(key):
    return key in PARENTS or key.endswith("world_view_root.gd.sync")


class Frame:
    __slots__ = (
        "i", "t", "scene", "floor", "biome", "ms", "ticks", "enemies", "pp", "pe", "fx", "boss", "phase",
        "mark", "cats", "bd",
    )


def load(path):
    frames = []
    full = False
    with open(path, newline="", encoding="utf-8") as f:
        rd = csv.reader(f)
        head = next(rd)
        col = {name: k for k, name in enumerate(head)}
        full = "bd" in col
        need = ["t_s", "scene", "floor", "biome", "frame_ms", "ticks", "enemies", "proj_player", "proj_enemy"]
        for n in need:
            if n not in col:
                raise SystemExit("not a perf-log CSV: no column %r" % n)
        cat_cols = [(name, col[c]) for name, c in CATS if c in col] if full else []
        g = lambda row, name, d="": row[col[name]] if name in col and col[name] < len(row) else d  # noqa: E731
        for k, row in enumerate(rd):
            if len(row) < len(head) - (1 if full else 0):
                continue  # a row cut by a crash
            fr = Frame()
            fr.i = k
            fr.t = _num(row[col["t_s"]])
            fr.scene = row[col["scene"]]
            fr.floor = row[col["floor"]]
            fr.biome = row[col["biome"]]
            fr.ms = _num(row[col["frame_ms"]])
            fr.ticks = int(_num(row[col["ticks"]]))
            fr.enemies = int(_num(row[col["enemies"]]))
            fr.pp = int(_num(row[col["proj_player"]]))
            fr.pe = int(_num(row[col["proj_enemy"]]))
            fr.fx = int(_num(g(row, "fx")))
            fr.boss = g(row, "boss") == "1"
            fr.phase = g(row, "boss_phase")
            fr.mark = g(row, "mark")
            fr.cats = {name: _num(row[c]) for name, c in cat_cols} if full else None
            fr.bd = None
            if full:
                bd = {}
                s = row[col["bd"]] if col["bd"] < len(row) else ""
                if s:
                    for part in s.split(";"):
                        key, _, v = part.rpartition("=")
                        if key:
                            bd[key] = float(v)
                fr.bd = bd
            frames.append(fr)
    return frames, full


def stats(ms_list):
    s = sorted(ms_list)
    total = sum(s)
    n = len(s)
    return {
        "n": n,
        "avg": total / n if n else 0.0,
        "p50": pct(s, 0.50),
        "p95": pct(s, 0.95),
        "p99": pct(s, 0.99),
        "max": s[-1] if s else 0.0,
        "fps": n / (total / 1000.0) if total > 0 else 0.0,
    }


def top_costs(fr, n=5):
    if fr.bd is None:
        return ""
    items = [(k, v) for k, v in fr.bd.items() if not _is_parent(k)]
    items.append(("engine+draw", fr.cats.get("engine+draw (unaccounted)", 0.0)))
    items.sort(key=lambda kv: -kv[1])
    return ", ".join("%s %.1f" % (k, v / 1000.0) for k, v in items[:n])


def dominant(frs, full, n=2):
    if not full:
        if not frs:
            return ""
        return "load: %.0f enemies, %.0f proj" % (
            sum(f.enemies for f in frs) / len(frs), sum(f.pp + f.pe for f in frs) / len(frs))
    acc = defaultdict(float)
    for f in frs:
        for k, v in f.cats.items():
            acc[k] += v
    total = sum(acc.values()) or 1.0
    parts = sorted(acc.items(), key=lambda kv: -kv[1])[:n]
    keys = defaultdict(float)
    for f in frs:
        for k, v in f.bd.items():
            if not _is_parent(k):
                keys[k] += v
    tk = sorted(keys.items(), key=lambda kv: -kv[1])[:2]
    return "%s; top: %s" % (
        ", ".join("%s %.0f%%" % (k, 100.0 * v / total) for k, v in parts),
        ", ".join("%s %.1f ms/fr" % (k, v / 1000.0 / len(frs)) for k, v in tk),
    )


def clusters(frames, limit_ms):
    out = []
    cur = []
    for f in frames:
        if f.ms <= limit_ms:
            continue
        if cur and f.t - cur[-1].t > CLUSTER_GAP_S:
            out.append(cur)
            cur = []
        cur.append(f)
    if cur:
        out.append(cur)
    return out


def where(f):
    return "%s f%s %s" % (f.scene, f.floor, f.biome) if f.floor not in ("", "-1") else f.scene


def bucketed(frames, value, buckets):
    lines = ["| range | frames | avg ms | p95 | p99 | max |", "|---|---:|---:|---:|---:|---:|"]
    for lo, hi in buckets:
        ms = [f.ms for f in frames if lo <= value(f) <= hi]
        if not ms:
            continue
        s = stats(ms)
        label = str(lo) if lo == hi else ("%d+" % lo if hi >= 10**9 else "%d-%d" % (lo, hi))
        lines.append("| %s | %d | %.2f | %.2f | %.2f | %.2f |" % (label, s["n"], s["avg"], s["p95"], s["p99"], s["max"]))
    return lines


def summarize(path):
    frames, full = load(path)
    name = os.path.splitext(os.path.basename(path))[0]
    L = []
    if not frames:
        return ["# Perf log %s" % name, "", "No frames in the file."]
    dur = frames[-1].t - frames[0].t
    marks = [f for f in frames if f.mark]
    L += [
        "# Perf log %s" % name,
        "",
        "%d frames over %.1f s, %s log (%s), %d F9 marks. Times in ms unless marked."
        % (len(frames), dur, "full" if full else "light", os.path.basename(path), len(marks)),
        "",
        "## Totals per scene and floor",
        "",
        "| scene / floor | frames | avg | p50 | p95 | p99 | max | fps |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    groups = defaultdict(list)
    order = []
    for f in frames:
        k = where(f)
        if k not in groups:
            order.append(k)
        groups[k].append(f.ms)
    for k in order + ["all"]:
        s = stats(groups[k] if k != "all" else [f.ms for f in frames])
        L.append("| %s | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.0f |"
                 % (k, s["n"], s["avg"], s["p50"], s["p95"], s["p99"], s["max"], s["fps"]))
    L += ["", "## The %d worst frames" % WORST_N, ""]
    L.append("t s | ms | where | ticks | enemies | proj p/e | fx | boss | top costs (ms)" if full else
             "t s | ms | where | ticks | enemies | proj p/e | fx | boss")
    for f in sorted(frames, key=lambda f: -f.ms)[:WORST_N]:
        boss = ("ph%s" % f.phase) if f.boss else "-"
        line = "%.2f | %.1f | %s | %d | %d | %d/%d | %d | %s" % (
            f.t, f.ms, where(f), f.ticks, f.enemies, f.pp, f.pe, f.fx, boss)
        if full:
            line += " | " + top_costs(f)
        L.append("- " + line)
    L += ["", "## Stutter clusters", ""]
    for lim in (33, 50):
        cs = clusters(frames, lim)
        cs.sort(key=lambda c: -(c[-1].t - c[0].t + c[-1].ms / 1000.0))
        L.append("Over %d ms: %d frames in %d clusters%s" % (
            lim, sum(len(c) for c in cs), len(cs), " (the 8 longest):" if len(cs) > 8 else ":"))
        for c in cs[:8]:
            span = c[-1].t - c[0].t + c[-1].ms / 1000.0
            L.append("- %.2f s, %.2f s long, %d frames, worst %.1f ms, %s; %s" % (
                c[0].t - c[0].ms / 1000.0, span, len(c), max(f.ms for f in c), where(c[0]), dominant(c, full)))
        L.append("")
    play = [f for f in frames if f.scene in PLAY_SCENES]
    L += ["## Frame time against the load (play frames only)", "", "Enemies (live non-hero actors):", ""]
    L += bucketed(play, lambda f: f.enemies, ENEMY_BUCKETS)
    L += ["", "Projectiles (hero + enemy):", ""]
    L += bucketed(play, lambda f: f.pp + f.pe, PROJ_BUCKETS)
    L += ["", "## Top costs over the run", ""]
    if not full:
        L.append("Light log: no breakdown columns (record with `--perf-log` for the costs).")
    else:
        n = len(frames)
        L += ["| part | mean us/frame | share | p99 us |", "|---|---:|---:|---:|"]
        tot = sum(sum(f.cats.values()) for f in frames) or 1.0
        for name_, _ in CATS:
            vals = sorted(f.cats.get(name_, 0.0) for f in frames)
            s = sum(vals)
            L.append("| %s | %.0f | %.0f%% | %.0f |" % (name_, s / n, 100.0 * s / tot, pct(vals, 0.99)))
        keys = defaultdict(float)
        peak = defaultdict(float)
        for f in frames:
            for k, v in f.bd.items():
                keys[k] += v
                if v > peak[k]:
                    peak[k] = v
        L += ["", "The 15 costliest buckets (nested buckets overlap: view.* and actors.* sit inside the views' sync):",
              ""]
        for k, v in sorted(((k, v) for k, v in keys.items() if not _is_parent(k)), key=lambda kv: -kv[1])[:15]:
            L.append("- %s: %.0f us/frame, max %.1f ms" % (k, v / n, peak[k] / 1000.0))
    L += ["", "## F9 marks (+-%.0f s)" % MARK_WINDOW_S, ""]
    if not marks:
        L.append("No marks.")
    ts = [f.t for f in frames]
    for m in marks[:15]:
        a = bisect.bisect_left(ts, m.t - MARK_WINDOW_S)
        b = bisect.bisect_right(ts, m.t + MARK_WINDOW_S)
        win = frames[a:b]
        s = stats([f.ms for f in win])
        worst = max(win, key=lambda f: f.ms)
        L.append("- mark %s at %.2f s (%s): %d frames, avg %.2f, p99 %.2f, max %.1f at %.2f s; %s" % (
            m.mark, m.t, where(m), s["n"], s["avg"], s["p99"], s["max"], worst.t, dominant(win, full)))
    if len(marks) > 15:
        L.append("- (%d more marks not shown)" % (len(marks) - 15))
    return L


def write(path, out=None):
    lines = summarize(path)
    if out is None:
        name = os.path.splitext(os.path.basename(path))[0]
        out = os.path.join(ROOT, "build", "perf", name + "_summary.md")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return out, lines


def _fake_csv(path, full, rows=40000):
    rnd = random.Random(7)
    light = ["frame", "t_s", "scene", "floor", "biome", "paused", "frame_ms", "ticks", "enemies", "proj_player",
             "proj_enemy", "fx", "boss", "boss_phase", "mark", "nodes", "draw_calls", "primitives", "objects_drawn",
             "vram_mb"]
    extra = ["step_us", "sim_us", "views_us", "listeners_us", "other_script_us", "engine_us", "draw_us", "bd"]
    t = 0.0
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(light + (extra if full else []))
        for i in range(rows):
            scene = "menu" if i < 500 else ("hub" if i < 1500 else "run")
            en = 0 if scene != "run" else (i // 200) % 70
            ms = 6.0 + en * 0.05 + rnd.random()
            if 20000 <= i < 20006:
                ms = 70.0  # the planted stutter
            t += ms / 1000.0
            row = [i, "%.4f" % t, scene, 1 if scene == "run" else -1, "frozen_shore" if scene == "run" else "", 0,
                   "%.3f" % ms, 1, en, en * 2, en, en * 3, 0, -1, "1" if i == 20003 else "",
                   "", "", "", "", ""]
            if full:
                sim = int(ms * 300)
                views = int(ms * 200)
                row += [sim + 100, sim, views, 50, 100, int(ms * 1000) - sim - 100 - views - 50, 900,
                        "sim_step=%d;step_once=%d;sync_all=%d;view.actors=%d;phase.ai.plan=%d"
                        % (sim, sim + 100, views, views // 2, sim // 3)]
            w.writerow(row)


def self_check():
    tmp = tempfile.mkdtemp(prefix="perf_selfcheck_")
    ok = True
    for full in (True, False):
        p = os.path.join(tmp, "perf_selfcheck_%s.csv" % ("full" if full else "light"))
        _fake_csv(p, full)
        t0 = time.time()
        out, lines = write(p, os.path.join(tmp, "out_%s.md" % full))
        dt = time.time() - t0
        text = "\n".join(lines)
        checks = {
            "<= 160 lines": len(lines) <= 160,
            "under 15 s": dt < 15.0,
            "40000 frames": "40000 frames" in text,
            "the planted stutter": "6 frames, worst 70.0 ms" in text,
            "the mark": "mark 1 at" in text,
            "the scenes": "| menu |" in text and "| run f1 frozen_shore |" in text,
            "the costs": ("| sim |" in text) if full else ("Light log" in text),
        }
        for k, v in checks.items():
            if not v:
                ok = False
                print("FAIL (%s): %s" % ("full" if full else "light", k))
        print("%s log: %d lines in %.2f s -> %s" % ("full" if full else "light", len(lines), dt, out))
    shutil.rmtree(tmp, ignore_errors=True)
    print("self-check " + ("OK" if ok else "FAILED"))
    return 0 if ok else 1


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("csv", nargs="?")
    ap.add_argument("--out")
    ap.add_argument("--self-check", action="store_true")
    a = ap.parse_args(argv)
    if a.self_check:
        return self_check()
    if not a.csv:
        ap.error("give a CSV path (or --self-check)")
    out, lines = write(a.csv, a.out)
    print("\n".join(lines[:12]))
    print("... (%d lines) -> %s" % (len(lines), out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

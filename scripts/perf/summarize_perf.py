#!/usr/bin/env python3
"""Summarize one perf-log CSV (the game's `-- --perf-log`, docs/process/PERF_LOG.md) into a markdown report.

    python scripts/perf/summarize_perf.py <perf_....csv> [--out build/perf/<name>_summary.md]
    python scripts/perf/summarize_perf.py --self-check

The report goes to build/perf/<csv name>_summary.md (never into docs). It opens with what is biggest (the frame, the
GPU against the CPU, the costliest render passes and script parts, what the scene held), then: the totals per scene
and floor; GPU against CPU per scene; the GPU time per render pass (overall, per biome, at the worst frames); the 50
worst frames with their top costs and load; the stutter clusters (over 33 ms and over 50 ms); the frame time against
enemies, projectiles, lights, shadows, particles and transparent geometry; the top script costs (sim / views /
listeners / other script / unaccounted engine+draw); the Graphics options in force; and a window of +-2 s round each
F9 mark. A light log gets what its columns hold. Python 3 standard library only.
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
from array import array
from collections import Counter, defaultdict

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
# The census against the frame: (title, value of a census dict, buckets).
SCENE_BUCKETS = [
    ("Lights casting shadows", lambda c: c.get("sh_dir", 0) + c.get("sh_omni", 0) + c.get("sh_spot", 0),
     [(0, 0), (1, 1), (2, 2), (3, 4), (5, 8), (9, 10**9)]),
    ("Lights (all)", lambda c: c.get("l_dir", 0) + c.get("l_omni", 0) + c.get("l_spot", 0),
     [(0, 2), (3, 5), (6, 10), (11, 20), (21, 10**9)]),
    ("Particles (emitting, 3D GPU + CPU)", lambda c: c.get("gpup_n", 0) + c.get("cpup_n", 0),
     [(0, 0), (1, 500), (501, 2000), (2001, 5000), (5001, 20000), (20001, 10**9)]),
    ("Transparent geometry (est.)", lambda c: c.get("alpha", 0),
     [(0, 50), (51, 150), (151, 300), (301, 600), (601, 10**9)]),
]
WORST_N = 50
CLUSTER_GAP_S = 0.25  # bad frames this close belong to one cluster
MARK_WINDOW_S = 2.0
GPU_BOUND = 0.85  # the GPU's time is at least this share of the frame
WAIT_SHARE = 0.25  # the draw's wait (not recording the viewports) is at least this share of the frame
PASS_TOP = 15
# The main thread's frame in order (PerfRecorder._span_cols): the process step, after it, the draw (draw_us), then
# until the next physics step, then the physics steps.
SPAN_COLS = ["proc_span_us", "after_us", "between_us", "phys_span_us"]
HITCH_MS = 1000.0  # a frame this long (a load, a shader compile) is left out of the headline's means


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


def _kv(s, sep=";"):
    out = {}
    for part in s.split(sep):
        k, _, v = part.partition("=")
        if k:
            out[k] = v
    return out


def _census(s):
    out = {}
    for k, v in _kv(s).items():
        out[k] = _num(v)
    return out


class Frame:
    __slots__ = (
        "i", "t", "scene", "floor", "biome", "ms", "ticks", "enemies", "pp", "pe", "fx", "boss", "phase",
        "mark", "cats", "bd", "rec", "gpu", "rcpu", "draw", "setup", "proc", "phys", "sc", "cfg", "bound",
        "span",
    )


class Passes:
    """The per-pass GPU and CPU times (the `gp` column), sparse: per pass id the frames it ran in and its times."""

    def __init__(self):
        self.names = {}
        self.rows = defaultdict(lambda: array("i"))
        self.gpu = defaultdict(lambda: array("f"))
        self.cpu = defaultdict(lambda: array("f"))
        self.lags = Counter()
        self.has = bytearray()  # per frame: 1 when the frame's passes are known
        self.lag = 0

    def add_row(self, r, s):
        parts = s.split(";")
        if parts and parts[0].startswith("@"):
            self.lags[int(_num(parts[0][1:]))] += 1
            parts = parts[1:]
        for p in parts:
            a = p.split(":")
            if len(a) != 3:
                continue
            pid = int(a[0])
            self.rows[pid].append(r)
            self.gpu[pid].append(float(a[1]))
            self.cpu[pid].append(float(a[2]))

    def finish(self, has_rows, n):
        """Moves each row's passes onto the frame they belong to (the row `lag` frames later carries them)."""
        self.lag = self.lags.most_common(1)[0][0] if self.lags else 0
        self.has = bytearray(n)
        for r in has_rows:
            k = r - self.lag
            if 0 <= k < n:
                self.has[k] = 1
        for pid in list(self.rows):
            rows = self.rows[pid]
            self.rows[pid] = array("i", (r - self.lag for r in rows))

    def on(self):
        return len(self.names) > 4

    def label(self, pid):
        n = self.names.get(pid, "#%d" % pid)
        return n[4:] if n.startswith("win/") else n

    def table(self, mask=None):
        """Per pass over the frames in `mask` (all known frames when None): (pid, mean_gpu, p95, p99, mean_cpu)."""
        n = sum(1 for k, h in enumerate(self.has) if h and (mask is None or mask[k]))
        out = []
        if n == 0:
            return out, 0
        for pid, rows in self.rows.items():
            g = self.gpu[pid]
            c = self.cpu[pid]
            vals = []
            cs = 0.0
            for j, k in enumerate(rows):
                if 0 <= k < len(self.has) and self.has[k] and (mask is None or mask[k]):
                    vals.append(g[j])
                    cs += c[j]
            if not vals:
                continue
            vals.sort()
            full = [0.0] * (n - len(vals)) + vals
            out.append((pid, sum(vals) / n, pct(full, 0.95), pct(full, 0.99), cs / n))
        out.sort(key=lambda x: -x[1])
        return out, n

    def of_frames(self, ks):
        """{frame: [(gpu_us, pid), ...]} for the frames in `ks`."""
        want = set(ks)
        out = defaultdict(list)
        for pid, rows in self.rows.items():
            g = self.gpu[pid]
            for j, k in enumerate(rows):
                if k in want:
                    out[k].append((g[j], pid))
        for k in out:
            out[k].sort(reverse=True)
        return out


def load(path):
    frames = []
    passes = Passes()
    censuses = []
    cfgs = []
    with open(path, newline="", encoding="utf-8") as f:
        rd = csv.reader(f)
        head = next(rd)
        col = {name: k for k, name in enumerate(head)}
        full = "bd" in col
        need = ["t_s", "scene", "floor", "biome", "frame_ms", "ticks", "enemies", "proj_player", "proj_enemy"]
        for n in need:
            if n not in col:
                raise SystemExit("not a perf-log CSV: no column %r" % n)
        last_need = max(col[n] for n in need)
        cat_cols = [(name, col[c]) for name, c in CATS if c in col] if full else []
        g = lambda row, name, d="": row[col[name]] if name in col and col[name] < len(row) else d  # noqa: E731
        raw_gpu = []
        raw_rcpu = []
        gp_rows = []
        sc_i = -1
        cfg_i = -1
        for row in rd:
            if len(row) <= last_need:
                continue  # a row cut by a crash
            fr = Frame()
            fr.i = len(frames)
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
            fr.rec = _num(g(row, "rec_us"), -1.0)
            raw_gpu.append(_num(g(row, "gpu_us"), -1000.0) / 1000.0)
            raw_rcpu.append(_num(g(row, "rcpu_us"), -1000.0) / 1000.0)
            fr.cats = {name: _num(row[c]) if c < len(row) else 0.0 for name, c in cat_cols} if full else None
            fr.bd = None
            fr.draw = _num(g(row, "draw_us"), -1000.0) / 1000.0 if full else -1.0
            fr.setup = _num(g(row, "setup_us"), -1000.0) / 1000.0
            fr.proc = _num(g(row, "proc_us"), -1000.0) / 1000.0
            fr.phys = _num(g(row, "phys_us"), -1000.0) / 1000.0
            sp = [g(row, c) for c in SPAN_COLS]
            fr.span = tuple(_num(v) / 1000.0 for v in sp) if all(v != "" for v in sp) else None
            if full:
                bd = {}
                s = g(row, "bd")
                if s:
                    for part in s.split(";"):
                        key, _, v = part.rpartition("=")
                        if key:
                            bd[key] = float(v)
                fr.bd = bd
                names = g(row, "gp_new")
                if names:
                    for part in names.split("|"):
                        pid, _, nm = part.partition("=")
                        if pid:
                            passes.names[int(pid)] = nm
                gp = g(row, "gp")
                if gp:
                    passes.add_row(fr.i, gp)
                    gp_rows.append(fr.i)
                sc = g(row, "sc")
                if sc:
                    censuses.append(_census(sc))
                    sc_i = len(censuses) - 1
                cf = g(row, "cfg")
                if cf:
                    cfgs.append([cf, 0, fr.t])
                    cfg_i = len(cfgs) - 1
            fr.sc = sc_i
            fr.cfg = cfg_i
            if cfg_i >= 0:
                cfgs[cfg_i][1] += 1
            frames.append(fr)
    n = len(frames)
    passes.finish(gp_rows, n)
    lag = passes.lag
    for k, fr in enumerate(frames):
        j = k + lag
        fr.gpu = raw_gpu[j] if j < n else -1.0
        fr.rcpu = raw_rcpu[j] if j < n else -1.0
        fr.bound = _bound(fr)
    return frames, full, passes, censuses, cfgs


def _bound(fr):
    if fr.gpu <= 0 or fr.ms <= 0:
        return ""
    if fr.gpu >= GPU_BOUND * fr.ms:
        return "gpu"
    if fr.draw >= 0 and fr.rcpu >= 0 and fr.draw - fr.rcpu >= WAIT_SHARE * fr.ms:
        return "wait"
    return "cpu"


def _wait(fr):
    if fr.draw < 0 or fr.rcpu < 0:
        return -1.0
    return max(fr.draw - fr.rcpu - max(fr.setup, 0.0), 0.0)


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


def _mean(vals):
    vals = list(vals)
    return sum(vals) / len(vals) if vals else 0.0


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


def _label(lo, hi):
    return str(lo) if lo == hi else ("%d+" % lo if hi >= 10**9 else "%d-%d" % (lo, hi))


def bucketed(frames, value, buckets, gpu=False):
    head = "| range | frames | avg ms | p95 | p99 | max |" + (" gpu ms |" if gpu else "")
    lines = [head, "|---|---:|---:|---:|---:|---:|" + ("---:|" if gpu else "")]
    for lo, hi in buckets:
        frs = [f for f in frames if lo <= value(f) <= hi]
        if not frs:
            continue
        s = stats([f.ms for f in frs])
        line = "| %s | %d | %.2f | %.2f | %.2f | %.2f |" % (
            _label(lo, hi), s["n"], s["avg"], s["p95"], s["p99"], s["max"])
        if gpu:
            line += " %.2f |" % _mean(f.gpu for f in frs if f.gpu >= 0)
        lines.append(line)
    return lines


def _shares(frs):
    c = Counter(f.bound for f in frs if f.bound)
    n = sum(c.values())
    if n == 0:
        return None
    return {k: 100.0 * c[k] / n for k in ("gpu", "cpu", "wait")}


def _headline(frames, full, passes, censuses, play):
    L = ["## What is biggest", ""]
    base = [f for f in (play or frames) if f.ms < HITCH_MS]
    hitches = len(play or frames) - len(base)
    s = stats([f.ms for f in base])
    sh = _shares(base)
    gpu = [f.gpu for f in base if f.gpu >= 0]
    line = "- **Frame** (%s): avg %.2f ms (%.0f fps), p95 %.2f, p99 %.2f." % (
        "play frames" if play else "all frames", s["avg"], s["fps"], s["p95"], s["p99"])
    if sh is not None:
        line += " GPU-bound %.0f%%, CPU-bound %.0f%%, waiting in the draw %.0f%%." % (
            sh["gpu"], sh["cpu"], sh["wait"])
    if hitches:
        line += " (%d hitches over %.0f ms left out of this section's means.)" % (hitches, HITCH_MS)
    L.append(line)
    if gpu:
        gs = sorted(gpu)
        rc = [f.rcpu for f in base if f.rcpu >= 0]
        L.append("- **GPU**: the main window's render takes %.2f ms a frame on the GPU (p95 %.2f), %.2f ms of CPU "
                 "recording it." % (_mean(gs), pct(gs, 0.95), _mean(rc)))
    if passes.on():
        mask = bytearray(1 if f.scene in PLAY_SCENES else 0 for f in frames) if play else None
        tab, n = passes.table(mask)
        tot = sum(x[1] for x in tab) or 1.0
        L.append("- **Costliest GPU passes**: " + ", ".join(
            "%s %.2f ms (%.0f%%)" % (passes.label(pid), m / 1000.0, 100.0 * m / tot) for pid, m, _, _, _ in tab[:5])
            + ".")
    elif full:
        L.append("- **GPU passes**: not in this log (launch with `--gpu-profile` before the `--`).")
    if full:
        acc = defaultdict(float)
        for f in base:
            for k, v in f.cats.items():
                acc[k] += v
        n = len(base) or 1
        parts = sorted(acc.items(), key=lambda kv: -kv[1])
        L.append("- **Main thread**: " + ", ".join("%s %.2f ms" % (k, v / 1000.0 / n) for k, v in parts) + ".")
        spans = [f for f in base if f.span is not None and f.draw >= 0]
        if spans:
            k = len(spans)
            proc = sum(f.span[0] for f in spans) / k
            timed = sum(sum(f.cats[c] for c in f.cats if not c.startswith("engine")) for f in spans) / k / 1000.0
            L.append("- **Main thread, in order**: the process step %.2f ms (the timed sim, views and listeners %.2f, "
                     "the rest of the nodes' _process %.2f), after it until the draw %.2f, the draw %.2f, then until "
                     "the next step (events, input, a frame cap) %.2f, the physics steps %.2f." % (
                         proc, timed, max(proc - timed, 0.0), sum(f.span[1] for f in spans) / k,
                         sum(f.draw for f in spans) / k, sum(f.span[2] for f in spans) / k,
                         sum(f.span[3] for f in spans) / k))
        waits = [w for w in (_wait(f) for f in base) if w >= 0]
        if waits:
            L.append("- **Inside engine+draw**: the draw %.2f ms a frame, of which recording the viewports %.2f ms "
                     "and waiting (GPU, vsync, present; est.) %.2f ms; the frame setup %.2f ms." % (
                         _mean(f.draw for f in base if f.draw >= 0), _mean(f.rcpu for f in base if f.rcpu >= 0),
                         _mean(waits), _mean(f.setup for f in base if f.setup >= 0)))
    cs = [censuses[f.sc] for f in base if f.sc >= 0]
    if cs:
        def m(key):
            return _mean(c.get(key, 0.0) for c in cs)
        L.append("- **Scene** (mean): %.0f lights (%.0f casting shadows), %.0f particles in %.0f emitting systems, "
                 "%.0f MultiMesh instances, %.0f of %.0f visible geometry transparent (est.), %.0f materials, "
                 "%.0f shaders; textures %.0f MB." % (
                     m("l_dir") + m("l_omni") + m("l_spot"), m("sh_dir") + m("sh_omni") + m("sh_spot"),
                     m("gpup_n") + m("cpup_n"), m("gpup") + m("cpup"), m("mm_n"), m("alpha"), m("geo"),
                     m("mats"), m("shaders"), m("tex_mb")))
    return L + [""]


def _gpu_cpu_table(frames):
    L = ["## GPU against CPU per scene and floor", "",
         "GPU-bound: the GPU's time is at least %.0f%% of the frame. Waiting: otherwise, the draw spent at least "
         "%.0f%% of the frame not recording the viewports (vsync, a frame cap, the present, or the GPU a frame "
         "behind). CPU-bound: the rest. The GPU times are matched to their frame (the engine reads them late)."
         % (100 * GPU_BOUND, 100 * WAIT_SHARE), "",
         "| scene / floor | frames | avg ms | gpu ms | render cpu ms | draw wait ms | gpu-bound | cpu-bound | wait |",
         "|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    groups = defaultdict(list)
    order = []
    for f in frames:
        k = where(f)
        if k not in groups:
            order.append(k)
        groups[k].append(f)
    for k in order:
        frs = groups[k]
        sh = _shares(frs)
        if sh is None:
            continue
        waits = [w for w in (_wait(f) for f in frs) if w >= 0]
        L.append("| %s | %d | %.2f | %.2f | %.2f | %s | %.0f%% | %.0f%% | %.0f%% |" % (
            k, len(frs), _mean(f.ms for f in frs), _mean(f.gpu for f in frs if f.gpu >= 0),
            _mean(f.rcpu for f in frs if f.rcpu >= 0), "%.2f" % _mean(waits) if waits else "-",
            sh["gpu"], sh["cpu"], sh["wait"]))
    return L + [""]


def _pass_sections(frames, passes):
    L = ["## GPU time per render pass", ""]
    if not passes.on():
        return L + ["Not in this log: the per-pass times need the engine flag `--gpu-profile` (before the `--`) and "
                    "the full `--perf-log`.", ""]
    play = bytearray(1 if f.scene in PLAY_SCENES else 0 for f in frames)
    tab, n = passes.table(play if any(play) else None)
    tot = sum(x[1] for x in tab) or 1.0
    L += ["Play frames with their passes known: %d (the engine reads a frame's stamps %d frames late; matched here). "
          "`sub/` is any viewport but the main window (summed); `win/` is dropped." % (n, passes.lag), "",
          "| pass | gpu mean ms | p95 | p99 | share | cpu mean ms |", "|---|---:|---:|---:|---:|---:|"]
    for pid, m, p95, p99, c in tab[:PASS_TOP]:
        L.append("| %s | %.3f | %.3f | %.3f | %.0f%% | %.3f |" % (
            passes.label(pid), m / 1000.0, p95 / 1000.0, p99 / 1000.0, 100.0 * m / tot, c / 1000.0))
    L.append("")
    biomes = []
    for f in frames:
        if f.scene in PLAY_SCENES and f.biome and f.biome not in biomes:
            biomes.append(f.biome)
    if biomes:
        cols = {}
        for b in biomes:
            mask = bytearray(1 if (f.scene in PLAY_SCENES and f.biome == b) else 0 for f in frames)
            t, nb = passes.table(mask)
            cols[b] = ({pid: m for pid, m, _, _, _ in t}, nb, sum(x[1] for x in t))
        L += ["Per biome (gpu mean ms; the top passes overall):", "",
              "| pass | " + " | ".join(biomes) + " |", "|---|" + "---:|" * len(biomes)]
        L.append("| **all passes** | " + " | ".join("%.2f" % (cols[b][2] / 1000.0) for b in biomes) + " |")
        for pid, _, _, _, _ in tab[:8]:
            L.append("| %s | " % passes.label(pid) + " | ".join(
                "%.2f" % (cols[b][0].get(pid, 0.0) / 1000.0) for b in biomes) + " |")
        L.append("")
    known = [f for f in frames if f.scene in PLAY_SCENES and passes.has[f.i]]
    if known:
        known.sort(key=lambda f: -f.ms)
        worst = known[:max(1, len(known) // 100)]
        mask = bytearray(len(frames))
        for f in worst:
            mask[f.i] = 1
        wt, nw = passes.table(mask)
        mean_all = {pid: m for pid, m, _, _, _ in tab}
        L += ["The costliest passes at the worst 1%% of play frames (%d frames, from %.1f ms; gpu mean ms there "
              "against the whole play):" % (nw, worst[-1].ms), ""]
        for pid, m, _, _, _ in wt[:8]:
            L.append("- %s: %.2f ms (overall %.2f, %+.2f)" % (
                passes.label(pid), m / 1000.0, mean_all.get(pid, 0.0) / 1000.0, (m - mean_all.get(pid, 0.0)) / 1000.0))
        L.append("")
    return L


def _scene_sections(play, censuses):
    known = [f for f in play if f.sc >= 0 and f.ms < HITCH_MS]
    if not known:
        return []
    L = ["## Frame time against what the scene holds (play frames under %.0f ms, the last census before each frame)"
         % HITCH_MS, ""]
    for title, value, buckets in SCENE_BUCKETS:
        L += [title + ":", ""]
        L += bucketed(known, lambda f, v=value: v(censuses[f.sc]), buckets, gpu=True)
        L.append("")
    keys = defaultdict(float)
    for f in known:
        for k, v in censuses[f.sc].items():
            keys[k] += v
    shown = ["%s %.0f" % (k, v / len(known)) for k, v in keys.items() if not k.startswith("pack.")]
    packs = sorted(((k[5:], v / len(known)) for k, v in keys.items() if k.startswith("pack.")), key=lambda kv: -kv[1])
    L += ["The census on average: " + ", ".join(shown) + ".", ""]
    if packs:
        L += ["Pack effects alive per family (mean): " + ", ".join("%s %.1f" % kv for kv in packs[:12]) + ".", ""]
    return L


def _options_section(cfgs):
    if not cfgs:
        return []
    L = ["## Graphics options in force", ""]
    first = _kv(cfgs[0][0])
    L.append("From %.1f s (%d frames): %s." % (cfgs[0][2], cfgs[0][1], ", ".join("%s=%s" % kv for kv in first.items())))
    prev = first
    for s, n, t in cfgs[1:8]:
        cur = _kv(s)
        diff = ["%s=%s" % (k, v) for k, v in cur.items() if prev.get(k) != v]
        L.append("- from %.1f s (%d frames): %s" % (t, n, ", ".join(diff) or "(no change)"))
        prev = cur
    if len(cfgs) > 8:
        L.append("- (%d more changes not shown)" % (len(cfgs) - 8))
    return L + [""]


def summarize(path):
    frames, full, passes, censuses, cfgs = load(path)
    name = os.path.splitext(os.path.basename(path))[0]
    L = []
    if not frames:
        return ["# Perf log %s" % name, "", "No frames in the file."]
    dur = frames[-1].t - frames[0].t
    marks = [f for f in frames if f.mark]
    rec = sorted(f.rec for f in frames if f.rec >= 0)
    play = [f for f in frames if f.scene in PLAY_SCENES]
    census_us = [c.get("census_us", 0.0) for c in censuses]
    L += [
        "# Perf log %s" % name,
        "",
        "%d frames over %.1f s, %s log (%s), %d F9 marks. Times in ms unless marked."
        % (len(frames), dur, "full" if full else "light", os.path.basename(path), len(marks)),
        "",
    ]
    L += _headline(frames, full, passes, censuses, play)
    L += [
        ("The recorder's own main-thread time: mean %.0f us, p99 %.0f us a frame." % (sum(rec) / len(rec), pct(rec, 0.99))
         if rec else "The recorder's own time: not in this log.")
        + (" Its scene census: %d, each %.0f us in all (spread over a few frames)." % (len(census_us), _mean(census_us))
           if census_us else ""),
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
    L.append("")
    if any(f.gpu >= 0 for f in frames):
        L += _gpu_cpu_table(frames)
    if full:
        L += _pass_sections(frames, passes)
    worst = sorted(frames, key=lambda f: -f.ms)[:WORST_N]
    wp = passes.of_frames([f.i for f in worst]) if passes.on() else {}
    L += ["## The %d worst frames" % WORST_N, ""]
    L.append("t s | ms | where | ticks | enemies | proj p/e | fx | boss | gpu | top costs (ms)" if full else
             "t s | ms | where | ticks | enemies | proj p/e | fx | boss | gpu")
    for f in worst:
        boss = ("ph%s" % f.phase) if f.boss else "-"
        line = "%.2f | %.1f | %s | %d | %d | %d/%d | %d | %s | %s" % (
            f.t, f.ms, where(f), f.ticks, f.enemies, f.pp, f.pe, f.fx, boss,
            "%.1f" % f.gpu if f.gpu >= 0 else "-")
        if full:
            line += " | " + top_costs(f)
            if f.i in wp:
                line += "; gpu: " + ", ".join("%s %.1f" % (passes.label(p), g / 1000.0) for g, p in wp[f.i][:2])
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
    has_gpu = any(f.gpu >= 0 for f in play)
    L += ["## Frame time against the load (play frames only)", "", "Enemies (live non-hero actors):", ""]
    L += bucketed(play, lambda f: f.enemies, ENEMY_BUCKETS, gpu=has_gpu)
    L += ["", "Projectiles (hero + enemy):", ""]
    L += bucketed(play, lambda f: f.pp + f.pe, PROJ_BUCKETS, gpu=has_gpu)
    L.append("")
    L += _scene_sections(play, censuses)
    L += ["## Top costs over the run", ""]
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
        procs = [f.proc for f in frames if f.proc >= 0]
        if procs:
            L += ["", "The engine's own monitors (the slowest step of each second; Godot keeps the max per second): "
                  "process %.2f ms, physics process %.2f ms (mean over the frames)." % (
                _mean(procs), _mean(f.phys for f in frames if f.phys >= 0))]
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
    L.append("")
    L += _options_section(cfgs)
    L += ["## F9 marks (+-%.0f s)" % MARK_WINDOW_S, ""]
    if not marks:
        L.append("No marks.")
    ts = [f.t for f in frames]
    for m in marks[:15]:
        a = bisect.bisect_left(ts, m.t - MARK_WINDOW_S)
        b = bisect.bisect_right(ts, m.t + MARK_WINDOW_S)
        win = frames[a:b]
        s = stats([f.ms for f in win])
        worst_f = max(win, key=lambda f: f.ms)
        line = "- mark %s at %.2f s (%s): %d frames, avg %.2f, p99 %.2f, max %.1f at %.2f s; %s" % (
            m.mark, m.t, where(m), s["n"], s["avg"], s["p99"], s["max"], worst_f.t, dominant(win, full))
        gw = [f.gpu for f in win if f.gpu >= 0]
        if gw:
            sh = _shares(win)
            line += "; gpu %.2f ms, gpu-bound %.0f%%" % (_mean(gw), sh["gpu"] if sh else 0.0)
        if passes.on():
            mask = bytearray(len(frames))
            for f in win:
                mask[f.i] = 1
            t, _ = passes.table(mask)
            line += "; passes: " + ", ".join("%s %.2f" % (passes.label(p), mm / 1000.0) for p, mm, _, _, _ in t[:3])
        L.append(line)
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


FAKE_PASSES = ["Frame Begin", "win/Render Depth Pre-Pass", "win/Render Directional/SpotLight Shadows",
               "win/Process SSAO", "win/Process SSIL", "win/Render Opaque Pass", "win/Render 3D Transparent Pass",
               "win/Glow", "win/Tonemap", "sub/Render CanvasItems"]
FAKE_LAG = 8  # longer than the planted stutter, so its passes land on it only when the lag is undone
STUTTER = range(20000, 20006)


def _fake_csv(path, full, rows=40000):
    rnd = random.Random(7)
    light = ["frame", "t_s", "scene", "floor", "biome", "paused", "frame_ms", "ticks", "enemies", "proj_player",
             "proj_enemy", "fx", "boss", "boss_phase", "mark", "nodes", "draw_calls", "primitives", "objects_drawn",
             "vram_mb", "rec_us", "gpu_us", "rcpu_us"]
    extra = ["step_us", "sim_us", "views_us", "listeners_us", "other_script_us", "engine_us", "draw_us", "bd",
             "setup_us", "proc_us", "phys_us", "gp", "gp_new", "sc", "cfg"] + SPAN_COLS
    t = 0.0
    ms_of = []
    for i in range(rows):
        scene = "menu" if i < 500 else ("hub" if i < 1500 else "run")
        en = 0 if scene != "run" else (i // 200) % 70
        ms = 70.0 if i in STUTTER else 6.0 + en * 0.05 + rnd.random()  # the planted stutter
        ms_of.append((scene, en, ms))
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(light + (extra if full else []))
        for i, (scene, en, ms) in enumerate(ms_of):
            t += ms / 1000.0
            # The GPU's numbers arrive FAKE_LAG rows late, as the engine reads them.
            src = i - FAKE_LAG
            g_ms = 0.0
            if src >= 0:
                s_scene, s_en, s_ms = ms_of[src]
                g_ms = s_ms * (0.95 if src in STUTTER or s_en > 50 else 0.4)
            biome = ("frozen_shore" if i < 25000 else "starfall") if scene == "run" else ""
            row = [i, "%.4f" % t, scene, 1 if scene == "run" else -1, biome, 0,
                   "%.3f" % ms, 1, en, en * 2, en, en * 3, 0, -1, "1" if i == 20003 else "",
                   "", "", "", "", "", 40, int(g_ms * 1000), int(g_ms * 200)]
            if full:
                sim = int(ms * 300)
                views = int(ms * 200)
                row += [sim + 100, sim, views, 50, 100, int(ms * 1000) - sim - 100 - views - 50, 900,
                        "sim_step=%d;step_once=%d;sync_all=%d;view.actors=%d;phase.ai.plan=%d"
                        % (sim, sim + 100, views, views // 2, sim // 3)]
                row += [10, int(ms * 600), 30]
                gp = ""
                if src >= 0:
                    g = g_ms * 1000
                    shadow = g * (0.8 if src in STUTTER else 0.1)
                    rest = g - shadow
                    parts = [(0, 1, 5), (1, rest * 0.1, 20), (2, shadow, 30), (3, rest * 0.1, 5), (4, rest * 0.1, 5),
                             (5, rest * 0.4, 60), (6, rest * 0.15, 20), (7, rest * 0.1, 3), (8, rest * 0.05, 3),
                             (9, 2, 40)]
                    gp = "@%d;" % FAKE_LAG + ";".join("%d:%d:%d" % (k, g_, c) for k, g_, c in parts)
                names = "|".join("%d=%s" % (k, n) for k, n in enumerate(FAKE_PASSES)) if i == FAKE_LAG else ""
                sc = ""
                if i % 300 == 0:
                    sc = "l_dir=1;sh_dir=1;l_omni=%d;sh_omni=%d;l_spot=0;sh_spot=0;gpup=4;gpup_n=%d;alpha=%d;" \
                         "geo=900;mats=80;shaders=20;tex_mb=300;census_us=900;pack.burst=3" % (
                             2 + en // 10, en // 20, en * 40, 40 + en * 3)
                cfg = ""
                if i == 0:
                    cfg = "window=2560x1440;scale3d=1.00;vsync=off;shadows=high;ssao=1;glow=1"
                elif i == 30000:
                    cfg = "window=2560x1440;scale3d=1.00;vsync=off;shadows=low;ssao=1;glow=1"
                row += [gp, names, sc, cfg]
                rest_us = int(ms * 1000) - 900  # the draw is 900
                row += [int(rest_us * 0.7), int(rest_us * 0.1), int(rest_us * 0.15), rest_us - int(rest_us * 0.7)
                        - int(rest_us * 0.1) - int(rest_us * 0.15)]
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
        head = "\n".join(lines[:14])
        checks = {
            "<= 300 lines": len(lines) <= 300,
            "under 30 s": dt < 30.0,
            "40000 frames": "40000 frames" in text,
            "the planted stutter": "6 frames, worst 70.0 ms" in text,
            "the mark": "mark 1 at" in text,
            "the recorder's cost": "mean 40 us" in text,
            "the scenes": "| menu |" in text and "| run f1 frozen_shore |" in text,
            "the costs": ("| sim |" in text) if full else ("Light log" in text),
            "the biggest first": "## What is biggest" in head and "GPU-bound" in head,
            "the GPU table": "## GPU against CPU per scene and floor" in text,
        }
        if full:
            worst_part = text.split("the worst 1% of play frames")[-1][:400]
            checks.update({
                "the costliest pass on top": "Costliest GPU passes**: Render Opaque Pass" in head,
                "the passes per biome": "| pass | frozen_shore | starfall |" in text,
                # The planted stutter's GPU time is mostly shadows; it lands on its frames only when the lag is undone.
                "the lag undone": "- Render Directional/SpotLight Shadows" in worst_part,
                "the stutter's pass": "gpu: Render Directional/SpotLight Shadows 53.2" in text,
                "the scene buckets": "Lights casting shadows:" in text and "Transparent geometry (est.):" in text,
                "the options": "shadows=high" in text and "- from " in text and "shadows=low" in text,
                "the pack families": "burst 3.0" in text,
                "the main thread in order": "**Main thread, in order**: the process step" in head,
            })
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
    print("\n".join(lines[:14]))
    print("... (%d lines) -> %s" % (len(lines), out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

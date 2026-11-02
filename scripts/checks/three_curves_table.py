"""v0.10.5 O16: tabulates build/three_curves/seeds_*.csv (scripts/checks/three_curves.gd) per floor and per minute.

Writes build/three_curves/table.txt and prints it; paste into evidence by hand.
    python scripts/checks/three_curves_table.py
"""

import csv
import glob
import os
import statistics as st

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "build", "three_curves")
# data/run/five_floors.tres enemy_hp_floor_permille x enemy_damage_floor_permille (loop 1, no Deep): the floor factor
# the arrival's challenge index leaves out (the kind's table HP is already floor-scaled)
HP_F = {1: 850, 2: 1380, 3: 1900, 4: 2620, 5: 3610}
DMG_F = {1: 850, 2: 1180, 3: 1400, 4: 1660, 5: 1960}
E = {1: 1000, 2: 2000, 3: 4000, 4: 4000, 5: 4000}  # data/scaling/catch_up.tres expected_power_permille (last past end)


def load():
    rows = []
    for p in sorted(glob.glob(os.path.join(ROOT, "seeds_*.csv"))):
        with open(p, newline="") as f:
            rows += list(csv.DictReader(f))
    for r in rows:
        for k, v in r.items():
            if k != "phase":
                r[k] = int(v)
    # durations: seconds since the run's previous row
    last = {}
    for r in rows:
        r["dt"] = r["t_s"] - last.get(r["seed"], 0)
        last[r["seed"]] = r["t_s"]
    return rows


def med(xs):
    return st.median(xs) if xs else 0


def q(xs, p):
    if not xs:
        return 0
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(p * (len(xs) - 1) + 0.5))]


def main():
    rows = load()
    seeds = sorted({r["seed"] for r in rows})
    floors = sorted({r["floor"] for r in rows})
    out = [f"three_curves: {len(seeds)} seeds ({seeds[0]}..{seeds[-1]}), {len(rows)} rows"]
    out.append("")
    out.append("## Per floor (median over seeds; rates over the phase's seconds; [p10..p90] where shown)")
    out.append(
        "floor | P start | P end [p10..p90] | P/E end | m | boss m | chal (x floor factor) | chal/P end | dps floor | "
        "dps boss | boss s [p10..p90] | kills/min | HP lost/min floor | hits/min floor | HP lost/min boss | "
        "dashes/min | shards earned | spent | held at portal | unbought chests | cards end"
    )
    for f in floors:
        per = []
        for s in seeds:
            fl = [r for r in rows if r["seed"] == s and r["floor"] == f and r["phase"] == "floor"]
            bo = [r for r in rows if r["seed"] == s and r["floor"] == f and r["phase"] == "boss"]
            if not fl:
                continue
            fdt = max(1, sum(r["dt"] for r in fl))
            bdt = max(1, sum(r["dt"] for r in bo))
            arr = sum(r["arrivals"] for r in fl)
            chal = sum(r["chal"] * r["arrivals"] for r in fl) / max(1, arr) * HP_F[f] * DMG_F[f] / 1e6
            end = bo[-1] if bo else fl[-1]
            per.append(
                dict(
                    p0=fl[0]["P"],
                    p1=end["P"],
                    pe=end["P"] / E[f],
                    m=fl[-1]["m"],
                    mb=end["m_boss"],
                    chal=chal,
                    cp=chal / end["P"],
                    dps=sum(r["hp_removed"] for r in fl) / fdt,
                    dpsb=sum(r["hp_removed"] for r in bo) / bdt,
                    bs=bdt,
                    kpm=sum(r["kills"] for r in fl) * 60 / fdt,
                    lost=sum(r["hp_lost"] for r in fl) * 60 / fdt,
                    hits=sum(r["hit_ticks"] for r in fl) * 60 / fdt,
                    lostb=sum(r["hp_lost"] for r in bo) * 60 / bdt,
                    dash=sum(r["dashes"] for r in fl + bo) * 60 / (fdt + bdt),
                    earned=sum(r["earned"] for r in fl + bo),
                    spent=sum(r["spent"] for r in fl + bo),
                    held=end["shards"],
                    unb=fl[-1]["chest_unbought"],
                    cards=end["cards"],
                )
            )

        def m_(k):
            return med([p[k] for p in per])

        def r_(k):
            xs = [p[k] for p in per]
            return f"{med(xs):.0f} [{q(xs, 0.1):.0f}..{q(xs, 0.9):.0f}]"

        out.append(
            f"{f} | {m_('p0'):.0f} | {r_('p1')} | {m_('pe'):.2f} | {m_('m'):.0f} | {m_('mb'):.0f} | {m_('chal'):.0f} | "
            f"{m_('cp'):.3f} | {m_('dps'):.1f} | {m_('dpsb'):.1f} | {r_('bs')} | {m_('kpm'):.1f} | {m_('lost'):.1f} | "
            f"{m_('hits'):.1f} | {m_('lostb'):.1f} | {m_('dash'):.1f} | {m_('earned'):.0f} | {m_('spent'):.0f} | "
            f"{m_('held'):.0f} | {m_('unb'):.0f} | {m_('cards'):.0f}"
        )
    out.append("")
    out.append("## Per minute of floor fighting (all seeds pooled; floor phase only)")
    out.append("floor | minute | P | chal (x floor factor) | dps | kills/min | HP lost/min | hits/min | shards earned/min | shards held")
    for f in floors:
        bym = {}
        for s in seeds:
            fl = [r for r in rows if r["seed"] == s and r["floor"] == f and r["phase"] == "floor"]
            acc = 0
            for r in fl:
                mi = acc // 60
                acc += r["dt"]
                bym.setdefault(mi, []).append(r)
        for mi in sorted(bym):
            rs = bym[mi]
            dt = max(1, sum(r["dt"] for r in rs))
            arr = sum(r["arrivals"] for r in rs)
            if dt < 60 * len(seeds) // 2:
                continue  # the zero-length end-of-floor rows
            out.append(
                f"{f} | {mi + 1} | {st.mean(r['P'] for r in rs):.0f} | "
                f"{sum(r['chal'] * r['arrivals'] for r in rs) / max(1, arr) * HP_F[f] * DMG_F[f] / 1e6:.0f} | "
                f"{sum(r['hp_removed'] for r in rs) / dt:.1f} | {sum(r['kills'] for r in rs) * 60 / dt:.1f} | "
                f"{sum(r['hp_lost'] for r in rs) * 60 / dt:.1f} | {sum(r['hit_ticks'] for r in rs) * 60 / dt:.1f} | "
                f"{sum(r['earned'] for r in rs) * 60 / dt:.1f} | {st.mean(r['shards'] for r in rs):.0f}"
            )
    text = "\n".join(out) + "\n"
    with open(os.path.join(ROOT, "table.txt"), "w") as f:
        f.write(text)
    print(text)


if __name__ == "__main__":
    main()

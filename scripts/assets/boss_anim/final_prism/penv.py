"""src.blend: the main piece's outline per direction and height; the loose pieces' centres."""
import bpy, sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, plib
o = plib.work_mesh(); me = o.data
ids, size = plib.pieces(me)
main = max(size, key=size.get)
co = np.array([v.co[:] for v in me.vertices]); ids = np.array(ids)
M = ids == main
AX = (-0.43, -0.18)
dx = co[:, 0] - AX[0]; dy = co[:, 1] - AX[1]
r = np.hypot(dx, dy); ang = np.degrees(np.arctan2(dy, dx)) % 360
sec = ((ang + 22.5) // 45).astype(int) % 8
tab = {}
for s in range(8):
    rows = []
    for k in range(1, 20):
        z0 = k * 0.15; m = M & (sec == s) & (co[:, 2] >= z0) & (co[:, 2] < z0 + 0.15)
        if m.sum() < 3: rows.append(None); continue
        rr = r[m]
        rows.append([round(float(np.percentile(rr, 10)), 2), round(float(np.median(rr)), 2), round(float(rr.max()), 2), int(m.sum())])
    tab[s * 45] = rows
loose = []
for pid in sorted(size, key=size.get, reverse=True)[1:]:
    c = co[ids == pid]; cen = (c.min(axis=0) + c.max(axis=0)) / 2
    loose.append({"n": int(len(c)), "c": [round(float(x), 3) for x in cen], "size": [round(float(x), 2) for x in (c.max(axis=0) - c.min(axis=0))],
                  "r": round(float(math.hypot(cen[0] - AX[0], cen[1] - AX[1])), 2), "ang": round(float(math.degrees(math.atan2(cen[1] - AX[1], cen[0] - AX[0])) % 360))})
zdlib.emit({"z_of_rows": [round(k * 0.15, 2) for k in range(1, 20)], "sectors": tab, "loose": loose})

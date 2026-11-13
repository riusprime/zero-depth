"""src.blend: the main piece by colour, height and what hangs below a cut.  -- zcut"""
import bpy, sys, os, math, bmesh
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib, plib
a = sys.argv[sys.argv.index('--') + 1:]
zc = float(a[0]) if a else 1.2
o = plib.work_mesh()
me = o.data
col = plib.vert_colours(o)
ids, size = plib.pieces(me)
main = max(size, key=size.get)
co = np.array([v.co[:] for v in me.vertices])
M = np.array([i == main for i in ids])
pale = (col.min(axis=1) > 0.30) & (col[:, 0] < col[:, 2] * 1.6)
red = (col[:, 0] > 0.25) & (col[:, 0] > col[:, 1] * 2.2)
cyan = (col[:, 2] > 0.35) & (col[:, 2] > col[:, 0] * 1.5)
rows = []
for k in range(0, 31):
    z0 = k * 0.1; m = M & (co[:, 2] >= z0) & (co[:, 2] < z0 + 0.1)
    if not m.any(): continue
    c = co[m]
    rows.append([round(z0, 1), int(m.sum()), int((m & pale).sum()), int((m & red).sum()),
                 [round(float(c[:, 0].min()), 2), round(float(c[:, 0].max()), 2)], [round(float(c[:, 1].min()), 2), round(float(c[:, 1].max()), 2)]])
cy = co[M & cyan]
# what hangs below the cut: pieces of the main piece's part under zc
low = [i for i in range(len(me.vertices)) if M[i] and co[i, 2] < zc]
sub = set(low); par = {i: i for i in low}
def find(x):
    while par[x] != x: par[x] = par[par[x]]; x = par[x]
    return x
key = {}
for i in low:
    k = tuple(round(c, 3) for c in co[i])
    if k in key: par[find(i)] = find(key[k])
    else: key[k] = i
for e in me.edges:
    x, y = e.vertices
    if x in sub and y in sub:
        fx, fy = find(x), find(y)
        if fx != fy: par[fx] = fy
grp = {}
for i in low: grp.setdefault(find(i), []).append(i)
hang = []
for g in sorted(grp.values(), key=len, reverse=True)[:40]:
    c = co[g]
    hang.append([len(g), round(float(pale[g].mean()), 2), [round(float(x), 2) for x in c.min(axis=0)], [round(float(x), 2) for x in c.max(axis=0)]])
zdlib.emit({"main_centroid": [round(float(x), 3) for x in co[M].mean(axis=0)], "pale": int((M & pale).sum()), "red": int((M & red).sum()),
            "cyan": {"n": int(len(cy)), "min": [round(float(x), 2) for x in cy.min(axis=0)] if len(cy) else None, "max": [round(float(x), 2) for x in cy.max(axis=0)] if len(cy) else None},
            "bands": rows, "hang": hang})

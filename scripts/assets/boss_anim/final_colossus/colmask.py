"""Which faces are painted as the pale cloak, read from the base colour texture (a small copy of it)."""
import bpy
import numpy as np

_px = None
def pixels(o):
    global _px
    if _px is None:
        mat = o.material_slots[0].material; img = None
        for n in mat.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image: img = n.image
        im = img.copy(); im.scale(1024, 1024)
        W, H = im.size
        a = np.empty(W * H * 4, dtype=np.float32); im.pixels.foreach_get(a)
        _px = a.reshape(H, W, 4)[:, :, :3].copy(); bpy.data.images.remove(im)
    return _px

def face_colours(o):
    px = pixels(o); H, W = px.shape[:2]
    me = o.data; uv = me.uv_layers.active.data
    out = np.zeros((len(me.polygons), 3))
    for p in me.polygons:
        us = [uv[l].uv for l in p.loop_indices]
        cu = sum(u[0] for u in us) / len(us); cv = sum(u[1] for u in us) / len(us)
        pts = [(cu, cv)] + [((u[0] + cu) / 2, (u[1] + cv) / 2) for u in us]
        c = np.zeros(3)
        for u, v in pts: c += px[min(H - 1, max(0, int(v % 1.0 * H))), min(W - 1, max(0, int(u % 1.0 * W)))]
        out[p.index] = c / len(pts)
    return out

def pale_faces(o):
    c = face_colours(o)
    lum = c.mean(axis=1); sat = c.max(axis=1) - c.min(axis=1)
    return (lum > 0.22) & (sat < 0.5 * c.max(axis=1))

def pale_verts(o):
    """Per vertex: the share of its faces that are pale."""
    pf = pale_faces(o); me = o.data
    s = np.zeros(len(me.vertices)); n = np.zeros(len(me.vertices))
    for p in me.polygons:
        for v in p.vertices: s[v] += pf[p.index]; n[v] += 1
    return s / np.maximum(n, 1)

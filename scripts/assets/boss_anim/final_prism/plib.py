"""Shared by the Prism's scripts: the work frame, the texture's colour per vertex, the mesh's loose pieces."""
import bpy, math
import numpy as np
from mathutils import Matrix

# The delivered model is 0.31 units tall and faces +X. The work frame is ten times that, facing -Y (her left is +X).
TO_WORK = Matrix.Rotation(math.radians(-90), 4, 'Z') @ Matrix.Scale(10, 4)

def work_mesh():
    o = [x for x in bpy.data.objects if x.type == 'MESH'][0]
    for x in list(bpy.data.objects):
        if x is not o: bpy.data.objects.remove(x)
    o.parent = None
    o.data.transform(o.matrix_world); o.matrix_world.identity()
    o.data.transform(TO_WORK)
    return o

def vert_colours(o):
    mat = o.material_slots[0].material; img = None
    for n in mat.node_tree.nodes:
        if n.type == 'BSDF_PRINCIPLED':
            l = n.inputs["Base Color"].links
            if l and l[0].from_node.type == 'TEX_IMAGE': img = l[0].from_node.image
    W, H = img.size
    step = max(1, W // 2048)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[::step, ::step, :3]
    h, w = px.shape[:2]
    me = o.data; uv = me.uv_layers.active.data
    n = len(me.loops)
    uvs = np.zeros(n * 2, dtype=np.float32); uv.foreach_get("uv", uvs); uvs = uvs.reshape(n, 2)
    vi = np.zeros(n, dtype=np.int32); me.loops.foreach_get("vertex_index", vi)
    x = np.clip((uvs[:, 0] % 1.0 * w).astype(int), 0, w - 1); y = np.clip((uvs[:, 1] % 1.0 * h).astype(int), 0, h - 1)
    c = px[y, x]
    col = np.zeros((len(me.vertices), 3)); cnt = np.zeros(len(me.vertices))
    np.add.at(col, vi, c); np.add.at(cnt, vi, 1)
    return col / np.maximum(cnt, 1)[:, None]

def pieces(me, digits=3):
    """Vertex -> piece id (joined through edges and coincident points), and the sizes."""
    par = list(range(len(me.vertices)))
    def find(a):
        while par[a] != a: par[a] = par[par[a]]; a = par[a]
        return a
    key = {}
    for v in me.vertices:
        k = tuple(round(x, digits) for x in v.co)
        if k in key:
            a, b = find(key[k]), find(v.index)
            if a != b: par[a] = b
        else: key[k] = v.index
    for e in me.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b: par[a] = b
    ids = [find(i) for i in range(len(me.vertices))]; size = {}
    for i in ids: size[i] = size.get(i, 0) + 1
    return ids, size

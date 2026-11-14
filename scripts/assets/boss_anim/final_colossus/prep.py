"""src.blend -> src10.blend: the delivered mesh turned to face -Y and scaled x10 (the work space), and its shells listed."""
import bpy, sys, os, math, struct, json
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Matrix, Vector
HERE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
for o in list(bpy.data.objects):
    if o.type != 'MESH' or o.name == "Icosphere": bpy.data.objects.remove(o)
m = [o for o in bpy.data.objects if o.type == 'MESH'][0]
info = {"name": m.name, "data": m.data.name, "loc": list(m.location), "rot": list(m.rotation_euler), "scale": list(m.scale),
        "mats": [s.material.name for s in m.material_slots], "uv": [u.name for u in m.data.uv_layers],
        "attrs": [a.name for a in m.data.attributes], "verts": len(m.data.vertices),
        "tris": sum(len(p.vertices) - 2 for p in m.data.polygons)}
for im in bpy.data.images: info.setdefault("images", []).append([im.name, im.filepath, im.source, list(im.size), bool(im.packed_file)])
T = Matrix.Rotation(math.radians(-90), 4, 'Z') @ Matrix.Scale(10, 4)
m.data.transform(m.matrix_world); m.matrix_world.identity(); m.data.transform(T)
me = m.data
parent = list(range(len(me.vertices)))
def find(a):
    while parent[a] != a: parent[a] = parent[parent[a]]; a = parent[a]
    return a
for e in me.edges:
    a, b = find(e.vertices[0]), find(e.vertices[1])
    if a != b: parent[a] = b
key = {}
for v in me.vertices:
    k = tuple(round(x, 3) for x in v.co)
    if k in key:
        a, b = find(key[k]), find(v.index)
        if a != b: parent[a] = b
    else: key[k] = v.index
comp = {}
for v in me.vertices: comp.setdefault(find(v.index), []).append(v.index)
rows = []
for c, lst in comp.items():
    mn = [min(me.vertices[i].co[k] for i in lst) for k in range(3)]; mx = [max(me.vertices[i].co[k] for i in lst) for k in range(3)]
    rows.append((len(lst), [round(x, 2) for x in mn], [round(x, 2) for x in mx]))
rows.sort(key=lambda r: -r[0])
info["shells"] = len(rows); info["big"] = rows[:40]
info["small_total"] = sum(r[0] for r in rows[40:])
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "src10.blend"))
# the delivered file's own JSON chunk: node, material and image entries
p = r"C:\Users\extri\Desktop\zerodepth\zero-depth-v090\assets\models\bosses\final_boss_colossus.glb"
with open(p, "rb") as f:
    f.read(12); n, _ = struct.unpack("<II", f.read(8)); j = json.loads(f.read(n))
info["glb"] = {k: j.get(k) for k in ("nodes", "scenes", "materials", "images", "textures", "samplers", "asset")}
info["glb"]["mesh_prims"] = [[list(pr.get("attributes", {}).keys()), pr.get("material")] for me_ in j["meshes"] for pr in me_["primitives"]]
info["glb"]["buffers"] = j.get("buffers"); info["glb"]["nbufviews"] = len(j.get("bufferViews", []))
zdlib.emit(info)

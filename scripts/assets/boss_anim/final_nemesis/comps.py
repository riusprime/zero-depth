import bpy, sys, os, bmesh
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
o = [x for x in bpy.data.objects if x.type=='MESH' and x.name.startswith('tripo')][0]
bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
mw = o.matrix_world
seen = set(); comps = []
for v in bm.verts:
    if v.index in seen: continue
    st=[v]; seen.add(v.index); c=[]
    while st:
        u=st.pop(); c.append(u.index)
        for e in u.link_edges:
            w=e.other_vert(u)
            if w.index not in seen: seen.add(w.index); st.append(w)
    comps.append(c)
comps.sort(key=len, reverse=True)
res=[]
for c in comps[:25]:
    ws=[mw @ bm.verts[i].co for i in c]
    res.append({"n":len(c),"min":[round(min(p[i] for p in ws),2) for i in range(3)],"max":[round(max(p[i] for p in ws),2) for i in range(3)]})
# welded (by distance) component count
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bm.verts.ensure_lookup_table()
seen=set(); n2=0; sizes=[]
for v in bm.verts:
    if v.index in seen: continue
    st=[v]; seen.add(v.index); k=0
    while st:
        u=st.pop(); k+=1
        for e in u.link_edges:
            w=e.other_vert(u)
            if w.index not in seen: seen.add(w.index); st.append(w)
    sizes.append(k)
sizes.sort(reverse=True)
zdlib.emit({"ncomps":len(comps),"top":res,"welded_verts":len(bm.verts),"welded_comps":len(sizes),"welded_sizes":sizes[:15],
  "nonmanifold_edges":sum(1 for e in bm.edges if not e.is_manifold), "edges":len(bm.edges)})

import bpy, sys, os, bmesh
sys.path.insert(0, os.path.dirname(__file__))
o = [x for x in bpy.data.objects if x.type=='MESH' and x.name.startswith('tripo')][0]
mw = o.matrix_world
bm = bmesh.new(); bm.from_mesh(o.data)
bmesh.ops.transform(bm, matrix=mw, verts=bm.verts)
zs = [float(a) for a in sys.argv[sys.argv.index('--')+1:]]
W,H = 100, 38
x0,x1,y0,y1 = -1.0,1.0,-0.76,0.76
for z in zs:
    g=[[' ']*W for _ in range(H)]
    for e in bm.edges:
        a,b=e.verts[0].co,e.verts[1].co
        if (a.z-z)*(b.z-z)<0:
            t=(z-a.z)/(b.z-a.z); p=a.lerp(b,t)
            c=int((p.x-x0)/(x1-x0)*(W-1)); r=int((p.y-y0)/(y1-y0)*(H-1))
            if 0<=c<W and 0<=r<H: g[r][c]='#'
    print(f"SL z={z}  (x -1..1 left->right, 0.02/char; y -0.76 (front) top .. +0.76 (back) bottom, 0.04/row)")
    print("SL "+"".join('|' if i%10==0 else '.' for i in range(W)))
    for r in range(H): print("SL "+"".join(g[r])+f" {y0+(y1-y0)*r/(H-1):+.2f}")

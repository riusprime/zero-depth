import bpy, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
ico = bpy.data.objects.get("Icosphere")
if ico: bpy.data.objects.remove(ico)
W,H=800,800; S=2.6
zdlib.setup_render((W,H))
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
def grid(path, hcenter, vcenter, hflip=False):
    im = bpy.data.images.load(path); a=np.array(im.pixels[:],dtype=np.float32).reshape(H,W,4); bpy.data.images.remove(im)
    ppm = W/S
    import math
    for k in range(-8,13):
        v = k*0.25
        col = (1,0.2,0.2,1) if k%4==0 else (0.2,0.9,1,1)
        px = int(W/2 + (v-hcenter)*ppm*(-1 if hflip else 1))
        if 0<=px<W: a[:,px]=a[:,px]*0.45+np.array(col)*0.55
        py = int(H/2 + (v-vcenter)*ppm)
        if 0<=py<H: a[py,:]=a[py,:]*0.45+np.array(col)*0.55
    o=bpy.data.images.new("g",W,H,alpha=True); o.pixels=a.ravel().tolist(); o.filepath_raw=path; o.file_format='PNG'; o.save(); bpy.data.images.remove(o)
ps=[]
# front: camera at -Y, image right = +X
p=os.path.join(out,"g_front.png"); zdlib.render(p,(0,-1,0),target=(0,0,1.1),ortho=S); grid(p,0,1.1); ps.append(p)
# sword side: camera at -X, image right = -Y (front to the right)
p=os.path.join(out,"g_side.png"); zdlib.render(p,(-1,0,0),target=(0,0,1.1),ortho=S); grid(p,0,1.1,hflip=True); ps.append(p)
# from below: camera at -Z
cam=zdlib.get_cam()
p=os.path.join(out,"g_below.png")
zdlib.aim(cam,(0,0,-1),target=(0,0,1.1),ortho=S)
from mathutils import Euler
cam.rotation_euler=Euler((3.14159265,0,0))  # looking +Z, image right=+X, image up=-Y(front)
bpy.context.scene.render.filepath=p; bpy.ops.render.render(write_still=True); ps.append(p)
zdlib.sheet(ps, os.path.join(out,"g_sheet.png"), 3)

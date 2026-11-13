import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
from mathutils import Vector, Matrix, Quaternion
rig = bpy.data.objects["Rig"]
R = {b.name: b.matrix_local for b in rig.data.bones}
d = lambda n: R[n].to_3x3().col[1].normalized()
sw, F, U = d("sword"), d("forearm.R"), d("upper_arm.R")
n0 = F.cross(sw).normalized()
if n0.x < 0: n0.negate()
A = Matrix((sw, n0, sw.cross(n0))).transposed()
Bm = Matrix((Vector((0,0,1)), Vector((1,0,0)), Vector((0,0,1)).cross(Vector((1,0,0))))).transposed()
Qh = (Bm @ A.transposed()).to_quaternion()
out = {"sw": list(sw), "F": list(F), "n0": list(n0), "Qh_axis_angle": [list(Qh.to_axis_angle()[0]), math.degrees(Qh.to_axis_angle()[1])]}
for dev in (-30, -20, 0, 20, 30):
    out[f"fd_dev{dev}"] = [round(x, 3) for x in (Quaternion((1, 0, 0), math.radians(dev)) @ Qh @ F)]
zdlib.emit(out)

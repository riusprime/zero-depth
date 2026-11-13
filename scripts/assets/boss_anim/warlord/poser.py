"""Pose the rig by armature-space maths (no constraints), then key every bone.

A pose is {bone: {op: value}}:
  loc  Vector          offset of the bone's head (armature space)
  rot  Quaternion      rotation on top of what the parent carries (armature axes, about the head)
  abs  Quaternion      rotation from the rest pose, ignoring the parents' rotation
  aim  Vector          then swing the bone's own axis onto this direction (shortest arc)
  aimvec (v, target)   then swing the rest-space vector v (carried by the bone) onto target
  ik   (ankle, pole)   on a thigh: solve thigh + shin so the shin's tail reaches ankle, knee towards pole
The Warlord faces +X, +Y is its left: +Y rotation leans forward, +Z turns left, +X tilts to its right.
Changed from the Twin Wardens' copy: the two-bone reach finds the delivered names (Thigh -> Calf, Upperarm ->
Forearm), the body's offset is keyed on "Hip", and LAG is set by the animation script.
"""
import bpy, math
from mathutils import Vector, Matrix, Quaternion

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
def q(axis, deg): return Quaternion(axis, math.radians(deg))
def qe(x=0, y=0, z=0): return q(Z, z) @ q(Y, y) @ q(X, x)

class Poser:
    # A shoulder plate sits on the torso: it follows the chest and takes a third of the collarbone's swing, so a
    # reaching arm doesn't carry the plate off the body.
    LAG = {}
    def __init__(self, rig):
        self.rig = rig
        self.bones = [b for b in rig.data.bones]            # parents come first
        self.rest = {b.name: b.matrix_local.copy() for b in self.bones}
        self.par = {b.name: (b.parent.name if b.parent else None) for b in self.bones}
        self.len = {b.name: b.length for b in self.bones}
        self.prevq = {}

    def solve(self, pose):
        world, basis = {}, {}
        pending = {}
        for b in self.bones:
            n = b.name; p = self.par[n]; ops = dict(pose.get(n, {})); ops.update(pending.pop(n, {}))
            M0 = (world[p] @ self.rest[p].inverted() @ self.rest[n]) if p else self.rest[n].copy()
            h = M0.translation + Vector(ops.get("loc", (0, 0, 0)))
            R = M0.to_3x3()
            lag = self.LAG.get(n)
            if lag is not None and p and self.par[p]:      # carried by the grandparent, and only partly by the parent
                g = self.par[p]
                Rg = (world[g] @ self.rest[g].inverted() @ self.rest[n]).to_3x3()
                R = Rg.to_quaternion().slerp(R.to_quaternion(), lag).to_matrix()
            if "abs" in ops: R = ops["abs"].to_matrix() @ self.rest[n].to_3x3()
            if "rot" in ops: R = ops["rot"].to_matrix() @ R
            if "ik" in ops:
                ankle, pole = ops["ik"]; child = n.replace("Thigh", "Calf").replace("Upperarm", "Forearm")
                l1, l2 = self.len[n], self.len[child]
                d = ankle - h; dist = min(d.length, (l1 + l2) * 0.999); nn = d.normalized()
                a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist); hh = math.sqrt(max(l1 * l1 - a * a, 0))
                pp = (pole - nn * pole.dot(nn)).normalized()
                knee = h + nn * a + pp * hh
                ops["aim"] = knee - h
                pending[child] = {"aim": (h + nn * dist) - knee}
            if "aim" in ops:
                R = R.col[1].normalized().rotation_difference(Vector(ops["aim"]).normalized()).to_matrix() @ R
            if "aimvec" in ops:
                v, tgt = ops["aimvec"]
                cur = (R @ self.rest[n].to_3x3().inverted()) @ Vector(v)
                R = cur.normalized().rotation_difference(Vector(tgt).normalized()).to_matrix() @ R
            M = R.to_4x4(); M.translation = h
            world[n] = M; basis[n] = M0.inverted() @ M
        return world, basis

    def key(self, pose, frame):
        world, basis = self.solve(pose)
        for n, Mb in basis.items():
            pb = self.rig.pose.bones[n]; pb.rotation_mode = 'QUATERNION'
            loc, rot, _ = Mb.decompose()
            if n in self.prevq and self.prevq[n].dot(rot) < 0: rot.negate()
            self.prevq[n] = rot.copy()
            pb.rotation_quaternion = rot; pb.keyframe_insert("rotation_quaternion", frame=frame)
            if n in ("Root", "Hip"):
                pb.location = loc; pb.keyframe_insert("location", frame=frame)
        return world

def new_action(rig, name):
    old = bpy.data.actions.get(name)
    if old: bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    if rig.animation_data is None: rig.animation_data_create()
    rig.animation_data.action = act
    for pb in rig.pose.bones:
        pb.matrix_basis.identity()
    return act

"""Shared helpers for the warden rig scripts (run inside Blender)."""
import bpy, math, json
from mathutils import Vector, Matrix, Euler

def setup_render(res=(640, 720)):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'
    sh.show_cavity = True; sh.cavity_type = 'BOTH'
    sh.show_shadows = False
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = 'PNG'
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.color = (0.18, 0.19, 0.22)
    return sc

def get_cam():
    cam = bpy.data.objects.get("ZDCam")
    if cam is None:
        cam = bpy.data.objects.new("ZDCam", bpy.data.cameras.new("ZDCam"))
        bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam

VIEWS = {  # direction the camera sits in, from the target
    "front": Vector((1, 0, 0)), "back": Vector((-1, 0, 0)),
    "left": Vector((0, 1, 0)), "right": Vector((0, -1, 0)),
    "top": Vector((0, 0, 1)),
    "q": Vector((1, -0.8, 0.45)), "q2": Vector((1, 0.8, 0.45)), "qb": Vector((-1, -0.8, 0.45)),
}

def aim(cam, view, target=(0, 0, 1.15), ortho=3.0, dist=8.0):
    d = VIEWS[view].normalized() if isinstance(view, str) else Vector(view).normalized()
    t = Vector(target)
    cam.location = t + d * dist
    up = 'Y'
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', up).to_euler()
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = ortho
    cam.data.clip_end = 100

def render(path, view="front", frame=None, **kw):
    sc = bpy.context.scene
    if frame is not None:
        sc.frame_set(frame)
    aim(get_cam(), view, **kw)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

def sheet(paths, out, cols):
    """Paste rendered PNGs into one contact sheet (numpy via bpy images)."""
    import numpy as np
    imgs = []
    for p in paths:
        im = bpy.data.images.load(p)
        w, h = im.size
        a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        imgs.append(a); bpy.data.images.remove(im)
    h, w = imgs[0].shape[:2]
    rows = (len(imgs) + cols - 1) // cols
    canvas = np.zeros((rows * h, cols * w, 4), dtype=np.float32); canvas[..., 3] = 1
    for i, a in enumerate(imgs):
        r, c = divmod(i, cols)
        y0 = (rows - 1 - r) * h
        canvas[y0:y0 + h, c * w:(c + 1) * w] = a
    o = bpy.data.images.new("sheet", cols * w, rows * h, alpha=True)
    o.pixels = canvas.ravel().tolist()
    o.filepath_raw = out; o.file_format = 'PNG'; o.save()
    bpy.data.images.remove(o)

def emit(d):
    print("JSON>>" + json.dumps(d))

import bpy, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "out"))
info = {}
for im in bpy.data.images:
    info[im.name] = [list(im.size), im.channels, im.colorspace_settings.name]
    if im.size[0] > 0 and "tex" not in info.get("_saved", ""):
        c = im.copy(); c.scale(1024, 1024); c.filepath_raw = os.path.join(out, "tex_" + im.name.replace(".", "_") + ".png"); c.file_format = 'PNG'; c.save()
mats = {}
for m in bpy.data.materials:
    if m.node_tree:
        mats[m.name] = [(n.type, n.image.name if n.type == 'TEX_IMAGE' and n.image else None) for n in m.node_tree.nodes]
zdlib.emit({"images": info, "mats": mats})

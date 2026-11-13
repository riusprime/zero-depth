import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
ico = bpy.data.objects.get("Icosphere")
if ico: bpy.data.objects.remove(ico)
zdlib.setup_render((560, 640))
out = os.path.join(os.path.dirname(__file__), "..", "out")
ps = []
for v in ["front", "left", "back", "right", "top", "q"]:
    p = os.path.abspath(os.path.join(out, f"look_{v}.png")); zdlib.render(p, v, ortho=2.6); ps.append(p)
zdlib.sheet(ps, os.path.abspath(os.path.join(out, "look_sheet.png")), 3)

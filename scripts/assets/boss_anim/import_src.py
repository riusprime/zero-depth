"""A delivered .glb -> src.blend in the work folder.  -- <path to the .glb>"""
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import zdlib
src = os.path.abspath(sys.argv[sys.argv.index('--') + 1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
os.makedirs(os.path.join(zdlib.WORK, "out"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(zdlib.WORK, "src.blend"))

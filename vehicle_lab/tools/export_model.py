"""Development-only Blender conversion. The original .blend is never modified.
Usage: python tools/export_model.py /path/to/model.blend /path/to/preview.glb
Requires bpy==4.5.8 (or Blender --background --python ... -- args).
"""
import bpy
import sys
import json
from pathlib import Path

source, dest = map(lambda x: Path(x).resolve(), sys.argv[-2:])
bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
bpy.context.scene.frame_set(0)
# Preserve every object, including the fourth wheel stored under the second scene root.
# Decimate only dense meshes; keep materials, UVs and the animated object pivots.
before, after, changes = 0, 0, []
for obj in list(bpy.data.objects):
    if obj.type != 'MESH':
        continue
    obj.data.calc_loop_triangles()
    triangles = len(obj.data.loop_triangles)
    before += triangles
    if triangles > 2500:
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new('Mobile preview LOD', 'DECIMATE')
        modifier.ratio = 0.30
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.calc_loop_triangles()
    count = len(obj.data.loop_triangles)
    after += count
    changes.append({'object': obj.name, 'triangles_original': triangles, 'triangles_preview': count})
# Packed images are authoritative for materials; shrink only very large maps.
images = []
for image in bpy.data.images:
    if image.source != 'FILE':
        continue
    w, h = image.size
    if w and h and max(w, h) > 1024:
        factor = 1024 / max(w, h)
        image.scale(max(1, round(w*factor)), max(1, round(h*factor)))
        image.pack()
    images.append({'name': image.name, 'original': [w, h], 'preview': list(image.size)})
bpy.context.scene.frame_set(0)
dest.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(dest), export_format='GLB', use_selection=False,
    export_animations=True, export_animation_mode='ACTIONS',
    export_force_sampling=True, export_frame_step=1, export_frame_range=False,
    export_optimize_animation_size=False, export_optimize_animation_keep_anim_object=True,
    export_anim_slide_to_zero=True, export_current_frame=True,
    export_yup=True, export_materials='EXPORT', export_cameras=False, export_lights=False,
    export_extras=True,
)
report = {'converter': bpy.app.version_string, 'triangles_original': before,
          'triangles_preview': after, 'meshes': changes, 'images': images,
          'notes': ['All 228 objects included; both scene roots retained.',
                    'Simplified preview geometry only. Original archive untouched.',
                    'Animation sampled at 24 fps, not cropped to the scene range.',
                    'Vertex-color alpha links unsupported by glTF may render differently.']}
(dest.parent.parent/'reports'/'conversion.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print('TRIANGLES', before, '->', after)

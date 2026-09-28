"""Extract exact pivots and Blender reference matrices used by the viewer.
Development tool: needs bpy 4.5. It is what makes the browser regression test meaningful.
"""
import bpy
import sys
import json
from pathlib import Path
from mathutils import Matrix, Vector

src, dest = map(Path, sys.argv[-2:])
bpy.ops.wm.open_mainfile(filepath=str(src.resolve()), use_scripts=False)
scene = bpy.context.scene
scene.frame_set(0)
# The glTF exporter re-bases every node: C * M * C^-1 is Blender(Z-up) -> glTF(Y-up).
C = Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))

def convert_vec(v): return [float(v[0]), float(v[2]), float(-v[1])]
def converted_world(obj):
    mat = C @ obj.matrix_world @ C.inverted()
    return [float(mat[row][col]) for col in range(4) for row in range(4)]

rig = {'wheels': [], 'steering': None}
# Each wheel mesh is a child of its own empty pivot, so the pivot origin is the
# rotation centre and its exported local X axis is the axle axis.
for mesh_name, pivot_name, front in [
        ('Object_221', '[wheel_lf]_49', False), ('Object_242.001', '[wheel_lf_57.001', True),
        ('Object_245', '[wheel_l_58', True), ('Object_248', '[wheel_59', False)]:
    obj = bpy.data.objects[mesh_name]
    rig['wheels'].append({'node': pivot_name, 'center': [0,0,0], 'axis': convert_vec(Vector((1,0,0))),
                          'up': [0,1,0], 'center_world': convert_vec(obj.parent.matrix_world.translation),
                          'front': front, 'radius': 0.477})
steering = bpy.data.objects['steeringwheel_35']
rig['steering'] = {'node': 'steeringwheel_35', 'center': [0,0,0], 'axis': [0,0,1], 'up': [0,1,0],
                   'center_world': convert_vec(steering.matrix_world.translation),
                   'isolate_nodes': [o.name for o in steering.children_recursive if o.type == 'MESH']}
(dest/'model'/'rig.json').write_text(json.dumps(rig, indent=2), encoding='utf-8')
references = {'rest': {o.name: converted_world(o) for o in bpy.data.objects}, 'actions': {}}
for action in bpy.data.actions:
    obj = next(o for o in bpy.data.objects if o.animation_data and o.animation_data.action == action)
    start, end = action.frame_range
    samples = []
    for frame in sorted(set([start, end, (start+end)//2, start+min(1, end-start)])):
        scene.frame_set(int(frame), subframe=frame-int(frame))
        samples.append({'time': (frame-start)/24, 'frame': frame, 'world': converted_world(obj)})
    references['actions'][action.name] = {'node': obj.name, 'samples': samples}
(dest/'reports'/'animation_reference.json').write_text(json.dumps(references, indent=2), encoding='utf-8')

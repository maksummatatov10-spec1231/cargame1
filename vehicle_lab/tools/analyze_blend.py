"""Build a reproducible, exhaustive data inventory from the supplied .blend.
Run using a Python installation with bpy 4.5 (development tool, NOT needed by viewer).
"""
import bpy
import json
import sys
from pathlib import Path
from mathutils import Vector

source = Path(sys.argv[-2]).resolve()
out = Path(sys.argv[-1]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
scene = bpy.context.scene

def simple(x):
    if isinstance(x, (int, float, str, bool)) or x is None:
        return x
    try:
        return list(x)
    except TypeError:
        return str(x)

def animation(idblock):
    ad = idblock.animation_data
    if not ad:
        return None
    return {
        'action': ad.action.name if ad.action else None,
        'drivers': [{'path': f.data_path, 'index': f.array_index, 'expression': f.driver.expression} for f in ad.drivers],
        'nla_tracks': [{'name': t.name, 'mute': t.mute, 'strips': [
            {'name': s.name, 'action': s.action.name if s.action else None,
             'start': s.frame_start, 'end': s.frame_end, 'scale': s.scale,
             'repeat': s.repeat, 'blend_type': s.blend_type} for s in t.strips
        ]} for t in ad.nla_tracks]
    }

report = {
    'source': source.name, 'blender_reader': bpy.app.version_string,
    'scene': {'name': scene.name, 'fps': scene.render.fps, 'fps_base': scene.render.fps_base,
              'frame_start': scene.frame_start, 'frame_end': scene.frame_end, 'current_frame': scene.frame_current,
              'units': scene.unit_settings.system, 'scale_length': scene.unit_settings.scale_length},
    'scenes': [s.name for s in bpy.data.scenes],
    'objects': [], 'actions': [], 'meshes': [], 'materials': [], 'images': []
}
for ob in bpy.data.objects:
    entry = {
        'name': ob.name, 'type': ob.type, 'data': ob.data.name if ob.data else None,
        'parent': ob.parent.name if ob.parent else None, 'children': [c.name for c in ob.children],
        'location': list(ob.location), 'rotation_mode': ob.rotation_mode,
        'rotation_euler': list(ob.rotation_euler), 'rotation_quaternion': list(ob.rotation_quaternion),
        'scale': list(ob.scale), 'dimensions': list(ob.dimensions),
        'matrix_world': [list(row) for row in ob.matrix_world],
        'world_bounds': [list(ob.matrix_world @ Vector(c)) for c in ob.bound_box] if ob.type == 'MESH' else None,
        'hidden_render': ob.hide_render, 'hidden_viewport': ob.hide_viewport,
        'modifiers': [{'name': m.name, 'type': m.type} for m in ob.modifiers],
        'constraints': [{'name': c.name, 'type': c.type, 'influence': c.influence} for c in ob.constraints],
        'animation': animation(ob),
        'custom_properties': {str(k): simple(ob[k]) for k in ob.keys()},
        'materials': [s.material.name if s.material else None for s in ob.material_slots],
    }
    if ob.type == 'ARMATURE':
        entry['bones'] = [{'name': b.name, 'parent': b.parent.name if b.parent else None} for b in ob.data.bones]
    report['objects'].append(entry)
for action in bpy.data.actions:
    curves = []
    for f in action.fcurves:
        keys = [{'frame': k.co.x, 'value': k.co.y, 'interpolation': k.interpolation,
                 'handle_left': list(k.handle_left), 'handle_right': list(k.handle_right)} for k in f.keyframe_points]
        samples = [f.evaluate(i) for i in range(int(action.frame_range[0]), int(action.frame_range[1])+1)]
        curves.append({'path': f.data_path, 'index': f.array_index, 'keys': keys,
                       'sample_min': min(samples) if samples else None,
                       'sample_max': max(samples) if samples else None,
                       'modifiers': [m.type for m in f.modifiers]})
    report['actions'].append({'name': action.name, 'users': action.users, 'fake_user': action.use_fake_user,
                              'frame_range': list(action.frame_range), 'curves': curves})
for mesh in bpy.data.meshes:
    mesh.calc_loop_triangles()
    report['meshes'].append({'name': mesh.name, 'vertices': len(mesh.vertices), 'edges': len(mesh.edges),
        'polygons': len(mesh.polygons), 'triangles': len(mesh.loop_triangles),
        'uv_layers': [u.name for u in mesh.uv_layers], 'color_attributes': [c.name for c in mesh.color_attributes],
        'shape_keys': [b.name for b in mesh.shape_keys.key_blocks] if mesh.shape_keys else [],
        'materials': [m.name if m else None for m in mesh.materials],
        'users': mesh.users})
for mat in bpy.data.materials:
    nodes, links = [], []
    if mat.node_tree:
        for n in mat.node_tree.nodes:
            item = {'name': n.name, 'type': n.type,
                    'inputs': {i.name: simple(i.default_value) for i in n.inputs if hasattr(i,'default_value')}}
            if n.type == 'TEX_IMAGE':
                item['image'] = n.image.name if n.image else None
            nodes.append(item)
        links = [{'from_node': l.from_node.name, 'from_socket': l.from_socket.name,
                  'to_node': l.to_node.name, 'to_socket': l.to_socket.name} for l in mat.node_tree.links]
    report['materials'].append({'name': mat.name, 'users': mat.users, 'diffuse_color': list(mat.diffuse_color),
        'use_nodes': mat.use_nodes, 'nodes': nodes, 'links': links})
for image in bpy.data.images:
    report['images'].append({'name': image.name, 'filepath': image.filepath, 'size': list(image.size),
        'source': image.source, 'packed': bool(image.packed_file), 'colorspace': image.colorspace_settings.name,
        'users': image.users})
report['libraries'] = [l.filepath for l in bpy.data.libraries]
report['embedded_texts'] = [{'name': t.name, 'lines': len(t.lines)} for t in bpy.data.texts]
report['summary'] = {
    'objects': len(report['objects']), 'mesh_objects': sum(o.type=='MESH' for o in bpy.data.objects),
    'meshes': len(report['meshes']), 'materials': len(report['materials']), 'images': len(report['images']),
    'actions': len(report['actions']), 'armatures': sum(o.type=='ARMATURE' for o in bpy.data.objects),
    'vertices_unique_meshes': sum(m['vertices'] for m in report['meshes']),
    'triangles_unique_meshes': sum(m['triangles'] for m in report['meshes']),
    'triangles_instanced': sum(len(o.data.loop_triangles) for o in bpy.data.objects if o.type=='MESH'),
    'shape_key_meshes': sum(bool(m['shape_keys']) for m in report['meshes']),
}
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report['summary'], ensure_ascii=False, indent=2))

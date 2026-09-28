import bpy,json,sys
from pathlib import Path
root=Path(sys.argv[-2]);out=Path(sys.argv[-1]);report=[]
for path in sorted(root.glob('*.fbx')):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.fbx(filepath=str(path),use_anim=True)
 s=bpy.context.scene
 item={'file':path.name,'fps':s.render.fps,'fps_base':s.render.fps_base,'objects':[],'actions':[],'materials':[],'images':[]}
 for o in bpy.data.objects:
  d={'name':o.name,'type':o.type,'parent':o.parent.name if o.parent else None,'dimensions':list(o.dimensions),'scale':list(o.scale),'action':o.animation_data.action.name if o.animation_data and o.animation_data.action else None}
  if o.type=='MESH':
   o.data.calc_loop_triangles();d.update(vertices=len(o.data.vertices),triangles=len(o.data.loop_triangles),vertex_groups=[g.name for g in o.vertex_groups],materials=[m.name for m in o.data.materials],modifiers=[m.type for m in o.modifiers])
  if o.type=='ARMATURE':d['bones']=[{'name':b.name,'parent':b.parent.name if b.parent else None,'head':list(o.matrix_world@b.head_local),'tail':list(o.matrix_world@b.tail_local)} for b in o.data.bones]
  item['objects'].append(d)
 for a in bpy.data.actions:
  item['actions'].append({'name':a.name,'range':list(a.frame_range),'curves':len(a.fcurves),'keys':sum(len(c.keyframe_points) for c in a.fcurves),'paths':sorted(set(c.data_path for c in a.fcurves))})
 for m in bpy.data.materials:item['materials'].append({'name':m.name,'diffuse':list(m.diffuse_color)})
 item['images']=[{'name':i.name,'path':i.filepath,'packed':bool(i.packed_file)} for i in bpy.data.images]
 report.append(item)
 print(path.name,'fps',s.render.fps, 'objects',[(o['name'],o['type'],o.get('triangles')) for o in item['objects']], 'actions',item['actions'])
out.write_text(json.dumps(report,ensure_ascii=False,indent=2))

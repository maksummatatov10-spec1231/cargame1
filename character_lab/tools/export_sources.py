import bpy,json,sys
from pathlib import Path
src,out=map(Path,sys.argv[-2:]);items=[]
labels={'Breathing Idle':'Ожидание / дыхание','Walking':'Ходьба','Running':'Бег','Backward Right Turn':'Шаг назад с поворотом вправо','Y Bot':'Y Bot / базовая поза'}
for p in sorted(src.glob('*.fbx')):
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(p),use_anim=True)
 a=next(iter(bpy.data.actions));a.name=p.stem
 start,end=a.frame_range;fps=bpy.context.scene.render.fps
 bpy.context.scene.frame_set(int(start))
 slug=p.stem.lower().replace(' ','_')
 bpy.ops.export_scene.gltf(filepath=str(out/(slug+'.glb')),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_anim_slide_to_zero=True,export_current_frame=True)
 items.append({'id':slug,'title':labels[p.stem],'file':slug+'.glb','source':p.name,'fps':fps,'start':start,'end':end,'duration':(end-start)/fps,'kind':'source','bones':len(next(o for o in bpy.data.objects if o.type=='ARMATURE').data.bones)})
(out/'catalog.json').write_text(json.dumps(items,ensure_ascii=False,indent=2))

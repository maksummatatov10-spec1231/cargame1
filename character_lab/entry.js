import * as T from './vendor/three.module.min.js';
const V=a=>new T.Vector3(...a), smooth=t=>t*t*t*(t*(t*6-15)+10);
// World-space targets in the original vehicle coordinate system (metres, Y up).
// Floor is -0.62685 before display grounding. Every pose is solved from bind pose.
export const stages=[
{t:0,label:'Подготовка',hip:[-1.65,.371,-.12],yaw:Math.PI/2,lean:0,lf:[-1.67,-.522,.02],rf:[-1.67,-.522,-.20],lh:[-1.60,.10,.14],rh:[-1.59,.10,-.37],door:0},
{t:1.3,label:'Рука на двери',hip:[-1.65,.371,-.12],yaw:Math.PI/2,lean:.12,lf:[-1.67,-.522,.02],rf:[-1.67,-.522,-.20],lh:[-1.57,.10,.15],rh:[-1.06,.51,-.04],door:0},
{t:3,label:'Открытие двери',hip:[-1.83,.371,.05],yaw:Math.PI/2,lean:.08,lf:[-1.82,-.522,.18],rf:[-1.85,-.522,-.05],lh:[-1.80,.10,.30],rh:[-1.85,.50,-.35],door:1},
{t:4,label:'Правая нога на порог',hip:[-1.27,.46,-.10],yaw:2.2,lean:.30,lf:[-1.52,-.522,.08],rf:[-.84,.08,-.54],lh:[-.92,.96,-.12],rh:[-.79,.75,-.75],door:1},
{t:5.5,label:'Перенос веса / наклон головы',hip:[-.91,.48,-.16],yaw:2.65,lean:.52,lf:[-1.12,-.12,.0],rf:[-.38,.18,-.87],lh:[-.87,.90,-.12],rh:[-.43,.87,-.62],door:1},
{t:7,label:'Таз на сиденье',hip:[-.47,.43,-.15],yaw:Math.PI,lean:.20,lf:[-.95,.13,-.37],rf:[-.37,.15,-.80],lh:[-.88,.65,-.28],rh:[-.32,.83,-.63],door:1},
{t:8.4,label:'Левая нога в салон',hip:[-.47,.43,-.15],yaw:Math.PI,lean:-.20,lf:[-.57,.15,-.80],rf:[-.37,.15,-.80],lh:[-.83,.63,-.30],rh:[-.32,.83,-.63],door:1},
{t:9.2,label:'Рука к внутренней ручке',hip:[-.47,.43,-.15],yaw:Math.PI,lean:-.20,lf:[-.57,.15,-.80],rf:[-.37,.15,-.80],lh:[-1.06,.61,-.56],rh:[-.32,.83,-.63],door:1},
{t:10.8,label:'Закрытие двери',hip:[-.47,.43,-.15],yaw:Math.PI,lean:-.20,lf:[-.57,.15,-.80],rf:[-.37,.15,-.80],lh:[-.79,.61,-.32],rh:[-.32,.83,-.63],door:0},
{t:12,label:'За рулём',hip:[-.47,.43,-.15],yaw:Math.PI,lean:-.20,lf:[-.57,.15,-.80],rf:[-.37,.15,-.80],lh:[-.58,.83,-.63],rh:[-.32,.83,-.63],door:0}
];
export function createEntry(root,ground){
 const bones={};root.traverse(o=>{if(o.isBone)bones[o.name.replace('mixamorig','').replace(/[:_]/g,'')]=o});
 const rest=Object.values(bones).map(b=>[b,b.position.clone(),b.quaternion.clone(),b.scale.clone()]);
 const wp=b=>b.getWorldPosition(new T.Vector3());
 function aim(b,child,target){root.updateMatrixWorld(true);const q=b.getWorldQuaternion(new T.Quaternion()),pq=b.parent.getWorldQuaternion(new T.Quaternion());const from=wp(child).sub(wp(b)).normalize(),to=target.clone().sub(wp(b)).normalize();b.quaternion.copy(pq.invert().multiply(new T.Quaternion().setFromUnitVectors(from,to).multiply(q)));root.updateMatrixWorld(true)}
 function ik(a,b,c,target,pole){const p=wp(a),l1=p.distanceTo(wp(b)),l2=wp(b).distanceTo(wp(c));const d=target.clone().sub(p),dist=T.MathUtils.clamp(d.length(),Math.abs(l1-l2)+.0001,l1+l2-.0001);d.normalize();const n=pole.clone().sub(p);n.addScaledVector(d,-n.dot(d)).normalize();const x=(l1*l1-l2*l2+dist*dist)/(2*dist),h=Math.sqrt(Math.max(0,l1*l1-x*x));const elbow=p.clone().addScaledVector(d,x).addScaledVector(n,h);aim(a,b,elbow);aim(b,c,target)}
 return time=>{
  let i=stages.findIndex(s=>s.t>=time);if(i<=0)i=1;const a=stages[i-1],b=stages[i],f=smooth(T.MathUtils.clamp((time-a.t)/(b.t-a.t),0,1));const pose={};for(const k of ['hip','lf','rf','lh','rh'])pose[k]=V(a[k]).lerp(V(b[k]),f).add(new T.Vector3(0,ground,0));for(const k of ['yaw','lean','door'])pose[k]=T.MathUtils.lerp(a[k],b[k],f);
  // Reconcile standing contact with actual lowest vehicle vertex.
  const floorCorrection=ground-.6268510818481445;for(const k of ['hip','lf','rf','lh','rh']){const w=time<=3?1:time<5.5?1-smooth((time-3)/2.5):0;pose[k].y-=floorCorrection*w;}
  root.position.set(0,0,0);root.rotation.set(0,pose.yaw,0);for(const [bone,p,q,s]of rest){bone.position.copy(p);bone.quaternion.copy(q);bone.scale.copy(s)}root.updateMatrixWorld(true);root.position.copy(pose.hip.clone().sub(wp(bones.Hips)));root.updateMatrixWorld(true);
  bones.Spine.rotateX(pose.lean*.55);bones.Spine1.rotateX(pose.lean*.45);bones.Neck.rotateX(-pose.lean*.25);root.updateMatrixWorld(true);
  const forward=V([Math.sin(pose.yaw),0,Math.cos(pose.yaw)]),side=V([Math.cos(pose.yaw),0,-Math.sin(pose.yaw)]);
  for(const [s,key,sign] of [['Left','l',1],['Right','r',-1]]){
   const knee=pose.hip.clone().addScaledVector(forward,.65).add(new T.Vector3(0,.7,0)).addScaledVector(side,.1*sign);ik(bones[s+'UpLeg'],bones[s+'Leg'],bones[s+'Foot'],pose[key+'f'],knee);
   aim(bones[s+'Foot'],bones[s+'ToeBase'],pose[key+'f'].clone().addScaledVector(forward,.15).add(V([0,-.06,0])));
   const elbow=pose.hip.clone().addScaledVector(side,.65*sign).add(V([0,.1,0]));ik(bones[s+'Arm'],bones[s+'ForeArm'],bones[s+'Hand'],pose[key+'h'],elbow);
   aim(bones[s+'Hand'],bones[s+'HandMiddle1'],pose[key+'h'].clone().addScaledVector(forward,.1));
   for(const finger of ['Thumb','Index','Middle','Ring','Pinky'])for(let n=1;n<=3;n++)bones[s+'Hand'+finger+n]?.rotateZ(-.16*sign);
  }
  root.updateMatrixWorld(true);return{door:pose.door,label:(time>=12?b:a).label};
 }
}

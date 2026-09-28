import * as T from './vendor/three.module.min.js';
import {GLTFLoader} from './vendor/GLTFLoader.js';
import {OrbitControls} from './vendor/OrbitControls.js';
import {RoomEnvironment} from './vendor/RoomEnvironment.js';
import {buildMotion,sample,DURATION} from './motion.js';
const $=id=>document.getElementById(id);const canvas=document.querySelector('canvas'),stage=$('stage');
let playing=false,time=0,selected,action,model,mixer,ready=false,parts=[],steerPart,rest=[],motions,ground;
const nodes=new Map(),clips=new Map();const scene=new T.Scene(),motion=new T.Group();scene.add(motion);
let renderer,camera,controls;
function error(e){$('status').textContent='Ошибка: '+e.message+' · нужен браузер с WebGL 2';console.error(e)}
function save(){rest=[];model.traverse(n=>rest.push([n,n.position.clone(),n.quaternion.clone(),n.scale.clone()]));}
function restore(){for(const[n,p,q,s]of rest){n.position.copy(p);n.quaternion.copy(q);n.scale.copy(s)}}
function makePart(name){const node=nodes.get(name);model.updateMatrixWorld(true);const box=new T.Box3().setFromObject(node),center=box.getCenter(new T.Vector3());const inv=node.getWorldQuaternion(new T.Quaternion()).invert();return{node,center:node.worldToLocal(center.clone()),worldCenter:box.getCenter(new T.Vector3()),axis:new T.Vector3(1,0,0).applyQuaternion(inv).normalize(),up:new T.Vector3(0,1,0).applyQuaternion(inv).normalize(),radius:box.getSize(new T.Vector3()).y/2,p:node.position.clone(),q:node.quaternion.clone()};}
function rotate(part,quaternion){const n=part.node;n.quaternion.copy(part.q).multiply(quaternion);n.position.copy(part.p).add(part.center.clone().applyQuaternion(part.q)).sub(part.center.clone().applyQuaternion(n.quaternion));}
function apply(t){time=Math.max(0,Math.min(selected.duration,t));
 if(action){action.time=time;mixer.update(0)}else{
  restore();let target=new T.Vector3(),yaw=0;
  if(selected.id==='demo-steering'){rotate(steerPart,new T.Quaternion().setFromAxisAngle(steerPart.axis,Math.sin(time/6*Math.PI*2)*2.2));}
  else{const s=sample(motions[selected.id],time);target.set(s.x,0,s.z);yaw=-s.yaw;
   parts.forEach((p,i)=>rotate(p,new T.Quaternion().setFromAxisAngle(p.up,-s.angles[i]).multiply(new T.Quaternion().setFromAxisAngle(p.axis,-s.spin[i]))));
   rotate(steerPart,new T.Quaternion().setFromAxisAngle(steerPart.axis,-s.steer*14));
  }
  if($('follow').checked){const delta=target.clone().sub(motion.position);camera.position.add(delta);controls.target.add(delta)}motion.position.copy(target);motion.rotation.y=yaw;
 }
 model.updateMatrixWorld(true);$('seek').value=selected.duration?time/selected.duration:0;$('clock').textContent=`${time.toFixed(2)} / ${selected.duration.toFixed(2)} с`;
}
function setCamera(steering=false){model.traverse(n=>{if(n.isMesh){let p=n,inside=false;while(p){if(p===steerPart.node)inside=true;p=p.parent}n.visible=!steering||inside}});if(steering){const center=steerPart.node.localToWorld(steerPart.center.clone());controls.target.copy(center);camera.position.copy(center).add(new T.Vector3(-.12,.16,.85));controls.minDistance=.15;}else{controls.target.copy(motion.position).add(new T.Vector3(0,1,0));camera.position.copy(motion.position).add(new T.Vector3(-7,4.5,-9));controls.minDistance=1;}controls.update()}
function choose(id){selected=catalog.find(x=>x.id===id);playing=false;mixer.stopAllAction();restore();motion.position.set(0,0,0);motion.rotation.set(0,0,0);action=null;
 if(selected.kind==='source'){action=mixer.clipAction(clips.get(id));action.reset().setLoop(T.LoopOnce,1);action.clampWhenFinished=true;action.play();action.paused=true;}
 $('description').textContent=selected.description;$('play').disabled=!selected.duration;$('play').textContent='▶ Играть';$('seek').disabled=!selected.duration;apply(0);setCamera(id==='demo-steering');
}
let catalog=[];
async function init(){try{
 renderer=new T.WebGLRenderer({canvas,alpha:true,antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1;
 camera=new T.PerspectiveCamera(38,1,.01,250);controls=new OrbitControls(camera,canvas);controls.enableDamping=true;controls.maxDistance=90;
 scene.add(new T.HemisphereLight(0xffffff,0x454d42,2));const l=new T.DirectionalLight(0xfff3e2,2);l.position.set(-5,10,-7);scene.add(l);
 const env=new RoomEnvironment(),pm=new T.PMREMGenerator(renderer);scene.environment=pm.fromScene(env,.04).texture;scene.environmentIntensity=.6;env.dispose();pm.dispose();
 const grid=new T.GridHelper(200,200,0x77827e,0x37464d);scene.add(grid);
 new ResizeObserver(()=>{renderer.setSize(stage.clientWidth,stage.clientHeight,false);camera.aspect=stage.clientWidth/stage.clientHeight;camera.updateProjectionMatrix()}).observe(stage);
 const data=await(await fetch('model/catalog.json')).json();catalog=data.items.filter(x=>x.kind==='source');
 catalog.push({id:'demo-steering',title:'Руль · плавный цикл',duration:6,kind:'demo',description:'Создано отдельно: вращение настоящего руля вокруг центра и наклонной оси.'},{id:'demo-forward',title:'Езда · разгон и торможение',duration:DURATION,kind:'demo',description:'Создано отдельно: плавный разгон, движение и торможение до остановки. Колёса проходят расстояние по своему радиусу.'},{id:'demo-right',title:'Правый поворот · Ackermann',duration:DURATION,kind:'demo',description:'Создано отдельно: плавный вход и выход из поворота, геометрия Аккермана, разные скорости колёс по внутренней и внешней дуге. Руль с передаточным отношением 14:1. Кинематическая модель, не физическая симуляция подвески.'});
 const gltf=await new GLTFLoader().loadAsync('model/ford_raptor.glb');model=gltf.scene;
 await Promise.all(gltf.parser.json.nodes.map(async(n,i)=>{if(n.name)nodes.set(n.name,await gltf.parser.getDependency('node',i))}));gltf.animations.forEach(c=>clips.set(c.name,c));
 ground=-new T.Box3().setFromObject(model).min.y;model.position.y=ground;motion.add(model);model.updateMatrixWorld(true);save();mixer=new T.AnimationMixer(model);
 parts=['Object_221','Object_242.001','Object_245','Object_248'].map(makePart);steerPart=makePart('steeringwheel_35');
 // Source steering shaft is tilted ~18 degrees from vehicle longitudinal axis.
 steerPart.axis=new T.Vector3(0,.316,.949).normalize().applyQuaternion(steerPart.node.getWorldQuaternion(new T.Quaternion()).invert());
 const wb=Math.abs(parts[0].worldCenter.z-parts[1].worldCenter.z),track=Math.abs(parts[1].worldCenter.x-parts[2].worldCenter.x);
 motions={'demo-forward':buildMotion(false,wb,track,parts.map(p=>p.radius)),'demo-right':buildMotion(true,wb,track,parts.map(p=>p.radius))};
 for(const kind of ['source','demo']){const group=document.createElement('optgroup');group.label=kind==='source'?'Из исходника — 8 Actions':'Созданы отдельно — движение автомобиля';catalog.filter(c=>c.kind===kind).forEach(c=>{const o=new Option(c.title+(c.duration?'':' (поза)'),c.id);group.append(o)});$('clips').append(group)}
 $('clips').disabled=false;$('clips').onchange=()=>choose($('clips').value);$('play').onclick=()=>{if(time>=selected.duration)apply(0);playing=!playing;$('play').textContent=playing?'Ⅱ Пауза':'▶ Играть'};
 $('reset').onclick=()=>{playing=false;apply(0);$('play').textContent='▶ Играть'};$('seek').oninput=()=>{playing=false;apply(Number($('seek').value)*selected.duration);$('play').textContent='▶ Играть'};
 $('overview').onclick=()=>setCamera(false);$('steering').onclick=()=>setCamera(true);
 choose(catalog[0].id);ready=true;$('status').textContent='228 узлов · 8 исходных Actions · 3 новых движения';
 window.lab={select:choose,seek:apply,get ready(){return ready},get time(){return time},parts:()=>parts.map(p=>p.node.localToWorld(p.center.clone()).toArray()),motion:()=>motion.position.toArray()};
 let last=performance.now();function frame(now){requestAnimationFrame(frame);const dt=Math.min((now-last)/1000,.25);last=now;if(playing&&!document.hidden){let n=time+dt*Number($('speed').value);if(n>=selected.duration){if($('loop').checked)n%=selected.duration;else{n=selected.duration;playing=false;$('play').textContent='▶ Играть'}}apply(n)}controls.update();renderer.render(scene,camera)}requestAnimationFrame(frame);
 }catch(e){error(e)}}init();

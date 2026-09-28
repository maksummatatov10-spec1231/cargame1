import * as T from '../vendor/three.module.min.js';
import {MeshBVH} from '../vendor/mesh-bvh.js';
// Surface test, all actual vehicle meshes, no shifted proxy points or exclusions.
export async function validate(lab){
 const cars=[],cache=new WeakMap(),skins=[],samples=[];
 lab.car.traverse(o=>{if(o.isMesh){if(!cache.has(o.geometry))cache.set(o.geometry,new MeshBVH(o.geometry,{indirect:true}));cars.push({o,bvh:cache.get(o.geometry)})}});
 lab.character.traverse(o=>{if(o.isSkinnedMesh)skins.push(o)});
 for(let n=0;n<=48;n++){
  const time=n/4;lab.setTime(time);lab.scene.updateMatrixWorld(true);const hits=new Set();
  for(const skin of skins){skin.skeleton.update();const g=new T.BufferGeometry();g.setIndex(skin.geometry.index.clone());const positions=new Float32Array(skin.geometry.attributes.position.count*3),v=new T.Vector3();for(let i=0;i<positions.length/3;i++)skin.getVertexPosition(i,v).toArray(positions,i*3);g.setAttribute('position',new T.BufferAttribute(positions,3));g.computeBoundingBox();g.boundsTree=new MeshBVH(g,{indirect:true});const box=g.boundingBox.clone().applyMatrix4(skin.matrixWorld);
   for(const {o,bvh}of cars){o.geometry.computeBoundingBox();if(!box.intersectsBox(o.geometry.boundingBox.clone().applyMatrix4(o.matrixWorld)))continue;if(bvh.intersectsGeometry(g,o.matrixWorld.clone().invert().multiply(skin.matrixWorld)))hits.add(o.name)}g.dispose();
  }samples.push({time,intersectedMeshes:[...hits]});await new Promise(r=>setTimeout(r,0));
 }
 return{method:'All actual skinned triangle surfaces versus all car meshes, 49 samples at 0.25 seconds. Includes contacts; does not certify continuous motion, penetration depth, solid containment or self-collision.',status:samples.some(s=>s.intersectedMeshes.length)?'FAIL: intersections remain':'No sampled surface intersections',samples};
}

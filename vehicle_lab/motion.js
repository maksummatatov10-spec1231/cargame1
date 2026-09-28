// Deterministic bicycle-path integration at 240 Hz. All angles in radians.
// Smooth acceleration/braking, progressive steering, Ackermann wheel angles,
// and independent wheel arc lengths (no shared arbitrary spin frequency).
export const DT=1/240, DURATION=12;
const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*x*(x*(x*6-15)+10)};
export function buildMotion(turn,wheelbase,track,radii){
 let x=0,z=0,yaw=0,spin=[0,0,0,0],lastV=0;const frames=[];
 for(let i=0;i<=DURATION/DT;i++){
  const t=i*DT,v=3.5*smooth(t/2)*(1-smooth((t-9)/3));
  const steer=turn?0.30*smooth((t-2)/2)*(1-smooth((t-7)/2)):0;
  const k=Math.tan(steer)/wheelbase,rate=v*k;
  const angles=[0,Math.atan2(wheelbase*k,1+track*k/2),Math.atan2(wheelbase*k,1-track*k/2),0];
  const factors=[1+track*k/2,Math.hypot(1+track*k/2,wheelbase*k),Math.hypot(1-track*k/2,wheelbase*k),1-track*k/2];
  frames.push({t,x,z,yaw,v,steer,angles,spin:[...spin],accel:(v-lastV)/DT,lateral:v*rate});lastV=v;
  const middle=yaw+rate*DT/2;x+=Math.sin(middle)*v*DT;z-=Math.cos(middle)*v*DT;yaw+=rate*DT;
  spin=spin.map((s,n)=>s+v*factors[n]*DT/radii[n]);
 }
 return frames;
}
export function sample(frames,t){const f=Math.max(0,Math.min(frames.length-1,t/DT)),i=Math.floor(f),a=frames[i],b=frames[Math.min(i+1,frames.length-1)],u=f-i;const out={};for(const key in a)out[key]=Array.isArray(a[key])?a[key].map((v,n)=>v+(b[key][n]-v)*u):a[key]+(b[key]-a[key])*u;return out;}

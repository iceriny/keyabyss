#[compute]
#version 450
// Thin condensate freezes from the crystal network; no radial reveal or atlas.
// State: filtered crystal height, film phase, branch enclosure, crystal coverage.
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(set=0,binding=0,rgba32f) uniform readonly image2D crystal;
layout(set=0,binding=1,rgba16f) uniform readonly image2D previous_surface;
layout(set=0,binding=2,rgba16f) uniform writeonly image2D next_surface;
layout(push_constant,std430) uniform Params { vec4 step; } p;
const ivec2 NEAR[6]=ivec2[6](ivec2(1,0),ivec2(-1,0),ivec2(0,1),ivec2(0,-1),ivec2(1,1),ivec2(-1,-1));
ivec2 bounded(ivec2 q){return clamp(q,ivec2(0),imageSize(crystal)-1);}
vec4 cell(ivec2 q){return imageLoad(crystal,bounded(q));}
float height(ivec2 q){vec4 s=cell(q);return s.a>0.0?s.g:0.0;}
float hash(vec2 q){vec3 v=fract(vec3(q.xyx)*.1031);v+=dot(v,v.yzx+33.33);return fract((v.x+v.y)*v.z);}
float noise(vec2 q){vec2 a=floor(q),t=fract(q);t=t*t*(3.0-2.0*t);return mix(mix(hash(a),hash(a+vec2(1,0)),t.x),mix(hash(a+vec2(0,1)),hash(a+1.0),t.x),t.y);}
float branch_enclosure(ivec2 q){
    // A film bridges a surrounding branch network. At an exposed tip, ice lies
    // mostly on one side; such a point cannot nucleate an outward film lobe.
    vec2 direction_sum=vec2(0);float hits=0.0;
    for(int i=0;i<6;i++){
        int reach=int(ceil(24.0*max(1.0,float(imageSize(crystal).x)/320.0)));
        for(int distance=1;distance<=reach;distance++){
            if(cell(q+NEAR[i]*distance).a>.5){
                vec2 axis=vec2(NEAR[i]);
                direction_sum+=vec2(axis.x-.5*axis.y,axis.y*.8660254);
                hits+=1.0;
                break;
            }
        }
    }
    if(hits<2.0) return 0.0;
    return smoothstep(.18,.66,1.0-length(direction_sum)/hits);
}
void main(){
    ivec2 q=ivec2(gl_GlobalInvocationID.xy);
    if(any(greaterThanEqual(q,imageSize(crystal)))) return;
    if(p.step.y>0.5){imageStore(next_surface,q,vec4(0));return;}
    vec4 s=cell(q);
    vec4 previous=imageLoad(previous_surface,q);
    float ice=step(.5,s.a),h=height(q)*6.0,phase=previous.g,average=0.0;
    for(int i=0;i<6;i++){
        h+=height(q+NEAR[i]);
        average+=imageLoad(previous_surface,bounded(q+NEAR[i])).g/6.0;
    }
    // A bistable front spreads only from already frozen condensate. Moisture
    // variation pins parts of the edge, avoiding a uniformly dilated silhouette.
    float lattice_scale=float(imageSize(crystal).x)/320.0;
    float moisture=.45+.55*noise(vec2(q)*.033/max(1.0,lattice_scale)+vec2(7,19));
    float threshold=mix(.25,.08,moisture);
    float mature=ice*smoothstep(220.0*lattice_scale,520.0*lattice_scale,p.step.z-s.a);
    float enclosure=p.step.w<.5?branch_enclosure(q):previous.b;
    float rate=30.0*max(1.0,lattice_scale*lattice_scale)*(average-phase)+16.0*phase*(1.0-phase)*(phase-threshold)+mature*5.0*(1.0-phase);
    // Crystal itself supplies the front; gaps bridge only inside nearby branches.
    phase=clamp(phase+rate*p.step.x,0.0,max(enclosure,ice));
    imageStore(next_surface,q,vec4(h/12.0,phase,enclosure,ice));
}

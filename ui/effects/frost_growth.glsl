#[compute]
#version 450
// Hexagonal vapor diffusion, boundary freezing and attachment.
// Algorithm reference: ibiblio.org/e-notes/webgl/snow/snowflake.htm
// State: donor weight, vapor (ice: deposited height), boundary mass, birth iteration.
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(set=0,binding=0,rgba32f) uniform readonly image2D old_state;
layout(set=0,binding=1,rgba32f) uniform writeonly image2D new_state;
layout(push_constant,std430) uniform Params { vec4 step; vec4 scale; } p;
const ivec2 NEAR[6]=ivec2[6](ivec2(1,0),ivec2(-1,0),ivec2(0,1),ivec2(0,-1),ivec2(1,1),ivec2(-1,-1));
vec4 read_cell(ivec2 q){return imageLoad(old_state,clamp(q,ivec2(0),imageSize(old_state)-1));}
float hash(vec2 q){vec3 v=fract(vec3(q.xyx)*.1031);v+=dot(v,v.yzx+33.33);return fract((v.x+v.y)*v.z);}
void main(){
    ivec2 q=ivec2(gl_GlobalInvocationID.xy), n=imageSize(old_state);
    if(any(greaterThanEqual(q,n))) return;
    int mode=int(p.step.x);
    if(mode==2){
        vec2 axial=(vec2(q)+.5)/vec2(n)-.5;
        vec2 world=vec2(axial.x-.5*axial.y,axial.y*.8660254);
        float vapor=(p.step.w+.035*(hash(vec2(q))-0.5))*(1.0-smoothstep(.28,.43,length(world)));
        bool seed=false;
        int roots=2+int(hash(vec2(p.step.z,71.0))*3.0)+int(p.scale.y);
        float rotation=hash(vec2(p.step.z,13.0))*6.2831853;
        for(int i=0;i<roots;i++){
            float angle=rotation+6.2831853*(float(i)+.3*hash(vec2(i,p.step.z)))/float(roots);
            float radius=mix(.05,.23,hash(vec2(i+9,p.step.z)));
            vec2 world_root=vec2(cos(angle),sin(angle))*radius;
            vec2 root=vec2(world_root.x+world_root.y*.5773503,world_root.y/ .8660254)+.5;
            seed=seed || all(equal(q,ivec2(root*vec2(n))));
        }
        imageStore(new_state,q,seed?vec4(0,.025,1,1):vec4(1.0/7.0,vapor,0,0));
        return;
    }
    vec4 s=read_cell(q);
    if(s.a>0.0){
        // Basal deposition is a separate, bounded visual approximation. It does
        // not recycle mass into the 2D vapor lattice (donor weight remains zero).
        float maturity=max(0.0,(p.step.y-s.a)*p.scale.x/3000.0);
        if(mode==1) s.g+=.00018*(.25+5.0*maturity*maturity)*p.step.w/.42*p.scale.x;
        imageStore(new_state,q,s); return;
    }
    if(mode==0){
        int ice=0;
        for(int i=0;i<6;i++) ice+=read_cell(q+NEAR[i]).a>0.0?1:0;
        // Each vapor donor divides its mass only between non-ice neighbors.
        s.r=1.0/float(7-ice);
    }else{
        float vapor=s.r*s.g;
        for(int i=0;i<6;i++){vec4 neighbor=read_cell(q+NEAR[i]);vapor+=neighbor.r*neighbor.g;}
        s.g=vapor;
        int ice=7-int(round(1.0/s.r));
        if(ice>0){
            float frozen=vapor*.93;
            s.b+=frozen;
            s.g-=frozen;
            float threshold=ice==3?.85:1.0;
            if(ice>3 || s.b>=threshold){s.a=p.step.y+1.0;s.r=0.0;s.g=.025;}
        }
    }
    imageStore(new_state,q,s);
}

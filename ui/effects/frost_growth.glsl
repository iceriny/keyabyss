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
// One full donor/diffusion step per dispatch. An 8x8 output tile needs two
// rings of old cells and one ring of donor weights; neighbors keep old vapor.
shared vec4 old_tile[144];
shared float donors[100];
int tile_index(ivec2 q){return q.y*12+q.x;}
int donor_index(ivec2 q){return q.y*10+q.x;}
void main(){
    ivec2 q=ivec2(gl_GlobalInvocationID.xy), n=imageSize(old_state);
    int mode=int(p.step.x);
    if(mode==2){
        if(any(greaterThanEqual(q,n))) return;
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
    ivec2 origin=ivec2(gl_WorkGroupID.xy)*8-ivec2(2);
    for(int i=int(gl_LocalInvocationIndex);i<144;i+=64){
        old_tile[i]=read_cell(origin+ivec2(i%12,i/12));
    }
    barrier();
    for(int i=int(gl_LocalInvocationIndex);i<100;i+=64){
        // The old two-pass solver clamps the donor's address, then reads that
        // real cell's neighbors. Clamp the center before offsetting neighbors.
        ivec2 center=clamp(origin+ivec2(i%10,i/10)+ivec2(1),ivec2(0),n-1)-origin;
        vec4 cell=old_tile[tile_index(center)];
        float weight=cell.r;
        if(cell.a<=0.0){
            int ice=0;
            for(int j=0;j<6;j++) ice+=old_tile[tile_index(center+NEAR[j])].a>0.0?1:0;
            weight=1.0/float(7-ice);
        }
        donors[i]=weight;
    }
    barrier();
    // Padded invocations must participate in both workgroup barriers.
    if(any(greaterThanEqual(q,n))) return;
    ivec2 local=ivec2(gl_LocalInvocationID.xy);
    ivec2 tile_at=local+ivec2(2), donor_at=local+ivec2(1);
    vec4 s=old_tile[tile_index(tile_at)];
    s.r=donors[donor_index(donor_at)];
    if(s.a>0.0){
        // Basal deposition is a separate, bounded visual approximation. It does
        // not recycle mass into the 2D vapor lattice (donor weight remains zero).
        float maturity=max(0.0,(p.step.y-s.a)*p.scale.x/3000.0);
        s.g+=.00018*(.25+5.0*maturity*maturity)*p.step.w/.42*p.scale.x;
        imageStore(new_state,q,s); return;
    }
    float vapor=s.r*s.g;
    for(int i=0;i<6;i++){
        vec4 neighbor=old_tile[tile_index(tile_at+NEAR[i])];
        neighbor.r=donors[donor_index(donor_at+NEAR[i])];
        vapor+=neighbor.r*neighbor.g;
    }
    s.g=vapor;
    int ice=7-int(round(1.0/s.r));
    if(ice>0){
        float frozen=vapor*.93;
        s.b+=frozen;
        s.g-=frozen;
        float threshold=ice==3?.85:1.0;
        if(ice>3 || s.b>=threshold){s.a=p.step.y+1.0;s.r=0.0;s.g=.025;}
    }
    imageStore(new_state,q,s);
}

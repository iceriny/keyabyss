#[compute]
#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(set=0,binding=0) uniform sampler2D previous_state;
layout(set=0,binding=1,rgba16f) uniform writeonly image2D next_state;
layout(set=0,binding=2) uniform sampler2D velocity_field;
struct Source { vec4 segment; vec4 fuel; };
layout(set=0,binding=3,std430) readonly buffer Sources { Source items[]; } sources;
layout(push_constant,std430) uniform Params {
    vec4 domain; // world size, dt, clock
    vec4 control; // source count
} p;
float hash(vec2 x) { return fract(sin(dot(x,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 x) {
    vec2 i=floor(x), f=fract(x); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);
}
void main() {
    ivec2 q=ivec2(gl_GlobalInvocationID.xy), n=imageSize(next_state);
    if(any(greaterThanEqual(q,n))) return;
    vec2 uv=(vec2(q)+0.5)/vec2(n), at=uv*p.domain.xy;
    // Quality changes resample concentrations once, without replaying ignition.
    if(p.control.x < 0.0) {
        imageStore(next_state,q,texture(previous_state,uv));
        return;
    }
    float dt=p.domain.z, time=p.domain.w;
    vec2 v=texture(velocity_field,uv).xy;
    vec2 mid=uv-v*dt*0.5/p.domain.xy;
    v=texture(velocity_field,mid).xy;
    vec4 s=texture(previous_state,uv-v*dt/p.domain.xy);
    // Fuel, heat and soot are concentrations, not paint carried at constant
    // opacity. The projected flow includes blast expansion: dilute all three
    // with its local divergence so a hot pocket cannot stretch into a solid sheet.
    vec2 texel=1.0/vec2(textureSize(velocity_field,0));
    vec2 spacing=texel*p.domain.xy;
    float divergence=(texture(velocity_field,mid+vec2(texel.x,0)).x
                     -texture(velocity_field,mid-vec2(texel.x,0)).x)/(2.0*spacing.x)
                    +(texture(velocity_field,mid+vec2(0,texel.y)).y
                     -texture(velocity_field,mid-vec2(0,texel.y)).y)/(2.0*spacing.y);
    s*=exp(-max(divergence,0.0)*dt);
    // A horizontal patch of many unequal fuel pockets, with no screen-up axis.
    float pockets=noise(at/47.0+vec2(sin(time*.8),cos(time*.67))*.55);
    pockets=mix(pockets,noise(at/19.0+vec2(cos(time),sin(time))*.4),.27);
    float supply=0.0;
    for(int i=0;i<int(p.control.x);i++){
        Source source=sources.items[i];
        vec2 axis=source.segment.zw-source.segment.xy;
        float along=clamp(dot(at-source.segment.xy,axis)/max(dot(axis,axis),.001),0.0,1.0);
        vec2 local=(at-mix(source.segment.xy,source.segment.zw,along))/source.fuel.x;
        supply+=exp(-dot(local,local)*2.7)*source.fuel.y;
    }
    float feed=smoothstep(.33,.72,pockets)*min(supply,1.5);
    s.r=min(1.5,s.r+feed*dt*3.5);
    s.g+=feed*dt*.45;
    float burned=s.r*(1.0-exp(-dt*4.0))*smoothstep(.025,.16,s.g);
    s.r-=burned;
    s.g=max(0.0,s.g+burned*2.8-dt*(.6*s.g+.85*s.g*s.g));
    s.b=s.b*exp(-dt*1.6)+burned*.1;
    s.a=burned/max(dt,.001);
    float edge=smoothstep(0.0,.025,min(min(uv.x,uv.y),min(1.0-uv.x,1.0-uv.y)));
    imageStore(next_state,q,max(s,vec4(0))*edge);
}

shader_type canvas_item;
uniform sampler2D crystal_surface : filter_linear,repeat_disable;
uniform sampler2D microstructure : filter_linear_mipmap,repeat_disable;
uniform sampler2D film_structure : filter_linear_mipmap,repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture,filter_linear_mipmap,repeat_disable;
uniform bool show_film=true;
uniform float patch_size=610.0;
uniform float fade=1.0;
uniform float refraction=1.0;
uniform float lattice_angle=0.0;
varying float crystal_body;
varying float material_coverage;
varying float micro_roughness;
varying float frost_grains;
varying float film_body;
varying float facet_variance;
vec4 growth_surface(vec2 uv){
    vec2 p=uv-.5;
    p=mat2(vec2(cos(lattice_angle),-sin(lattice_angle)),vec2(sin(lattice_angle),cos(lattice_angle)))*p;
    // Undo the axial lattice shear; six crystal directions stay 60 degrees apart.
    vec2 q=vec2(p.x+p.y/.8660254*.5,p.y/.8660254)+.5;
    vec4 s=texture(crystal_surface,clamp(q,vec2(0),vec2(1)));
    s*=step(0.0,q.x)*step(q.x,1.0)*step(0.0,q.y)*step(q.y,1.0);
    if(!show_film) s.gb=vec2(0);
    return s;
}
vec2 surface_uv(vec2 uv){
    // Displace only the exposed front; retain the existing interior relief.
    // Height and coverage share this sample, so light follows the broken edge.
    vec4 s=growth_surface(uv);
    float exposed=1.0-smoothstep(.55,.95,max(s.a,s.g));
    vec2 at=uv*.82+.09;
    vec2 grain=vec2(texture(film_structure,at).r,
                    texture(film_structure,vec2(1.0-at.y,at.x)).r)-vec2(.46);
    return uv+grain*.045*exposed;
}
float frost_density(vec2 uv,vec4 center){
    // Follow the actual branch network, including its gaps, rather than a
    // circular fade. A narrow neighborhood gives the front room to disperse.
    float density=max(center.a,center.g)*2.0;
    float reach=clamp(patch_size*.035,3.0,36.0)/patch_size;
    for(int i=0;i<8;i++){
        float angle=float(i)*.78539816;
        vec4 neighbor=growth_surface(uv+vec2(cos(angle),sin(angle))*reach);
        density+=max(neighbor.a,neighbor.g);
    }
    return density*.1;
}
vec2 micro_detail(vec2 uv,vec2 tangent){
    // Blend three fixed fields along the lattice's three unoriented axes.
    // The ridge tangent picks their weights, so detail follows the branch rather
    // than swimming under a per-pixel rotated UV. All samples stay inside the map.
    const vec2 AXES[3]=vec2[3](vec2(1,0),vec2(.5,.8660254),vec2(-.5,.8660254));
    vec2 result=vec2(0);float total=0.0;
    for(int i=0;i<3;i++){
        float weight=pow(abs(dot(tangent,AXES[i])),8.0)+.015;
        float angle=float(i)*1.04719755+.78539816;
        mat2 rotation=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)));
        vec2 at=rotation*(uv-.5)*.66+.5;
        result+=weight*vec2(texture(microstructure,at).r,textureLod(microstructure,at,3.0).r);
        total+=weight;
    }
    return result/total;
}
vec3 film_detail(vec2 uv,float phase){
    vec2 at=uv*.82+.09;
    float fine=texture(film_structure,at).r;
    float broad=textureLod(film_structure,at,3.0).r;
    // Texture shapes the front as well as the interior. The phase remains the
    // growth clock: no isolated islands can appear before the freezing front.
    float breakup=clamp((fine-.46)*4.0+(broad-.46)*6.0,-1.0,1.0);
    float threshold=.44+breakup*.32;
    float front=phase-threshold;
    float footprint=max(.012,fwidth(front)*.75);
    float mask=smoothstep(-footprint,footprint,front);
    float thickness=max(.12,.8+(broad-.46)*3.0+(fine-broad)*.45)*mask;
    return vec3(mask,thickness,fine);
}
float height_at(vec2 uv){
    vec4 s=growth_surface(uv);
    vec3 film=film_detail(uv,s.g);
    return s.r*7.0+film.y;
}
void fragment() {
    vec2 at=surface_uv(UV);
    vec4 s=growth_surface(at);
    vec3 film=film_detail(UV,s.g);
    // Smooth deposited height preserves the original rounded crystal body.
    // Sample at the display footprint instead of a fixed low-resolution grid.
    vec2 px=max(fwidth(UV),vec2(.5)/vec2(textureSize(crystal_surface,0)));
    vec2 slope=vec2(height_at(at+vec2(px.x,0))-height_at(at-vec2(px.x,0)),
                    height_at(at+vec2(0,px.y))-height_at(at-vec2(0,px.y)))/(2.0*patch_size*px);
    vec3 face_normal=normalize(vec3(-slope,1.0));
    facet_variance=dot(dFdx(face_normal),dFdx(face_normal))+dot(dFdy(face_normal),dFdy(face_normal));
    vec2 tangent=normalize(vec2(-slope.y,slope.x)+vec2(.0001));
    vec2 detail=micro_detail(UV,tangent);
    float edge=s.a-(.5+(detail.y-detail.x)*1.4);
    float footprint=max(.025,fwidth(edge)*.65);
    float coverage=smoothstep(-footprint,footprint,edge);
    // Full ice becomes broken clusters, then only the texture's isolated
    // brightest grains survive. Both the film and crystal obey this mask.
    float density=frost_density(UV,s);
    float support=smoothstep(.025,.24,density);
    float threshold=mix(.64,.16,pow(smoothstep(.04,.95,density),1.8));
    float grain_width=max(.008,fwidth(detail.x)*.65);
    float grains_mask=smoothstep(threshold-grain_width,threshold+grain_width,detail.x);
    grains_mask=mix(grains_mask,1.0,smoothstep(.8,.98,density));
    grains_mask*=support;
    float fringe=(1.0-smoothstep(.2,.65,density))*support*grains_mask*.5;
    coverage=max(coverage*grains_mask,fringe);
    film.xy*=grains_mask;
    crystal_body=clamp(s.r*1.8,0.0,1.0);
    film_body=film.x;
    frost_grains=smoothstep(.26,.61,detail.x)*max(coverage,film.x*.7);
    micro_roughness=clamp(detail.y*1.3,0.0,1.0);
    float relief=(detail.x-detail.y)*2.2*max(coverage,film.x*.65);
    slope+=vec2(dFdx(relief),dFdy(relief));
    NORMAL=normalize(vec3(-slope,1.0));
    material_coverage=max(coverage,film.x*.90)*fade;
    vec3 transmitted=textureLod(screen_texture,SCREEN_UV-NORMAL.xy*SCREEN_PIXEL_SIZE*(1.0+s.r*5.0)*refraction,0.0).rgb;
    // Film detail remains readable without specular lighting: translucent grain
    // density and fine frost are carried across the whole frozen surface.
    vec3 absorption=exp(-vec3(.32,.17,.09)*(s.r+film.y*.12));
    float grains=smoothstep(.48,.67,film.z);
    vec3 scattering=vec3(.24,.34,.39)*(.09*crystal_body+frost_grains*.55+film.x*(.012+grains*.09));
    COLOR=vec4(transmitted*absorption+scattering,material_coverage*.95);
}
void light() {
    vec3 half_vector=normalize(LIGHT_DIRECTION+vec3(0,0,1));
    float diffuse=max(dot(NORMAL,LIGHT_DIRECTION),0.0);
    float facing=max(dot(NORMAL,half_vector),0.0);
    float sharpness=mix(145.0,58.0,micro_roughness);
    float filtered_sharpness=1.0/(1.0/sharpness+min(facet_variance,.08)*.3);
    float specular=pow(facing,filtered_sharpness)*filtered_sharpness/sharpness;
    float fresnel=.035+.965*pow(1.0-max(dot(half_vector,vec3(0,0,1)),0.0),5.0);
    vec3 reflected=vec3(specular*fresnel*16.0)+vec3(.16,.23,.28)*diffuse*(.08*crystal_body+frost_grains*.5+film_body*.08);
    LIGHT=vec4(LIGHT_COLOR.rgb*LIGHT_ENERGY*reflected*material_coverage,LIGHT_COLOR.a);
}

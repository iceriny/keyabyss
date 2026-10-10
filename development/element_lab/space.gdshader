shader_type canvas_item;
uniform vec2 extent=vec2(1600,900);
uniform sampler2D paper_noise : filter_linear,repeat_enable;
void fragment(){
    float cloud=texture(paper_noise,UV*vec2(1.6,.9)).r;
    float vignette=1.0-smoothstep(.22,.8,length((UV-.5)*vec2(1.25,1)));
    vec3 base=mix(vec3(.008,.015,.018),vec3(.019,.030,.033),cloud)*(.6+vignette*.4);
    COLOR=vec4(base,1);
    NORMAL=normalize(vec3(-dFdx(cloud)*3.0,-dFdy(cloud)*3.0,1));
}

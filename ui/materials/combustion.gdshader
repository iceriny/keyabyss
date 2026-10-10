shader_type canvas_item;
render_mode unshaded,blend_premul_alpha;
uniform sampler2D combustion : filter_linear,repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture,filter_linear,repeat_disable;
// All battle fire reads one chemistry layer in the shared world domain.
void fragment() {
    vec4 gas=texture(combustion,UV);
    float temperature=gas.g;
    float heat=clamp(temperature/3.0,0.0,1.0);
    float energy=heat*heat*.9+pow(heat,12.0)*12.0;
    // Cooling gas becomes transparent; it does not retain a dark red silhouette.
    energy*=smoothstep(.35,1.05,temperature);
    vec3 warm=vec3(1.0,.035+heat*heat*.75,.004+pow(heat,5.0)*.45);
    warm=mix(warm,vec3(1.0,.94,.8),smoothstep(.8,1.0,heat));
    // Emission comes from hot reacting gas; soot coverage remains separate.
    float alpha=(1.0-exp(-gas.b*2.0))*.3;
    vec2 normal=vec2(dFdx(temperature),dFdy(temperature));
    vec2 offset=clamp(normal*12.0,vec2(-2),vec2(2))*SCREEN_PIXEL_SIZE;
    float refraction=smoothstep(.25,.65,temperature)*.16;
    vec3 behind=texture(screen_texture,SCREEN_UV+offset).rgb;
    COLOR=vec4(warm*energy+behind*refraction+vec3(.08,.06,.045)*alpha,
               clamp(alpha+refraction,0.0,1.0));
}

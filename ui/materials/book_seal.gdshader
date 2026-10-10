shader_type canvas_item;
render_mode unshaded;

uniform vec4 tint : source_color = vec4(.55,.85,1.0,1.0);
uniform float clock = 0.0;
uniform float strength = 1.0;
uniform float recession = 0.0;
varying vec4 modulation;

void vertex() {
    modulation = COLOR;
}

void fragment() {
    float ink = texture(TEXTURE, UV).a;
    vec2 texel = TEXTURE_PIXEL_SIZE * 3.0;
    float halo = 0.0;
    for (int i = 0; i < 8; i++) {
        float angle = float(i) * .78539816;
        vec2 offset = vec2(cos(angle),sin(angle)) * texel;
        halo += texture(TEXTURE, UV + offset).a * .085;
        halo += texture(TEXTURE, UV + offset * 2.6).a * .04;
    }
    vec2 p = UV - .5;
    float angle = atan(p.y,p.x);
    float flow = pow(.5+.5*sin(angle*2.0-length(p)*16.0-clock*.85), 5.0);
    float light = .65 + flow * 1.65;
    // Recessed battle seals keep the outer inscription nearer and clearer;
    // inner connections recede into a dimmer, softer layer.
    float near_layer = smoothstep(.13,.46,length(p))*(.8+.2*cos(angle-.8));
    float depth = recession*(1.0-near_layer);
    float core = mix(ink,halo,.6*depth);
    float alpha = clamp(core*.85+halo*.7,0.0,1.0)*strength*(1.0-.6*depth);
    COLOR = vec4(tint.rgb*(1.25+light*1.8),alpha*tint.a) * modulation;
}

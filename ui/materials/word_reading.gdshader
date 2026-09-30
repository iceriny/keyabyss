shader_type canvas_item;
render_mode unshaded;

uniform vec2 canvas_size = vec2(194.0, 52.0);
uniform float word_line_y = 32.0;
uniform float selection = 0.0;
uniform float cursor_start = 0.0;
uniform float cursor_width = 0.0;
uniform vec4 shade : source_color = vec4(0.024, 0.059, 0.094, 1.0);
uniform vec4 idle_rule : source_color = vec4(0.62, 0.75, 0.74, 1.0);
uniform vec4 active_rule : source_color = vec4(0.86, 0.78, 0.58, 1.0);

void fragment() {
	vec2 p = UV*canvas_size-vec2(12.0,9.0);
	vec2 q = (UV-0.5)*2.0;
	float feather = pow(max(0.0,1.0-dot(q,q)),2.0);
	float ends = pow(max(0.0,1.0-q.x*q.x),3.0);
	float line = exp(-pow((p.y-word_line_y)/max(0.5,fwidth(p.y)*0.6),2.0))*ends;
	float cursor = smoothstep(cursor_start-0.5,cursor_start+0.5,p.x)*(1.0-smoothstep(cursor_start+cursor_width-0.5,cursor_start+cursor_width+0.5,p.x));
	float rule_alpha = line*mix(0.25,0.55,selection);
	rule_alpha = max(rule_alpha,line*cursor*step(0.1,cursor_width)*0.85);
	float shade_alpha = feather*mix(0.30,0.46,selection);
	float alpha = rule_alpha+shade_alpha*(1.0-rule_alpha);
	vec3 rgb = mix(idle_rule.rgb,active_rule.rgb,selection)*rule_alpha+shade.rgb*shade_alpha*(1.0-rule_alpha);
	COLOR *= vec4(rgb/max(alpha,0.00001),alpha);
}

// Isotropic turbulence for volume effects; crystal microstructure comes from a texture.
float element_hash(vec2 p) {
	vec3 v=fract(vec3(p.xyx)*0.1031);
	v+=dot(v,v.yzx+33.33);
	return fract((v.x+v.y)*v.z);
}
float element_noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(element_hash(i),element_hash(i+vec2(1,0)),f.x),mix(element_hash(i+vec2(0,1)),element_hash(i+vec2(1)),f.x),f.y);
}
float element_fbm(vec2 p) {
	mat2 turn=mat2(vec2(0.8,0.6),vec2(-0.6,0.8));
	return element_noise(p)*0.55+element_noise(turn*p*2.1+17.0)*0.29+element_noise(p*4.5+3.0)*0.16;
}

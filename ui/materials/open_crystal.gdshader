shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
#include "res://ui/materials/open_crystal_optics.gdshaderinc"

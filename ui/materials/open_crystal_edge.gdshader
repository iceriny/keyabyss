shader_type canvas_item;
render_mode unshaded;
// Directly sample the existing HDR stage. No extra battle/menu screen capture.
uniform sampler2D screen_tex : repeat_disable, filter_linear;
#define CRYSTAL_SCENE_SOURCE
#include "res://ui/materials/open_crystal_optics.gdshaderinc"

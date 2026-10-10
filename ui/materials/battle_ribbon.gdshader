shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://ui/materials/soft_shapes.gdshaderinc"

void fragment() {
	float across = UV.y * 2.0 - 1.0;
	// Geometry is three times the optical width, leaving room for subpixel coverage.
	float profile = soft_gaussian_line(across, 1.0 / sqrt(45.0));
	profile *= 1.0 - smoothstep(0.65, 1.0, abs(across));
	COLOR.a *= profile;
}

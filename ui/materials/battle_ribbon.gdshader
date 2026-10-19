shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://ui/materials/soft_shapes.gdshaderinc"
uniform bool physical_width = false;
uniform vec2 taper_pivot = vec2(0.0);

void fragment() {
	float across = physical_width ? UV.y / UV.x : UV.y * 2.0 - 1.0;
	if (!physical_width && taper_pivot.x > 0.0) {
		// Constant-width Line2D geometry prevents tapered triangles from pulling
		// normalized transverse UVs off the centerline at every physics sample.
		float taper = UV.x < taper_pivot.x
			? taper_pivot.y * smoothstep(0.0, taper_pivot.x, UV.x)
			: mix(taper_pivot.y, 1.0, smoothstep(taper_pivot.x, 1.0, UV.x));
		across /= max(taper, 0.001);
	}
	// Geometry is three times the optical width, leaving room for subpixel coverage.
	float profile = soft_gaussian_line(across, 1.0 / sqrt(45.0));
	profile *= 1.0 - smoothstep(0.65, 1.0, abs(across));
	COLOR.a *= profile;
}

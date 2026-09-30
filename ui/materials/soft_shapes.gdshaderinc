// Distances and widths use the caller's coordinate space.
float soft_gaussian(float distance, float width) {
	float x = distance / width;
	return exp(-x * x);
}

float soft_gaussian_line(float distance, float width) {
	// Filter a signed field, before abs/pow can erase its pixel derivatives.
	float pixel = length(vec2(dFdx(distance), dFdy(distance)));
	float filtered_width = sqrt(width * width + pixel * pixel * 0.5);
	return soft_gaussian(distance, filtered_width) * width / filtered_width;
}

float soft_exponential_line(float distance, float width) {
	// Integral of the exponential profile over the pixel's projected footprint.
	float half_pixel = max(length(vec2(dFdx(distance), dFdy(distance))) * 0.707107, width * 0.001);
	vec2 ends = vec2(distance - half_pixel, distance + half_pixel);
	vec2 primitive = sign(ends) * width * (1.0 - exp(-abs(ends) / width));
	return (primitive.y - primitive.x) / (2.0 * half_pixel);
}

float soft_fill(float signed_distance, float minimum_width, float pixel_scale) {
	float aa = max(fwidth(signed_distance) * pixel_scale, minimum_width);
	return 1.0 - smoothstep(-aa, aa, signed_distance);
}

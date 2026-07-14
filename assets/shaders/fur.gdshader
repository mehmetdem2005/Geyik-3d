shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.42, 0.24, 0.11, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.16, 0.08, 0.035, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;

float hash21(vec2 point) {
	point = fract(point * vec2(234.34, 435.345));
	point += dot(point, point + 34.23);
	return fract(point.x * point.y);
}

void fragment() {
	float coarse = hash21(floor(UV * vec2(130.0, 210.0)));
	float fine = hash21(floor(UV * vec2(510.0, 760.0)));
	float strand = pow(abs(sin(UV.y * 740.0 + coarse * 3.0)), 7.0);
	vec3 color = mix(shadow_color.rgb, base_color.rgb, 0.70 + coarse * 0.22);
	ALBEDO = color * (0.94 + fine * 0.06 + strand * 0.05);
	ROUGHNESS = roughness_value;
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 light_wood : source_color = vec4(0.32, 0.13, 0.055, 1.0);
uniform vec4 dark_wood : source_color = vec4(0.075, 0.025, 0.012, 1.0);

float hash21(vec2 point) {
	point = fract(point * vec2(127.1, 311.7));
	point += dot(point, point + 19.19);
	return fract(point.x * point.y);
}

void fragment() {
	float distortion = hash21(floor(UV * vec2(22.0, 72.0))) * 0.36;
	float grain = 0.5 + 0.5 * sin((UV.y * 54.0 + distortion + sin(UV.x * 10.0)) * 3.14159);
	grain = smoothstep(0.15, 0.92, grain);
	ALBEDO = mix(dark_wood.rgb, light_wood.rgb, 0.28 + grain * 0.72);
	ROUGHNESS = 0.48 + grain * 0.16;
}

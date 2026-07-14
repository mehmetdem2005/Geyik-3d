shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.10, 0.35, 0.34, 0.78);
uniform vec4 deep_color : source_color = vec4(0.025, 0.13, 0.18, 0.86);

varying float wave_light;

void vertex() {
	float wave_a = sin(VERTEX.z * 0.29 + TIME * 1.45);
	float wave_b = cos(VERTEX.x * 0.43 - TIME * 1.12);
	VERTEX.y += (wave_a + wave_b) * 0.055;
	wave_light = wave_a * 0.5 + wave_b * 0.5;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(shallow_color.rgb, deep_color.rgb, 0.34 + fresnel * 0.46 - wave_light * 0.04);
	METALLIC = 0.05;
	ROUGHNESS = mix(0.16, 0.06, fresnel);
	ALPHA = mix(shallow_color.a, deep_color.a, fresnel);
}

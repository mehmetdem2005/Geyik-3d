shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 root_color : source_color = vec4(0.08, 0.20, 0.06, 1.0);
uniform vec4 tip_color : source_color = vec4(0.32, 0.46, 0.15, 1.0);

varying float blade_height;

void vertex() {
	blade_height = UV.y;
	float phase = MODEL_MATRIX[3].x * 0.19 + MODEL_MATRIX[3].z * 0.15;
	float sway = sin(TIME * 1.35 + phase) * 0.045 * UV.y * UV.y;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.37;
}

void fragment() {
	ALBEDO = mix(root_color.rgb, tip_color.rgb, blade_height);
	ROUGHNESS = 0.98;
}

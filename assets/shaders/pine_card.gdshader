shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.28;

void vertex() {
	float phase = MODEL_MATRIX[3].x * 0.087 + MODEL_MATRIX[3].z * 0.069;
	float crown_weight = smoothstep(0.04, 0.98, UV.y);
	VERTEX.x += sin(TIME * 0.75 + phase + VERTEX.y * 0.4) * 0.028 * crown_weight;
}

void fragment() {
	vec4 base = texture(albedo_texture, UV);
	if (base.a < alpha_cutoff) {
		discard;
	}
	ALBEDO = base.rgb;
	ROUGHNESS = 0.88;
	ALPHA = base.a;
}

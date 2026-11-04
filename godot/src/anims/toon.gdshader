shader_type spatial;

// S35: fighters drawn, not rendered: two tones (lit / cool shadow) from the
// sun, the albedo flat (loom texture times the material colour). The
// outline is a second pass (toon_outline.gdshader). toon.gd sets it up.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_tex = false;
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.56, 0.76);
uniform float threshold = 0.05;
uniform float softness = 0.03;

void fragment() {
	vec4 c = albedo;
	if (has_tex) {
		c *= texture(albedo_tex, UV);
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// cast shadows cut as hard as the terminator: soft shadow maps read as dirt
	float lit = smoothstep(threshold - softness, threshold + softness, ndl) * step(0.5, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint * 0.5, vec3(1.0), lit);
}

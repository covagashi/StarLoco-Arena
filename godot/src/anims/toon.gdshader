shader_type spatial;

// S35: fighters drawn, not rendered: two tones (lit / cool shadow) from the
// sun, the albedo flat (loom texture times the material colour). The
// outline is a second pass (toon_outline.gdshader). toon.gd sets it up.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_tex = false;
// Meshy coaches (tools/art/coach_masks.py): one baked texture, so skin and
// hair are a mask (R skin, G hair). A masked texel takes the tint at the
// texel's brightness over the mask's bright colour (its 80th percentile),
// capped so a baked highlight doesn't wash the tint out to white.
uniform sampler2D mask_tex : hint_default_black, filter_linear;
uniform bool has_mask = false;
uniform bool tint_skin = false;
uniform bool tint_hair = false;
uniform vec4 skin_tint : source_color = vec4(1.0);
uniform vec4 hair_tint : source_color = vec4(1.0);
uniform float skin_ref = 1.0;
uniform float hair_ref = 1.0;
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.56, 0.76);
uniform float threshold = 0.05;
uniform float softness = 0.03;

void fragment() {
	vec4 c = albedo;
	if (has_tex) {
		c *= texture(albedo_tex, UV);
	}
	if (has_mask) {
		vec2 m = texture(mask_tex, UV).rg;
		float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		if (tint_skin) {
			c.rgb = mix(c.rgb, skin_tint.rgb * min(lum / skin_ref, 1.1), m.r);
		}
		if (tint_hair) {
			c.rgb = mix(c.rgb, hair_tint.rgb * min(lum / hair_ref, 1.1), m.g);
		}
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

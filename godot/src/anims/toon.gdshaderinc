// S35: the toon body (toon.gdshader includes it; toon_cut.gdshader too,
// with CUT defined: a coach's mark, cut by its texture's alpha).

// S35: fighters drawn, not rendered: two tones (lit / cool shadow) from the
// sun, the albedo flat (loom texture times the material colour). The
// outline is a second pass (toon_outline.gdshader). toon.gd sets it up.

uniform vec4 albedo : source_color = vec4(1.0);
#ifdef CUT
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;   // an emblem, once
#else
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
#endif
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
// S37: a few garments are alive (Fighter3D.LIVE, toon.gd sets these; 0 =
// off for everything else). jelly: metres the surface trembles along its
// normal (gelatina); shine: a glint sweeping over the gold texels
// (Superjefe); flame: the flame flickers and glows (Aurea flamma).
uniform float jelly = 0.0;
uniform float shine = 0.0;
uniform float flame = 0.0;
varying vec3 world_pos;

#include "res://src/anims/live.gdshaderinc"

void vertex() {
	if (jelly > 0.0) {
		VERTEX += NORMAL * jelly * jelly_wave(VERTEX, TIME);
	}
	if (flame > 0.0) {
		VERTEX = flame_flicker(VERTEX, TIME, flame);
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

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
	if (shine > 0.0) {
		// gold = warm and saturated: the band only lights those texels
		float gold = clamp((min(c.r, c.g) - c.b) * 2.5, 0.0, 1.0);
		float sweep = fract(TIME * 0.35 - dot(world_pos, vec3(0.9, 1.4, 0.0)));
		float band = 1.0 - smoothstep(0.0, 0.05, abs(sweep - 0.5));
		EMISSION = vec3(1.0, 0.9, 0.62) * band * gold * shine;
	}
	if (flame > 0.0) {
		EMISSION = c.rgb * flame * (0.8 + 0.4 * sin(TIME * 17.0) * sin(TIME * 5.3));
	}
#ifdef CUT
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// cast shadows cut as hard as the terminator: soft shadow maps read as dirt
	float lit = smoothstep(threshold - softness, threshold + softness, ndl) * step(0.5, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint * 0.5, vec3(1.0), lit);
}

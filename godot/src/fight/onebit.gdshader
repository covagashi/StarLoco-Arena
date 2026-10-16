// 1-bit fight-map filter (sprints/S04): the retail art underneath is turned
// into ink/paper with an 8x8 Bayer threshold, and a light map decides how much
// of it survives the dark. A pixel shows paper only when
//     tone(art) * light  >  bayer(x, y)
// so darkness is literally a pixel pattern, and every light opens it up.
//
// Lives on a ColorRect that covers the screen, in a CanvasLayer above the map
// and below the HUD, so the HUD and tactical overlays stay readable.
//
// The retail art was painted for colour, not for 1 bit: its greens and browns
// sit in the same mid-grey band, so a plain threshold melts them into one even
// pattern. Three knobs fight that: levels (black/white point) to stretch the
// tones, posterize to flatten them into bands, and ink edges traced where the
// COLOUR changes, which keeps shapes that luminance alone loses.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// Same screen, mipmapped: a cheap local average for the detail boost below.
uniform sampler2D screen_blur : hint_screen_texture, filter_linear_mipmap;

// Size of one dither cell in screen pixels. The retail art is painted at full
// resolution; at 1 px the pattern turns to noise, so it is sampled coarser.
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 2.0;

// Tone curve applied to the art before thresholding.
uniform float black_point : hint_range(0.0, 1.0) = 0.0;
uniform float white_point : hint_range(0.0, 1.0) = 1.0;
uniform float gamma : hint_range(0.1, 4.0) = 1.0;
// Local contrast: tone = local_mean + (tone - local_mean) * detail. The local
// mean is the screen's mip level detail_radius (each level halves resolution).
// 1 = off. Brings out the cracks and seams the painted art keeps faint.
uniform float detail : hint_range(0.0, 8.0) = 1.0;
uniform float detail_radius : hint_range(0.0, 6.0) = 3.0;
// 0 = continuous tone; N >= 2 = quantize to N bands before dithering.
uniform int levels = 0;

// Ink outlines where neighbouring colours differ by more than edge_threshold
// (RGB distance, 0..1.7). 0 strength = off.
uniform float edge_strength : hint_range(0.0, 1.0) = 0.0;
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.25;

// Light map: ambient everywhere, plus up to 16 radial lights.
// lights[i] = (x, y, radius, intensity), x/y/radius in screen pixels.
uniform float ambient : hint_range(0.0, 1.0) = 1.0;
uniform int light_count = 0;
uniform vec4 lights[16];
uniform float light_falloff : hint_range(0.1, 8.0) = 1.5;

// The map underneath is already 1-bit, converted texture by texture
// (tools/asset-import/onebit.py). Then this shader only lays the darkness
// over it, Glagstone-style: a world pixel survives where light > bayer, and
// is ink otherwise. Pixels that are not pure ink/paper (live actors, effects)
// are thresholded by their own luminance on the same pattern.
uniform bool world_onebit = false;

// 0 = the result; 1 = the art exactly as the shader samples it; 2 = the tone
// after levels/posterize; 3 = the darkness pattern alone (paper where
// light > bayer); 4 = the light map in grey. For tuning and the layer sheets.
uniform int debug_view = 0;

uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 paper : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Classic 8x8 ordered-dither matrix, built by bit interleaving: 0..63.
int bayer8(ivec2 p) {
	int x = p.x & 7;
	int y = p.y & 7;
	int xy = x ^ y;
	return ((xy & 1) << 5) | ((y & 1) << 4) | ((xy & 2) << 2)
		| ((y & 2) << 1) | ((xy & 4) >> 1) | ((y & 4) >> 2);
}

vec3 art_at(vec2 px, vec2 texel) {
	return texture(screen_tex, px * texel).rgb;
}

void fragment() {
	vec2 texel = SCREEN_PIXEL_SIZE;
	vec2 screen_px = SCREEN_UV / texel;
	vec2 cell = floor(screen_px / pixel_size);
	vec2 center_px = (cell + 0.5) * pixel_size;
	vec3 art = art_at(center_px, texel);

	float tone = dot(art, vec3(0.2126, 0.7152, 0.0722));
	if (detail != 1.0) {
		vec3 near = textureLod(screen_blur, center_px * texel, detail_radius).rgb;
		float mean = dot(near, vec3(0.2126, 0.7152, 0.0722));
		tone = mean + (tone - mean) * detail;
	}
	tone = clamp((tone - black_point) / max(white_point - black_point, 0.001), 0.0, 1.0);
	tone = pow(tone, gamma);
	if (levels >= 2) {
		float n = float(levels - 1);
		tone = floor(tone * n + 0.5) / n;
	}

	float light = ambient;
	for (int i = 0; i < light_count && i < 16; i++) {
		vec4 l = lights[i];
		float d = distance(center_px, l.xy) / max(l.z, 1.0);
		light += l.w * pow(clamp(1.0 - d, 0.0, 1.0), light_falloff);
	}
	light = clamp(light, 0.0, 1.0);

	float threshold = (float(bayer8(ivec2(cell))) + 0.5) / 64.0;
	bool lit = tone * light > threshold;
	if (world_onebit) {
		// The art is already at its own pixel grid: read the exact screen
		// pixel, never the dither cell's centre, or pixel_size > 1 smears it.
		vec3 own = texture(screen_tex, SCREEN_UV).rgb;
		float raw = dot(own, vec3(0.2126, 0.7152, 0.0722));
		lit = raw > threshold && light > threshold;
	}

	if (edge_strength > 0.0) {
		float step_px = pixel_size;
		float diff = 0.0;
		diff = max(diff, distance(art, art_at(center_px + vec2(step_px, 0.0), texel)));
		diff = max(diff, distance(art, art_at(center_px + vec2(0.0, step_px), texel)));
		diff = max(diff, distance(art, art_at(center_px - vec2(step_px, 0.0), texel)));
		diff = max(diff, distance(art, art_at(center_px - vec2(0.0, step_px), texel)));
		// Edges fade with the light too: in the dark they go first.
		if (diff > edge_threshold && light * edge_strength > threshold) {
			lit = false;
		}
	}

	COLOR = lit ? paper : ink;
	if (debug_view == 1) {
		COLOR = vec4(art, 1.0);
	} else if (debug_view == 2) {
		COLOR = vec4(vec3(tone), 1.0);
	} else if (debug_view == 3) {
		COLOR = light > threshold ? paper : ink;
	} else if (debug_view == 4) {
		COLOR = vec4(vec3(light), 1.0);
	}
}

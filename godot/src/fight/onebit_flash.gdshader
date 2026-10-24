// 1-bit light beat (sprints/S04): for an instant the day world dims to an
// 8x8 Bayer pattern of ink, and only a pool of light at the impact stays
// clear — the Glagstone darkness, as a punctual effect, never a dark fight.
// Draws ink dots only (no screen read), so the colours underneath — team
// auras, tactical marks — stay untouched wherever the light reaches.
shader_type canvas_item;

uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec2 light_pos = vec2(0.0);      // screen pixels
uniform float light_radius = 140.0;      // screen pixels
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const int BAYER[64] = int[64](0, 32, 8, 40, 2, 34, 10, 42, 48, 16, 56, 24, 50, 18, 58, 26,
	12, 44, 4, 36, 14, 46, 6, 38, 60, 28, 52, 20, 62, 30, 54, 22,
	3, 35, 11, 43, 1, 33, 9, 41, 51, 19, 59, 27, 49, 17, 57, 25,
	15, 47, 7, 39, 13, 45, 5, 37, 63, 31, 55, 23, 61, 29, 53, 21);

void fragment() {
	ivec2 p = ivec2(floor(FRAGCOORD.xy)) % 8;
	float threshold = (float(BAYER[p.y * 8 + p.x]) + 0.5) / 64.0;
	float d = distance(FRAGCOORD.xy, light_pos) / max(light_radius, 1.0);
	float light = clamp(1.0 - d * d, 0.0, 1.0);
	COLOR = darkness * (1.0 - light) > threshold ? ink : vec4(0.0);
}

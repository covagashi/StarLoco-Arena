// S37: the motion of the live garments, shared by the toon body
// (toon.gdshaderinc) and its outline (toon_outline.gdshader) so the hull
// moves with the surface.

// 0..1, a slow wobble of two waves across the garment: outward only, as
// the garment sits just off the skin and an inward push lets it through
float jelly_wave(vec3 v, float t) {
	float w = 0.6 * sin(t * 7.0 + v.y * 22.0) + 0.4 * sin(t * 11.0 + v.x * 31.0 + v.z * 17.0);
	return 0.5 + 0.5 * w;
}

// the flame sways and jumps a little (in the piece's own space, where the
// flame is one surface among the pole's: no centre to scale it about)
vec3 flame_flicker(vec3 v, float t, float k) {
	v.x += 0.010 * k * sin(t * 9.0 + v.y * 40.0);
	v.z += 0.006 * k * sin(t * 13.0 + v.y * 35.0);
	v.y += 0.005 * k * sin(t * 17.0);
	return v;
}

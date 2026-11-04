shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

// S35: inverted-hull outline in screen pixels, so it is as thin at game
// zoom as in a close-up (a hull in metres would vanish or turn into a
// rope). Dark brown, never black (style sheet).

uniform vec4 color : source_color = vec4(0.165, 0.114, 0.078, 1.0);
uniform float width_px = 1.3;
// world size of one screen pixel, set by toon.gd from the camera (the
// projection matrix doesn't give it reliably in the compatibility renderer)
uniform float px_world = 0.016;

void vertex() {
	VERTEX += NORMAL * px_world * width_px;
}

void fragment() {
	ALBEDO = color.rgb;
}

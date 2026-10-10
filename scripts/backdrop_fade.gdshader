shader_type canvas_item;
// Stage 1 backdrop pieces: tint toward the haze at their depth (instead of
// see-through alpha) and dissolve the bottom of the sprite, so a piece fades
// into fog or floor rather than ending on a flat cut.
uniform vec4 haze : source_color = vec4(0.33, 0.27, 0.27, 1.0);
uniform float haze_amount = 0.0;
uniform float fade_from = 1.0;

void fragment() {
	vec4 c = COLOR;
	c.rgb = mix(c.rgb, haze.rgb, haze_amount);
	c.a *= 1.0 - smoothstep(fade_from, 1.0, UV.y);
	COLOR = c;
}

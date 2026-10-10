shader_type canvas_item;

// Lays tint.rgb over the sprite by tint.a (hit flash, telegraph colours).
// Soft pixels (contact shadow) are left alone.
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, tint.rgb, tint.a * step(0.6, c.a));
	COLOR = c * COLOR;
}

shader_type canvas_item;
// Enemy effects (ART_SPEC §10): hit flash (white), defeat pixel-dissolve (random pixel order),
// Enraged tint toward R1. Binary alpha only: pixels vanish whole, never fade.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float enraged : hint_range(0.0, 1.0) = 0.0;
const vec3 R1 = vec3(0.878, 0.204, 0.290);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = COLOR;
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	if (hash(px) < dissolve) {
		c.a = 0.0;
	}
	c.rgb = mix(c.rgb, R1, enraged * 0.35);
	c.rgb = mix(c.rgb, vec3(1.0), step(0.5, flash));
	COLOR = c;
}

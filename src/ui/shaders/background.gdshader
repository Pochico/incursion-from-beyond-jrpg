shader_type canvas_item;
// Fondo grafito con viñeta, grano de película, cuadrícula opcional
// y destellos diagonales sutiles.

uniform vec4 base_color : source_color = vec4(0.16, 0.16, 0.18, 1.0);
uniform vec4 edge_color : source_color = vec4(0.04, 0.04, 0.05, 1.0);
uniform float vignette = 0.85;
uniform float grain = 0.035;

uniform vec4 streak_color : source_color = vec4(0.776, 0.957, 0.196, 1.0);
uniform float streak_strength = 0.05;
uniform float streak_speed = 0.015;

uniform float grid_strength = 0.0;
uniform float grid_size = 48.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 col = base_color.rgb;

	// Viñeta
	float d = distance(UV, vec2(0.5));
	col = mix(col, edge_color.rgb, smoothstep(0.3, 0.95, d) * vignette);

	// Cuadrícula
	if (grid_strength > 0.0) {
		vec2 g = mod(FRAGCOORD.xy, grid_size);
		float line = step(g.x, 1.0) + step(g.y, 1.0);
		col += vec3(min(line, 1.0) * grid_strength);
	}

	// Destellos diagonales «/» que se desplazan lentamente
	float diag = (FRAGCOORD.x + FRAGCOORD.y * 0.6) * 0.0012 - TIME * streak_speed;
	float streak = pow(max(sin(diag * 6.2831), 0.0), 60.0);
	col = mix(col, streak_color.rgb, streak * streak_strength);

	// Grano animado (12 fps para que parezca película)
	float n = hash(FRAGCOORD.xy + floor(TIME * 12.0) * 17.0) - 0.5;
	col += n * grain;

	COLOR = vec4(col, 1.0);
}

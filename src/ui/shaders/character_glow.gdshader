shader_type canvas_item;
// Silueta + resplandor de color detrás del personaje, y atenuado opcional.
// Las UV fuera de [0,1] se tratan como transparentes, para que el brillo
// pueda salirse de los límites de la imagen original.

uniform vec4 glow_color : source_color = vec4(0.776, 0.957, 0.196, 1.0);
uniform float glow_strength = 0.0;   // 0 = sin brillo
uniform float outline_px = 6.0;      // grosor del contorno, en píxeles de textura
uniform float glow_px = 30.0;        // alcance del halo, en píxeles de textura
uniform float dim = 0.0;             // 0 = normal, 1 = negro

varying vec4 vertex_modulate;

void vertex() {
	vertex_modulate = COLOR;
}

float inside(vec2 p) {
	return step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * inside(UV);
	vec3 col = tex.rgb * (1.0 - dim);

	float ga = 0.0;
	if (glow_strength > 0.001) {
		float outline = 0.0;
		float halo = 0.0;
		for (int i = 0; i < 16; i++) {
			float ang = 6.2831853 * float(i) / 16.0;
			vec2 dir = vec2(cos(ang), sin(ang)) * TEXTURE_PIXEL_SIZE;
			vec2 p = UV + dir * outline_px;
			outline = max(outline, texture(TEXTURE, p).a * inside(p));
			for (int r = 1; r <= 3; r++) {
				vec2 q = UV + dir * glow_px * float(r) / 3.0;
				halo += texture(TEXTURE, q).a * inside(q);
			}
		}
		halo /= 48.0;
		ga = clamp(max(outline, halo * 1.6), 0.0, 1.0) * glow_strength;
	}

	float a = tex.a + ga * (1.0 - tex.a);
	vec3 rgb = a > 0.0001 ? (col * tex.a + glow_color.rgb * ga * (1.0 - tex.a)) / a : vec3(0.0);
	COLOR = vec4(rgb, a) * vertex_modulate;
}

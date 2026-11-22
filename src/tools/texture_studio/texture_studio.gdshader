shader_type canvas_item;
// Estudio de texturas: formato + aplanado/resalte + posterizado + entintado.
// Todo se evalúa en «espacio de recorte» c ∈ [0,1)² (con fract para repetir),
// de modo que la vista previa y la exportación producen exactamente lo mismo.

uniform sampler2D source : filter_linear_mipmap, repeat_disable;
uniform bool has_source = false;
uniform vec2 crop_pos = vec2(0.0);      // recorte dentro de la imagen original (UV)
uniform vec2 crop_size = vec2(1.0);
uniform vec2 out_size = vec2(1024.0);   // resolución de salida en píxeles
uniform float tiles = 1.0;              // vista previa en mosaico (1 = una copia)
uniform bool show_original = false;

// Formato: mezcla de bordes para que la textura se repita sin costuras.
uniform bool seamless_x = false;
uniform bool seamless_y = false;
uniform float seam_width = 0.25;        // fracción de la textura que se mezcla junto a cada borde

// Estilo
uniform float smooth_px = 0.0;          // simplificado: radio del desenfoque previo (px de salida)
uniform float tone = 0.0;               // −1 aplanar … 0 … +1 resaltar
uniform int poster_steps = 0;           // 0 = sin posterizar; si no, niveles por canal
uniform float ink_threshold = 10.0;     // diferencia de color mínima para trazar línea (>2 = sin líneas)
uniform float ink_px = 1.0;             // grosor de línea (px de salida, a cada lado)
uniform vec4 ink_color : source_color = vec4(0.09, 0.07, 0.13, 1.0);
uniform float ink_from_shape = 1.0;     // 1 = versión oscura del color de la forma; 0 = color de tinta

vec3 tap(vec2 c, vec2 gx, vec2 gy) {
	vec2 uv = crop_pos + fract(c) * crop_size;
	return textureGrad(source, uv, gx, gy).rgb;
}

// Simplificado: desenfoque en dos anillos (8 + 8 muestras) que funde el ruido
// fino en manchas, para que posterizado y entintado sigan las formas grandes.
vec3 smoothed(vec2 c, vec2 gx, vec2 gy) {
	vec3 col = tap(c, gx, gy);
	if (smooth_px > 0.01) {
		vec2 r = smooth_px / out_size;
		vec3 acc = col * 2.0;
		for (int i = 0; i < 8; i++) {
			float a = 6.2831853 * float(i) / 8.0;
			vec2 d = vec2(cos(a), sin(a));
			acc += tap(c + d * r, gx, gy);
			acc += tap(c + d * r * 0.5, gx, gy) * 1.5;
		}
		col = acc / 22.0;
	}
	return col;
}

float edge_weight(float t) {
	t = fract(t);
	return smoothstep(0.0, max(seam_width, 0.001), min(t, 1.0 - t));
}

// Repetible en X: se mezcla con la copia desplazada media textura. La costura
// de esa copia cae en el centro, justo donde manda la original.
vec3 seam_x(vec2 c, vec2 gx, vec2 gy) {
	vec3 a = smoothed(c, gx, gy);
	if (!seamless_x) return a;
	vec3 b = smoothed(c + vec2(0.5, 0.0), gx, gy);
	return mix(b, a, edge_weight(c.x));
}

vec3 base_color(vec2 c, vec2 gx, vec2 gy) {
	vec3 a = seam_x(c, gx, gy);
	if (!seamless_y) return a;
	vec3 b = seam_x(c + vec2(0.0, 0.5), gx, gy);
	return mix(b, a, edge_weight(c.y));
}

vec3 stylize(vec3 col) {
	// Aplanado (tone < 0) / resalte (tone > 0): saturación y contraste.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	float sat = 1.0 + tone * (tone < 0.0 ? 0.85 : 0.9);
	float con = 1.0 + tone * (tone < 0.0 ? 0.55 : 0.6);
	col = mix(vec3(lum), col, sat);
	col = clamp((col - 0.5) * con + 0.5, 0.0, 1.0);
	// Posterizado por canal.
	if (poster_steps >= 2) {
		float n = float(poster_steps - 1);
		col = floor(col * n + 0.5) / n;
	}
	return col;
}

vec3 process(vec2 c, vec2 gx, vec2 gy) {
	return stylize(base_color(c, gx, gy));
}

void fragment() {
	vec2 c = UV * tiles;
	vec2 gx = dFdx(c) * crop_size;
	vec2 gy = dFdy(c) * crop_size;
	if (!has_source) {
		COLOR = vec4(0.0);
	} else if (show_original) {
		COLOR = vec4(tap(c, gx, gy), 1.0);
	} else {
		vec3 col = process(c, gx, gy);
		if (ink_threshold < 2.0) {
			vec2 o = ink_px / out_size;
			vec3 n1 = process(c + vec2(o.x, 0.0), gx, gy);
			vec3 n2 = process(c - vec2(o.x, 0.0), gx, gy);
			vec3 n3 = process(c + vec2(0.0, o.y), gx, gy);
			vec3 n4 = process(c - vec2(0.0, o.y), gx, gy);
			float d = max(max(distance(col, n1), distance(col, n2)), max(distance(col, n3), distance(col, n4)));
			float line = smoothstep(ink_threshold, ink_threshold + 0.04, d);
			vec3 line_col = mix(ink_color.rgb, col * 0.28, ink_from_shape);
			col = mix(col, line_col, line);
		}
		COLOR = vec4(col, 1.0);
	}
}

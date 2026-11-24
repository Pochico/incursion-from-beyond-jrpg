shader_type spatial;
// Capa que se suma encima de la geometría de la mazmorra (material_overlay):
//  - el frente del pulso del resonador: un anillo (cilindro vertical) que crece
//    desde `origin` hasta `max_radius` y se desvanece; en un pasillo se ve como
//    una línea en suelo, paredes y techo que se aleja;
//  - `glow`: brillo propio de una pared secreta detectada (0 = nada): sobre
//    todo en los bordes de la pared (caja `box_center` ± `box_half`; `box_axes`
//    marca los ejes que cuentan, sin el del grosor) y un tinte suave dentro.
render_mode blend_add, unshaded, depth_draw_never, cull_back, fog_disabled;

uniform vec4 color : source_color = vec4(0.94, 0.66, 1.0, 1.0);
uniform vec3 origin = vec3(0.0);
uniform float radius = 0.0;       // m: posición del frente
uniform float max_radius = 10.0;  // m: alcance
uniform float strength = 0.0;     // 0..1: intensidad del pulso (se desvanece)
uniform float width = 0.35;       // m: grosor del frente
uniform float glow = 0.0;         // brillo propio (paredes secretas)
uniform vec3 box_center = vec3(0.0);
uniform vec3 box_half = vec3(1.0);
uniform vec3 box_axes = vec3(1.0, 1.0, 0.0);
uniform float rim_width = 0.28;   // m: ancho del borde que brilla
uniform float fill = 0.12;        // brillo del interior respecto al del borde

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = length(wpos.xz - origin.xz);
	// Frente nítido y una estela tenue detrás.
	float front = smoothstep(width, 0.0, abs(d - radius));
	float trail = smoothstep(radius, radius - 2.5, d) * step(d, radius) * 0.18;
	float inside = step(d, max_radius);
	float pulse = (front + trail) * strength * inside;
	// Distancia al borde más cercano de la pared (solo en los ejes de la cara).
	vec3 dd = box_half - abs(wpos - box_center) + (1.0 - box_axes) * 100.0;
	float edge = min(dd.x, min(dd.y, dd.z));
	float rim = smoothstep(rim_width, 0.0, edge);
	float pulse_glow = glow * (rim + fill) * (0.78 + 0.22 * sin(TIME * 3.0));
	ALBEDO = color.rgb * (pulse * 1.4 + pulse_glow);
}

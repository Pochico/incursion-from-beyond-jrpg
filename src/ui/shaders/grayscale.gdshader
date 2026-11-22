shader_type canvas_item;
// Ilustración en escala de grises con algo de contraste (pantalla de estado).

uniform float contrast = 1.2;
uniform float brightness = 0.95;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	g = clamp((g - 0.5) * contrast + 0.5, 0.0, 1.0) * brightness;
	// COLOR ya trae el color de la textura: solo se conserva su alfa (y el de modulate).
	COLOR = vec4(vec3(g), COLOR.a);
}

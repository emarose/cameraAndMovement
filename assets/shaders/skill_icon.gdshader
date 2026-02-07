shader_type canvas_item;

uniform bool is_passive = false;
uniform bool is_learned = false;
uniform float border_width : hint_range(0.0, 0.1) = 0.04;
uniform vec4 learned_color : source_color = vec4(1.0, 0.85, 0.1, 1.0); // Dorado
uniform vec4 unlearned_color : source_color = vec4(0.3, 0.3, 0.3, 1.0); // Gris oscuro

void fragment() {
	vec2 uv = UV - 0.5;
	vec4 tex = texture(TEXTURE, UV);
	
	float mask = 0.0;
	float border_mask = 0.0;
	
	if (is_passive) {
		// Geometría circular
		float dist = length(uv);
		mask = smoothstep(0.5, 0.48, dist); // Recorte circular
		border_mask = smoothstep(0.5, 0.48, dist) - smoothstep(0.5 - border_width, 0.48 - border_width, dist);
	} else {
		// Geometría cuadrada
		float max_dist = max(abs(uv.x), abs(uv.y));
		mask = smoothstep(0.5, 0.49, max_dist); // Recorte cuadrado
		border_mask = smoothstep(0.5, 0.49, max_dist) - smoothstep(0.5 - border_width, 0.49 - border_width, max_dist);
	}
	
	// Aplicar el color del borde
	vec4 final_color = tex;
	if (border_mask > 0.1) {
		final_color = is_learned ? learned_color : unlearned_color;
	}
	
	// Mezclar con la opacidad de la máscara (para redondear esquinas/círculo)
	final_color.a *= mask;
	
	COLOR = final_color;
}
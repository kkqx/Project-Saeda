shader_type canvas_item;
// Animação da arte do título: o cabelo balança de leve (mais forte nas pontas),
// a imagem "respira" e o rabisco do fundo cintila bem devagar.
uniform vec2 face_center = vec2(0.83, 0.42);

void fragment() {
	vec2 uv = UV;
	float right = smoothstep(0.58, 0.70, uv.x);
	float d = distance(vec2(uv.x * 1.78, uv.y), vec2(face_center.x * 1.78, face_center.y));
	float away = smoothstep(0.22, 0.75, d);          // 0 no rosto, 1 nas pontas do cabelo
	float sway = sin(uv.y * 16.0 + TIME * 1.4) * 0.0016 + sin(uv.y * 6.0 - TIME * 0.9) * 0.0022;
	uv.x += sway * right * away * (0.4 + uv.y);
	uv.y += sin(TIME * 0.9) * 0.0012 * right;       // respiração
	vec4 c = texture(TEXTURE, uv);
	// cintilar do rabisco: pequena variação de brilho por faixa, só no fundo (esquerda)
	float left = 1.0 - right;
	float flick = sin(uv.y * 60.0 + uv.x * 40.0 + TIME * 0.8) * 0.5 + 0.5;
	c.rgb *= 1.0 + (flick - 0.5) * 0.06 * left;
	COLOR = c;
}

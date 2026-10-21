shader_type canvas_item;

// Balanço do cabelo na tela inicial.
// Roda só na camada "title_hair.png" (mechas soltas); o resto da arte fica parado.
// Quanto mais longe da raiz (mais à esquerda), mais a mecha se mexe.

uniform float amplitude : hint_range(0.0, 0.03) = 0.006;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float root_x = 0.76;   // a partir daqui (UV.x) o cabelo fica parado
uniform float tip_x = 0.42;    // daqui para a esquerda o balanço é total

void fragment() {
	float weight = 1.0 - smoothstep(tip_x, root_x, UV.x);
	float t = TIME * speed;
	float dx = sin(t * 1.3 + UV.y * 9.0 + UV.x * 5.0) + 0.5 * sin(t * 2.3 + UV.y * 21.0);
	float dy = 0.4 * cos(t * 1.1 + UV.x * 7.0);
	vec2 offset = vec2(dx, dy) * amplitude * weight;
	COLOR = texture(TEXTURE, UV + offset);
}

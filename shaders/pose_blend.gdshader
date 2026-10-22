shader_type canvas_item;

// Crossfade entre duas poses da personagem (mesmo tamanho de frame).
// A textura desenhada é a pose anterior (TEXTURE); tex_b é a pose atual.
// A mistura é feita em alfa pré-multiplicado, então onde as duas poses se
// sobrepõem o corpo continua opaco e só as partes que mudam (pernas, cabelo) dissolvem.

uniform sampler2D tex_b : filter_linear, repeat_disable;
uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
// balanço do passo: tronco/cabelo e saia se movem para lados opostos (UV; 0.014 = 1 px)
uniform float sway = 0.0;

float band(float y, float lo, float hi) {
	float k = clamp((y - lo) / (hi - lo), 0.0, 1.0);
	float s = sin(3.14159 * k);
	return s * s;
}

void fragment() {
	vec2 uv = UV;
	uv.x -= sway * (band(UV.y, 0.12, 0.62) - 0.7 * band(UV.y, 0.5, 0.88));
	vec4 a = texture(TEXTURE, uv);
	vec4 b = texture(tex_b, uv);
	vec3 pa = a.rgb * a.a;
	vec3 pb = b.rgb * b.a;
	float alpha = mix(a.a, b.a, mix_amount);
	vec3 rgb = mix(pa, pb, mix_amount);
	COLOR = vec4(alpha > 0.0001 ? rgb / alpha : vec3(0.0), alpha) * tint;
}

shader_type canvas_item;

// Crossfade entre duas poses da personagem (mesmo tamanho de frame).
// A textura desenhada é a pose anterior (TEXTURE); tex_b é a pose atual.
// A mistura é feita em alfa pré-multiplicado, então onde as duas poses se
// sobrepõem o corpo continua opaco e só as partes que mudam (pernas, cabelo) dissolvem.

uniform sampler2D tex_b : filter_linear, repeat_disable;
uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(tex_b, UV);
	vec3 pa = a.rgb * a.a;
	vec3 pb = b.rgb * b.a;
	float alpha = mix(a.a, b.a, mix_amount);
	vec3 rgb = mix(pa, pb, mix_amount);
	COLOR = vec4(alpha > 0.0001 ? rgb / alpha : vec3(0.0), alpha) * tint;
}

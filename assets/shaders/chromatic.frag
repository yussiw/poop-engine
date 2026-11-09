#pragma header

// offset: distancia do deslocamento de cor (ex.: 0.004). Pensado pra uma camera inteira (setCamera).
uniform float offset;

void main() {
	vec2 uv = openfl_TextureCoordv;
	vec2 dir = (uv - vec2(0.5)) * offset;
	float r = flixel_texture2D(bitmap, uv + dir).r;
	vec4 g = flixel_texture2D(bitmap, uv);
	float b = flixel_texture2D(bitmap, uv - dir).b;
	gl_FragColor = vec4(r, g.g, b, g.a);
}

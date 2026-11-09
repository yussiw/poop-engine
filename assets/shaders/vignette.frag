#pragma header

// strength: 0 = sem efeito, 1 = bordas bem escuras. Pensado pra uma camera inteira (setCamera).
uniform float strength;

void main() {
	vec4 c = flixel_texture2D(bitmap, openfl_TextureCoordv);
	vec2 d = openfl_TextureCoordv - vec2(0.5);
	float v = smoothstep(0.85, 0.2, length(d) * 1.25);
	gl_FragColor = vec4(c.rgb * mix(1.0, v, strength), c.a);
}

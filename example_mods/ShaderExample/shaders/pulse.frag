#pragma header

// iTime e atualizado sozinho pela engine (segundos). Serve em sprites: o brilho pulsa.
uniform float iTime;
uniform float speed;

void main() {
	vec4 c = flixel_texture2D(bitmap, openfl_TextureCoordv);
	float k = 0.8 + 0.2 * sin(iTime * speed);
	gl_FragColor = vec4(c.rgb * k, c.a);
}

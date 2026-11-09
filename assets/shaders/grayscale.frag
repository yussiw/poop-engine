#pragma header

uniform float amount;

void main() {
	vec4 c = flixel_texture2D(bitmap, openfl_TextureCoordv);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	gl_FragColor = vec4(mix(c.rgb, vec3(g), amount), c.a);
}

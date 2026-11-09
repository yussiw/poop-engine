function onCreatePost() {
	var p = setShader(dad, "pulse");
	if (p != null)
		p.setFloat("speed", 4.0);
	var vig = shader("vignette");
	vig.setFloat("strength", 0.6);
	var chroma = shader("chromatic");
	chroma.setFloat("offset", 0.004);
	Shaders.setCamera(FlxG.camera, [vig, chroma]);

}

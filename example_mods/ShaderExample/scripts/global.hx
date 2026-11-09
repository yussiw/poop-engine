// Exemplo de shaders (copie a pasta ShaderExample inteira pra mods/ e ative o mod).
// Roda em toda musica. A opcao "shaders" (Graficos) liga/desliga tudo isso.

function onCreatePost() {
	// 1) shader em um sprite: o oponente pulsa (shaders/pulse.frag, aqui dentro do mod)
	var p = setShader(dad, "pulse");
	if (p != null)
		p.setFloat("speed", 4.0);

	// 2) shaders na tela inteira de uma camera: vinheta + aberracao cromatica (assets/shaders/ do jogo base)
	var vig = shader("vignette");
	vig.setFloat("strength", 0.6);
	var chroma = shader("chromatic");
	chroma.setFloat("offset", 0.004);
	Shaders.setCamera(FlxG.camera, [vig, chroma]);

	// Pra tirar: Shaders.clearCamera(FlxG.camera);  /  Shaders.remove(dad);
}

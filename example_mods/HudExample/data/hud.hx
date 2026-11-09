// HUD custom (data/hud.hx do mod). Roda junto dos outros scripts da musica.
// Campos do PlayState: healthBar, healthBarBG, iconP1, iconP2, scoreTxt, watermark, accuracy, score, misses, combo.
// Eventos extras: onUpdateScore(score, misses, acc) [cancelEvent() = voce escreve o texto], onUpdateIcons(elapsed) [cancelEvent() = voce posiciona os icones]

function onCreatePost() {
	watermark.visible = false;                       // esconde a marca d'agua
	healthBarBG.y = 20; healthBar.y = 24;            // barra de vida no topo
	healthBar.createFilledBar(rgb(255, 60, 90), rgb(60, 220, 255));
	scoreTxt.size = 22;
	scoreTxt.x = healthBarBG.x; scoreTxt.y = healthBarBG.y + 40;
	scoreTxt.alignment = FlxTextAlign.CENTER;
	scoreTxt.fieldWidth = healthBarBG.width;
}

function onUpdateScore(score, misses, acc) {
	scoreTxt.text = score + "  |  x" + misses + "  |  " + Math.round(acc * 100) / 100 + "%";
	cancelEvent();
}

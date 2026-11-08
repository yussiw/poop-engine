// Exemplo de script de musica (assets/songs/<id>/script.hx)
function onBeatHit(beat) {
	if (beat > 0 && beat % 32 == 0)
		game.camHUD.flash(0x66FFFFFF, 0.4);
}

function onNoteHit(note, rating) {
	if (rating == "sick" && game.combo % 50 == 0 && game.combo > 0)
		game.bf.playAnim("hey");
}

// ---- Eventos extras (descomente pra testar) ----
// function onSplash(splash, note) { splash.color = rgb(255, 255, 0); }   // splash da nota SICK
// function onNoteHitPre(note, rating) { if (rating == "shit") cancelEvent(); } // cancela o acerto
// function onCameraMove(mustHit) { /* cancelEvent() pra controlar a camera sozinho */ }
// Campos do PlayState podem ser lidos direto (gravar: game.score = 5): score, health, combo, bf, dad, downscroll, splashes...
// shared["x"] = 1 e shared["x"] sao compartilhados entre scripts; importScript("scripts/outro") junta outro .hx neste.

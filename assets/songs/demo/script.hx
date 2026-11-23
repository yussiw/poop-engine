function onBeatHit(beat) {
	if (beat > 0 && beat % 32 == 0)
		game.camHUD.flash(0x66FFFFFF, 0.4);
}

function onNoteHit(note, rating) {
	if (rating == "sick" && game.combo % 50 == 0 && game.combo > 0)
		game.bf.playAnim("hey");
}

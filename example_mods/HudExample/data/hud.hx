function onCreatePost() {
	watermark.visible = false;
	healthBarBG.y = 20; healthBar.y = 24;
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

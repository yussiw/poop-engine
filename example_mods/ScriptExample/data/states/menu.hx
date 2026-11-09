import flixel.text.FlxText;
function onCreate() {

	itemStartY = 40;
	itemSpacing = 130;
	menuItems.push({
		id: "mods",
		file: "options",
		idle: "options basic",
		selected: "options white",
		action: "mods"
	});
}
function onCreatePost() {
	bg.color = rgb(150, 210, 255);

	var t = createText(0, FlxG.height - 90, FlxG.width, "Menu customizado por script!", 24);
	t.alignment = FlxTextAlign.CENTER;
	t.scrollFactor.set();
	add(t);
}

function onChange(i, id) {
	trace("selecionado: " + id);
}

function onSelect(i, id) {
	if (id == "credits") {
		cancelEvent();
		FlxG.camera.flash(rgb(255, 255, 255), 0.4);
		playSound("menu/cancel", 0.6);
	}
}

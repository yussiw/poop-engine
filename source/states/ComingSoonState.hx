package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;

/** Placeholder pras telas que ainda nao existem (Story Mode / Credits). */
class ComingSoonState extends FlxState {
	override function create():Void {
		super.create();
		var bg = new FlxSprite(0, 0, Paths.image("menus/menuDesat"));
		add(bg);
		var t = new Alphabet(0, 0, "Em breve");
		t.screenCenter();
		add(t);
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		if (Controls.tap || Controls.swipeRight || Controls.back) {
			FlxG.sound.play(Paths.sfx("menu/cancel"), 0.6);
			TransitionSubState.go(new MainMenuState());
		}
	}
}

package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
class ComingSoonState extends FlxState {
	var back:Void->FlxState;

	public function new(?back:Void->FlxState) {
		super();
		this.back = back;
	}

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
			TransitionSubState.go(back != null ? back() : new MainMenuState());
		}
	}
}

package;

import flixel.FlxG;
import flixel.FlxGame;
import openfl.display.Sprite;
import states.MainMenuState;
import states.TransitionSubState;

class Main extends Sprite {
	public function new() {
		super();
		addChild(new FlxGame(1280, 720, MainMenuState, 60, 60, true, false));
		TransitionSubState.init();
		FlxG.autoPause = false;
		FlxG.save.bind("poopengine");
		Options.load();
		TouchCursor.init();
		Paths.init();
		#if !mobile
		FlxG.mouse.visible = true;
		#else
		FlxG.mouse.visible = false;
		#end
	}
}

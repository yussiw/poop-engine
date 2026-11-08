package;

import flixel.FlxG;
import flixel.FlxGame;
import openfl.display.FPS;
import openfl.display.Sprite;
import states.MainMenuState;
import states.TransitionSubState;

class Main extends Sprite {
	static var instance:Main;
	static var fpsDisplay:FPS;

	public function new() {
		super();
		instance = this;
		addChild(new FlxGame(1280, 720, MainMenuState, 60, 60, true, false));
		TransitionSubState.init();
		FlxG.autoPause = false;
		FlxG.save.bind("poopengine");
		Paths.init();
		Options.load();
		TouchCursor.init();
		#if !mobile
		FlxG.mouse.visible = true;
		#else
		FlxG.mouse.visible = false;
		#end
	}

	/** Mostra/esconde o contador de FPS (opcao fpsCounter). */
	public static function setFpsVisible(v:Bool):Void {
		if (instance == null)
			return;
		if (fpsDisplay == null) {
			if (!v)
				return;
			fpsDisplay = new FPS(10, 3, 0xFFFFFF);
			instance.addChild(fpsDisplay);
		}
		fpsDisplay.visible = v;
	}
}

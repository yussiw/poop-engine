package states;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

/** Game over da Kade: BF morrendo na tela preta, toque = tentar de novo, swipe direita/voltar = sair. */
class GameOverSubState extends FlxSubState {
	var dead:Character;
	var camFollow:FlxObject;
	var confirmed:Bool = false;
	var lock:Float = 0.6;

	public function new(x:Float, y:Float, camFollow:FlxObject) {
		super();
		this.camFollow = camFollow;
		dead = new Character(x, y, "bf-dead", true);
		add(dead);
	}

	override function create():Void {
		super.create();
		FlxG.sound.play(Paths.sfx("gameOverSFX"));
		FlxG.camera.follow(camFollow, LOCKON, 0.01);
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		var a = dead.animation.curAnim;
		if (a != null && a.name == "firstDeath" && a.finished)
			dead.playAnim("deathLoop");
		if (lock > 0) {
			lock -= elapsed;
			return;
		}
		if (confirmed)
			return;
		if (Controls.tap) {
			confirmed = true;
			dead.playAnim("deathConfirm");
			FlxG.sound.play(Paths.sfx("gameOverEnd"));
			new FlxTimer().start(0.7, function(_) {
				FlxG.camera.fade(FlxColor.BLACK, 2, false, function() FlxG.resetState());
			});
		} else if (Controls.swipeRight || Controls.back)
			TransitionSubState.go(new FreeplayState());
	}
}

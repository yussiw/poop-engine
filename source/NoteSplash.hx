package;

import flixel.FlxG;
import flixel.FlxSprite;

/**
 * Splash que aparece sobre o receptor quando voce acerta uma nota SICK (atlas game/splashes/<skin>.xml,
 * animacoes "note impact 1|2 <cor>"). Reaproveitado via FlxTypedGroup.recycle. Mods trocam a imagem
 * (images/game/splashes/default.png/.xml) ou a skin: NoteSplash.skin = "outra" num script.
 */
@:keep
class NoteSplash extends FlxSprite {
	public static var skin:String = "default";
	public static var splashScale:Float = 0.85;
	public static var splashAlpha:Float = 0.8;

	public function new() {
		super(-1000, -1000);
		antialiasing = Options.antialiasing;
	}

	public function setup(strum:FlxSprite, lane:Int):Void {
		var f = Paths.sparrow("game/splashes/" + skin);
		if (f == null)
			f = Paths.sparrow("game/splashes/default");
		if (f == null) {
			kill();
			return;
		}
		frames = f;
		Paths.addAnim(this, "s", "note impact " + FlxG.random.int(1, 2) + " " + Note.COLORS[lane], 24, false);
		if (!animation.exists("s")) {
			kill();
			return;
		}
		scale.set(splashScale, splashScale);
		updateHitbox();
		animation.play("s", true);
		animation.finishCallback = function(_) kill();
		alpha = splashAlpha;
		x = strum.x + (strum.width - width) / 2;
		y = strum.y + (strum.height - height) / 2;
	}
}

package;

import flixel.FlxSprite;

@:keep
class Note extends FlxSprite {
	public static final DIRS:Array<String> = ["left", "down", "up", "right"];
	public static final COLORS:Array<String> = ["purple", "blue", "green", "red"];
	public static inline var SCALE:Float = 0.7;
	public static inline var WIDTH:Float = 112; // 160 * 0.7 (swagWidth da Kade)

	public var strumTime:Float;
	public var lane:Int;
	public var mustPress:Bool;
	public var sustainLength:Float;
	public var wasHit:Bool = false;
	public var tooLate:Bool = false;
	public var held:Bool = false;
	/** corpo do sustain (esticado) e ponta final ("hold end"), controlados pelo PlayState.layoutSustain */
	public var sustain:FlxSprite = null;
	public var tail:FlxSprite = null;

	public function new(strumTime:Float, lane:Int, sustainLength:Float, mustPress:Bool) {
		super(-1000, -1000);
		this.strumTime = strumTime;
		this.lane = lane;
		this.sustainLength = sustainLength;
		this.mustPress = mustPress;

		frames = Paths.sparrow("game/notes/default");
		animation.addByPrefix("n", COLORS[lane] + "0", 24, true);
		animation.play("n");
		scale.set(SCALE, SCALE);
		updateHitbox();
		antialiasing = Options.antialiasing;

		if (sustainLength > 0) {
			sustain = new FlxSprite(-1000, -1000);
			sustain.frames = frames;
			sustain.animation.addByPrefix("p", COLORS[lane] + " hold piece", 24, true);
			sustain.animation.play("p");
			sustain.scale.x = SCALE;
			sustain.antialiasing = Options.antialiasing;
			sustain.alpha = 0.6;

			// ponta (cauda) do sustain. O atlas tem "<cor> hold end", mas o roxo vem com o nome errado ("pruple end hold").
			tail = new FlxSprite(-1000, -1000);
			tail.frames = frames;
			var c = COLORS[lane];
			for (nm in [c + " hold end", c + " end hold", "pruple end hold"])
				if (!tail.animation.exists("t"))
					tail.animation.addByPrefix("t", nm + "0", 24, true);
			if (tail.animation.exists("t")) {
				tail.animation.play("t");
				tail.scale.set(SCALE, SCALE);
				tail.updateHitbox();
				tail.antialiasing = Options.antialiasing;
				tail.alpha = 0.6;
			} else
				tail = null; // atlas de mod sem cauda: so o corpo
		}
	}
}

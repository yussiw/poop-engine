package;

import flixel.FlxSprite;

@:keep
class Note extends FlxSprite {
	public static final DIRS:Array<String> = ["left", "down", "up", "right"];
	public static final COLORS:Array<String> = ["purple", "blue", "green", "red"];
	public static inline var SCALE:Float = 0.7;
	public static inline var WIDTH:Float = 112;
	public var strumTime:Float;
	public var lane:Int;
	public var mustPress:Bool;
	public var sustainLength:Float;
	public var wasHit:Bool = false;
	public var tooLate:Bool = false;
	public var held:Bool = false;
	public var ch:Int = -1;
	public var sustain:FlxSprite = null;
	public var tail:FlxSprite = null;

	public function new(strumTime:Float, lane:Int, sustainLength:Float, mustPress:Bool) {
		super(-1000, -1000);
		this.strumTime = strumTime;
		this.lane = lane;
		this.sustainLength = sustainLength;
		this.mustPress = mustPress;
		frames = Paths.sparrow("game/notes/default");
		Paths.addAnim(this, "n", COLORS[lane] + "0", 24, true);
		animation.play("n");
		scale.set(SCALE, SCALE);
		updateHitbox();
		antialiasing = Options.antialiasing;

		if (sustainLength > 0) {
			sustain = new FlxSprite(-1000, -1000);
			sustain.frames = frames;
			Paths.addAnim(sustain, "p", COLORS[lane] + " hold piece", 24, true);
			sustain.animation.play("p");
			sustain.scale.x = SCALE;
			sustain.antialiasing = Options.antialiasing;
			sustain.alpha = 0.6;
			tail = new FlxSprite(-1000, -1000);
			tail.frames = frames;
			var c = COLORS[lane];
			for (nm in [c + " hold end", c + " end hold", "pruple end hold"])
				if (!tail.animation.exists("t"))
					Paths.addAnim(tail, "t", nm + "0", 24, true);
			if (tail.animation.exists("t")) {
				tail.animation.play("t");
				tail.scale.set(SCALE, SCALE);
				tail.updateHitbox();
				tail.antialiasing = Options.antialiasing;
				tail.alpha = 0.6;
			} else
				tail = null;
		}
	}
}

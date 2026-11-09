package;

import flixel.FlxSprite;

@:keep
class Strum extends FlxSprite {
	public var lane:Int;
	public var resetTimer:Float = 0;
	public function new(x:Float, y:Float, lane:Int) {
		super(x, y);
		this.lane = lane;
		frames = Paths.sparrow("game/notes/default");
		var d = Note.DIRS[lane];
		Paths.addAnim(this, "static", "arrow" + d.toUpperCase() + "0", 24, false);
		Paths.addAnim(this, "press", d + " press", 24, false);
		Paths.addAnim(this, "confirm", d + " confirm", 24, false);
		scale.set(Note.SCALE, Note.SCALE);
		updateHitbox();
		antialiasing = Options.antialiasing;
		play("static");
	}

	public function play(anim:String):Void {
		animation.play(anim, true);
		centerOffsets();
		centerOrigin();
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);
		if (resetTimer > 0) {
			resetTimer -= elapsed;
			if (resetTimer <= 0)
				play("static");
		}
	}
}

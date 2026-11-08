package;

import flixel.FlxSprite;

class HealthIcon extends FlxSprite {
	public var sprTracker:FlxSprite;

	public function new(name:String, isPlayer:Bool = false) {
		super();
		var g = Paths.image('icons/$name/icon');
		if (g == null)
			g = Paths.image("icons/face/icon");
		var two = g.width > g.height;
		loadGraphic(g, true, Std.int(two ? g.width / 2 : g.width), g.height);
		animation.add("n", [0], 0, false);
		animation.add("l", [two ? 1 : 0], 0, false);
		animation.play("n");
		flipX = isPlayer;
		antialiasing = Options.antialiasing;
		scrollFactor.set();
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);
		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	}
}

package;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import haxe.Json;

using StringTools;

/** Personagem totalmente definido por assets/data/characters/<id>.json */
@:keep
class Character extends FlxSprite {
	public static final SING:Array<String> = ["singLEFT", "singDOWN", "singUP", "singRIGHT"];

	public var id:String;
	public var isPlayer:Bool;
	public var holdTimer:Float = 0;
	public var singSteps:Float = 4;
	public var icon:String = "face";
	public var healthColor:FlxColor = FlxColor.RED;

	var offs:Map<String, Array<Float>> = new Map();
	var idle:String = "idle";
	var swapSing:Bool = false;

	public function new(x:Float, y:Float, id:String, isPlayer:Bool) {
		super(x, y);
		this.id = id;
		this.isPlayer = isPlayer;
		var d:Dynamic = Paths.json('data/characters/$id.json');
		if (d == null)
			d = Paths.json('data/characters/bf.json');

		frames = Paths.sparrow(d.image);
		antialiasing = true;
		if (d.scale != null) {
			scale.set(d.scale, d.scale);
			updateHitbox();
		}
		flipX = d.flipX == true;
		swapSing = d.swapSing == true;
		if (d.icon != null)
			icon = d.icon;
		if (d.idle != null)
			idle = d.idle;
		if (d.singSteps != null)
			singSteps = d.singSteps;
		if (d.healthColor != null) {
			var c:Array<Int> = d.healthColor;
			healthColor = FlxColor.fromRGB(c[0], c[1], c[2]);
		}

		var anims:Array<Dynamic> = d.anims;
		for (a in anims) {
			var fps:Int = a.fps != null ? a.fps : 24;
			var loop:Bool = a.loop == true;
			if (a.indices != null)
				animation.addByIndices(a.name, a.prefix, a.indices, "", fps, loop);
			else
				animation.addByPrefix(a.name, a.prefix, fps, loop);
			var o:Array<Float> = [0, 0];
			if (a.offsets != null)
				o = a.offsets;
			offs.set(a.name, o);
		}
		dance();
	}

	public function playAnim(name:String, force:Bool = true):Void {
		if (!animation.exists(name))
			return;
		animation.play(name, force);
		var o = offs.get(name);
		if (o != null)
			offset.set(o[0], o[1]);
	}

	public function dance():Void
		playAnim(idle);

	public function danceIfIdle():Void {
		var n = animation.curAnim != null ? animation.curAnim.name : null;
		if (n == null || !n.startsWith("sing"))
			dance();
	}

	public function sing(lane:Int, miss:Bool = false):Void {
		if (swapSing && (lane == 0 || lane == 3))
			lane = 3 - lane;
		holdTimer = 0;
		playAnim(SING[lane] + (miss ? "miss" : ""));
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);
		var n = animation.curAnim != null ? animation.curAnim.name : null;
		if (n != null && n.startsWith("sing")) {
			holdTimer += elapsed;
			if (holdTimer >= Conductor.stepCrochet * 0.001 * singSteps) {
				dance();
				holdTimer = 0;
			}
		} else
			holdTimer = 0;
	}
}

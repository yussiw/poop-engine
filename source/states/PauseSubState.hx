package states;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
class PauseSubState extends FlxSubState {
	var cam:FlxCamera;
	var names:Array<String> = [];
	var items:FlxTypedGroup<Alphabet>;
	var sel:Int = 0;
	var lock:Float = 0.4;
	public function new(cam:FlxCamera) {
		super();
		this.cam = cam;
	}
	override function create():Void {
		super.create();
		names = [Lang.get("pause.resume"), Lang.get("pause.restart"), Lang.get("pause.exit")];
		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.cameras = [cam];
		add(bg);

		var info = new FlxText(20, 15, 0, PlayState.instance.songName, 32);
		var diff = new FlxText(20, 15 + 32, 0, Lang.get("pause.difficulty"), 32);
		for (t in [info, diff]) {
			t.setFormat(Paths.font("vcr.ttf"), 32);
			t.updateHitbox();
			t.x = FlxG.width - (t.width + 20);
			t.alpha = 0;
			t.cameras = [cam];
			add(t);
		}
		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(info, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(diff, {alpha: 1, y: diff.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		items = new FlxTypedGroup<Alphabet>();
		add(items);
		for (i in 0...names.length) {
			var a = new Alphabet(0, 70 * i + 30, names[i]);
			a.isMenuItem = true;
			a.targetY = i;
			a.cameras = [cam];
			items.add(a);
		}
		changeSel(0);
	}

	function changeSel(c:Int):Void {
		if (c != 0)
			FlxG.sound.play(Paths.sfx("menu/scroll"), 0.4);
		sel = (sel + c + names.length) % names.length;
		var n = 0;
		for (a in items.members) {
			a.targetY = n - sel;
			n++;
			a.alpha = a.targetY == 0 ? 1 : 0.6;
		}
	}
	function accept():Void {
		switch (sel) {
			case 0:
				close();
			case 1:
				TransitionSubState.go(new PlayState());
			default:
				TransitionSubState.go(new FreeplayState());
		}
	}
	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		if (lock > 0) {
			lock -= elapsed;
			return;
		}
		if (Controls.back) {
			close();
			return;
		}
		if (Controls.next)
			changeSel(1);
		if (Controls.prev)
			changeSel(-1);
		if (Controls.tap) {
			for (i in 0...items.members.length) {
				var it = items.members[i];
				if (Math.abs(Controls.tapY - (it.y + it.height / 2)) < 55) {
					if (i == sel)
						accept();
					else
						changeSel(i - sel);
					break;
				}
			}
		}
	}
}

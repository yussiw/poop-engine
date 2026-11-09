package states;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class MenuState extends FlxState {
	var items:Array<FlxText> = [];
	var ids:Array<String> = [];
	var sel:Int = 0;
	var leaving:Bool = false;
	override function create():Void {
		super.create();
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);

		var bg = new FlxSprite(0, 0, Paths.image("menus/menuBGBlue"));
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		add(bg);

		var list:Array<Dynamic> = Paths.json("data/songlist.json");
		for (s in list) {
			ids.push(s.id);
			var t = new FlxText(0, FlxG.height / 2, FlxG.width, s.name, 56);
			t.setFormat(Paths.font("vcr.ttf"), 56, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.borderSize = 3;
			items.push(t);
			add(t);
		}
		var title = new FlxText(0, 20, FlxG.width, "POOP ENGINE", 40);
		title.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.WHITE, FlxTextAlign.CENTER);
		add(title);
		var hint = new FlxText(0, FlxG.height - 50, FlxG.width, "Deslize pra cima/baixo  -  Toque pra jogar", 24);
		hint.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, FlxTextAlign.CENTER);
		add(hint);
	}

	function move(d:Int):Void {
		sel = Std.int(FlxMath.bound(sel + d, 0, items.length - 1));
		FlxG.sound.play(Paths.sfx("menu/scroll"), 0.6);
	}

	function accept():Void {
		if (leaving)
			return;
		leaving = true;
		FlxG.sound.play(Paths.sfx("menu/confirm"), 0.7);
		PlayState.songId = ids[sel];
		if (FlxG.sound.music != null)
			FlxG.sound.music.fadeOut(0.5);
		TransitionSubState.go(new PlayState());
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		if (leaving)
			return;
		if (Controls.next)
			move(1);
		if (Controls.prev)
			move(-1);
		if (Controls.tap) {
			for (i in 0...items.length) {
				if (Math.abs(Controls.tapY - (items[i].y + 35)) < 45) {
					if (i == sel)
						accept();
					else {
						sel = i;
						FlxG.sound.play(Paths.sfx("menu/scroll"), 0.6);
					}
					break;
				}
			}
		}
		for (i in 0...items.length) {
			var targetY = FlxG.height / 2 - 35 + (i - sel) * 90;
			items[i].y = FlxMath.lerp(targetY, items[i].y, Math.exp(-elapsed * 10));
			items[i].alpha = i == sel ? 1 : 0.45;
		}
	}
}

package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/** Freeplay igual ao da vanilla/Kade. Swipe cima/baixo troca, toque na selecionada joga, swipe direita volta. */
class FreeplayState extends FlxState {
	static var curSelected:Int = 0;

	var songs:Array<Dynamic>;
	var grpSongs:FlxTypedGroup<Alphabet>;
	var icons:Array<HealthIcon> = [];
	var scoreText:FlxText;
	var diffText:FlxText;
	var scoreBG:FlxSprite;
	var lerpScore:Float = 0;
	var intendedScore:Int = 0;
	var leaving:Bool = false;

	override function create():Void {
		super.create();
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);

		songs = Paths.json("data/songlist.json");
		var bg = new FlxSprite(0, 0, Paths.image("menus/menuBGBlue"));
		bg.antialiasing = true;
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);
		for (i in 0...songs.length) {
			var t = new Alphabet(0, 70 * i + 30, songs[i].name);
			t.isMenuItem = true;
			t.targetY = i;
			grpSongs.add(t);
			var icon = new HealthIcon(songs[i].icon != null ? songs[i].icon : "face");
			icon.sprTracker = t;
			icons.push(icon);
			add(icon);
		}

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);
		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, FlxColor.BLACK);
		scoreBG.alpha = 0.6;
		add(scoreBG);
		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "NORMAL", 24);
		diffText.font = scoreText.font;
		add(diffText);
		add(scoreText);
		changeSelection(0);
	}

	function changeSelection(c:Int):Void {
		if (c != 0)
			FlxG.sound.play(Paths.sfx("menu/scroll"), 0.4);
		curSelected = (curSelected + c + songs.length) % songs.length;
		intendedScore = Highscore.get(songs[curSelected].id);
		var n = 0;
		for (item in grpSongs.members) {
			item.targetY = n - curSelected;
			n++;
			item.alpha = item.targetY == 0 ? 1 : 0.6;
		}
		for (i in 0...icons.length)
			icons[i].alpha = i == curSelected ? 1 : 0.6;
	}

	function accept():Void {
		if (leaving)
			return;
		leaving = true;
		FlxG.sound.play(Paths.sfx("menu/confirm"), 0.7);
		PlayState.songId = songs[curSelected].id;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		TransitionSubState.go(new PlayState());
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		lerpScore = FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24));
		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		scoreText.text = "PERSONAL BEST:" + Math.round(lerpScore);
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - scoreBG.scale.x / 2;
		diffText.x = Std.int(scoreBG.x + scoreBG.width / 2);
		diffText.x -= diffText.width / 2;

		if (leaving)
			return;
		if (Controls.next)
			changeSelection(1);
		if (Controls.prev)
			changeSelection(-1);
		if (Controls.swipeRight || Controls.back) {
			FlxG.sound.play(Paths.sfx("menu/cancel"), 0.6);
			TransitionSubState.go(new MainMenuState());
			return;
		}
		if (Controls.tap) {
			for (i in 0...grpSongs.members.length) {
				var it = grpSongs.members[i];
				if (Math.abs(Controls.tapY - (it.y + it.height / 2)) < 55) {
					if (i == curSelected)
						accept();
					else {
						changeSelection(i - curSelected);
					}
					break;
				}
			}
		}
	}
}

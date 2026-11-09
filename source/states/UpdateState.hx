package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import Updater.UpdPhase;

class UpdateState extends FlxState {
	static inline var BAR_H:Int = 20;
	static inline var PURPLE:Int = 0xFFA020F0;

	var bar:FlxSprite;
	var txt:FlxText;
	var shown:Float = 0;
	var wait:Float = 0;
	var leaving:Bool = false;

	override function create():Void {
		super.create();
		FlxG.camera.bgColor = FlxColor.BLACK;

		var bg = new FlxSprite(0, 0, Paths.image("menus/funkay"));
		if (bg.frameHeight > 0) {
			bg.setGraphicSize(0, FlxG.height);
			bg.updateHitbox();
			bg.screenCenter();
		}
		bg.antialiasing = Options.antialiasing;
		add(bg);

		var track = new FlxSprite(0, FlxG.height - BAR_H).makeGraphic(FlxG.width, BAR_H, 0xFF2B0A47);
		add(track);
		bar = new FlxSprite(0, FlxG.height - BAR_H).makeGraphic(FlxG.width, BAR_H, PURPLE);
		bar.origin.set(0, 0);
		bar.scale.x = 0.0001;
		add(bar);

		txt = new FlxText(10, FlxG.height - BAR_H - 44, FlxG.width - 20, "", 24);
		txt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(txt);

		Updater.start();
	}

	function mb(n:Int):String
		return Std.string(Math.round(n / 104857.6) / 10);

	function failText(msg:String):String
		return msg == "unsupported" ? Lang.get("upd.dl.unsupported") : Lang.get("upd.dl.failed") + " (" + msg + ")";

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);

		var target:Float = Updater.progress;
		var canLeave = true;
		switch (Updater.phase) {
			case Idle, Checking:
				txt.text = Lang.get("upd.dl.checking");
				target = 0;
			case UpToDate:
				txt.text = Lang.get("upd.dl.uptodate");
				wait += elapsed;
				if (wait > 1.5)
					leave();
			case Downloading:
				txt.text = Lang.fmt("upd.dl.downloading", ["pct" => Std.string(Std.int(Updater.progress * 100)), "done" => mb(Updater.loaded), "total" => mb(Updater.total)]);
			case Downloaded:
				txt.text = Lang.get("upd.dl.installing");
				Updater.install();
			case Installing:
				txt.text = Lang.get("upd.dl.installing");
				target = 1;
				canLeave = false;
			case NeedPermission:
				txt.text = Lang.get("upd.dl.permission");
				target = 1;
				if (Controls.tap)
					Updater.install();
			case Failed(msg):
				txt.text = failText(msg) + "\n" + Lang.get("upd.dl.back");
				target = 0;
				if (Controls.tap)
					leave();
		}

		shown = FlxMath.lerp(shown, target, FlxMath.bound(elapsed * 10, 0, 1));
		bar.scale.x = Math.max(0.0001, shown);
		bar.visible = shown > 0.002;

		if (canLeave && (Controls.back || Controls.swipeRight))
			leave();
	}

	function leave():Void {
		if (leaving)
			return;
		leaving = true;
		Updater.cancel();
		FlxG.sound.play(Paths.sfx("menu/cancel"), 0.6);
		TransitionSubState.go(new OptionsState());
	}
}

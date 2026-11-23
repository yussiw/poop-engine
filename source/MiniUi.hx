package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

typedef MiniBtn = {
	var bg:FlxSprite;
	var txt:FlxText;
	var x:Float;
	var y:Float;
	var w:Float;
	var h:Float;
	var cb:Void->Void;
	var rep:Bool;
	var fs:Int;
}

class MiniUi {
	static inline var C_BTN:Int = 0xFF3D5A99;
	static inline var C_LABEL:Int = 0xFF22283A;
	static inline var C_HELD:Int = 0xFF7F9FE6;

	public var px:Float = 0;
	public var py:Float = 0;
	public var down:Bool = false;
	public var just:Bool = false;
	public var hitBtn:Bool = false;

	var state:FlxState;
	var btns:Array<MiniBtn> = [];
	var held:MiniBtn = null;
	var holdT:Float = 0;
	var repT:Float = 0;

	public function new(state:FlxState) {
		this.state = state;
	}

	public function add(x:Float, y:Float, w:Float, h:Float, label:String, ?cb:Void->Void, rep:Bool = false):MiniBtn {
		var bg = new FlxSprite(x, y).makeGraphic(Std.int(w), Std.int(h), 0xFFFFFFFF);
		bg.color = cb != null ? C_BTN : C_LABEL;
		var fs = Std.int(Math.min(22, h * 0.5));
		var txt = new FlxText(x + 4, y + (h - fs * 1.25) / 2, w - 8, "", fs);
		txt.setFormat(Paths.font("vcr.ttf"), fs, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		txt.antialiasing = Options.antialiasing;
		state.add(bg);
		state.add(txt);
		var b:MiniBtn = {
			bg: bg,
			txt: txt,
			x: x,
			y: y,
			w: w,
			h: h,
			cb: cb,
			rep: rep,
			fs: fs
		};
		btns.push(b);
		setLabel(b, label);
		return b;
	}

	public function setLabel(b:MiniBtn, label:String):Void {
		var max = Std.int((b.w - 8) / (b.fs * 0.6));
		if (label.length > max && max > 3)
			label = label.substr(0, max - 2) + "..";
		b.txt.text = label;
	}

	function read():Void {
		just = false;
		down = false;
		for (t in FlxG.touches.list) {
			if (t.pressed) {
				down = true;
				px = t.x;
				py = t.y;
				if (t.justPressed)
					just = true;
			}
		}
		#if !mobile
		if (FlxG.mouse.pressed) {
			down = true;
			px = FlxG.mouse.x;
			py = FlxG.mouse.y;
			if (FlxG.mouse.justPressed)
				just = true;
		}
		#end
	}

	public function update(elapsed:Float):Void {
		read();
		if (just) {
			hitBtn = false;
			for (b in btns) {
				if (px >= b.x && px <= b.x + b.w && py >= b.y && py <= b.y + b.h) {
					hitBtn = true;
					if (b.cb != null) {
						held = b;
						holdT = 0;
						repT = 0;
						b.bg.color = C_HELD;
						FlxG.sound.play(Paths.sfx("menu/scroll"), 0.3);
						b.cb();
					}
					break;
				}
			}
		}
		if (!down) {
			if (held != null)
				held.bg.color = C_BTN;
			held = null;
			hitBtn = false;
			return;
		}
		if (held != null && held.rep) {
			holdT += elapsed;
			if (holdT > 0.35) {
				repT += elapsed;
				while (repT > 0.06) {
					repT -= 0.06;
					held.cb();
				}
			}
		}
	}
}

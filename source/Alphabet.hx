package;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;

class Alphabet extends FlxSpriteGroup {
	public var targetY:Float = 0;
	public var isMenuItem:Bool = false;

	static final SYMBOLS:Map<String, String> = [
		"-" => "hyphen", "." => "period", "," => "comma", "'" => "singlequote", "!" => "exclamationmark", "?" => "questionmark",
		":" => "colon", "&" => "ampersand", "+" => "plus", "/" => "slash", "_" => "underscore", "%" => "percent"
	];
	static final NUMS:Array<String> = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"];
	static var atlas:FlxAtlasFrames = null;
	static var glyphs:Map<String, FlxFrame> = new Map();

	public static function reset():Void {
		atlas = null;
		glyphs = new Map();
	}

	public static function plain(t:String):String {
		var from = "áàâãäéèêëíìîïóòôõöúùûüçñ";
		var to = "aaaaaeeeeiiiiooooouuuucn";
		var out = new StringBuf();
		for (i in 0...t.length) {
			var c = t.charAt(i);
			var k = from.indexOf(c.toLowerCase());
			out.add(k >= 0 ? to.charAt(k) : c);
		}
		return out.toString();
	}
	public function new(x:Float, y:Float, text:String) {
		super(x, y);
		text = plain(text);
		var f = Paths.sparrow("menus/alphabet-bold");
		if (f == null)
			return;
		if (f != atlas) {
			atlas = f;
			glyphs = new Map();
		}
		var xPos:Float = 0;
		for (i in 0...text.length) {
			var c = text.charAt(i).toLowerCase();
			if (c == " ") {
				xPos += 40;
				continue;
			}
			var name:String = null;
			var code = c.charCodeAt(0);
			if (code >= 97 && code <= 122)
				name = c;
			else if (code >= 48 && code <= 57)
				name = NUMS[code - 48];
			else if (SYMBOLS.exists(c))
				name = SYMBOLS.get(c);
			if (name == null)
				continue;

			var fr = glyphs.get(name);
			if (fr == null) {
				fr = f.getByName("character-" + name + "0000");
				if (fr != null)
					glyphs.set(name, fr);
			}
			if (fr == null)
				continue;
			var l = new FlxSprite(xPos, 0);
			l.frames = f;
			l.frame = fr;
			l.updateHitbox();
			l.antialiasing = Options.antialiasing;
			add(l);
			xPos += l.width;
		}
	}

	override function update(elapsed:Float):Void {
		if (isMenuItem) {
			var r = 1 - Math.pow(1 - 0.16, elapsed * 60);
			y = FlxMath.lerp(y, targetY * 1.3 * 120 + FlxG.height * 0.48, r);
			x = FlxMath.lerp(x, targetY * 20 + 90, r);
		}
		super.update(elapsed);
	}
}

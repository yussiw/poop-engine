package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
typedef ShaderSource = {frag:String, vert:String};

class Shaders {
	static var sources:Map<String, ShaderSource> = new Map();
	static var timed:Array<FlxRuntimeShader> = [];
	static var elapsedTotal:Float = 0;
	static var hooked:Bool = false;
	static var reTime:EReg = ~/uniform[ \t]+(highp |mediump |lowp )?float[ \t]+iTime/;
	static var reRes:EReg = ~/uniform[ \t]+(highp |mediump |lowp )?vec2[ \t]+iResolution/;

	public static function init():Void {
		if (hooked)
			return;
		hooked = true;
		FlxG.signals.postUpdate.add(tick);
		FlxG.signals.preStateSwitch.add(function() {
			timed = [];
		});
	}

	static function tick():Void {
		if (timed.length == 0)
			return;
		elapsedTotal += FlxG.elapsed;
		for (s in timed)
			s.setFloat("iTime", elapsedTotal);
	}

	public static function clear():Void
		sources = new Map();

	public static function exists(name:String):Bool
		return Paths.exists('shaders/$name.frag');

	static function source(name:String):ShaderSource {
		var s = sources.get(name);
		if (s != null)
			return s;
		var frag = Paths.getText('shaders/$name.frag');
		if (frag == null)
			return null;
		s = {frag: frag, vert: Paths.getText('shaders/$name.vert')};
		sources.set(name, s);
		return s;
	}

	public static function load(name:String):FlxRuntimeShader {
		var s = source(name);
		if (s == null) {
			trace('[Shaders] nao achei shaders/$name.frag');
			return null;
		}
		try {
			var sh = new FlxRuntimeShader(s.frag, s.vert);
			if (reTime.match(s.frag)) {
				sh.setFloat("iTime", elapsedTotal);
				timed.push(sh);
			}
			if (reRes.match(s.frag))
				sh.setFloatArray("iResolution", [FlxG.width, FlxG.height]);
			return sh;
		} catch (e:Dynamic) {
			trace('[Shaders] erro ao criar "$name": $e');
			return null;
		}
	}

	public static function apply(spr:FlxSprite, name:String):FlxRuntimeShader {
		var sh = load(name);
		if (sh != null && Options.shaders && spr != null)
			spr.shader = sh;
		return sh;
	}

	public static function remove(spr:FlxSprite):Void {
		if (spr != null)
			spr.shader = null;
	}

	public static function setCamera(cam:FlxCamera, list:Array<FlxRuntimeShader>):Void {
		if (cam == null)
			return;
		var filters:Array<BitmapFilter> = [];
		if (Options.shaders && list != null)
			for (sh in list)
				if (sh != null)
					filters.push(new ShaderFilter(sh));
		cam.setFilters(filters);
	}

	public static function applyCamera(cam:FlxCamera, name:String):FlxRuntimeShader {
		var sh = load(name);
		if (sh != null)
			setCamera(cam, [sh]);
		return sh;
	}
	public static function clearCamera(cam:FlxCamera):Void {
		if (cam != null)
			cam.setFilters([]);
	}
}

package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import hscript.Interp;
import hscript.Parser;

/**
 * Script HScript (.hx). Funcoes que o script pode definir:
 *   onCreate(), onCreatePost(), onSongStart(), onUpdate(elapsed), onStepHit(step), onBeatHit(beat),
 *   onNoteHit(note, rating), onOpponentHit(note), onMiss(note)
 * Variaveis disponiveis: game (PlayState), FlxG, FlxSprite, FlxTween, FlxEase, Paths, Conductor, Math, Std,
 *   rgb(r,g,b), add(obj), addHUD(obj), remove(obj)
 */
class Script {
	var interp:Interp;

	public var name:String;
	public var ok:Bool = false;

	public function new(code:String, name:String, game:Dynamic) {
		this.name = name;
		interp = new Interp();
		var v = interp.variables;
		v.set("game", game);
		v.set("FlxG", FlxG);
		v.set("FlxSprite", FlxSprite);
		v.set("FlxTween", FlxTween);
		v.set("FlxEase", FlxEase);
		v.set("Paths", Paths);
		v.set("Conductor", Conductor);
		v.set("Math", Math);
		v.set("Std", Std);
		v.set("rgb", function(r:Int, g:Int, b:Int):Int return FlxColor.fromRGB(r, g, b));
		v.set("add", function(o:Dynamic) game.add(o));
		v.set("remove", function(o:Dynamic) game.remove(o));
		v.set("addHUD", function(o:Dynamic) {
			o.cameras = [game.camHUD];
			game.add(o);
		});
		try {
			var parser = new Parser();
			parser.allowTypes = true;
			parser.allowJSON = true;
			interp.execute(parser.parseString(code));
			ok = true;
		} catch (e:Dynamic) {
			trace('[script $name] erro: $e');
		}
	}

	public function call(fn:String, ?args:Array<Dynamic>):Dynamic {
		if (!ok)
			return null;
		var f = interp.variables.get(fn);
		if (f == null || !Reflect.isFunction(f))
			return null;
		try {
			return Reflect.callMethod(null, f, args == null ? [] : args);
		} catch (e:Dynamic) {
			trace('[script $name] $fn: $e');
			return null;
		}
	}
}

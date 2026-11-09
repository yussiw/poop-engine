package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;
import hscript.Parser;

/**
 * Script HScript (.hx). Usado por: musicas/stages (PlayState), menus (data/states/*.hx) e qualquer coisa que
 * crie `new Script(code, nome, dono)`.
 *
 * FUNCOES QUE O SCRIPT PODE DEFINIR (cada state chama as suas; veja o README):
 *   onCreate, onCreatePost, onUpdate(elapsed), onUpdatePost(elapsed), onDestroy ...
 *   PlayState: onSongStart, onSongEnd, onStepHit(s), onBeatHit(b), onCountdown(i), onNoteSpawn(note),
 *   onNoteHit(note, rating), onOpponentHit(note), onMiss(note), onGhostTap(lane), onSplash(splash, note),
 *   onPopup(rating), onCameraMove(mustHit), onPause, onResume, onGameOver
 *   Eventos "cancelaveis": chame cancelEvent() dentro da funcao pra pular o comportamento padrao.
 *
 * VARIAVEIS GLOBAIS: state / game (o dono: PlayState, MainMenuState...), script, scriptName, shared (Map comum a
 *   todos os scripts), as classes do Flixel (FlxG, FlxSprite, FlxText, FlxTween, FlxEase, FlxTimer, FlxColor, ...),
 *   as da engine (Paths, Conductor, Options, Lang, Controls, Note, Strum, Character, ...), Math, Std, Reflect, Type, Json...
 *   Campos do dono podem ser LIDOS direto (ex.: `score`, `bf`, `health`); pra gravar use game.score = 5.
 * HELPERS: rgb, point, add/remove/insert, addHUD, createSprite, createText, playSound, timer, tween, image, sparrow,
 *   getText, getJson, exists, translate, option, switchState, importScript, disableScript, cancelEvent, setVar/getVar, trace,
 *   shader(nome), setShader(sprite, nome), setCameraShader(camera, nome)  [classe Shaders: veja Shaders.hx].
 * IMPORT: `import flixel.text.FlxText;` / `import x.y.Classe as Outro;` funcionam (classes ja incluidas no jogo).
 */
class Script {
	public static inline var VERSION:Int = 2;

	/** Mapa compartilhado por todos os scripts (sobrevive a troca de state). Em script: shared["chave"] / shared.get("chave"). */
	public static var shared:Map<String, Dynamic> = new Map();
	/** true quando algum script chamou cancelEvent() durante o ultimo dispatch. */
	public static var cancelled:Bool = false;
	/** ultimos erros (parse/execucao), mais novo por ultimo. */
	public static var errors:Array<String> = [];

	static var globals:Map<String, Dynamic> = null;
	static var importRe:EReg = ~/^[ \t]*import[ \t]+([A-Za-z0-9_.]+)([ \t]+as[ \t]+([A-Za-z0-9_]+))?[ \t\r]*;?[ \t\r]*$/gm;

	public var interp:ScriptInterp;
	public var name:String;
	public var ok:Bool = false;
	public var disabled:Bool = false;
	public var owner:Dynamic;

	public function new(code:String, name:String, owner:Dynamic, ?extra:Map<String, Dynamic>) {
		this.name = name;
		this.owner = owner;
		interp = new ScriptInterp();
		if (owner != null)
			interp.scriptObject = owner;
		var v = interp.variables;
		for (k => val in getGlobals())
			v.set(k, val);
		v.set("game", owner);
		v.set("state", owner);
		v.set("script", this);
		v.set("scriptName", name);
		v.set("shared", shared);
		setupHelpers(v);
		if (extra != null)
			for (k => val in extra)
				v.set(k, val);
		run(code);
	}

	/** Executa mais codigo no mesmo escopo (usado por importScript). */
	public function run(code:String):Bool {
		try {
			var parser = new Parser();
			parser.allowTypes = true;
			parser.allowJSON = true;
			parser.allowMetadata = true;
			interp.execute(parser.parseString(preprocess(code)));
			ok = true;
			return true;
		} catch (e:Dynamic) {
			fail('erro ao carregar: $e');
			return false;
		}
	}

	function fail(msg:String):Void {
		var m = '[script $name] $msg';
		errors.push(m);
		if (errors.length > 50)
			errors.shift();
		trace(m);
	}

	/** Troca as linhas `import ...;` por linhas vazias (pra manter a numeracao) e define as classes no escopo. */
	function preprocess(code:String):String {
		return importRe.map(code, function(r:EReg):String {
			var path = r.matched(1);
			var alias:String = null;
			try {
				alias = r.matched(3);
			} catch (e:Dynamic) {}
			var short = path.substr(path.lastIndexOf(".") + 1);
			var cls:Dynamic = Type.resolveClass(path);
			if (cls == null)
				cls = Type.resolveEnum(path);
			if (cls == null)
				cls = getGlobals().get(short);
			if (cls == null)
				fail('import nao encontrado: $path (a classe precisa estar compilada na engine; veja Script.hx)');
			else
				interp.variables.set(alias != null && alias != "" ? alias : short, cls);
			return "";
		});
	}

	// ------------------------------------------------------------------ chamadas
	public function exists(fn:String):Bool {
		var f = interp.variables.get(fn);
		return f != null && Reflect.isFunction(f);
	}

	public function call(fn:String, ?args:Array<Dynamic>):Dynamic {
		if (!ok || disabled)
			return null;
		var f = interp.variables.get(fn);
		if (f == null || !Reflect.isFunction(f))
			return null;
		try {
			return Reflect.callMethod(null, f, args == null ? [] : args);
		} catch (e:Dynamic) {
			fail('$fn: $e');
			return null;
		}
	}

	public function get(n:String):Dynamic
		return interp.variables.get(n);

	public function set(n:String, v:Dynamic):Void
		interp.variables.set(n, v);

	/** Chama `fn` em todos os scripts. Retorna true se algum chamou cancelEvent(). */
	public static function callAll(list:Array<Script>, fn:String, ?args:Array<Dynamic>):Bool {
		cancelled = false;
		for (s in list)
			s.call(fn, args);
		var c = cancelled;
		cancelled = false;
		return c;
	}

	// ------------------------------------------------------------------ helpers expostos ao script
	function setupHelpers(v:Map<String, Dynamic>):Void {
		var self = this;
		var o:Dynamic = owner;
		v.set("trace", Reflect.makeVarArgs(function(a:Array<Dynamic>):Dynamic {
			trace('[script $name] ' + a.join(" "));
			return null;
		}));
		v.set("print", v.get("trace"));
		v.set("rgb", function(r:Int, g:Int, b:Int):Int return FlxColor.fromRGB(r, g, b));
		v.set("rgba", function(r:Int, g:Int, b:Int, a:Int):Int return FlxColor.fromRGB(r, g, b, a));
		v.set("point", function(x:Float, y:Float):FlxPoint return FlxPoint.get(x, y));
		v.set("add", function(obj:Dynamic) o.add(obj));
		v.set("remove", function(obj:Dynamic) o.remove(obj));
		v.set("insert", function(i:Int, obj:Dynamic) o.insert(i, obj));
		v.set("addHUD", function(obj:Dynamic) {
			if (Reflect.field(o, "camHUD") != null)
				obj.cameras = [Reflect.field(o, "camHUD")];
			o.add(obj);
		});
		v.set("createSprite", function(x:Float, y:Float, img:String):FlxSprite {
			var s = new FlxSprite(x, y);
			if (img != null && img != "") {
				var g = Paths.image(img);
				if (g != null)
					s.loadGraphic(g);
			}
			s.antialiasing = Options.antialiasing;
			return s;
		});
		v.set("createAnimated", function(x:Float, y:Float, img:String):FlxSprite {
			var s = new FlxSprite(x, y);
			s.frames = Paths.sparrow(img);
			s.antialiasing = Options.antialiasing;
			return s;
		});
		v.set("createText", function(x:Float, y:Float, w:Float, text:String, size:Int):FlxText {
			var t = new FlxText(x, y, w, text, size);
			t.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			return t;
		});
		v.set("playSound", function(n:String, vol:Float):FlxSound {
			var s = Paths.sfx(n);
			return s == null ? null : FlxG.sound.play(s, vol);
		});
		v.set("playMusic", function(n:String, vol:Float) {
			var m = Paths.music(n);
			if (m != null)
				FlxG.sound.playMusic(m, vol);
		});
		v.set("timer", function(sec:Float, fn:Dynamic, loops:Int):FlxTimer return new FlxTimer().start(sec, function(t) fn(t), loops));
		v.set("tween", function(obj:Dynamic, props:Dynamic, dur:Float, opts:Dynamic):FlxTween return FlxTween.tween(obj, props, dur, opts));
		v.set("image", function(k:String) return Paths.image(k));
		v.set("sparrow", function(k:String) return Paths.sparrow(k));
		v.set("getText", function(k:String):String return Paths.getText(k));
		v.set("getJson", function(k:String):Dynamic return Paths.json(k));
		v.set("exists", function(k:String):Bool return Paths.exists(k));
		v.set("shader", function(n:String) return Shaders.load(n));
		v.set("setShader", function(spr:Dynamic, n:String) return Shaders.apply(spr, n));
		v.set("setCameraShader", function(cam:Dynamic, n:String) return Shaders.applyCamera(cam, n));
		v.set("translate", function(k:String):String return Lang.get(k));
		v.set("option", function(k:String):Dynamic return Options.get(k));
		v.set("setVar", function(k:String, val:Dynamic) shared.set(k, val));
		v.set("getVar", function(k:String):Dynamic return shared.get(k));
		v.set("cancelEvent", function() cancelled = true);
		v.set("disableScript", function() self.disabled = true);
		v.set("switchState", function(s:Dynamic) switchState(s));
		v.set("importScript", function(path:String):Bool {
			var p = StringTools.endsWith(path, ".hx") ? path : path + ".hx";
			var code = Paths.getText(p);
			if (code == null) {
				self.fail('importScript: nao achei $p');
				return false;
			}
			return self.run(code);
		});
	}

	/** switchState("menu" | "freeplay" | "options" | "mods" | "play" | "editor" | "credits") ou uma instancia de FlxState. */
	public static function switchState(s:Dynamic):Void {
		var st:flixel.FlxState = null;
		if (Std.isOfType(s, String)) {
			st = switch (Std.string(s).toLowerCase()) {
				case "menu", "mainmenu": new states.MainMenuState();
				case "freeplay": new states.FreeplayState();
				case "options": new states.OptionsState();
				case "mods", "modselect": new states.ModSelectState();
				case "play", "playstate": new states.PlayState();
				case "editor", "chart": new states.ChartPickState();
				case "credits", "story", "comingsoon": new states.ComingSoonState();
				default: null;
			}
		} else if (Std.isOfType(s, flixel.FlxState))
			st = cast s;
		if (st == null)
			trace('[script] switchState: estado desconhecido "$s"');
		else
			states.TransitionSubState.go(st);
	}

	// ------------------------------------------------------------------ classes globais
	public static function getGlobals():Map<String, Dynamic> {
		if (globals != null)
			return globals;
		var g:Map<String, Dynamic> = new Map();
		// Flixel
		g.set("FlxG", FlxG);
		g.set("FlxSprite", FlxSprite);
		g.set("FlxObject", FlxObject);
		g.set("FlxText", FlxText);
		g.set("FlxCamera", FlxCamera);
		g.set("FlxTween", FlxTween);
		g.set("FlxEase", FlxEase);
		g.set("FlxTimer", FlxTimer);
		g.set("FlxMath", FlxMath);
		g.set("FlxFlicker", FlxFlicker);
		g.set("FlxSound", FlxSound);
		g.set("FlxGroup", FlxGroup);
		g.set("FlxSpriteGroup", FlxSpriteGroup);
		// abstracts / enums viram objetos (hscript nao enxerga abstract direto)
		g.set("FlxColor", {
			TRANSPARENT: FlxColor.TRANSPARENT, WHITE: FlxColor.WHITE, GRAY: FlxColor.GRAY, BLACK: FlxColor.BLACK, GREEN: FlxColor.GREEN,
			LIME: FlxColor.LIME, YELLOW: FlxColor.YELLOW, ORANGE: FlxColor.ORANGE, RED: FlxColor.RED, PURPLE: FlxColor.PURPLE,
			BLUE: FlxColor.BLUE, BROWN: FlxColor.BROWN, PINK: FlxColor.PINK, MAGENTA: FlxColor.MAGENTA, CYAN: FlxColor.CYAN,
			fromRGB: function(r:Int, gg:Int, b:Int):Int return FlxColor.fromRGB(r, gg, b),
			fromRGBA: function(r:Int, gg:Int, b:Int, a:Int):Int return FlxColor.fromRGB(r, gg, b, a),
			fromString: function(s:String):Int return FlxColor.fromString(s),
			fromHSB: function(h:Float, s:Float, b:Float):Int return FlxColor.fromHSB(h, s, b),
			interpolate: function(a:Int, b:Int, f:Float):Int return FlxColor.interpolate(a, b, f)
		});
		g.set("FlxAxes", {X: flixel.util.FlxAxes.X, Y: flixel.util.FlxAxes.Y, XY: flixel.util.FlxAxes.XY});
		g.set("FlxTextAlign", {LEFT: FlxTextAlign.LEFT, CENTER: FlxTextAlign.CENTER, RIGHT: FlxTextAlign.RIGHT, JUSTIFY: FlxTextAlign.JUSTIFY});
		g.set("FlxTextBorderStyle", {
			NONE: FlxTextBorderStyle.NONE,
			SHADOW: FlxTextBorderStyle.SHADOW,
			OUTLINE: FlxTextBorderStyle.OUTLINE,
			OUTLINE_FAST: FlxTextBorderStyle.OUTLINE_FAST
		});
		// Haxe
		g.set("Math", Math);
		g.set("Std", Std);
		g.set("StringTools", StringTools);
		g.set("Reflect", Reflect);
		g.set("Type", Type);
		g.set("Json", Json);
		g.set("Lambda", Lambda);
		g.set("Date", Date);
		// engine
		g.set("Paths", Paths);
		g.set("Conductor", Conductor);
		g.set("Controls", Controls);
		g.set("Options", Options);
		g.set("Lang", Lang);
		g.set("Highscore", Highscore);
		g.set("Note", Note);
		g.set("NoteSplash", NoteSplash);
		g.set("Strum", Strum);
		g.set("Character", Character);
		g.set("HealthIcon", HealthIcon);
		g.set("Alphabet", Alphabet);
		g.set("Checkbox", Checkbox);
		g.set("Updates", Updates);
		g.set("GitInfo", GitInfo);
		g.set("Shaders", Shaders);
		g.set("FlxRuntimeShader", flixel.addons.display.FlxRuntimeShader);
		g.set("ShaderFilter", openfl.filters.ShaderFilter);
		g.set("Script", Script);
		g.set("PlayState", states.PlayState);
		g.set("MainMenuState", states.MainMenuState);
		g.set("FreeplayState", states.FreeplayState);
		g.set("OptionsState", states.OptionsState);
		g.set("ModSelectState", states.ModSelectState);
		g.set("TransitionSubState", states.TransitionSubState);
		globals = g;
		return g;
	}
}

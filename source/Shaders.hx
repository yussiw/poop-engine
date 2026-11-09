package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;

typedef ShaderSource = {frag:String, vert:String};

/**
 * Shaders GLSL carregados de arquivo (assets/shaders/<nome>.frag e, opcional, <nome>.vert; o mod ativo substitui
 * pelo mesmo caminho: <mod>/shaders/<nome>.frag). O codigo usa `#pragma header` no comeco, igual aos shaders do OpenFL/Flixel:
 *
 *   #pragma header
 *   uniform float amount;
 *   void main() {
 *       vec4 c = flixel_texture2D(bitmap, openfl_TextureCoordv);
 *       gl_FragColor = c;
 *   }
 *
 * Uniforms automaticos (se o shader declarar): `iTime` (segundos, atualizado todo quadro) e `iResolution` (vec2, tela do jogo).
 *
 * Uso em script (veja o README):
 *   var sh = Shaders.load("grayscale");        // FlxRuntimeShader: sh.setFloat("amount", 1) / setFloatArray / setInt / setBool
 *   Shaders.apply(bf, "pulse");                // em um sprite
 *   Shaders.setCamera(camHUD, [sh]);           // na tela toda de uma camera (lista de shaders)
 *   Shaders.clearCamera(camHUD);
 *
 * A opcao "shaders" (Graficos) desliga tudo: apply/setCamera passam a nao fazer nada (load continua devolvendo o shader).
 */
class Shaders {
	static var sources:Map<String, ShaderSource> = new Map();
	/** shaders que usam iTime (zerado ao trocar de state: os sprites deles morrem junto) */
	static var timed:Array<FlxRuntimeShader> = [];
	static var elapsedTotal:Float = 0;
	static var hooked:Bool = false;
	static var reTime:EReg = ~/uniform[ \t]+(highp |mediump |lowp )?float[ \t]+iTime/;
	static var reRes:EReg = ~/uniform[ \t]+(highp |mediump |lowp )?vec2[ \t]+iResolution/;

	/** Chamar uma vez no Main, depois de criar o FlxGame. */
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

	/** Esquece o codigo em cache (trocou de mod). */
	public static function clear():Void
		sources = new Map();

	/** Existe shaders/<name>.frag (no mod ativo ou no jogo)? */
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

	/** Cria uma instancia nova do shader (cada uma tem seus proprios uniforms). Devolve null se o arquivo nao existe. */
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

	/** Carrega e poe o shader num sprite. Devolve o shader (pra mexer nos uniforms) ou null. */
	public static function apply(spr:FlxSprite, name:String):FlxRuntimeShader {
		var sh = load(name);
		if (sh != null && Options.shaders && spr != null)
			spr.shader = sh;
		return sh;
	}

	/** Tira o shader do sprite. */
	public static function remove(spr:FlxSprite):Void {
		if (spr != null)
			spr.shader = null;
	}

	/** Poe uma lista de shaders na tela inteira de uma camera (substitui os que ja estavam). */
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

	/** Atalho: carrega pelo nome e poe na camera (acrescentando aos que ja la estavam nao e suportado; use setCamera com a lista toda). */
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

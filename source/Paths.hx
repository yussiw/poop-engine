package;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Todo acesso a arquivos passa por aqui. Ordem de busca:
 *   1. <pasta externa>/mods/<ModAtivo>/<mesmo caminho de assets/>
 *   2. assets/ (embutido no APK)
 *
 * Pasta externa (mesma ideia do "external" da Codename Engine Mobile):
 *   Android: /storage/emulated/0/.PoopEngine/   (raiz do armazenamento, igual .CodenameEngine / .PsychEngine;
 *            exige a permissao "acesso a todos os arquivos", que o app pede sozinho)
 *   Desktop: pasta do executavel
 * Cada mod e uma subpasta: mods/MeuMod/data/..., mods/MeuMod/songs/..., mods/MeuMod/images/...
 * O mod ativo e escolhido no menu principal (deslizar pra esquerda / TAB) e fica salvo.
 */
@:keep
class Paths {
	static var rootPath:String = null;
	static var activeMod:String = "";
	static var frameCache:Map<String, FlxAtlasFrames> = new Map();

	public static var externalReady:Bool = false;
	static var asked:Bool = false;
	static var diag:String = "";

	/** Texto de diagnostico (mostrado no menu enquanto a pasta externa nao funciona). */
	public static function diagnostics():String
		return diag;

	/** Pede as permissoes de novo (usado por um toque no menu). */
	public static function requestAgain():Void {
		#if android
		asked = false;
		requestStorage();
		#end
	}

	#if android
	static function androidInfo():Void {
		try {
			diag += "sdk=" + extension.androidtools.os.Build.VERSION.SDK_INT + " todosArquivos=" + extension.androidtools.os.Environment.isExternalStorageManager() + "\n";
		} catch (e:Dynamic) {
			diag += "androidtools erro: " + Std.string(e).substr(0, 60) + "\n";
		}
	}
	#end

	#if android
	static function requestStorage():Void {
		if (asked)
			return;
		asked = true;
		try {
			if (extension.androidtools.os.Build.VERSION.SDK_INT >= 33)
				extension.androidtools.Permissions.requestPermissions(['READ_MEDIA_IMAGES', 'READ_MEDIA_VIDEO', 'READ_MEDIA_AUDIO']);
			else
				extension.androidtools.Permissions.requestPermissions(['READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE']);
			if (extension.androidtools.os.Build.VERSION.SDK_INT >= 30 && !extension.androidtools.os.Environment.isExternalStorageManager())
				extension.androidtools.Settings.requestSetting('MANAGE_APP_ALL_FILES_ACCESS_PERMISSION');
		} catch (e:Dynamic) {
			trace('[Paths] falha ao pedir permissao: $e');
		}
	}
	#end

	/** Chamado de novo pelo menu enquanto a permissao nao foi concedida; retorna true quando a pasta externa ficou pronta. */
	public static function retryExternal():Bool {
		if (externalReady)
			return false;
		init();
		return externalReady;
	}

	/** Chamar no Main, depois do FlxG.save.bind. */
	public static function init():Void {
		#if sys
		diag = "";
		#if android
		requestStorage();
		androidInfo();
		#end
		rootPath = findWritableRoot();
		#if android
		externalReady = rootPath != null && rootPath.indexOf(".PoopEngine") >= 0;
		#else
		externalReady = true;
		#end
		mkdirs(modsDir());
		var saved:String = FlxG.save.data.mod;
		activeMod = (saved != null && saved != "" && FileSystem.exists(modsDir() + saved) && FileSystem.isDirectory(modsDir() + saved)) ? saved : "";
		trace('[Paths] raiz=$rootPath mods=${modsDir()} ativo="$activeMod" encontrados=${listMods()}');
		#end
	}

	#if sys
	static function mkdirs(dir:String):Bool {
		try {
			if (FileSystem.exists(dir))
				return FileSystem.isDirectory(dir);
			var parent = haxe.io.Path.directory(haxe.io.Path.removeTrailingSlashes(dir));
			if (parent != "" && !FileSystem.exists(parent))
				mkdirs(parent);
			FileSystem.createDirectory(dir);
			return FileSystem.exists(dir);
		} catch (e:Dynamic) {
			diag += "mkdir erro: " + Std.string(e).substr(0, 60) + "\n";
			trace('[Paths] nao consegui criar $dir: $e');
			return false;
		}
	}

	/** Aceita a pasta se der pra criar/abrir e listar. Escrita e so informativa (aparece no diagnostico). */
	static function probe(dir:String):Bool {
		var made = mkdirs(dir);
		var readable = false;
		var writable = false;
		var err = "";
		try {
			FileSystem.readDirectory(dir);
			readable = true;
		} catch (e:Dynamic) {
			err += " rd:" + Std.string(e).substr(0, 30);
		}
		try {
			File.saveContent(dir + ".probe", "ok");
			FileSystem.deleteFile(dir + ".probe");
			writable = true;
		} catch (e:Dynamic) {
			err += " wr:" + Std.string(e).substr(0, 30);
		}
		diag += dir + "\n  criou=" + made + " le=" + readable + " escreve=" + writable + err + "\n";
		return made && readable;
	}

	static function findWritableRoot():String {
		var candidates:Array<String> = [];
		#if android
		candidates.push("/storage/emulated/0/.PoopEngine/");
		candidates.push("/sdcard/.PoopEngine/");
		candidates.push(haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory)); // ultimo recurso (privado)
		#else
		candidates.push(haxe.io.Path.addTrailingSlash(haxe.io.Path.directory(Sys.programPath())));
		candidates.push(haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory));
		#end
		for (c in candidates)
			if (probe(c))
				return c;
		return candidates[candidates.length - 1];
	}
	#end

	/** Cria a pasta (e as pais). Usado pelo editor de chart pra salvar dentro do mod. */
	public static function ensureDir(dir:String):Bool {
		#if sys
		return mkdirs(dir);
		#else
		return false;
		#end
	}

	/** Pasta que contem as subpastas de mods (ex.: /storage/emulated/0/.PoopEngine/mods/). */
	public static function modsDir():String {
		#if sys
		return (rootPath == null ? "" : rootPath) + "mods/";
		#else
		return "";
		#end
	}

	/** Nomes das subpastas de mods (ordem alfabetica). */
	public static function listMods():Array<String> {
		var out:Array<String> = [];
		#if sys
		try {
			for (n in FileSystem.readDirectory(modsDir()))
				if (!StringTools.startsWith(n, ".") && FileSystem.isDirectory(modsDir() + n))
					out.push(n);
		} catch (e:Dynamic) {}
		out.sort(function(a, b) return a.toLowerCase() < b.toLowerCase() ? -1 : 1);
		#end
		return out;
	}

	/** "" = so o jogo base. */
	public static function currentMod():String
		return activeMod;

	/** Troca o mod ativo ("" = nenhum), salva e limpa os caches pra o novo mod valer. */
	public static function setMod(name:String):Void {
		activeMod = name == null ? "" : name;
		FlxG.save.data.mod = activeMod;
		FlxG.save.flush();
		clearCache();
	}

	/** Passa pro proximo mod da lista (base -> mod1 -> mod2 -> ... -> base). Retorna o novo nome. */
	public static function nextMod():String {
		var all = [""].concat(listMods());
		var i = all.indexOf(activeMod);
		setMod(all[(i + 1) % all.length]);
		return activeMod;
	}

	/** Re-escaneia a pasta de mods (e tenta de novo a pasta externa). */
	public static function reload():Void {
		init();
		clearCache();
	}

	public static function clearCache():Void {
		frameCache.clear();
		FlxG.bitmap.clearCache();
		if (Lang.loaded)
			Lang.load(Lang.current); // o mod pode trazer/trocar traducoes
	}

	static function modPath(key:String):String {
		#if sys
		if (activeMod == "")
			return null;
		var p = modsDir() + activeMod + "/" + key;
		if (FileSystem.exists(p) && !FileSystem.isDirectory(p))
			return p;
		#end
		return null;
	}

	static inline function asset(key:String):String
		return "assets/" + key;

	/** Arquivos `<dir>/*.<ext>` (so o nivel direto), no mod ativo e no jogo base, sem repetir. Retorna chaves tipo "data/states/menu/a.hx". */
	public static function list(dir:String, ext:String):Array<String> {
		var out:Array<String> = [];
		var prefix = StringTools.endsWith(dir, "/") ? dir : dir + "/";
		var suffix = "." + ext;
		#if sys
		if (activeMod != "") {
			var d = modsDir() + activeMod + "/" + prefix;
			try {
				if (FileSystem.exists(d) && FileSystem.isDirectory(d))
					for (n in FileSystem.readDirectory(d))
						if (StringTools.endsWith(n, suffix) && out.indexOf(prefix + n) < 0)
							out.push(prefix + n);
			} catch (e:Dynamic) {}
		}
		#end
		var base = "assets/" + prefix;
		for (a in Assets.list()) {
			if (StringTools.startsWith(a, base) && StringTools.endsWith(a, suffix) && a.indexOf("/", base.length) < 0) {
				var k = a.substr(7);
				if (out.indexOf(k) < 0)
					out.push(k);
			}
		}
		out.sort(function(a, b) return a < b ? -1 : 1);
		return out;
	}

	public static function exists(key:String):Bool
		return modPath(key) != null || Assets.exists(asset(key));

	public static function getText(key:String):String {
		var t:String = null;
		#if sys
		var m = modPath(key);
		if (m != null)
			t = File.getContent(m);
		#end
		if (t == null && Assets.exists(asset(key)))
			t = Assets.getText(asset(key));
		if (t != null && t.length > 0 && t.charCodeAt(0) == 0xFEFF)
			t = t.substr(1);
		return t;
	}

	public static function json(key:String):Dynamic {
		var t = getText(key);
		if (t == null)
			return null;
		try {
			return Json.parse(t);
		} catch (e:Dynamic) {
			trace('JSON invalido em $key: $e');
			return null;
		}
	}

	public static function image(key:String):FlxGraphic {
		var id = "images/" + key + ".png";
		var g = FlxG.bitmap.get(id);
		if (g != null)
			return g;
		var bmd:BitmapData = null;
		#if sys
		var m = modPath(id);
		if (m != null)
			bmd = BitmapData.fromFile(m);
		#end
		if (bmd == null && Assets.exists(asset(id)))
			bmd = Assets.getBitmapData(asset(id));
		if (bmd == null) {
			trace('Imagem nao encontrada: $id');
			return null;
		}
		g = FlxG.bitmap.add(bmd, false, id);
		g.persist = true;
		g.destroyOnNoUse = false;
		return g;
	}

	public static function sparrow(key:String):FlxAtlasFrames {
		if (frameCache.exists(key))
			return frameCache.get(key);
		var g = image(key);
		var xml = getText("images/" + key + ".xml");
		if (g == null || xml == null) {
			trace('Atlas nao encontrado: $key');
			return null;
		}
		var f = FlxAtlasFrames.fromSparrow(g, xml);
		frameCache.set(key, f);
		return f;
	}

	public static function audio(id:String):Sound {
		#if sys
		var m = modPath(id);
		if (m != null)
			return Sound.fromFile(m);
		#end
		return Assets.exists(asset(id)) ? Assets.getSound(asset(id)) : null;
	}

	public static inline function sfx(name:String):Sound
		return audio("sounds/" + name + ".ogg");

	public static inline function music(name:String):Sound
		return audio("music/" + name + ".ogg");

	public static inline function font(name:String):String
		return "assets/fonts/" + name;
}

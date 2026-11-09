package;

import haxe.Json;
import haxe.io.Bytes;
import lime.net.HTTPRequest;
#if sys
import sys.io.File;
#end

enum UpdPhase {
	Idle;
	Checking;
	UpToDate;
	Downloading;
	Downloaded;
	Installing;
	NeedPermission;
	Failed(msg:String);
}

/**
 * Baixa o APK da release "nightly" do GitHub (criada pelo workflow) e chama o instalador do Android.
 * UpdateState so le `phase`/`progress`; os callbacks de rede so mexem nessas variaveis.
 */
class Updater {
	public static inline var TAG:String = "nightly";

	public static var phase:UpdPhase = Idle;
	public static var progress:Float = 0;
	public static var loaded:Int = 0;
	public static var total:Int = 0;

	static var session:Int = 0;
	static var assetUrl:String = "";
	static var assetSize:Int = 0;
	static var data:Bytes = null;
	static var apkPath:String = "";

	public static function supported():Bool {
		#if android
		return true;
		#else
		return false;
		#end
	}

	public static function start():Void {
		session++;
		var my = session;
		progress = 0;
		loaded = total = 0;
		data = null;
		if (!supported()) {
			phase = Failed("unsupported");
			return;
		}
		phase = Checking;
		Updates.get("https://api.github.com/repos/" + GitInfo.repo + "/releases/tags/" + TAG, function(text:String) {
			if (my != session)
				return;
			try {
				onRelease(Json.parse(text), my);
			} catch (e:Dynamic) {
				phase = Failed("release: " + Std.string(e).substr(0, 60));
			}
		}, function(_) {
			if (my == session)
				phase = Failed("net " + Updates.lastError);
		});
	}

	public static function cancel():Void {
		session++;
		#if android
		try {
			lime.system.JNI.createStaticMethod("org/poopengine/ApkDownloader", "cancel", "()V")();
		} catch (e:Dynamic) {}
		#end
		data = null;
		phase = Idle;
	}

	static function onRelease(j:Dynamic, my:Int):Void {
		var assets:Array<Dynamic> = j.assets;
		var pick:Dynamic = null;
		if (assets != null)
			for (a in assets)
				if (StringTools.endsWith(Std.string(a.name), ".apk")) {
					pick = a;
					break;
				}
		if (pick == null) {
			phase = Failed("noapk");
			return;
		}
		var re = ~/-([0-9a-f]{7,40})\.apk$/;
		if (re.match(Std.string(pick.name)) && GitInfo.hasCommit && StringTools.startsWith(GitInfo.commit, re.matched(1))) {
			phase = UpToDate;
			return;
		}
		assetUrl = Std.string(pick.browser_download_url);
		assetSize = pick.size == null ? 0 : Std.int(pick.size);
		download(my);
	}

	static function download(my:Int):Void {
		phase = Downloading;
		// mostra o tamanho total desde o inicio (vem do JSON da release), mesmo antes de chegar o 1o byte
		total = assetSize;
		#if android
		try {
			var dir = haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory);
			Paths.ensureDir(dir);
			apkPath = dir + "update.apk";
			var fnStart = lime.system.JNI.createStaticMethod("org/poopengine/ApkDownloader", "start", "(Ljava/lang/String;Ljava/lang/String;)I");
			var fnSize = lime.system.JNI.createStaticMethod("org/poopengine/ApkDownloader", "setTotal", "(I)V");
			fnStart(assetUrl, apkPath);
			fnSize(assetSize);
		} catch (e:Dynamic) {
			phase = Failed("download: " + Std.string(e).substr(0, 60));
		}
		#end
	}

	/** Chamar todo frame enquanto phase == Downloading (UpdateState faz isso). */
	public static function poll():Void {
		#if android
		if (phase != Downloading)
			return;
		try {
			var fnLoaded = lime.system.JNI.createStaticMethod("org/poopengine/ApkDownloader", "loaded", "()I");
			var fnTotal = lime.system.JNI.createStaticMethod("org/poopengine/ApkDownloader", "total", "()I");
			var fnState = lime.system.JNI.createStaticMethod("org/poopengine/ApkDownloader", "state", "()I");
			var fnError = lime.system.JNI.createStaticMethod("org/poopengine/ApkDownloader", "error", "()Ljava/lang/String;");
			loaded = fnLoaded();
			var t:Int = fnTotal();
			if (t > 0)
				total = t;
			progress = total > 0 ? Math.min(1, loaded / total) : 0;
			switch (fnState()) {
				case 1:
					progress = 1;
					phase = Downloaded;
				case 2:
					phase = Failed("download " + Std.string(fnError()));
				default:
			}
		} catch (e:Dynamic) {
			phase = Failed("poll: " + Std.string(e).substr(0, 60));
		}
		#end
	}

	/** Chamar na thread principal (UpdateState faz isso). Tambem serve pra tentar de novo depois de dar a permissao. */
	public static function install():Void {
		#if android
		try {
			if (data != null) {
				var dir = haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory);
				Paths.ensureDir(dir);
				apkPath = dir + "update.apk";
				File.saveBytes(apkPath, data);
				data = null;
			}
			var fn = lime.system.JNI.createStaticMethod("org/poopengine/ApkInstaller", "install", "(Ljava/lang/String;)I");
			var code:Int = fn(apkPath);
			phase = switch (code) {
				case 0: Installing;
				case 1: NeedPermission;
				default: Failed("install");
			};
		} catch (e:Dynamic) {
			phase = Failed("install: " + Std.string(e).substr(0, 60));
		}
		#end
	}
}

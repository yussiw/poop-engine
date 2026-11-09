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
				phase = Failed("net");
		});
	}

	public static function cancel():Void {
		session++;
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
		try {
			var r = new HTTPRequest<Bytes>(assetUrl);
			r.userAgent = "PoopEngine/" + Updates.version();
			r.timeout = 600000;
			var f = r.load();
			f.onProgress(function(l:Int, t:Int) {
				if (my != session)
					return;
				loaded = l;
				total = t > 0 ? t : assetSize;
				progress = total > 0 ? Math.min(1, l / total) : 0;
			});
			f.onComplete(function(b:Bytes) {
				if (my != session)
					return;
				data = b;
				progress = 1;
				phase = Downloaded;
			});
			f.onError(function(e:Dynamic) {
				if (my == session)
					phase = Failed("download");
			});
		} catch (e:Dynamic) {
			phase = Failed("download");
		}
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

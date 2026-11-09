package;

import flixel.FlxG;
import haxe.Json;
import lime.net.HTTPRequest;

enum UpdateStatus {
	Idle;
	Checking;
	UpToDate;
	/** n commits novos no GitHub */
	Behind(n:Int);
	/** esta build tem commits que o GitHub (ainda) nao tem */
	Ahead;
	/** o commit desta build nao existe no GitHub; so mostramos o ultimo de la */
	Unknown;
	Failed;
}

/**
 * Liga a engine ao repositorio do GitHub: sabe de qual commit esta build saiu (GitInfo) e pergunta a API publica do
 * GitHub se existe commit mais novo na branch. Tudo e assincrono; a tela de opcoes (categoria "updates") le os
 * campos daqui e redesenha quando `revision` muda.
 */
class Updates {
	public static var status:UpdateStatus = Idle;
	/** sobe a cada mudanca de estado, pra UI saber que precisa redesenhar */
	public static var revision:Int = 0;
	public static var latestSha:String = "";
	public static var latestMessage:String = "";
	public static var latestDate:String = "";

	static var req:HTTPRequest<String>;

	/** versao do app (Project.xml) */
	public static function version():String {
		var v:String = null;
		try {
			v = lime.app.Application.current.meta.get("version");
		} catch (e:Dynamic) {}
		return v == null || v == "" ? "0.1.0" : v;
	}

	public static function repoUrl():String
		return "https://github.com/" + GitInfo.repo;

	public static function openRepo():Void
		FlxG.openURL(GitInfo.hasCommit ? repoUrl() + "/commit/" + GitInfo.commit : repoUrl());

	static function bump():Void
		revision++;

	/** Pergunta ao GitHub se a branch tem commits depois do desta build. */
	public static function check():Void {
		if (status == Checking)
			return;
		status = Checking;
		bump();
		var api = "https://api.github.com/repos/" + GitInfo.repo;
		if (GitInfo.hasCommit)
			get(api + "/compare/" + GitInfo.commit + "..." + GitInfo.branch, onCompare, function(_) fallbackLatest(api));
		else
			fallbackLatest(api);
	}

	/** Chamado ao abrir a categoria: checa sozinho uma vez por sessao. */
	public static function onOpen():Void {
		if (status == Idle)
			check();
	}

	static function fallbackLatest(api:String):Void {
		get(api + "/commits/" + GitInfo.branch, function(text:String) {
			try {
				var j:Dynamic = Json.parse(text);
				readCommit(j);
				status = GitInfo.hasCommit && j.sha == GitInfo.commit ? UpToDate : Unknown;
			} catch (e:Dynamic) {
				status = Failed;
			}
			bump();
		}, function(_) {
			status = Failed;
			bump();
		});
	}

	static function onCompare(text:String):Void {
		try {
			var j:Dynamic = Json.parse(text);
			var commits:Array<Dynamic> = j.commits;
			if (commits != null && commits.length > 0)
				readCommit(commits[commits.length - 1]); // a lista vem do mais antigo pro mais novo
			var st:String = j.status;
			var n:Int = j.ahead_by == null ? 0 : Std.int(j.ahead_by);
			status = switch (st) {
				case "identical": UpToDate;
				case "behind": Ahead;
				default: n > 0 ? Behind(n) : UpToDate;
			}
		} catch (e:Dynamic) {
			status = Failed;
		}
		bump();
	}

	static function readCommit(c:Dynamic):Void {
		latestSha = c.sha == null ? "" : Std.string(c.sha);
		var cm:Dynamic = c.commit;
		if (cm != null) {
			var msg:String = cm.message == null ? "" : Std.string(cm.message);
			var nl = msg.indexOf("\n");
			latestMessage = nl >= 0 ? msg.substr(0, nl) : msg;
			var who:Dynamic = cm.committer;
			latestDate = who != null && who.date != null ? StringTools.replace(Std.string(who.date).substr(0, 16), "T", " ") : "";
		}
	}

	static function get(url:String, ok:String->Void, fail:Dynamic->Void):Void {
		try {
			var r = new HTTPRequest<String>(url);
			r.userAgent = "PoopEngine/" + version();
			r.timeout = 12000;
			r.headers.push(new lime.net.HTTPRequestHeader("Accept", "application/vnd.github+json"));
			req = r;
			r.load().onComplete(function(t:String) ok(t)).onError(function(e:Dynamic) fail(e));
		} catch (e:Dynamic) {
			fail(e);
		}
	}

	// ------------------------------------------------------------------ texto da tela de opcoes
	static inline function unk():String
		return Lang.get("upd.unknown");

	public static function panelText():String {
		var b = new StringBuf();
		b.add("Poop Engine v" + version() + "\n");
		b.add(Lang.get("upd.commit") + ": " + (GitInfo.hasCommit ? GitInfo.short : unk()) + "   " + Lang.get("upd.branch") + ": " + GitInfo.branch + "\n");
		if (GitInfo.message != "")
			b.add(GitInfo.message + "\n");
		if (GitInfo.author != "" || GitInfo.date != "")
			b.add(Lang.get("upd.by") + " " + (GitInfo.author == "" ? "?" : GitInfo.author) + "  -  " + GitInfo.dateText + "\n");
		b.add(Lang.get("upd.built") + ": " + GitInfo.buildDate + "   " + Lang.get("upd.platform") + ": " + platform() + "\n");
		b.add(Lang.get("upd.repo") + ": " + GitInfo.repo + "\n\n");
		b.add(Lang.get("upd.status") + ": " + statusText());
		if (latestSha != "")
			b.add("\n" + Lang.get("upd.latest") + ": " + latestSha.substr(0, 7) + (latestMessage == "" ? "" : "  " + latestMessage) + (latestDate == "" ? "" : "  (" + latestDate + ")"));
		return b.toString();
	}

	static function statusText():String
		return switch (status) {
			case Idle: Lang.get("upd.status.idle");
			case Checking: Lang.get("upd.status.checking");
			case UpToDate: Lang.get("upd.status.latest");
			case Behind(n): Lang.fmt("upd.status.behind", ["n" => Std.string(n)]);
			case Ahead: Lang.get("upd.status.ahead");
			case Unknown: Lang.get("upd.status.unknown");
			case Failed: Lang.get("upd.status.failed");
		};

	static function platform():String {
		var p = "";
		try {
			p = lime.system.System.platformLabel;
		} catch (e:Dynamic) {}
		return p == null || p == "" ? "?" : p;
	}
}

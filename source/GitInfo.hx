package;

import macros.GitMacro;

class GitInfo {
	public static inline var DEFAULT_REPO:String = "yussiw/poop-engine";

	public static final commit:String = pick(GitMacro.git("rev-parse HEAD"), GitMacro.env("GITHUB_SHA"));
	public static final message:String = GitMacro.git("log -1 --pretty=%s");
	public static final author:String = GitMacro.git("log -1 --pretty=%an");

	public static final date:String = GitMacro.git("log -1 --pretty=%cI");
	public static final buildDate:String = GitMacro.buildDate();
	public static final branch:String = cleanBranch(GitMacro.git("rev-parse --abbrev-ref HEAD"), GitMacro.env("GITHUB_REF_NAME"));
	public static final repo:String = parseRepo(GitMacro.env("GITHUB_REPOSITORY"), GitMacro.git("config --get remote.origin.url"));

	public static var hasCommit(get, never):Bool;
	public static var short(get, never):String;

	public static var dateText(get, never):String;

	static inline function get_hasCommit():Bool
		return commit != "";

	static inline function get_short():String
		return commit == "" ? "" : commit.substr(0, 7);
	static function get_dateText():String
		return date == "" ? "" : StringTools.replace(date.substr(0, 16), "T", " ");
	static function pick(a:String, b:String):String
		return a != "" ? a : b;
	static function cleanBranch(fromGit:String, fromEnv:String):String {
		for (b in [fromGit, fromEnv])
			if (b != "" && b != "HEAD" && b.indexOf("/merge") < 0)
				return b;
		return "main";
	}
	static function parseRepo(envRepo:String, remote:String):String {
		if (envRepo != "")
			return envRepo;
		var re = ~/github\.com[:\/]([^\/]+\/[^\/]+)/;
		if (re.match(remote)) {
			var r = re.matched(1);
			if (StringTools.endsWith(r, ".git"))
				r = r.substr(0, r.length - 4);
			return r;
		}
		return DEFAULT_REPO;
	}
}

package macros;
import haxe.macro.Expr;

class GitMacro {

	public static macro function git(args:String):Expr {
		return macro $v{runGit(args)};
	}
	public static macro function env(name:String):Expr {
		var v = Sys.getEnv(name);
		return macro $v{v == null ? "" : v};
	}
	public static macro function buildDate():Expr {
		return macro $v{DateTools.format(Date.now(), "%Y-%m-%d %H:%M")};
	}
	#if macro
	static function runGit(args:String):String {
		var out = "";
		try {
			var p = new sys.io.Process("git", args.split(" "));
			out = StringTools.trim(p.stdout.readAll().toString());
			var code = p.exitCode();
			p.close();
			if (code != 0)
				out = "";
		} catch (e:Dynamic) {
			out = "";
		}
		return out;
	}
	#end
}

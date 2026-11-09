package macros;

import haxe.macro.Expr;

/**
 * Macros que rodam na COMPILACAO e viram texto fixo dentro do jogo (por isso o app sabe de qual commit foi feito).
 * Sem git no PC (ex.: zip sem a pasta .git) o texto vem vazio e a engine mostra "desconhecido".
 */
class GitMacro {
	/** Resultado de `git <args>` (args separados por espaco). Vazio se o git falhar. Ex.: GitMacro.git("rev-parse HEAD"). */
	public static macro function git(args:String):Expr {
		return macro $v{runGit(args)};
	}

	/** Variavel de ambiente na hora de compilar (o GitHub Actions define GITHUB_SHA, GITHUB_REF_NAME, GITHUB_REPOSITORY). */
	public static macro function env(name:String):Expr {
		var v = Sys.getEnv(name);
		return macro $v{v == null ? "" : v};
	}

	/** Data/hora da compilacao. */
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

package;

import haxe.Json;

class Lang {
	public static var loaded:Bool = false;
	public static var current:String = "pt-BR";
	public static var available:Array<String> = ["pt-BR", "en-US"];

	static var table:Dynamic = {};
	static var fallback:Dynamic = {};

	public static function load(id:String):Void {
		current = id;
		var fb = Paths.json("data/lang/en-US.json");
		fallback = fb == null ? {} : fb;
		var t = id == "en-US" ? fb : Paths.json('data/lang/$id.json');
		table = t == null ? {} : t;
		loaded = true;
	}

	public static function get(key:String, ?def:String):String {
		var v:Dynamic = Reflect.field(table, key);
		if (v == null)
			v = Reflect.field(fallback, key);
		if (v == null)
			return def != null ? def : key;
		return Std.string(v);
	}

	public static function has(key:String):Bool
		return Reflect.field(table, key) != null || Reflect.field(fallback, key) != null;

	public static function fmt(key:String, vars:Map<String, String>):String {
		var s = get(key);
		for (k => v in vars)
			s = StringTools.replace(s, "{" + k + "}", v);
		return s;
	}
}

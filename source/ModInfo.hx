package;

import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef ModContributor = {
	var name:String;
	var role:String;
}

class ModInfo {
	public static inline var META_FILE:String = "_polymod_meta.json";

	public var id:String;

	public var kind:String = "legacy";

	public var name:String;
	public var version:String = "";
	public var link:String = "";
	public var description:String = "";
	public var license:String = "";
	public var apiVersion:String = "";
	public var contributors:Array<ModContributor> = [];

	public var error:String = "";

	public var hasMeta(get, never):Bool;

	function get_hasMeta():Bool
		return kind == "polymod";

	public function new(id:String) {
		this.id = id;
		this.name = id;
	}

	public function authorsText():String
		return contributors.map(function(c) return c.name).join(", ");

	public function authorsWithRoles():String
		return contributors.map(function(c) return c.role == "" ? c.name : c.name + " (" + c.role + ")").join(", ");

	public static function read(id:String, dir:String):ModInfo {
		var m = new ModInfo(id);
		#if sys
		var f = dir + META_FILE;
		try {
			if (!FileSystem.exists(f) || FileSystem.isDirectory(f))
				return m;
		} catch (e:Dynamic) {
			return m;
		}
		m.kind = "polymod";
		try {
			var t = File.getContent(f);
			if (t.length > 0 && t.charCodeAt(0) == 0xFEFF)
				t = t.substr(1);
			m.fill(Json.parse(t));
		} catch (e:Dynamic) {
			m.error = Std.string(e).substr(0, 80);
			trace('[ModInfo] $id: $META_FILE invalido: ${m.error}');
		}
		#end
		return m;
	}

	function fill(j:Dynamic):Void {
		if (j == null)
			return;
		var n = str(j, ["title", "name"]);
		if (n != "")
			name = n;
		version = str(j, ["mod_version", "version"]);
		link = str(j, ["homepage", "link", "url", "website"]);
		description = str(j, ["description", "desc"]);
		license = str(j, ["license"]);
		apiVersion = str(j, ["api_version", "apiVersion"]);

		var list:Dynamic = Reflect.field(j, "contributors");
		if (list == null)
			list = Reflect.field(j, "authors");
		if (list != null && Std.isOfType(list, Array)) {
			for (c in (list : Array<Dynamic>)) {
				if (Std.isOfType(c, String)) {
					addContributor(Std.string(c), "");
				} else if (c != null) {
					addContributor(str(c, ["name", "author"]), str(c, ["role"]));
				}
			}
		}
		if (contributors.length == 0) {
			var a = str(j, ["author"]);
			if (a != "")
				addContributor(a, "");
		}
	}

	function addContributor(n:String, role:String):Void {
		n = StringTools.trim(n);
		if (n != "")
			contributors.push({name: n, role: StringTools.trim(role)});
	}

	static function str(o:Dynamic, keys:Array<String>):String {
		for (k in keys) {
			var v:Dynamic = Reflect.field(o, k);
			if (v != null && !Std.isOfType(v, Array) && Std.string(v) != "")
				return StringTools.trim(Std.string(v));
		}
		return "";
	}
}

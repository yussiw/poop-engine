package;

typedef HLSpan = {begin:Int, end:Int, color:Int};

class HScriptHighlight {
	public static inline var DEFAULT:Int = 0xD4D4D4;
	static inline var KEYWORD:Int = 0xC586C0;
	static inline var STRING:Int = 0xCE9178;
	static inline var NUMBER:Int = 0xB5CEA8;
	static inline var COMMENT:Int = 0x6A9955;
	static inline var FUNC:Int = 0xDCDCAA;
	static inline var TYPE:Int = 0x4EC9B0;
	static inline var BUILTIN:Int = 0x9CDCFE;

	static var keywords:Map<String, Bool> = null;
	static var builtins:Map<String, Bool> = null;

	static function init():Void {
		if (keywords != null)
			return;
		keywords = new Map();
		for (k in [
			"function", "var", "final", "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "return", "new", "null",
			"true", "false", "this", "super", "import", "try", "catch", "throw", "in", "static", "public", "private", "inline", "cast", "untyped",
			"override", "extern", "class", "enum", "typedef"
		])
			keywords.set(k, true);
		builtins = new Map();
		for (b in ["game", "state", "script", "scriptName", "shared", "stateName", "trace"])
			builtins.set(b, true);
	}

	static inline function isDigit(c:Int):Bool
		return c >= 48 && c <= 57;

	static inline function isLetter(c:Int):Bool
		return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 36;

	public static function spans(src:String):Array<HLSpan> {
		init();
		var out:Array<HLSpan> = [];
		var n = src.length;
		var i = 0;
		var prevWord = "";
		while (i < n) {
			var c = src.charCodeAt(i);
			var nx = i + 1 < n ? src.charCodeAt(i + 1) : 0;
			if (c == 47 && nx == 47) {
				var j = i;
				while (j < n && src.charCodeAt(j) != 10)
					j++;
				out.push({begin: i, end: j, color: COMMENT});
				i = j;
				continue;
			}
			if (c == 47 && nx == 42) {
				var j = src.indexOf("*/", i + 2);
				j = j < 0 ? n : j + 2;
				out.push({begin: i, end: j, color: COMMENT});
				i = j;
				continue;
			}
			if (c == 34 || c == 39) {
				var j = i + 1;
				while (j < n && src.charCodeAt(j) != c) {
					if (src.charCodeAt(j) == 92)
						j++;
					j++;
				}
				j = j < n ? j + 1 : n;
				out.push({begin: i, end: j, color: STRING});
				i = j;
				prevWord = "";
				continue;
			}
			if (isDigit(c)) {
				var j = i;
				while (j < n) {
					var d = src.charCodeAt(j);
					var dn = j + 1 < n ? src.charCodeAt(j + 1) : 0;
					if (isDigit(d) || isLetter(d) || (d == 46 && isDigit(dn)))
						j++;
					else
						break;
				}
				out.push({begin: i, end: j, color: NUMBER});
				i = j;
				prevWord = "";
				continue;
			}
			if (isLetter(c)) {
				var j = i;
				while (j < n && (isLetter(src.charCodeAt(j)) || isDigit(src.charCodeAt(j))))
					j++;
				var word = src.substring(i, j);
				var color = -1;
				if (keywords.exists(word))
					color = KEYWORD;
				else if (prevWord == "function")
					color = FUNC;
				else if (builtins.exists(word))
					color = BUILTIN;
				else if (c >= 65 && c <= 90)
					color = TYPE;
				else {
					var k = j;
					while (k < n && (src.charCodeAt(k) == 32 || src.charCodeAt(k) == 9))
						k++;
					if (k < n && src.charCodeAt(k) == 40)
						color = FUNC;
				}
				if (color >= 0)
					out.push({begin: i, end: j, color: color});
				prevWord = word;
				i = j;
				continue;
			}
			if (c != 32 && c != 9 && c != 10 && c != 13)
				prevWord = "";
			i++;
		}
		return out;
	}
}

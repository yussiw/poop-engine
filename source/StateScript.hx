package;
class StateScript {
	public var scripts:Array<Script> = [];
	public function new(state:Dynamic, name:String, ?extra:Map<String, Dynamic>) {
		var keys:Array<String> = ["data/states/global.hx", 'data/states/$name.hx'];
		for (k in Paths.list('data/states/$name', "hx"))
			keys.push(k);
		var seen:Map<String, Bool> = new Map();
		for (k in keys) {
			if (seen.exists(k))
				continue;
			seen.set(k, true);
			var code = Paths.getText(k);
			if (code == null)
				continue;
			var e:Map<String, Dynamic> = extra == null ? new Map() : extra.copy();
			e.set("stateName", name);
			scripts.push(new Script(code, k, state, e));
		}
	}

	public function call(fn:String, ?args:Array<Dynamic>):Bool
		return Script.callAll(scripts, fn, args);
	public function has(fn:String):Bool {
		for (s in scripts)
			if (s.exists(fn))
				return true;
		return false;
	}
}

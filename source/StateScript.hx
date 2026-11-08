package;

/**
 * Scripts de um state/menu. Carrega, em ordem (o mod ativo substitui o arquivo base de mesmo caminho):
 *   data/states/global.hx            (todo state)
 *   data/states/<nome>.hx            (ex.: menu.hx, freeplay.hx, options.hx, modselect.hx, pause.hx)
 *   data/states/<nome>/*.hx          (varios arquivos, opcional)
 * O script enxerga o state como `state` (e seus campos direto: items, bg, cur...) e pode definir
 * onCreate / onCreatePost / onUpdate / onUpdatePost / onDestroy + os eventos de cada state.
 * call() retorna true se algum script chamou cancelEvent().
 */
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

package;

import flixel.FlxG;

/**
 * Definicao de uma opcao. type: "bool" | "int" | "choice" | "info" | "action".
 *   name/desc = chave de traducao (Lang) ou texto literal.
 *   choices (type choice) = ids; o texto mostrado vem da chave "<id>.<choice>" se existir.
 *   info   = linha so de leitura: `value` e uma funcao que devolve o texto mostrado depois do nome.
 *   action = item que executa `action()` ao ser tocado (sem valor salvo).
 */
typedef OptionDef = {
	var id:String;
	var category:String;
	var type:String;
	@:optional var def:Dynamic;
	@:optional var value:Dynamic;
	@:optional var action:Dynamic;
	@:optional var min:Float;
	@:optional var max:Float;
	@:optional var step:Float;
	@:optional var suffix:String;
	@:optional var choices:Array<String>;
	@:optional var name:String;
	@:optional var desc:String;
}

/**
 * Opcoes do jogador (salvas em FlxG.save.data.opts). Chame Options.load() no Main, depois do FlxG.save.bind.
 *
 * Todas as opcoes sao registradas em `defs` e agrupadas por categoria (igual a Codename). Mods e scripts
 * podem criar opcoes novas com Options.register({...}) e ler com Options.get("id").
 * Os campos estaticos abaixo sao so atalhos tipados das opcoes embutidas.
 */
class Options {
	/** ordem das categorias no menu de opcoes. Categorias novas (de mods) entram no fim. */
	public static var categories:Array<String> = ["gameplay", "graphics", "interface", "controls", "language", "updates"];

	/** categorias que mostram um painel de texto (funcao que devolve o texto) em vez de so a lista. Ex.: "updates". */
	public static var infoPanels:Map<String, Void->String> = new Map();

	public static var defs:Array<OptionDef> = [];
	static var values:Map<String, Dynamic> = new Map();

	// ---- atalhos (mantidos em sincronia por sync()) ----
	public static var volume10:Int = 10;
	public static var touchCursor:Bool = false;
	public static var flashing:Bool = true;
	public static var menuLog:Bool = true;
	public static var downscroll:Bool = false;
	public static var ghostTapping:Bool = true;
	public static var splashes:Bool = true;
	public static var camZooming:Bool = true;
	public static var antialiasing:Bool = true;
	public static var shaders:Bool = true;
	public static var lowQuality:Bool = false;
	public static var fpsCounter:Bool = false;
	public static var fps:Int = 60;
	public static var language:String = "pt-BR";

	static var inited:Bool = false;

	static function builtin():Void {
		// gameplay
		register({id: "downscroll", category: "gameplay", type: "bool", def: false});
		register({id: "ghostTapping", category: "gameplay", type: "bool", def: true});
		register({id: "splashes", category: "gameplay", type: "bool", def: true});
		register({id: "camZooming", category: "gameplay", type: "bool", def: true});
		// graficos
		register({id: "antialiasing", category: "graphics", type: "bool", def: true});
		register({id: "lowQuality", category: "graphics", type: "bool", def: false});
		register({id: "shaders", category: "graphics", type: "bool", def: true});
		register({id: "fps", category: "graphics", type: "choice", def: "60", choices: ["30", "60", "90", "120", "144"]});
		register({id: "fpsCounter", category: "graphics", type: "bool", def: false});
		register({id: "flashing", category: "graphics", type: "bool", def: true});
		// interface
		register({id: "menuLog", category: "interface", type: "bool", def: true});
		register({id: "volume", category: "interface", type: "int", def: 10, min: 0, max: 10, step: 1, suffix: "0%"});
		// controles
		register({id: "hitbox", category: "controls", type: "bool", def: false});
		register({id: "touchCursor", category: "controls", type: "bool", def: false});
		// idioma
		register({id: "language", category: "language", type: "choice", def: "pt-BR", choices: Lang.available});
		// atualizacoes (info do commit + checagem no GitHub; ver Updates.hx)
		register({id: "updCheck", category: "updates", type: "action", action: function() Updates.check()});
		register({id: "updGithub", category: "updates", type: "action", action: function() Updates.openRepo()});
		infoPanels.set("updates", Updates.panelText);
	}

	/**
	 * Garante que o valor tem o tipo certo pra opcao. Saves antigos (ou de outra versao da engine) podiam ter, por exemplo,
	 * `true` em "fps"/"volume" e `false` em "language", e a tela mostrava "FRAME RATE: TRUE". Valor invalido volta pro padrao.
	 */
	static function coerce(d:OptionDef, v:Dynamic):Dynamic {
		switch (d.type) {
			case "bool":
				if (Std.isOfType(v, Bool))
					return v;
				if (Std.isOfType(v, String)) {
					var t = Std.string(v).toLowerCase();
					if (t == "true")
						return true;
					if (t == "false")
						return false;
				}
				return d.def == true;
			case "int":
				if (v == null || Std.isOfType(v, Bool))
					return d.def;
				var n = Std.parseFloat(Std.string(v));
				if (Math.isNaN(n))
					return d.def;
				var lo:Float = d.min == null ? -1e9 : d.min;
				var hi:Float = d.max == null ? 1e9 : d.max;
				return Std.int(Math.max(lo, Math.min(hi, n)));
			case "choice":
				if (v == null || !Std.isOfType(v, String))
					return d.def;
				var t = Std.string(v);
				if (d.choices != null && d.choices.indexOf(t) >= 0)
					return t;
				// idiomas vindos de mods so entram em Lang.available depois (ver sync()), entao aceita qualquer texto
				return (d.id == "language" && t != "") ? t : d.def;
			default:
				return v;
		}
	}

	/** Registra (ou substitui) uma opcao. Chamavel de scripts: Options.register({id: "x", category: "mod", type: "bool", def: true}). */
	public static function register(d:OptionDef):Void {
		for (i in 0...defs.length)
			if (defs[i].id == d.id) {
				defs[i] = d;
				if (values.exists(d.id))
					values.set(d.id, coerce(d, values.get(d.id)));
				return;
			}
		defs.push(d);
		if (categories.indexOf(d.category) < 0)
			categories.push(d.category);
		values.set(d.id, values.exists(d.id) ? coerce(d, values.get(d.id)) : d.def);
	}

	public static function find(id:String):OptionDef {
		for (d in defs)
			if (d.id == id)
				return d;
		return null;
	}

	public static function ofCategory(cat:String):Array<OptionDef> {
		return [for (d in defs) if (d.category == cat) d];
	}

	public static function get(id:String):Dynamic {
		if (values.exists(id))
			return values.get(id);
		var d = find(id);
		return d == null ? null : d.def;
	}

	public static function set(id:String, v:Dynamic):Void {
		var d = find(id);
		if (d != null)
			v = coerce(d, v);
		values.set(id, v);
		var o:Dynamic = FlxG.save.data.opts;
		if (o == null) {
			o = {};
			FlxG.save.data.opts = o;
		}
		Reflect.setField(o, id, v);
		FlxG.save.flush();
		sync();
	}

	/** Avanca a opcao pro proximo valor (bool alterna, int cicla min..max, choice cicla a lista). */
	public static function cycle(d:OptionDef, dir:Int = 1):Void {
		switch (d.type) {
			case "info", "action":
				// sem valor pra ciclar (action: use Options.trigger)
				return;
			case "bool":
				set(d.id, !(get(d.id) == true));
			case "int":
				var st = d.step == null || d.step <= 0 ? 1 : d.step;
				var n:Float = Std.parseFloat(Std.string(get(d.id))) + st * dir;
				if (n > d.max)
					n = d.min;
				if (n < d.min)
					n = d.max;
				set(d.id, n);
			default:
				var i = d.choices.indexOf(Std.string(get(d.id)));
				set(d.id, d.choices[(i + dir + d.choices.length) % d.choices.length]);
		}
	}

	/** Texto do valor atual ("on"/"off" traduzidos, numero + sufixo, ou o nome da escolha). */
	public static function valueText(d:OptionDef):String {
		var v = get(d.id);
		return switch (d.type) {
			case "info", "action": d.value != null && Reflect.isFunction(d.value) ? Std.string(Reflect.callMethod(null, d.value, [])) : "";
			case "bool": Lang.get(v == true ? "common.on" : "common.off");
			case "int": Std.string(v) + (d.suffix == null ? "" : d.suffix);
			default: Lang.get(d.id + "." + Std.string(v), Std.string(v));
		}
	}

	/** Executa a funcao de uma opcao do tipo "action". */
	public static function trigger(d:OptionDef):Void {
		if (d.action != null && Reflect.isFunction(d.action))
			Reflect.callMethod(null, d.action, []);
	}

	public static function load():Void {
		if (!inited) {
			inited = true;
			builtin();
		}
		var d = FlxG.save.data;
		// migracao das chaves antigas (antes de existirem categorias)
		var legacy = ["optHitbox" => "hitbox", "optTouchCursor" => "touchCursor", "optFlashing" => "flashing", "optMenuLog" => "menuLog", "optVolume" => "volume"];
		for (k => id in legacy)
			if (Reflect.field(d, k) != null) {
				var v:Dynamic = Reflect.field(d, k);
				var def = find(id);
				values.set(id, def != null ? coerce(def, v) : v);
			}
		var o:Dynamic = d.opts;
		if (o != null)
			for (f in Reflect.fields(o)) {
				var raw:Dynamic = Reflect.field(o, f);
				var def = find(f);
				values.set(f, def == null ? raw : coerce(def, raw));
			}
		sync();
		FlxG.sound.volume = volume10 / 10;
	}

	/** Copia os valores do mapa pros campos estaticos e aplica efeitos globais (fps, idioma, antialiasing...). */
	public static function sync():Void {
		volume10 = Std.int(Math.max(0, Math.min(10, Std.parseFloat(Std.string(get("volume"))))));
		touchCursor = get("touchCursor") == true;
		flashing = get("flashing") == true;
		menuLog = get("menuLog") == true;
		downscroll = get("downscroll") == true;
		ghostTapping = get("ghostTapping") == true;
		splashes = get("splashes") == true;
		camZooming = get("camZooming") == true;
		antialiasing = get("antialiasing") == true;
		shaders = get("shaders") == true;
		lowQuality = get("lowQuality") == true;
		fpsCounter = get("fpsCounter") == true;
		Controls.showHitbox = get("hitbox") == true;
		var f = Std.parseInt(Std.string(get("fps")));
		fps = f == null || f < 15 ? 60 : f;
		var lg = Std.string(get("language"));
		if (Lang.available.indexOf(lg) < 0)
			Lang.available.push(lg);
		if (lg != language || !Lang.loaded) {
			language = lg;
			Lang.load(lg);
		}
		FlxG.sound.volume = volume10 / 10;
		if (FlxG.stage != null) {
			if (fps >= FlxG.updateFramerate) {
				FlxG.updateFramerate = fps;
				FlxG.drawFramerate = fps;
			} else {
				FlxG.drawFramerate = fps;
				FlxG.updateFramerate = fps;
			}
		}
		Main.setFpsVisible(fpsCounter);
	}
}

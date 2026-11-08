package;

import flixel.FlxG;

/**
 * Definicao de uma opcao. type: "bool" | "int" | "choice".
 *   name/desc = chave de traducao (Lang) ou texto literal.
 *   choices (type choice) = ids; o texto mostrado vem da chave "<id>.<choice>" se existir.
 */
typedef OptionDef = {
	var id:String;
	var category:String;
	var type:String;
	var def:Dynamic;
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
	public static var categories:Array<String> = ["gameplay", "graphics", "interface", "controls", "language"];

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
	}

	/** Registra (ou substitui) uma opcao. Chamavel de scripts: Options.register({id: "x", category: "mod", type: "bool", def: true}). */
	public static function register(d:OptionDef):Void {
		for (i in 0...defs.length)
			if (defs[i].id == d.id) {
				defs[i] = d;
				return;
			}
		defs.push(d);
		if (categories.indexOf(d.category) < 0)
			categories.push(d.category);
		if (!values.exists(d.id))
			values.set(d.id, d.def);
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
		if (d != null && d.type == "int")
			v = Std.int(Math.max(d.min, Math.min(d.max, Std.parseFloat(Std.string(v)))));
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
			case "bool": Lang.get(v == true ? "common.on" : "common.off");
			case "int": Std.string(v) + (d.suffix == null ? "" : d.suffix);
			default: Lang.get(d.id + "." + Std.string(v), Std.string(v));
		}
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
				values.set(id, def != null && def.type == "bool" ? v == true : v);
			}
		var o:Dynamic = d.opts;
		if (o != null)
			for (f in Reflect.fields(o))
				values.set(f, Reflect.field(o, f));
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

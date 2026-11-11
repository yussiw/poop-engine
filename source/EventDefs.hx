package;

typedef EvField = {label:String, kind:Int, def:String, step:Float, min:Float, max:Float, opts:Array<String>};
typedef EvDef = {name:String, label:String, short:String, color:Int, f1:EvField, f2:EvField};

/**
 * Definição dos eventos do chart (usada pelo editor). Execução em PlayState.fireEvent.
 * kind: 0 = número, 1 = lista de opções, 2 = id de personagem.
 */
class EventDefs {
	static function num(label:String, def:String, step:Float, min:Float, max:Float):EvField
		return {label: label, kind: 0, def: def, step: step, min: min, max: max, opts: null};

	static function opt(label:String, opts:Array<String>):EvField
		return {label: label, kind: 1, def: opts[0], step: 1, min: 0, max: 0, opts: opts};

	static function chr(label:String):EvField
		return {label: label, kind: 2, def: "bf", step: 1, min: 0, max: 0, opts: null};

	public static var LIST:Array<EvDef> = [
		{name: "Camera Focus", label: "Foco da câmera", short: "CAM", color: 0xFF4C8DFF, f1: num("Slot (-1 = automático)", "-1", 1, -1, 7), f2: null},
		{name: "Camera Zoom", label: "Zoom da câmera", short: "ZM", color: 0xFF3FB950, f1: num("Zoom", "0.9", 0.05, 0.3, 3), f2: num("Duração (s)", "0.5", 0.1, 0, 10)},
		{name: "Zoom Bump", label: "Pulso de zoom", short: "BMP", color: 0xFFD29922, f1: num("Zoom do jogo (+)", "0.03", 0.01, -0.5, 0.5), f2: num("Zoom do HUD (+)", "0.05", 0.01, -0.5, 0.5)},
		{name: "Camera Shake", label: "Tremer câmera", short: "SHK", color: 0xFFE5534B, f1: num("Intensidade", "0.01", 0.005, 0, 0.1), f2: num("Duração (s)", "0.3", 0.1, 0.1, 5)},
		{name: "Camera Flash", label: "Flash", short: "FLS", color: 0xFFBFC7D5, f1: opt("Cor (hex)", ["FFFFFF", "000000", "FF0000", "0000FF", "00FF00", "FFFF00"]), f2: num("Duração (s)", "0.5", 0.1, 0.1, 5)},
		{name: "HUD Alpha", label: "Opacidade do HUD", short: "HUD", color: 0xFFA371F7, f1: num("Opacidade", "0", 0.1, 0, 1), f2: num("Duração (s)", "0.5", 0.1, 0, 10)},
		{name: "Change BPM", label: "Mudar BPM", short: "BPM", color: 0xFFDB6D28, f1: num("BPM", "120", 1, 20, 400), f2: null},
		{name: "Scroll Speed", label: "Velocidade das notas", short: "SPD", color: 0xFF39C5CF, f1: num("Velocidade", "2", 0.1, 0.5, 6), f2: num("Duração (s)", "0", 0.5, 0, 20)},
		{name: "Change Character", label: "Trocar personagem", short: "CHR", color: 0xFFF778BA, f1: num("Slot", "1", 1, 0, 7), f2: chr("Personagem novo")},
		{name: "Play Anim", label: "Animação", short: "ANM", color: 0xFF56D364, f1: num("Slot", "1", 1, 0, 7), f2: opt("Animação", ["hey", "idle", "singLEFT", "singDOWN", "singUP", "singRIGHT"])}
	];

	public static function get(name:String):EvDef {
		for (d in LIST)
			if (d.name == name)
				return d;
		return null;
	}

	public static function charIds():Array<String> {
		var out:Array<String> = [];
		for (p in Paths.list("data/characters", "json")) {
			var n = p.substr(p.lastIndexOf("/") + 1);
			n = n.substr(0, n.length - 5);
			if (out.indexOf(n) < 0)
				out.push(n);
		}
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return out;
	}

	public static function fmt(v:Float):String
		return Std.string(Math.round(v * 1000) / 1000);

	public static function stepVal(f:EvField, cur:String, dir:Int, big:Bool):String {
		var o:Array<String> = f.kind == 1 ? f.opts : (f.kind == 2 ? charIds() : null);
		if (o != null) {
			if (o.length == 0)
				return cur;
			var i = o.indexOf(cur);
			i = i < 0 ? 0 : (i + dir + o.length) % o.length;
			return o[i];
		}
		var v = Std.parseFloat(cur);
		if (Math.isNaN(v))
			v = Std.parseFloat(f.def);
		v += dir * f.step * (big ? 5 : 1);
		return fmt(Math.max(f.min, Math.min(f.max, v)));
	}
}

package;

import flixel.FlxG;

/** Opcoes do jogador (salvas em FlxG.save). Chame Options.load() no Main, depois do FlxG.save.bind. */
class Options {
	/** volume geral em passos de 10% (0..10). */
	public static var volume10:Int = 10;

	/** mostra um cursor + o nome do gesto (toque / cima / baixo / esquerda / direita) so nos menus. */
	public static var touchCursor:Bool = false;

	/** luzes piscando no menu (flicker do magenta e dos itens); desligado = piscadas mais lentas e sem o magenta. */
	public static var flashing:Bool = true;

	/** mostra o log (mod, avisos) ao abrir o menu principal por 3 segundos. */
	public static var menuLog:Bool = true;

	public static function load():Void {
		var d = FlxG.save.data;
		if (d.optHitbox != null)
			Controls.showHitbox = d.optHitbox == true;
		if (d.optTouchCursor != null)
			touchCursor = d.optTouchCursor == true;
		if (d.optFlashing != null)
			flashing = d.optFlashing == true;
		if (d.optMenuLog != null)
			menuLog = d.optMenuLog == true;
		if (d.optVolume != null) {
			volume10 = Std.int(Math.max(0, Math.min(10, Std.int(d.optVolume))));
			FlxG.sound.volume = volume10 / 10;
		}
	}

	static function save(key:String, v:Dynamic):Void {
		Reflect.setField(FlxG.save.data, key, v);
		FlxG.save.flush();
	}

	public static function setHitbox(v:Bool):Void {
		Controls.showHitbox = v;
		save("optHitbox", v);
	}

	public static function setTouchCursor(v:Bool):Void {
		touchCursor = v;
		save("optTouchCursor", v);
	}

	public static function setFlashing(v:Bool):Void {
		flashing = v;
		save("optFlashing", v);
	}

	public static function setMenuLog(v:Bool):Void {
		menuLog = v;
		save("optMenuLog", v);
	}

	public static function setVolume(v:Int):Void {
		volume10 = Std.int(Math.max(0, Math.min(10, v)));
		FlxG.sound.volume = volume10 / 10;
		save("optVolume", volume10);
	}
}

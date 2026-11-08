package;

import flixel.FlxG;

/**
 * Input unificado. Chame Controls.update() no comeco do update() de cada state.
 *
 * GAMEPLAY (hitbox): a tela e dividida em 4 faixas verticais (esq/baixo/cima/dir).
 *   justPressed[i] / pressed[i] / released[i]
 * MENUS (gestos):
 *   swipe pra cima = next, swipe pra baixo = prev, swipe pra direita = swipeRight,
 *   toque = tap (tapX, tapY). back = botao voltar do Android / ESC.
 * No PC: lanes = D F J K, menus = setas / ENTER / ESC (pra testar rapido).
 */
class Controls {
	public static inline var SWIPE_MIN:Float = 60;

	public static var justPressed:Array<Bool> = [false, false, false, false];
	public static var pressed:Array<Bool> = [false, false, false, false];
	public static var released:Array<Bool> = [false, false, false, false];

	/** true = mostra as 4 faixas da hitbox piscando ao tocar (por padrao invisivel pra nao mudar o visual). */
	public static var showHitbox:Bool = false;

	public static var tap:Bool = false;
	public static var tapX:Float = 0;
	public static var tapY:Float = 0;
	public static var next:Bool = false;
	public static var prev:Bool = false;
	public static var swipeRight:Bool = false;
	public static var swipeLeft:Bool = false;
	public static var back:Bool = false;

	static var starts:Map<Int, {x:Float, y:Float}> = new Map();
	static var now:Array<Bool> = [false, false, false, false];

	public static function update():Void {
		tap = next = prev = swipeRight = swipeLeft = back = false;
		for (i in 0...4)
			now[i] = false;

		for (t in FlxG.touches.list)
			pointer(t.touchPointID, t.screenX, t.screenY, t.justPressed, t.pressed, t.justReleased);

		#if !mobile
		pointer(-1, FlxG.mouse.screenX, FlxG.mouse.screenY, FlxG.mouse.justPressed, FlxG.mouse.pressed, FlxG.mouse.justReleased);
		var k = FlxG.keys.pressed;
		if (k.D) now[0] = true;
		if (k.F) now[1] = true;
		if (k.J) now[2] = true;
		if (k.K) now[3] = true;
		var j = FlxG.keys.justPressed;
		if (j.DOWN) next = true;
		if (j.UP) prev = true;
		if (j.ENTER) {
			tap = true;
			tapX = FlxG.width / 2;
			tapY = FlxG.height / 2;
		}
		#end
		if (FlxG.keys.justPressed.ESCAPE)
			back = true;
		#if android
		if (FlxG.android.justReleased.BACK)
			back = true;
		#end

		for (i in 0...4) {
			justPressed[i] = now[i] && !pressed[i];
			released[i] = !now[i] && pressed[i];
			pressed[i] = now[i];
		}
	}

	/** Canto superior direito reservado pro botao de pause (nao conta como lane). */
	public static inline function inPauseZone(x:Float, y:Float):Bool
		return x > FlxG.width - 90 && y < 80;

	static function pointer(id:Int, x:Float, y:Float, jp:Bool, p:Bool, jr:Bool):Void {
		if (jp)
			starts.set(id, {x: x, y: y});
		if (p && !inPauseZone(x, y))
			now[Std.int(Math.max(0, Math.min(3, Math.floor(x / (FlxG.width / 4)))))] = true;
		if (jr && starts.exists(id)) {
			var s = starts.get(id);
			starts.remove(id);
			var dx = x - s.x;
			var dy = y - s.y;
			if (Math.sqrt(dx * dx + dy * dy) < SWIPE_MIN) {
				tap = true;
				tapX = x;
				tapY = y;
			} else if (Math.abs(dx) > Math.abs(dy)) {
				if (dx > 0)
					swipeRight = true;
				else
					swipeLeft = true;
			} else if (dy < 0)
				next = true;
			else
				prev = true;
		}
	}
}

package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import states.ChartEditorState;
import states.PlayState;

/**
 * Cursor de toque so pros menus (opcao "cursor" em OptionsState): mostra um anel no dedo, uma linha desde onde o
 * toque comecou e o nome do gesto (TOQUE / CIMA / BAIXO / ESQUERDA / DIREITA, com o mesmo limite do Controls).
 * Nao aparece no PlayState nem no ChartEditorState. Desenha numa camera propria, entao fica por cima de tudo da tela.
 *
 * Main chama TouchCursor.init() uma vez; a cada troca de state ele se anexa sozinho ao state novo.
 */
class TouchCursor extends FlxGroup {
	static inline var HOLD:Float = 0.7; // segundos que o gesto continua na tela depois de soltar (com fade)

	static var hooked:Bool = false;

	public static function init():Void {
		if (hooked)
			return;
		hooked = true;
		FlxG.signals.postStateSwitch.add(attach);
		if (FlxG.state != null)
			attach();
	}

	static function attach():Void {
		var st = FlxG.state;
		if (st == null || Std.isOfType(st, PlayState) || Std.isOfType(st, ChartEditorState))
			return;
		st.add(new TouchCursor());
	}

	var cam:FlxCamera;
	var trail:FlxSprite;
	var startDot:FlxSprite;
	var ring:FlxSprite;
	var label:FlxText;
	var all:Array<FlxSprite>;

	var down:Bool = false;
	var sx:Float = 0;
	var sy:Float = 0;
	var cx:Float = 0;
	var cy:Float = 0;
	var holdT:Float = 0;
	var activeId:Int = -1000;

	public function new() {
		super();
		cam = new FlxCamera();
		cam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(cam, false);

		// linha: 1 x 6 px esticada em X e girada em volta da ponta esquerda
		trail = new FlxSprite().makeGraphic(1, 6, FlxColor.WHITE);
		trail.origin.set(0, 3);
		trail.alpha = 0.6;

		startDot = new FlxSprite().makeGraphic(24, 24, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(startDot, 12, 12, 10, FlxColor.WHITE);

		ring = new FlxSprite().makeGraphic(72, 72, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(ring, 36, 36, 32, 0x66FFFFFF, {thickness: 5, color: FlxColor.WHITE});

		label = new FlxText(0, 0, 0, "", 24);
		label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 2;

		all = [trail, startDot, ring, label];
		for (s in all) {
			s.scrollFactor.set();
			s.cameras = [cam];
			s.antialiasing = true;
			s.visible = false;
			add(s);
		}
	}

	function hideAll():Void {
		for (s in all)
			s.visible = false;
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);
		if (!Options.touchCursor) {
			down = false;
			holdT = 0;
			hideAll();
			return;
		}

		// um ponteiro so: o primeiro toque ativo (ou o mouse, no PC, pra testar)
		var found = false;
		var px:Float = 0;
		var py:Float = 0;
		var jp = false;
		var jr = false;
		for (t in FlxG.touches.list) {
			if (!(t.justPressed || t.pressed || t.justReleased))
				continue;
			if (!found || t.touchPointID == activeId) {
				found = true;
				px = t.screenX;
				py = t.screenY;
				jp = t.justPressed;
				jr = t.justReleased;
				activeId = t.touchPointID;
			}
		}
		#if !mobile
		if (!found) {
			var m = FlxG.mouse;
			if (m.justPressed || m.pressed || m.justReleased) {
				found = true;
				px = m.screenX;
				py = m.screenY;
				jp = m.justPressed;
				jr = m.justReleased;
			}
		}
		#end

		if (found) {
			if (jp || !down) {
				down = true;
				sx = px;
				sy = py;
			}
			cx = px;
			cy = py;
			holdT = HOLD;
			if (jr)
				down = false; // soltou: o gesto fica na tela por HOLD segundos e some com fade
		} else {
			down = false;
			holdT = Math.max(0, holdT - elapsed);
		}

		if (!down && holdT <= 0) {
			hideAll();
			return;
		}

		var dx = cx - sx;
		var dy = cy - sy;
		var d = Math.sqrt(dx * dx + dy * dy);
		var swipe = d >= Controls.SWIPE_MIN;
		var name = "TOQUE";
		if (swipe) {
			if (Math.abs(dx) > Math.abs(dy))
				name = dx > 0 ? "DIREITA" : "ESQUERDA";
			else
				name = dy < 0 ? "CIMA" : "BAIXO";
		}
		var a = down ? 1.0 : holdT / HOLD;
		var tint:FlxColor = FlxColor.WHITE;
		if (swipe)
			tint = 0xFF99FFBB;

		ring.visible = true;
		ring.alpha = a;
		ring.color = tint;
		ring.setPosition(cx - 36, cy - 36);

		var showLine = d > 8;
		trail.visible = startDot.visible = showLine;
		if (showLine) {
			trail.scale.x = d;
			trail.angle = Math.atan2(dy, dx) * 180 / Math.PI;
			trail.setPosition(sx, sy - 3);
			trail.alpha = 0.6 * a;
			trail.color = tint;
			startDot.setPosition(sx - 12, sy - 12);
			startDot.alpha = 0.8 * a;
			startDot.color = tint;
		}

		label.visible = true;
		label.text = name;
		label.alpha = a;
		label.color = tint;
		label.x = Math.max(8, Math.min(FlxG.width - label.width - 8, cx + 44));
		label.y = Math.max(8, Math.min(FlxG.height - label.height - 8, cy - 70));
	}
}

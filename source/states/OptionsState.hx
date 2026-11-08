package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * Opcoes: hitbox, volume, cursor de toque, luzes piscando, log do menu.
 * Deslizar cima/baixo escolhe, toque no item selecionado muda o valor,
 * deslizar pra direita (ou voltar) retorna ao menu. Tudo e salvo na hora (ver Options.hx).
 */
class OptionsState extends FlxState {
	static inline var COUNT:Int = 5;

	var grp:FlxTypedGroup<Alphabet>;
	var cur:Int = 0;
	var leaving:Bool = false;

	override function create():Void {
		super.create();
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);

		var bg = new FlxSprite(0, 0, Paths.image("menus/menuDesat"));
		bg.color = 0xFFEA71FD;
		bg.antialiasing = true;
		add(bg);

		grp = new FlxTypedGroup<Alphabet>();
		add(grp);
		for (i in 0...COUNT) {
			var a = new Alphabet(0, 70 * i + 30, label(i));
			a.isMenuItem = true;
			a.targetY = i;
			grp.add(a);
		}

		var title = new FlxText(10, 8, FlxG.width - 20, "OPCOES", 28);
		title.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(title);

		var hint = new FlxText(10, FlxG.height - 30, FlxG.width - 20, "cima/baixo = escolher | toque = mudar | direita = voltar", 18);
		hint.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(hint);

		change(0);
	}

	function label(i:Int):String {
		return switch (i) {
			case 0: "hitbox: " + onOff(Controls.showHitbox);
			case 1: "volume: " + (Options.volume10 * 10);
			case 2: "cursor: " + onOff(Options.touchCursor);
			case 3: "flash: " + onOff(Options.flashing);
			default: "log: " + onOff(Options.menuLog);
		}
	}

	inline function onOff(v:Bool):String
		return v ? "on" : "off";

	/** O Alphabet nao troca de texto: recria o item na mesma posicao. */
	function refresh(i:Int):Void {
		var old = grp.members[i];
		var a = new Alphabet(old.x, old.y, label(i));
		a.isMenuItem = true;
		a.targetY = old.targetY;
		a.alpha = old.alpha;
		grp.remove(old, true);
		old.destroy();
		grp.insert(i, a);
	}

	function change(c:Int):Void {
		if (c != 0)
			FlxG.sound.play(Paths.sfx("menu/scroll"), 0.4);
		cur = (cur + c + COUNT) % COUNT;
		var n = 0;
		for (a in grp.members) {
			a.targetY = n - cur;
			a.alpha = a.targetY == 0 ? 1 : 0.6;
			n++;
		}
	}

	function toggle(i:Int):Void {
		switch (i) {
			case 0:
				Options.setHitbox(!Controls.showHitbox);
			case 1:
				Options.setVolume((Options.volume10 + 1) % 11);
			case 2:
				Options.setTouchCursor(!Options.touchCursor);
			case 3:
				Options.setFlashing(!Options.flashing);
			default:
				Options.setMenuLog(!Options.menuLog);
		}
		FlxG.sound.play(Paths.sfx("menu/scroll"), 0.6);
		refresh(i);
	}

	function back():Void {
		if (leaving)
			return;
		leaving = true;
		FlxG.sound.play(Paths.sfx("menu/cancel"), 0.6);
		TransitionSubState.go(new MainMenuState());
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		if (leaving)
			return;
		if (Controls.swipeRight || Controls.back) {
			back();
			return;
		}
		if (Controls.next)
			change(1);
		if (Controls.prev)
			change(-1);
		if (Controls.tap) {
			for (i in 0...grp.members.length) {
				var a = grp.members[i];
				if (Controls.tapY > a.y - 10 && Controls.tapY < a.y + 95) {
					if (i == cur)
						toggle(i);
					else {
						cur = i;
						change(0);
						FlxG.sound.play(Paths.sfx("menu/scroll"), 0.4);
					}
					break;
				}
			}
		}
	}
}

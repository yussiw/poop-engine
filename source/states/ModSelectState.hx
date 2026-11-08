package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * Selecao de mod. Lista: (base) + subpastas de mods/. Deslizar cima/baixo troca, toque no item selecionado aplica,
 * deslizar pra direita (ou voltar) cancela. Deslizar pra esquerda recarrega a lista de pastas.
 */
class ModSelectState extends FlxState {
	var names:Array<String> = [];
	var cur:Int = 0;
	var grp:FlxTypedGroup<Alphabet>;
	var activeTxt:FlxText;
	var leaving:Bool = false;

	override function create():Void {
		super.create();
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);

		var bg = new FlxSprite(0, 0, Paths.image("menus/menuDesat"));
		bg.color = 0xFF9271FD;
		bg.antialiasing = true;
		add(bg);

		names = [""].concat(Paths.listMods());
		cur = Std.int(Math.max(0, names.indexOf(Paths.currentMod())));

		grp = new FlxTypedGroup<Alphabet>();
		add(grp);
		for (i in 0...names.length) {
			var label = names[i] == "" ? "base" : names[i];
			var a = new Alphabet(0, 70 * i + 30, label);
			if (a.members.length == 0)
				a = new Alphabet(0, 70 * i + 30, "mod " + i); // nome so com caracteres que a fonte nao tem
			a.isMenuItem = true;
			a.targetY = i;
			grp.add(a);
		}

		activeTxt = new FlxText(10, 8, FlxG.width - 20, "", 24);
		activeTxt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(activeTxt);

		var hint = new FlxText(10, FlxG.height - 52, FlxG.width - 20, "", 18);
		hint.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hint.text = "cima/baixo = escolher | toque no selecionado = aplicar\ndireita = voltar | esquerda = recarregar lista\n" + Paths.modsDir();
		hint.y = FlxG.height - hint.height - 6;
		add(hint);

		change(0);
	}

	function change(c:Int):Void {
		if (c != 0)
			FlxG.sound.play(Paths.sfx("menu/scroll"), 0.4);
		cur = (cur + c + names.length) % names.length;
		var n = 0;
		for (a in grp.members) {
			a.targetY = n - cur;
			a.alpha = a.targetY == 0 ? 1 : 0.6;
			n++;
		}
		var act = Paths.currentMod();
		activeTxt.text = "MOD ATIVO: " + (act == "" ? "(base)" : act) + (names.length == 1 ? "   -   nenhum mod encontrado" : "");
	}

	function accept():Void {
		if (leaving)
			return;
		leaving = true;
		FlxG.sound.play(Paths.sfx("menu/confirm"), 0.7);
		var chosen = names[cur];
		if (chosen != Paths.currentMod())
			Paths.setMod(chosen);
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop(); // a musica do menu pode vir do mod
		TransitionSubState.go(new MainMenuState());
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		if (leaving)
			return;
		if (Controls.next || FlxG.keys.justPressed.DOWN)
			change(1);
		if (Controls.prev || FlxG.keys.justPressed.UP)
			change(-1);
		if (Controls.swipeRight || Controls.back) {
			FlxG.sound.play(Paths.sfx("menu/cancel"), 0.6);
			TransitionSubState.go(new MainMenuState());
			return;
		}
		if (Controls.swipeLeft) {
			Paths.reload();
			FlxG.resetState();
			return;
		}
		if (Controls.tap) {
			for (i in 0...grp.members.length) {
				var it = grp.members[i];
				if (Math.abs(Controls.tapY - (it.y + it.height / 2)) < 55) {
					if (i == cur)
						accept();
					else
						change(i - cur);
					break;
				}
			}
		}
	}
}

package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/** Escolha da musica pro editor de chart: "+ nova musica" + as musicas do songlist.json do mod ativo (ou da base). */
class ChartPickState extends FlxState {
	var ids:Array<String> = [""];
	var names:Array<String> = ["+ nova musica"];
	var cur:Int = 0;
	var grp:FlxTypedGroup<Alphabet>;
	var leaving:Bool = false;

	override function create():Void {
		super.create();
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);

		var bg = new FlxSprite(0, 0, Paths.image("menus/menuDesat"));
		bg.color = 0xFF55AA77;
		bg.antialiasing = true;
		add(bg);

		var list:Array<Dynamic> = Paths.json("data/songlist.json");
		if (list != null)
			for (e in list) {
				ids.push(Std.string(e.id));
				names.push(e.name != null ? Std.string(e.name) : Std.string(e.id));
			}

		grp = new FlxTypedGroup<Alphabet>();
		add(grp);
		for (i in 0...names.length) {
			var a = new Alphabet(0, 70 * i + 30, names[i]);
			if (a.members.length == 0)
				a = new Alphabet(0, 70 * i + 30, "musica " + i);
			a.isMenuItem = true;
			a.targetY = i;
			grp.add(a);
		}

		var mod = Paths.currentMod();
		var top = new FlxText(16, 12, FlxG.width - 32, "Editor de chart - Mod: " + (mod == "" ? "(base)" : mod), 22);
		top.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		top.antialiasing = true;
		add(top);

		var hint = new FlxText(16, 0, FlxG.width - 32, "", 16);
		hint.setFormat(Paths.font("vcr.ttf"), 16, mod == "" ? 0xFFFFE066 : FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hint.antialiasing = true;
		hint.text = (mod == "" ? "Atencao: nenhum mod ativo, entao nao da pra salvar. Escolha um mod no menu principal (deslize pra esquerda).\n" : "")
			+ "Cima/baixo: escolher | Toque no selecionado: abrir | Direita: voltar";
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
	}

	function accept():Void {
		if (leaving)
			return;
		leaving = true;
		FlxG.sound.play(Paths.sfx("menu/confirm"), 0.7);
		if (cur == 0) {
			var n = 1;
			while (Paths.exists('songs/nova-musica-$n/chart.json'))
				n++;
			ChartEditorState.isNew = true;
			ChartEditorState.songId = 'nova-musica-$n';
			ChartEditorState.newName = 'Nova Musica $n';
		} else {
			ChartEditorState.isNew = false;
			ChartEditorState.songId = ids[cur];
		}
		TransitionSubState.go(new ChartEditorState());
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		if (leaving)
			return;
		if (Controls.next)
			change(1);
		if (Controls.prev)
			change(-1);
		if (Controls.swipeRight || Controls.back) {
			FlxG.sound.play(Paths.sfx("menu/cancel"), 0.6);
			TransitionSubState.go(new MainMenuState());
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

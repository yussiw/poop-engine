package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * Opcoes em categorias (igual a Codename): primeiro a lista de categorias, depois as opcoes da categoria.
 * Deslizar cima/baixo escolhe, toque no item selecionado abre/muda o valor, deslizar pra direita (ou voltar)
 * sobe um nivel. Tudo e salvo na hora (ver Options.hx). Os textos vem do Lang (idioma escolhido).
 *
 * Mods: data/states/options.hx pode registrar opcoes/categorias novas (Options.register) em onCreate.
 */
class OptionsState extends FlxState {
	var grp:FlxTypedGroup<Alphabet>;
	var cur:Int = 0;
	var catCur:Int = 0;
	var inCategory:Bool = false;
	var category:String = "";
	var leaving:Bool = false;
	var entries:Array<String> = [];
	var title:FlxText;
	var hint:FlxText;
	var desc:FlxText;
	var scripts:StateScript;

	override function create():Void {
		super.create();
		scripts = new StateScript(this, "options");
		scripts.call("onCreate");
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);

		var bg = new FlxSprite(0, 0, Paths.image("menus/menuDesat"));
		bg.color = 0xFFEA71FD;
		bg.antialiasing = Options.antialiasing;
		add(bg);

		grp = new FlxTypedGroup<Alphabet>();
		add(grp);

		title = new FlxText(10, 8, FlxG.width - 20, "", 28);
		title.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(title);

		hint = new FlxText(10, FlxG.height - 30, FlxG.width - 20, "", 18);
		hint.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(hint);

		desc = new FlxText(10, FlxG.height - 62, FlxG.width - 20, "", 20);
		desc.setFormat(Paths.font("vcr.ttf"), 20, 0xFFFFFF99, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(desc);

		build(true);
		scripts.call("onCreatePost");
	}

	// ------------------------------------------------------------------ montagem
	function catName(c:String):String
		return Lang.get("cat." + c, c);

	function optionLabel(d:OptionDef):String
		return Lang.get("opt." + d.id, d.name != null ? Lang.get(d.name) : d.id) + ": " + Options.valueText(d);

	function build(snap:Bool = false):Void {
		for (a in grp.members)
			if (a != null)
				a.destroy();
		grp.clear();
		entries = [];
		if (!inCategory) {
			for (c in Options.categories)
				if (Options.ofCategory(c).length > 0)
					entries.push(c);
			title.text = Lang.get("options.title");
			hint.text = Lang.get("options.hint.category");
		} else {
			for (d in Options.ofCategory(category))
				entries.push(d.id);
			title.text = Lang.get("options.title") + " > " + catName(category).toUpperCase();
			hint.text = Lang.get("options.hint");
		}
		for (i in 0...entries.length) {
			var a = new Alphabet(0, 70 * i + 30, label(i));
			a.isMenuItem = true;
			a.targetY = i;
			grp.add(a);
		}
		cur = Std.int(Math.min(cur, entries.length - 1));
		change(0);
		if (snap)
			for (a in grp.members) {
				a.y = a.targetY * 1.3 * 120 + FlxG.height * 0.48;
				a.x = a.targetY * 20 + 90;
			}
	}

	function label(i:Int):String
		return inCategory ? optionLabel(Options.find(entries[i])) : catName(entries[i]);

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
		if (entries.length == 0)
			return;
		if (c != 0)
			FlxG.sound.play(Paths.sfx("menu/scroll"), 0.4);
		cur = (cur + c + entries.length) % entries.length;
		var n = 0;
		for (a in grp.members) {
			a.targetY = n - cur;
			a.alpha = a.targetY == 0 ? 1 : 0.6;
			n++;
		}
		if (inCategory) {
			var d = Options.find(entries[cur]);
			desc.text = Lang.get("opt." + d.id + ".desc", d.desc != null ? Lang.get(d.desc) : "");
		} else
			desc.text = "";
		scripts.call("onChange", [cur, entries[cur]]);
	}

	function accept(i:Int):Void {
		if (!inCategory) {
			if (scripts.call("onOpenCategory", [entries[i]]))
				return;
			catCur = cur;
			category = entries[i];
			inCategory = true;
			cur = 0;
			FlxG.sound.play(Paths.sfx("menu/scroll"), 0.6);
			build(true);
			return;
		}
		var d = Options.find(entries[i]);
		Options.cycle(d);
		scripts.call("onOptionChanged", [d.id, Options.get(d.id)]);
		FlxG.sound.play(Paths.sfx("menu/scroll"), 0.6);
		if (d.id == "language") {
			build(); // todos os textos mudam de idioma
			return;
		}
		refresh(i);
	}

	function back():Void {
		if (leaving)
			return;
		FlxG.sound.play(Paths.sfx("menu/cancel"), 0.6);
		if (inCategory) {
			inCategory = false;
			cur = catCur;
			build(true);
			return;
		}
		leaving = true;
		TransitionSubState.go(new MainMenuState());
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		scripts.call("onUpdate", [elapsed]);
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
						accept(i);
					else {
						cur = i;
						change(0);
						FlxG.sound.play(Paths.sfx("menu/scroll"), 0.4);
					}
					break;
				}
			}
		}
		scripts.call("onUpdatePost", [elapsed]);
	}

	override function destroy():Void {
		scripts.call("onDestroy");
		super.destroy();
	}
}

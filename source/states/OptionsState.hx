package states;

import Options.OptionDef;
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
 * Opcoes "bool" mostram o nome + a caixinha (assets/images/menus/options/checkbox); "int"/"choice" mostram "nome: valor";
 * "action" so o nome (toque executa). Categorias com painel (Options.infoPanels, ex.: "updates") mostram um texto fixo em cima.
 *
 * Mods: data/states/options.hx pode registrar opcoes/categorias novas (Options.register) em onCreate.
 */
class OptionsState extends FlxState {
	var grp:FlxTypedGroup<Alphabet>;
	var checks:FlxTypedGroup<Checkbox>;
	var checkOf:Map<Int, Checkbox> = new Map();
	var panelBG:FlxSprite;
	var panel:FlxText;
	var panelRev:Int = -1;
	var panelFn:Void->String = null;
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
		checks = new FlxTypedGroup<Checkbox>();
		add(checks);

		panelBG = new FlxSprite(30, 56).makeGraphic(FlxG.width - 60, 330, FlxColor.fromRGB(0, 0, 0, 140));
		panelBG.visible = false;
		add(panelBG);
		panel = new FlxText(46, 66, FlxG.width - 92, "", 22);
		panel.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		panel.visible = false;
		add(panel);

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

	function optionName(d:OptionDef):String
		return Lang.get("opt." + d.id, d.name != null ? Lang.get(d.name) : d.id);

	/** bool = so o nome (a caixinha mostra o valor); action = so o nome; o resto = "nome: valor". */
	function optionLabel(d:OptionDef):String {
		if (d.type == "bool" || d.type == "action")
			return optionName(d);
		return optionName(d) + ": " + Options.valueText(d);
	}

	function build(snap:Bool = false):Void {
		for (a in grp.members)
			if (a != null)
				a.destroy();
		grp.clear();
		for (c in checks.members)
			if (c != null)
				c.destroy();
		checks.clear();
		checkOf = new Map();
		entries = [];
		panelFn = inCategory ? Options.infoPanels.get(category) : null;
		panelBG.visible = panel.visible = panelFn != null;
		panelRev = -1;
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
			a.isMenuItem = panelFn == null;
			a.targetY = i;
			if (panelFn != null) {
				// categoria com painel: itens fixos embaixo do texto (sem a rolagem)
				a.x = 90;
				a.y = 430 + i * 100;
			}
			grp.add(a);
			addCheck(i, a);
		}
		cur = Std.int(Math.min(cur, entries.length - 1));
		change(0);
		if (snap && panelFn == null)
			for (a in grp.members) {
				a.y = a.targetY * 1.3 * 120 + FlxG.height * 0.48;
				a.x = a.targetY * 20 + 90;
			}
		if (panelFn != null)
			refreshPanel();
	}

	/** Opcao bool = caixinha ao lado do texto. */
	function addCheck(i:Int, a:Alphabet):Void {
		if (!inCategory)
			return;
		var d = Options.find(entries[i]);
		if (d == null || d.type != "bool")
			return;
		var c = new Checkbox(Options.get(d.id) == true);
		c.sprTracker = a;
		checks.add(c);
		checkOf.set(i, c);
	}

	function refreshPanel():Void {
		if (panelFn == null)
			return;
		panelRev = Updates.revision;
		panel.text = panelFn();
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
		var c = checkOf.get(i);
		if (c != null)
			c.sprTracker = a;
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
			a.alpha = n == cur ? 1 : 0.6;
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
			if (category == "updates")
				Updates.onOpen(); // checa o GitHub sozinho (uma vez por sessao)
			return;
		}
		var d = Options.find(entries[i]);
		if (d.type == "info")
			return;
		FlxG.sound.play(Paths.sfx("menu/scroll"), 0.6);
		if (d.type == "action") {
			Options.trigger(d);
			scripts.call("onOptionChanged", [d.id, null]);
			if (panelFn != null)
				refreshPanel();
			return;
		}
		Options.cycle(d);
		scripts.call("onOptionChanged", [d.id, Options.get(d.id)]);
		if (d.id == "language") {
			build(); // todos os textos mudam de idioma
			return;
		}
		var c = checkOf.get(i);
		if (c != null) {
			c.setChecked(Options.get(d.id) == true); // bool: so a caixinha muda (o texto e o mesmo)
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
		if (panelFn != null && panelRev != Updates.revision)
			refreshPanel();
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

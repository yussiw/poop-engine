package states;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

/**
 * Menu principal no estilo da Codename Engine (funkin/menus/MainMenuState.hx):
 * - fundo menuBG com scrollFactor Y 0.18 e escala 1.15; magenta = menuDesat tingido de 0xFFFD719B
 * - itens em y = 60 + i * 160, centralizados em X; o frame "selected" cresce a partir do topo (updateHitbox + centerOffsets)
 * - camera segue o item selecionado com lerp 0.06 (so o fundo se mexe de verdade)
 * - texto de versao no canto inferior esquerdo; tocar nele abre a selecao de mod (igual o clique na Codename)
 * Navegacao: swipe cima/baixo, toque no item selecionado confirma.
 */
class MainMenuState extends FlxState {
	static var lastCur:Int = 0;

	/**
	 * Itens do menu. Scripts (data/states/menu.hx) podem mudar a lista em onCreate:
	 *   menuItems.push({id: "meu", file: "menu_meu", idle: "meu idle", selected: "meu selected", action: "options"});
	 * file = atlas em images/menus/mainmenu/<file>.xml; action = nome de state ("freeplay", "options", "mods", "editor",
	 * "credits", "menu"...) ou uma funcao do script. Sem action, usa o id.
	 */
	public var menuItems:Array<MenuItemDef> = [
		{id: "story", file: "menu_story_mode", idle: "story_mode idle", selected: "story_mode selected", action: "credits"},
		{id: "freeplay", file: "freeplay", idle: "freeplay basic", selected: "freeplay white", action: "freeplay"},
		{id: "options", file: "options", idle: "options basic", selected: "options white", action: "options"},
		{id: "credits", file: "menu_credits", idle: "credits idle", selected: "credits selected", action: "credits"}
	];
	public var itemStartY:Float = 60;
	public var itemSpacing:Float = 160;
	public var cur:Int = 0;
	public var items:FlxTypedGroup<FlxSprite>;
	public var bg:FlxSprite;
	public var magenta:FlxSprite;
	public var camFollow:FlxObject;
	public var versionTxt:FlxText;
	public var selected:Bool = false;
	var scripts:StateScript;
	var retryTimer:Float = 0;
	var logBG:FlxSprite;
	var logTxt:FlxText;

	/** quanto os itens acompanham a camera no eixo Y (0 = parados, igual a Codename; o fundo usa 0.18). */
	static inline var ITEM_SCROLL:Float = 0.06;
	static inline var LOG_TIME:Float = 3; // segundos que o log fica visivel antes do fade
	static inline var LOG_FADE:Float = 0.6;

	override function create():Void {
		super.create();
		cur = lastCur;
		scripts = new StateScript(this, "menu");
		scripts.call("onCreate");
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);

		bg = new FlxSprite(-80, 0, Paths.image("menus/menuBG"));
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80, 0, Paths.image("menus/menuDesat"));
		magenta.visible = false;
		magenta.color = 0xFFFD719B;
		add(magenta);

		for (b in [bg, magenta]) {
			b.scrollFactor.set(0, 0.18);
			b.scale.set(1.15, 1.15);
			b.updateHitbox();
			b.screenCenter();
			b.antialiasing = Options.antialiasing;
		}

		items = new FlxTypedGroup<FlxSprite>();
		add(items);
		for (i in 0...menuItems.length) {
			var s = new FlxSprite(0, itemStartY + i * itemSpacing);
			s.frames = Paths.sparrow("menus/mainmenu/" + menuItems[i].file);
			s.animation.addByPrefix("idle", menuItems[i].idle, 24, true);
			s.animation.addByPrefix("selected", menuItems[i].selected, 24, true);
			s.animation.play("idle");
			s.ID = i;
			s.screenCenter(X);
			s.scrollFactor.set(0, ITEM_SCROLL);
			s.antialiasing = Options.antialiasing;
			items.add(s);
		}

		FlxG.camera.follow(camFollow, null, 0.06);

		versionTxt = new FlxText(12, FlxG.height - 46, 0, "Friday Night Funkin' v0.2.8\nPoop Engine v0.1", 16);
		versionTxt.scrollFactor.set();
		versionTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionTxt.y = FlxG.height - versionTxt.height - 4;
		add(versionTxt);

		var edTxt = new FlxText(10, 6, 0, Lang.get("menu.editor"), 18);
		edTxt.scrollFactor.set();
		edTxt.setFormat(Paths.font("vcr.ttf"), 18, 0xFF99FFBB, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(edTxt);

		// log temporario (mod, avisos, diagnostico): aparece ao abrir o menu, fica LOG_TIME segundos e some com fade
		logBG = new FlxSprite(FlxG.width - 576, 4);
		logBG.scrollFactor.set();
		add(logBG);
		logTxt = new FlxText(FlxG.width - 568, 10, 552, "", 16);
		logTxt.scrollFactor.set();
		logTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(logTxt);
		buildLog();
		if (Options.menuLog || !Paths.externalReady)
			showLog();
		else
			logTxt.alpha = logBG.alpha = 0;

		changeItem(0);
		scripts.call("onCreatePost");
	}

	/** Monta o texto do log. Nao reinicia o fade (so showLog faz isso). */
	function buildLog():Void {
		var mods = Paths.listMods();
		var cm = Paths.currentMod();
		var t = "MOD: " + (cm == "" ? "(base)" : cm) + "  [" + mods.length + " encontrado(s)]\n";
		t += "esquerda = escolher mod | direita = recarregar\ntoque no canto superior direito = mostrar este log";
		if (!Paths.externalReady)
			t += "\n\nSEM ACESSO A PASTA DE MODS. Conceda 'acesso a todos os arquivos' ao app e toque no canto superior direito pra pedir de novo. Deslize pra direita pra tentar outra vez.\n\n"
				+ Paths.diagnostics();
		else if (mods.length == 0)
			t += "\n\nNENHUM MOD ENCONTRADO. Coloque a pasta do mod em " + Paths.modsDir() + " e deslize pra direita pra recarregar.";
		logTxt.text = t;
		logBG.makeGraphic(Std.int(logTxt.fieldWidth) + 16, Std.int(logTxt.height) + 12, FlxColor.BLACK);
	}

	/** Mostra o log por LOG_TIME segundos e depois some com fade. */
	function showLog():Void {
		FlxTween.cancelTweensOf(logTxt);
		FlxTween.cancelTweensOf(logBG);
		logTxt.alpha = 1;
		logBG.alpha = 0.65;
		FlxTween.tween(logTxt, {alpha: 0}, LOG_FADE, {startDelay: LOG_TIME});
		FlxTween.tween(logBG, {alpha: 0}, LOG_FADE, {startDelay: LOG_TIME});
	}

	function changeItem(h:Int):Void {
		if (h != 0)
			FlxG.sound.play(Paths.sfx("menu/scroll"), 0.4);
		cur = (cur + h + items.length) % items.length;
		lastCur = cur;
		scripts.call("onChange", [cur, menuItems[cur].id]);
		items.forEach(function(spr:FlxSprite) {
			spr.animation.play("idle");
			if (spr.ID == cur) {
				spr.animation.play("selected");
				var mid = spr.getGraphicMidpoint();
				camFollow.setPosition(mid.x, mid.y);
				mid.put();
			}
			spr.updateHitbox();
			spr.centerOffsets();
		});
	}

	function accept():Void {
		if (selected)
			return;
		// onSelect(indice, id) + cancelEvent() = o script cuida da acao (nenhuma animacao padrao)
		if (scripts.call("onSelect", [cur, menuItems[cur].id]))
			return;
		var act:Dynamic = menuItems[cur].action;
		if (act != null && Reflect.isFunction(act)) {
			act(); // acao em funcao (do script): ela decide o que acontece
			return;
		}
		selected = true;
		FlxG.sound.play(Paths.sfx("menu/confirm"));
		if (Options.flashing) {
			magenta.visible = true;
			FlxFlicker.flicker(magenta, 1.1, 0.15, false);
		}
		items.forEach(function(s:FlxSprite) {
			if (s.ID != cur)
				FlxTween.tween(s, {alpha: 0}, 0.4, {ease: FlxEase.quintOut});
		});
		FlxFlicker.flicker(items.members[cur], 1, Options.flashing ? 0.06 : 0.15, false, false, function(_) go());
	}

	function go():Void {
		var it = menuItems[cur];
		Script.switchState(it.action != null ? it.action : it.id);
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		scripts.call("onUpdate", [elapsed]);
		// o frame "selected" e mais largo: mantem sempre centralizado em X
		items.forEach(function(s:FlxSprite) s.screenCenter(X));
		if (selected)
			return;
		if (!Paths.externalReady) {
			retryTimer += elapsed;
			if (retryTimer > 1) {
				retryTimer = 0;
				if (Paths.retryExternal()) {
					FlxG.resetState();
					return;
				}
				buildLog();
			}
		}
		// canto superior direito: pede a permissao de novo (se faltar) e mostra o log
		if (Controls.tap && Controls.tapX > FlxG.width * 0.5 && Controls.tapY < 80) {
			if (!Paths.externalReady)
				Paths.requestAgain();
			buildLog();
			showLog();
			return;
		}
		// tocar no texto de versao abre a selecao de mod (igual a Codename)
		if (Controls.tap && Controls.tapX >= versionTxt.x && Controls.tapX <= versionTxt.x + versionTxt.width + 20 && Controls.tapY >= versionTxt.y - 10) {
			TransitionSubState.go(new ModSelectState());
			return;
		}
		if ((Controls.tap && Controls.tapX < 300 && Controls.tapY < 44) || FlxG.keys.justPressed.E) {
			TransitionSubState.go(new ChartPickState());
			return;
		}
		if (Controls.swipeLeft || FlxG.keys.justPressed.TAB) {
			TransitionSubState.go(new ModSelectState());
			return;
		}
		if (Controls.swipeRight || FlxG.keys.justPressed.R) {
			Paths.reload();
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();
			FlxG.resetState();
			return;
		}
		if (Controls.next)
			changeItem(1);
		if (Controls.prev)
			changeItem(-1);
		if (Controls.tap) {
			for (s in items.members) {
				var sy = s.y - FlxG.camera.scroll.y * s.scrollFactor.y; // posicao real na tela (os itens acompanham a camera de leve)
				if (Controls.tapX > s.x && Controls.tapX < s.x + s.width && Controls.tapY > sy && Controls.tapY < sy + s.height) {
					if (s.ID == cur)
						accept();
					else
						changeItem(s.ID - cur);
					break;
				}
			}
		}
	}

	override function destroy():Void {
		scripts.call("onDestroy");
		super.destroy();
	}
}

typedef MenuItemDef = {
	var id:String;
	var file:String;
	var idle:String;
	var selected:String;
	@:optional var action:Dynamic;
}

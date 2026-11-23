package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import MiniUi.MiniBtn;
import haxe.Json;
#if sys
import sys.io.File;
#end

class CharacterEditorState extends FlxState {
	static inline var OX:Float = 330;
	static inline var OY:Float = 250;
	static inline var PX:Float = 770;

	var ui:MiniUi;
	var ids:Array<String> = [];
	var ci:Int = 0;
	var ai:Int = 0;
	var step:Int = 1;
	var data:Dynamic;
	var ch:FlxSprite;
	var scene:FlxGroup;
	var prefixes:Array<String> = [];
	var info:FlxText;
	var status:FlxText;
	var dirty:Bool = false;
	var armed:Bool = false;
	var leaving:Bool = false;
	var dragging:Bool = false;
	var lx:Float = 0;
	var ly:Float = 0;
	var fx:Float = 0;
	var fy:Float = 0;

	var bChar:MiniBtn;
	var bAnim:MiniBtn;
	var bPrefix:MiniBtn;
	var bFps:MiniBtn;
	var bStep:MiniBtn;
	var bLoop:MiniBtn;
	var bScale:MiniBtn;
	var bFlip:MiniBtn;

	override function create():Void {
		super.create();
		add(new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xFF1A1B26));
		var h = new FlxSprite(OX - 120, OY).makeGraphic(240, 1, 0xFF66FF99);
		var v = new FlxSprite(OX, OY - 120).makeGraphic(1, 240, 0xFF66FF99);
		add(h);
		add(v);
		scene = new FlxGroup();
		add(scene);
		add(new FlxSprite(PX - 10, 0).makeGraphic(FlxG.width - Std.int(PX) + 10, FlxG.height, 0xFF11121A));

		for (k in Paths.list("data/characters", "json"))
			ids.push(haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(k)));
		if (ids.length == 0)
			ids.push("bf");

		var mod = Paths.currentMod();
		var title = new FlxText(16, 10, 720, "Character Editor - Mod: " + (mod == "" ? "(base)" : mod), 20);
		title.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.antialiasing = Options.antialiasing;
		add(title);

		info = new FlxText(16, 560, 730, "", 17);
		info.setFormat(Paths.font("vcr.ttf"), 17, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		info.antialiasing = Options.antialiasing;
		add(info);

		status = new FlxText(16, 690, 730, "", 15);
		status.setFormat(Paths.font("vcr.ttf"), 15, 0xFFDDDDDD, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		status.antialiasing = Options.antialiasing;
		add(status);

		ui = new MiniUi(this);
		var x0 = PX;
		var y = 14.0;
		var rh = 50.0;
		var gap = 8.0;

		ui.add(x0, y, 70, rh, "<", function() loadChar(ci - 1));
		bChar = ui.add(x0 + 78, y, 268, rh, "");
		ui.add(x0 + 354, y, 70, rh, ">", function() loadChar(ci + 1));
		ui.add(x0 + 432, y, 70, rh, "Del", function() deleteHint());
		y += rh + gap;

		ui.add(x0, y, 70, rh, "<", function() changeAnim(-1));
		bAnim = ui.add(x0 + 78, y, 346, rh, "");
		ui.add(x0 + 432, y, 70, rh, ">", function() changeAnim(1));
		y += rh + gap;

		ui.add(x0, y, 70, rh, "<", function() changePrefix(-1));
		bPrefix = ui.add(x0 + 78, y, 346, rh, "");
		ui.add(x0 + 432, y, 70, rh, ">", function() changePrefix(1));
		y += rh + gap;

		ui.add(x0, y, 70, rh, "-", function() changeFps(-1), true);
		bFps = ui.add(x0 + 78, y, 346, rh, "");
		ui.add(x0 + 432, y, 70, rh, "+", function() changeFps(1), true);
		y += rh + gap;

		var aw = 120.0;
		ui.add(x0, y, aw, rh, "Esq", function() nudge(-1, 0), true);
		ui.add(x0 + (aw + gap), y, aw, rh, "Dir", function() nudge(1, 0), true);
		ui.add(x0 + (aw + gap) * 2, y, aw, rh, "Cima", function() nudge(0, -1), true);
		ui.add(x0 + (aw + gap) * 3, y, aw, rh, "Baixo", function() nudge(0, 1), true);
		y += rh + gap;

		bStep = ui.add(x0, y, 160, rh, "", function() {
			step = step == 1 ? 5 : (step == 5 ? 10 : 1);
			refresh();
		});
		ui.add(x0 + 168, y, 160, rh, "Tocar", function() playCur());
		bLoop = ui.add(x0 + 336, y, 166, rh, "", toggleLoop);
		y += rh + gap;

		ui.add(x0, y, 70, rh, "-", function() changeScale(-0.1), true);
		bScale = ui.add(x0 + 78, y, 346, rh, "");
		ui.add(x0 + 432, y, 70, rh, "+", function() changeScale(0.1), true);
		y += rh + gap;

		bFlip = ui.add(x0, y, 250, rh, "", toggleFlip);
		y += rh + gap + 14;

		ui.add(x0, y, 246, 56, "Salvar", function() save());
		ui.add(x0 + 256, y, 246, 56, "Voltar", leave);

		loadChar(Std.int(Math.max(0, ids.indexOf("bf"))));
		setStatus("Arraste o personagem na tela ou use os botoes para ajustar o offset. No PC: setas, Q/E.");
	}

	function curAnim():Dynamic {
		var anims:Array<Dynamic> = data.anims;
		if (anims == null || anims.length == 0)
			return null;
		ai = ((ai % anims.length) + anims.length) % anims.length;
		return anims[ai];
	}

	function loadChar(i:Int):Void {
		if (dirty && !armed) {
			armed = true;
			setStatus("ALTERACOES NAO SALVAS neste personagem! Toque de novo para descartar.", true);
			return;
		}
		ci = ((i % ids.length) + ids.length) % ids.length;
		var d:Dynamic = Paths.json('data/characters/${ids[ci]}.json');
		if (d == null)
			d = {image: "characters/bf", anims: []};
		data = Json.parse(Json.stringify(d));
		if (data.anims == null)
			data.anims = [];
		ai = 0;
		dirty = false;
		armed = false;
		buildSprite();
	}

	function buildSprite():Void {
		if (ch != null) {
			scene.remove(ch, true);
			ch.destroy();
		}
		ch = new FlxSprite(OX, OY);
		prefixes = [];
		var fr = Paths.sparrow(data.image);
		if (fr != null) {
			ch.frames = fr;
			var seen = new Map<String, Bool>();
			var re = ~/[0-9]+$/;
			for (f in fr.frames) {
				var p = re.replace(f.name, "");
				if (!seen.exists(p)) {
					seen.set(p, true);
					prefixes.push(p);
				}
			}
			prefixes.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		} else
			setStatus("Atlas nao encontrado: " + data.image, true);
		ch.antialiasing = Options.antialiasing;
		scene.add(ch);
		rebuildAnims();
	}

	function rebuildAnims():Void {
		ch.animation.destroyAnimations();
		var anims:Array<Dynamic> = data.anims;
		for (a in anims) {
			var fps:Int = a.fps != null ? a.fps : 24;
			var loop:Bool = a.loop == true;
			if (a.indices != null)
				ch.animation.addByIndices(a.name, a.prefix, a.indices, "", fps, loop);
			else
				ch.animation.addByPrefix(a.name, a.prefix, fps, loop);
		}
		var sc:Float = data.scale != null ? data.scale : 1;
		ch.scale.set(sc, sc);
		ch.updateHitbox();
		ch.flipX = data.flipX == true;
		playCur();
	}

	function playCur():Void {
		var a = curAnim();
		if (a != null && ch.animation.exists(a.name))
			ch.animation.play(a.name, true);
		applyOffset();
		refresh();
	}

	function applyOffset():Void {
		var a = curAnim();
		if (a == null) {
			ch.offset.set(0, 0);
			return;
		}
		var o:Array<Float> = a.offsets != null ? a.offsets : [0, 0];
		ch.offset.set(o[0], o[1]);
	}

	function shift(dx:Float, dy:Float):Void {
		var a = curAnim();
		if (a == null)
			return;
		var o:Array<Float> = a.offsets != null ? a.offsets : [0, 0];
		a.offsets = [Math.round(o[0] - dx), Math.round(o[1] - dy)];
		dirty = true;
		armed = false;
		applyOffset();
		refresh();
	}

	function nudge(sx:Int, sy:Int):Void
		shift(sx * step, sy * step);

	function changeAnim(d:Int):Void {
		ai += d;
		curAnim();
		playCur();
	}

	function changePrefix(d:Int):Void {
		var a = curAnim();
		if (a == null || prefixes.length == 0)
			return;
		var j = prefixes.indexOf(a.prefix);
		j = ((j + d) % prefixes.length + prefixes.length) % prefixes.length;
		a.prefix = prefixes[j];
		touched();
		rebuildAnims();
	}

	function changeFps(d:Int):Void {
		var a = curAnim();
		if (a == null)
			return;
		var f:Int = a.fps != null ? a.fps : 24;
		a.fps = Std.int(Math.max(1, Math.min(120, f + d)));
		touched();
		rebuildAnims();
	}

	function toggleLoop():Void {
		var a = curAnim();
		if (a == null)
			return;
		a.loop = a.loop != true;
		touched();
		rebuildAnims();
	}

	function changeScale(d:Float):Void {
		var s:Float = data.scale != null ? data.scale : 1;
		data.scale = Math.max(0.1, Math.round((s + d) * 100) / 100);
		touched();
		rebuildAnims();
	}

	function toggleFlip():Void {
		data.flipX = data.flipX != true;
		touched();
		rebuildAnims();
	}

	function touched():Void {
		dirty = true;
		armed = false;
	}

	function deleteHint():Void
		setStatus("Para apagar um personagem, remova data/characters/" + ids[ci] + ".json do seu mod.");

	function refresh():Void {
		var a = curAnim();
		var anims:Array<Dynamic> = data.anims;
		ui.setLabel(bChar, ids[ci] + (dirty ? " *" : ""));
		ui.setLabel(bAnim, a == null ? "(sem anim)" : a.name + " " + (ai + 1) + "/" + anims.length);
		ui.setLabel(bPrefix, a == null ? "-" : Std.string(a.prefix));
		ui.setLabel(bFps, a == null ? "-" : "fps " + (a.fps != null ? a.fps : 24));
		ui.setLabel(bStep, "passo " + step);
		ui.setLabel(bLoop, a != null && a.loop == true ? "loop: sim" : "loop: nao");
		var sc:Float = data.scale != null ? data.scale : 1;
		ui.setLabel(bScale, "escala " + sc);
		ui.setLabel(bFlip, data.flipX == true ? "flipX: sim" : "flipX: nao");
		var o:Array<Float> = a != null && a.offsets != null ? a.offsets : [0, 0];
		info.text = ids[ci] + " | " + data.image + "\n" + (a == null ? "" : a.name + " | prefix: " + a.prefix) + "\noffset: " + o[0] + ", " + o[1];
	}

	function setStatus(msg:String, err:Bool = false):Void {
		status.text = msg;
		status.color = err ? 0xFFFF8080 : 0xFFDDDDDD;
	}

	function save():Bool {
		#if sys
		var mod = Paths.currentMod();
		if (mod == "" || !Paths.externalReady) {
			setStatus("Escolha um MOD antes de salvar (menu principal: deslize pra esquerda). A base nao e alterada.", true);
			return false;
		}
		try {
			var dir = Paths.modsDir() + mod + "/data/characters/";
			if (!Paths.ensureDir(dir))
				throw "nao consegui criar " + dir;
			File.saveContent(dir + ids[ci] + ".json", Json.stringify(data, null, " "));
			dirty = false;
			armed = false;
			refresh();
			setStatus("Salvo! " + dir + ids[ci] + ".json");
			return true;
		} catch (e:Dynamic) {
			setStatus("ERRO ao salvar: " + Std.string(e), true);
			return false;
		}
		#else
		return false;
		#end
	}

	function leave():Void {
		if (leaving)
			return;
		if (dirty && !armed) {
			armed = true;
			setStatus("ALTERACOES NAO SALVAS! Toque em Voltar de novo pra sair sem salvar.", true);
			return;
		}
		leaving = true;
		TransitionSubState.go(new OptionsState());
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);
		if (leaving)
			return;
		ui.update(elapsed);

		if (ui.just && !ui.hitBtn && ui.px < PX - 14 && ui.py > 50) {
			dragging = true;
			lx = ui.px;
			ly = ui.py;
			fx = 0;
			fy = 0;
		}
		if (!ui.down)
			dragging = false;
		if (dragging && ui.down) {
			fx += ui.px - lx;
			fy += ui.py - ly;
			lx = ui.px;
			ly = ui.py;
			var ix = Std.int(fx);
			var iy = Std.int(fy);
			if (ix != 0 || iy != 0) {
				fx -= ix;
				fy -= iy;
				shift(ix, iy);
			}
		}

		var k = FlxG.keys.justPressed;
		if (k.LEFT)
			nudge(-1, 0);
		if (k.RIGHT)
			nudge(1, 0);
		if (k.UP)
			nudge(0, -1);
		if (k.DOWN)
			nudge(0, 1);
		if (k.Q)
			changeAnim(-1);
		if (k.E)
			changeAnim(1);
		if (k.ESCAPE)
			leave();
		#if android
		if (FlxG.android.justReleased.BACK)
			leave();
		#end
	}
}

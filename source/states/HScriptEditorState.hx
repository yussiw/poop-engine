package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.Assets;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
#if sys
import sys.io.File;
#end

class HScriptEditorState extends FlxState {
	public static var songId:String = "";
	public static var songName:String = "";

	static inline var AREA_X:Float = 16;
	static inline var AREA_Y:Float = 76;
	static inline var AREA_W:Float = 1248;
	#if mobile
	static inline var AREA_H:Float = 320;
	#else
	static inline var AREA_H:Float = 628;
	#end
	static inline var FONT:Float = 22;
	static inline var MAX_HL:Int = 30000;
	static inline var TEMPLATE:String = "function onBeatHit(beat) {\n  \n}\n";

	var ui:MiniUi;
	var tf:TextField;
	var fmt:TextFormat;
	var status:FlxText;
	var dirty:Bool = false;
	var armed:Bool = false;
	var hlDirty:Bool = false;
	var hlWait:Float = 0;
	var lastSx:Float = -1;
	var lastSy:Float = -1;
	var leaving:Bool = false;
	var savedMute:Array<FlxKey>;
	var savedUp:Array<FlxKey>;
	var savedDown:Array<FlxKey>;

	override function create():Void {
		super.create();
		var bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xFF14141A);
		add(bg);

		ui = new MiniUi(this);
		ui.add(16, 10, 170, 50, "Salvar", function() save());
		ui.add(196, 10, 110, 50, "Tab", insertTab);
		ui.add(316, 10, 170, 50, "Voltar", leave);

		var mod = Paths.currentMod();
		status = new FlxText(500, 12, FlxG.width - 516, "", 17);
		status.setFormat(Paths.font("vcr.ttf"), 17, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		status.antialiasing = Options.antialiasing;
		add(status);

		var text = Paths.getText('songs/$songId/script.hx');
		var existed = text != null;
		if (text == null)
			text = TEMPLATE;
		text = StringTools.replace(StringTools.replace(text, "\r\n", "\n"), "\r", "\n");

		fmt = new TextFormat(fontName(), Std.int(FONT), HScriptHighlight.DEFAULT);
		tf = new TextField();
		tf.type = TextFieldType.INPUT;
		tf.multiline = true;
		tf.wordWrap = false;
		tf.background = true;
		tf.backgroundColor = 0x1E1E24;
		tf.border = true;
		tf.borderColor = 0x555566;
		tf.selectable = true;
		tf.mouseEnabled = true;
		tf.defaultTextFormat = fmt;
		tf.text = text;
		tf.addEventListener(Event.CHANGE, onChange);
		FlxG.game.addChild(tf);
		FlxG.stage.focus = tf;
		tf.setSelection(text.length, text.length);

		#if FLX_KEYBOARD
		savedMute = FlxG.sound.muteKeys;
		savedUp = FlxG.sound.volumeUpKeys;
		savedDown = FlxG.sound.volumeDownKeys;
		FlxG.sound.muteKeys = null;
		FlxG.sound.volumeUpKeys = null;
		FlxG.sound.volumeDownKeys = null;
		#end

		layout();
		setStatus((existed ? "songs/" + songId + "/script.hx" : "Novo script: songs/" + songId + "/script.hx") + (mod == "" ? " | SEM MOD ATIVO: nao da pra salvar" : " | Mod: " + mod),
			mod == "");
	}

	static function fontName():String {
		try {
			if (Assets.exists("assets/fonts/vcr.ttf"))
				return Assets.getFont("assets/fonts/vcr.ttf").fontName;
		} catch (e:Dynamic) {}
		return "_typewriter";
	}

	function layout():Void {
		var sc = FlxG.scaleMode.scale;
		if (sc.x == lastSx && sc.y == lastSy)
			return;
		lastSx = sc.x;
		lastSy = sc.y;
		tf.x = AREA_X * sc.x;
		tf.y = AREA_Y * sc.y;
		tf.width = AREA_W * sc.x;
		tf.height = AREA_H * sc.y;
		fmt.size = Std.int(Math.max(8, FONT * sc.x));
		tf.defaultTextFormat = fmt;
		tf.setTextFormat(fmt);
		highlight();
	}

	function onChange(_:Event):Void {
		dirty = true;
		armed = false;
		hlDirty = true;
		hlWait = 0.12;
	}

	function highlight():Void {
		var t = tf.text;
		var n = t.length;
		if (n == 0)
			return;
		tf.setTextFormat(new TextFormat(null, null, HScriptHighlight.DEFAULT), 0, n);
		if (n > MAX_HL)
			return;
		var f = new TextFormat();
		for (sp in HScriptHighlight.spans(t)) {
			f.color = sp.color;
			tf.setTextFormat(f, sp.begin, sp.end);
		}
	}

	function insertTab():Void {
		tf.replaceSelectedText("  ");
		onChange(null);
		FlxG.stage.focus = tf;
	}

	function setStatus(msg:String, err:Bool = false):Void {
		status.text = msg;
		status.color = err ? 0xFFFF8080 : FlxColor.WHITE;
	}

	function check(code:String):String {
		try {
			var p = new hscript.Parser();
			p.allowTypes = true;
			p.allowJSON = true;
			p.allowMetadata = true;
			var clean = ~/^[ \t]*import[ \t]+.*$/gm.replace(code, "");
			p.parseString(clean);
			return null;
		} catch (e:Dynamic) {
			return Std.string(e);
		}
	}

	function save():Bool {
		#if sys
		var mod = Paths.currentMod();
		if (mod == "" || !Paths.externalReady) {
			setStatus("Escolha um MOD antes de salvar (menu principal: deslize pra esquerda). A base nao e alterada.", true);
			return false;
		}
		try {
			var code = StringTools.replace(StringTools.replace(tf.text, "\r\n", "\n"), "\r", "\n");
			var dir = Paths.modsDir() + mod + "/songs/" + songId + "/";
			if (!Paths.ensureDir(dir))
				throw "nao consegui criar " + dir;
			File.saveContent(dir + "script.hx", code);
			dirty = false;
			armed = false;
			var err = check(code);
			if (err == null)
				setStatus("Salvo! " + dir + "script.hx");
			else
				setStatus("Salvo, mas com erro de sintaxe: " + err, true);
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
		tf.visible = false;
		TransitionSubState.go(new HScriptPickState());
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);
		if (leaving)
			return;
		layout();
		ui.update(elapsed);
		if (hlDirty) {
			hlWait -= elapsed;
			if (hlWait <= 0) {
				hlDirty = false;
				highlight();
			}
		}
		if (FlxG.keys.justPressed.ESCAPE)
			leave();
		#if android
		if (FlxG.android.justReleased.BACK)
			leave();
		#end
		#if FLX_KEYBOARD
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
			save();
		#end
	}

	override function destroy():Void {
		if (tf != null) {
			tf.removeEventListener(Event.CHANGE, onChange);
			if (tf.parent != null)
				tf.parent.removeChild(tf);
			if (FlxG.stage.focus == tf)
				FlxG.stage.focus = null;
			tf = null;
		}
		#if FLX_KEYBOARD
		FlxG.sound.muteKeys = savedMute;
		FlxG.sound.volumeUpKeys = savedUp;
		FlxG.sound.volumeDownKeys = savedDown;
		#end
		super.destroy();
	}
}

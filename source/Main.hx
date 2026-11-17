package;

import flixel.FlxG;
import flixel.FlxGame;
import openfl.display.FPS;
import openfl.display.Sprite;
import states.MainMenuState;
import states.TransitionSubState;
#if (sys && !mobile)
import openfl.Lib;
import openfl.events.UncaughtErrorEvent;
import sys.io.File;
#end

class Main extends Sprite {
	static var instance:Main;
	static var fpsDisplay:FPS;

	public function new() {
		super();
		instance = this;
		#if (sys && !mobile)
		CrashLog.init();
		#end
		trace("[Main] iniciando FlxGame");
		addChild(new FlxGame(1280, 720, MainMenuState, 60, 60, true, false));
		trace("[Main] FlxGame ok");
		TransitionSubState.init();
		Shaders.init();
		FlxG.autoPause = false;
		FlxG.save.bind("poopengine");
		trace("[Main] save ok");
		Paths.init();
		trace("[Main] Paths.init ok");
		Options.load();
		trace("[Main] Options.load ok");
		TouchCursor.init();
		trace("[Main] TouchCursor.init ok");
		FlxG.signals.postStateSwitch.add(function() trace("[Main] estado: " + Type.getClassName(Type.getClass(FlxG.state))));
		#if !mobile
		FlxG.mouse.visible = true;
		#else
		FlxG.mouse.visible = false;
		#end
	}

	public static function setFpsVisible(v:Bool):Void {
		if (instance == null)
			return;
		if (fpsDisplay == null) {
			if (!v)
				return;
			fpsDisplay = new FPS(10, 3, 0xFFFFFF);
			instance.addChild(fpsDisplay);
		}
		fpsDisplay.visible = v;
	}
}


#if (sys && !mobile)
/**
 * Grava "PoopEngine-log.txt" ao lado do .exe com os traces e qualquer erro
 * que feche o jogo. Se a pasta nao for gravavel, usa a pasta de dados do app.
 */
class CrashLog {
	static var path:String = null;

	public static function init():Void {
		var dirs:Array<String> = [];
		try {
			dirs.push(haxe.io.Path.addTrailingSlash(haxe.io.Path.directory(Sys.programPath())));
		} catch (e:Dynamic) {}
		try {
			dirs.push(haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory));
		} catch (e:Dynamic) {}
		for (d in dirs) {
			try {
				File.saveContent(d + "PoopEngine-log.txt", "Poop Engine log - " + Date.now().toString() + "\n");
				path = d + "PoopEngine-log.txt";
				break;
			} catch (e:Dynamic) {}
		}
		if (path == null)
			return;

		var oldTrace = haxe.Log.trace;
		haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos) {
			write(Std.string(v));
			oldTrace(v, infos);
		};
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaught);
		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(onCritical);
		#end
	}

	static function write(s:String):Void {
		if (path == null)
			return;
		try {
			var f = File.append(path, false);
			f.writeString(s + "\n");
			f.close();
		} catch (e:Dynamic) {}
	}

	static function onUncaught(e:UncaughtErrorEvent):Void {
		write("ERRO NAO TRATADO: " + Std.string(e.error));
		write(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
	}

	#if cpp
	static function onCritical(msg:String):Void {
		write("ERRO CRITICO: " + msg);
		write(haxe.CallStack.toString(haxe.CallStack.callStack()));
		Sys.exit(1);
	}
	#end
}
#end

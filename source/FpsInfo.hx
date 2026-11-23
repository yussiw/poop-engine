package;

import openfl.Assets;
import openfl.Lib;
import openfl.filters.DropShadowFilter;
import openfl.events.Event;
import openfl.system.System;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldAutoSize;

class FpsInfo extends TextField {
	public var currentFPS(default, null):Int = 0;

	var times:Array<Float> = [];
	var peakMem:Float = 0;
	var lastText:String = "";
	var lastScale:Float = 0;
	var deviceText:String = null;
	var staticText:String = null;
	var memTimer:Float = 1;
	var lastStamp:Float = 0;
	var bigFmt:TextFormat;
	var smallFmt:TextFormat;

	static inline var BIG_SIZE:Int = 19;
	static inline var SMALL_SIZE:Int = 13;
	static inline var CUSTOM_FONT:String = "assets/fonts/fps.ttf";

	public function new(x:Float = 10, y:Float = 3, color:Int = 0xFFFFFF) {
		super();
		this.x = x;
		this.y = y;
		selectable = false;
		mouseEnabled = false;
		autoSize = TextFieldAutoSize.LEFT;
		multiline = true;
		var font = fontName();
		bigFmt = new TextFormat(font, BIG_SIZE, color, true);
		smallFmt = new TextFormat(font, SMALL_SIZE, color, false);
		defaultTextFormat = smallFmt;
		filters = [new DropShadowFilter(1.5, 45, 0x000000, 0.9, 2, 2, 1.5)];
		text = "FPS: ";
		lastStamp = haxe.Timer.stamp();
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function onFrame(_:Event):Void {
		var now = haxe.Timer.stamp();
		var dt = now - lastStamp;
		lastStamp = now;

		times.push(now);
		while (times.length > 0 && times[0] < now - 1)
			times.shift();
		currentFPS = times.length;

		if (!visible)
			return;
		rescale();

		memTimer += dt;
		if (memTimer < 0.5 && lastText != "")
			return;
		memTimer = 0;
		var t = build();
		if (t != lastText) {
			lastText = t;
			text = t;
			var first = t.indexOf("\n");
			if (first < 0)
				first = t.length;
			setTextFormat(bigFmt, 0, first);
			setTextFormat(smallFmt, first, t.length);
		}
	}

	static function fontName():String {
		try {
			if (Assets.exists(CUSTOM_FONT))
				return Assets.getFont(CUSTOM_FONT).fontName;
		} catch (e:Dynamic) {}
		return "_sans";
	}

	function rescale():Void {
		var st = Lib.current != null ? Lib.current.stage : null;
		if (st == null || st.stageHeight <= 0)
			return;
		var s = Math.max(1, st.stageHeight / 720);
		if (s != lastScale) {
			lastScale = s;
			scaleX = scaleY = s;
		}
	}

	function build():String {
		if (staticText == null)
			staticText = engineLine();
		if (deviceText == null)
			deviceText = deviceLine();
		return "FPS: " + currentFPS + "\n" + staticText + "\n" + deviceText + "\n" + memoryLine();
	}

	static function engineLine():String {
		var s = "Poop Engine v" + Updates.version();
		if (GitInfo.hasCommit)
			s += " (" + GitInfo.short + ")";
		return s;
	}

	static function deviceLine():String {
		#if android
		return "Device: Android";
		#elseif windows
		return "Device: Windows";
		#elseif linux
		return "Device: Linux";
		#elseif mac
		return "Device: macOS";
		#elseif ios
		return "Device: iOS";
		#elseif html5
		return "Device: Web";
		#else
		return "Device: ?";
		#end
	}

	function memoryLine():String {
		var mem:Float = 0;
		try {
			mem = System.totalMemory;
		} catch (e:Dynamic) {}
		if (mem > peakMem)
			peakMem = mem;
		return "Memory: " + mb(mem) + " (peak " + mb(peakMem) + ")";
	}

	static function mb(bytes:Float):String {
		var v = Math.round(bytes / 1048576 * 10) / 10;
		return v + " MB";
	}
}

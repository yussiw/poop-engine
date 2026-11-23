package states;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
class TransitionSubState extends FlxSubState {
	public static inline var DURATION:Float = 0.4;
	static inline var EDGE:Int = 360;
	public static var busy:Bool = false;

	static var pendingIn:Bool = false;

	static var hooked:Bool = false;

	public static function init():Void {
		if (hooked)
			return;
		hooked = true;
		FlxG.signals.postStateSwitch.add(onStateSwitched);
	}

	static function onStateSwitched():Void {
		busy = false;
		if (!pendingIn)
			return;
		pendingIn = false;
		var st:FlxState = FlxG.state;
		if (st == null)
			return;
		var t = new TransitionSubState(false);
		t.parentState = st;
		t.prevPersistentUpdate = st.persistentUpdate;
		st.persistentUpdate = true;
		st.openSubState(t);
	}

	public static function go(next:FlxState):Void {
		if (busy || next == null)
			return;
		busy = true;
		var leaf:FlxState = FlxG.state;
		while (leaf.subState != null)
			leaf = leaf.subState;
		var t = new TransitionSubState(true);
		t.next = next;
		leaf.openSubState(t);
	}
	var isOut:Bool;
	var next:FlxState = null;
	var parentState:FlxState = null;
	var prevPersistentUpdate:Bool = false;
	var cam:FlxCamera;
	var block:FlxSprite;
	var edge:FlxSprite;
	var time:Float = 0;
	var finished:Bool = false;
	public function new(isOut:Bool) {
		super();
		this.isOut = isOut;
	}

	override function create():Void {
		super.create();
		cam = new FlxCamera();
		cam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(cam, false);

		block = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		block.scrollFactor.set();
		block.cameras = [cam];
		add(block);

		edge = FlxGradient.createGradientFlxSprite(FlxG.width, EDGE, isOut ? [FlxColor.BLACK, FlxColor.TRANSPARENT] : [FlxColor.TRANSPARENT, FlxColor.BLACK]);
		edge.scrollFactor.set();
		edge.cameras = [cam];
		add(edge);
		place(0);
	}

	function place(p:Float):Void {
		var h = FlxG.height;
		if (isOut) {
			block.y = -h - EDGE + (h + EDGE) * p;
			edge.y = block.y + h;
		} else {

			block.y = (h + EDGE) * p;
			edge.y = block.y - EDGE;
		}
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);
		if (finished)
			return;
		time += elapsed;
		var p = Math.min(1, time / DURATION);
		place(isOut ? FlxEase.quadIn(p) : FlxEase.quadOut(p));
		if (p >= 1) {
			finished = true;
			if (isOut) {

				var n = next;
				next = null;
				pendingIn = true;
				FlxG.switchState(n);
			} else
				close();
		}
	}

	override function destroy():Void {
		if (parentState != null) {
			parentState.persistentUpdate = prevPersistentUpdate;
			parentState = null;
		}
		if (cam != null) {
			if (FlxG.cameras.list.indexOf(cam) >= 0)
				FlxG.cameras.remove(cam);
			cam = null;
		}
		super.destroy();
	}
}

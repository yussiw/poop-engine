package states;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;

/**
 * Transicao entre telas (estilo Psych/Codename): uma cortina preta com borda em degrade desce cobrindo a tela (saida)
 * e, na tela nova, desce de novo revelando o conteudo (entrada).
 *
 * Uso:   TransitionSubState.go(new OutroState());   // no lugar de FlxG.switchState(new OutroState())
 *
 * - go() abre a cortina em cima da tela atual (ou do ultimo substate aberto, ex.: a pausa) e, quando ela cobre tudo, troca de state.
 * - O gancho de Main (TransitionSubState.init) abre a parte de "entrada" automaticamente depois de cada troca feita por go().
 * - Desenha numa camera propria, entao cobre tambem o que esta em camHUD/camGame.
 */
class TransitionSubState extends FlxSubState {
	public static inline var DURATION:Float = 0.4;
	static inline var EDGE:Int = 360; // altura do degrade

	/** true enquanto uma saida esta rodando (evita abrir duas ao mesmo tempo). */
	public static var busy:Bool = false;

	/** true = a proxima tela criada deve abrir a transicao de entrada. */
	static var pendingIn:Bool = false;

	static var hooked:Bool = false;

	/** Chamar uma vez no Main, depois de criar o FlxGame. */
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
		st.persistentUpdate = true; // a tela nova ja anima/le entrada enquanto a cortina sobe
		st.openSubState(t);
	}

	/** Troca de tela com transicao. */
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

		// saida: degrade opaco->transparente (fica embaixo do bloco que desce); entrada: transparente->opaco (fica em cima)
		edge = FlxGradient.createGradientFlxSprite(FlxG.width, EDGE, isOut ? [FlxColor.BLACK, FlxColor.TRANSPARENT] : [FlxColor.TRANSPARENT, FlxColor.BLACK]);
		edge.scrollFactor.set();
		edge.cameras = [cam];
		add(edge);
		place(0);
	}

	/** p = 0..1 do progresso da animacao. */
	function place(p:Float):Void {
		var h = FlxG.height;
		if (isOut) {
			// bloco desce de acima da tela ate cobrir tudo; o degrade vai colado embaixo dele
			block.y = -h - EDGE + (h + EDGE) * p;
			edge.y = block.y + h;
		} else {
			// bloco (cobrindo tudo) desce e sai; o degrade vai colado em cima dele
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
				// manter coberto ate a troca acontecer; a camera some junto com o state antigo
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

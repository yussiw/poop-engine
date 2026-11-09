package;

import flixel.FlxSprite;

/**
 * Caixinha de marcar do menu de opcoes (atlas menus/options/checkbox: "Radio unselected", "Radio selecting animation",
 * "Radio Selected Static", "Radio deselect animation"). Fica ao lado do texto da opcao (sprTracker) e acompanha a posicao/alpha dele.
 */
class Checkbox extends FlxSprite {
	public static inline var SCALE:Float = 0.6;
	/** frame de referencia (o "unselected" tem 138x127; os outros frames sao recortes dele) */
	static inline var REF_W:Float = 138;

	public var sprTracker:FlxSprite;
	public var gap:Float = 24;
	public var checked(default, null):Bool = false;

	var ok:Bool = false;

	public function new(value:Bool) {
		super();
		var f = Paths.sparrow("menus/options/checkbox");
		if (f == null) {
			visible = false;
			return;
		}
		ok = true;
		frames = f;
		Paths.addAnim(this, "unselected", "Radio unselected", 24, false);
		Paths.addAnim(this, "unselecting", "Radio deselect animation", 24, false);
		Paths.addAnim(this, "selecting", "Radio selecting animation", 24, false);
		Paths.addAnim(this, "selected", "Radio Selected Static", 24, false);
		animation.finishCallback = function(n:String) {
			if (n == "selecting")
				animation.play("selected");
			else if (n == "unselecting")
				animation.play("unselected");
		};
		scale.set(SCALE, SCALE);
		antialiasing = Options.antialiasing;
		checked = value;
		animation.play(value ? "selected" : "unselected");
	}

	/** Marca/desmarca (com a animacao de "selecionando"/"desselecionando"). */
	public function setChecked(v:Bool, animate:Bool = true):Void {
		if (!ok || v == checked)
			return;
		checked = v;
		if (animate)
			animation.play(v ? "selecting" : "unselecting", true);
		else
			animation.play(v ? "selected" : "unselected", true);
	}

	override function update(elapsed:Float):Void {
		super.update(elapsed);
		if (!ok)
			return;
		// os frames tem tamanhos diferentes: centraliza em volta do mesmo ponto a cada quadro
		centerOrigin();
		if (sprTracker != null) {
			var cx = sprTracker.x + sprTracker.width + gap + REF_W * SCALE / 2;
			var cy = sprTracker.y + sprTracker.height / 2;
			x = cx - frameWidth / 2;
			y = cy - frameHeight / 2;
			alpha = sprTracker.alpha;
		}
	}
}

package;

import hscript.Interp;

/**
 * Interp com "objeto dono": nomes que o script nao definiu sao procurados nos campos do dono
 * (PlayState, MainMenuState...). So LEITURA: pra gravar use `game.score = 5` (ou `state.campo = x`).
 * (o hscript 2.5.0 nao tem Interp.scriptObject, por isso esta subclasse.)
 */
class ScriptInterp extends Interp {
	public var scriptObject:Dynamic = null;

	override function resolve(id:String):Dynamic {
		if (scriptObject != null && !variables.exists(id) && !locals.exists(id)) {
			var v:Dynamic = Reflect.getProperty(scriptObject, id);
			if (v != null || Reflect.hasField(scriptObject, id))
				return v;
		}
		return super.resolve(id);
	}
}

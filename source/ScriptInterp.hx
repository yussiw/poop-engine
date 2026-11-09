package;
import hscript.Interp;
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

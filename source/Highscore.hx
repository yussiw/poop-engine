package;

import flixel.FlxG;

class Highscore {
	public static function get(id:String):Int {
		var m:Map<String, Int> = FlxG.save.data.scores;
		return (m != null && m.exists(id)) ? m.get(id) : 0;
	}

	public static function save(id:String, score:Int):Void {
		var m:Map<String, Int> = FlxG.save.data.scores;
		if (m == null)
			m = new Map();
		if (!m.exists(id) || m.get(id) < score)
			m.set(id, score);
		FlxG.save.data.scores = m;
		FlxG.save.flush();
	}
}

package;

@:keep
class Conductor {
	public static var bpm:Float = 100;
	public static var crochet:Float = 600;
	public static var stepCrochet:Float = 150;
	public static var songPosition:Float = 0;

	public static function setBpm(b:Float):Void {
		bpm = b;
		crochet = 60000 / b;
		stepCrochet = crochet / 4;
	}
}

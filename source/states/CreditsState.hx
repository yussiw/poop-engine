package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

typedef CreditPerson = {
	var name:String;
	var role:String;
	var link:String;
}

typedef CreditGroup = {
	var title:String;
	var people:Array<CreditPerson>;
}

class CreditsState extends FlxState {
	static inline var TOP_H:Int = 84;
	static inline var BOTTOM_H:Int = 96;
	static inline var MAX_INFO:Int = 90;

	var groups:Array<CreditGroup> = [];
	var level:Int = 0;
	var catSel:Int = 0;
	var cur:Int = 0;
	var grpItems:FlxTypedGroup<Alphabet>;
	var title:FlxText;
	var roleTxt:FlxText;
	var linkTxt:FlxText;
	var hint:FlxText;
	var leaving:Bool = false;

	override function create():Void {
		super.create();
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music("freakyMenu"), 0.7);

		var bg = new FlxSprite(0, 0, Paths.image("menus/menuDesat"));
		bg.color = 0xFF6B4FC8;
		bg.antialiasing = Options.antialiasing;
		add(bg);

		buildGroups();

		grpItems = new FlxTypedGroup<Alphabet>();
		add(grpItems);

		var top = new FlxSprite(0, 0).makeGraphic(FlxG.width, TOP_H, FlxColor.BLACK);
		top.alpha = 0.75;
		add(top);
		title = new FlxText(0, 18, FlxG.width, "", 44);
		title.setFormat(Paths.font("vcr.ttf"), 44, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(title);

		var bottom = new FlxSprite(0, FlxG.height - BOTTOM_H).makeGraphic(FlxG.width, BOTTOM_H, FlxColor.BLACK);
		bottom.alpha = 0.75;
		add(bottom);
		roleTxt = new FlxText(10, FlxG.height - BOTTOM_H + 4, FlxG.width - 20, "", 22);
		roleTxt.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(roleTxt);
		linkTxt = new FlxText(10, FlxG.height - BOTTOM_H + 32, FlxG.width - 20, "", 20);
		linkTxt.setFormat(Paths.font("vcr.ttf"), 20, 0xFF99FFBB, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(linkTxt);
		hint = new FlxText(10, FlxG.height - 30, FlxG.width - 20, Lang.get("credits.hint"), 18);
		hint.setFormat(Paths.font("vcr.ttf"), 18, 0xFFDDDDDD, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(hint);

		fill();
		change(0);
	}

	function makePerson(name:String, role:String, link:String):CreditPerson
		return {name: name, role: role, link: link};

	function makeGroup(title:String, people:Array<CreditPerson>):CreditGroup
		return {title: title, people: people};

	function buildGroups():Void {
		groups.push(makeGroup("Codename Engine", [
			makePerson("Codename Engine", Lang.get("credits.assets"), "https://github.com/CodenameCrew/CodenameEngine")
		]));
		groups.push(makeGroup("FunkinCrew", [
			makePerson("FunkinCrew", Lang.get("credits.original"), "https://github.com/FunkinCrew/Funkin")
		]));
		groups.push(makeGroup("Kade Engine", [
			makePerson("Kade Engine", Lang.get("credits.inspiration"), "https://github.com/KadeDev/Kade-Engine")
		]));

		var id = Paths.currentMod();
		if (id != "") {
			var m = Paths.modInfo(id);
			if (m != null)
				groups.push(modGroup(m));
		}
	}

	function modGroup(m:ModInfo):CreditGroup {
		var people:Array<CreditPerson> = [];
		var name = m.name + (m.version != "" ? " v" + m.version : "");
		people.push(makePerson(name, m.description, m.link));
		for (c in m.contributors)
			people.push(makePerson(c.name, c.role, m.link));
		if (m.contributors.length == 0)
			people.push(makePerson(Lang.get(m.hasMeta ? "credits.noAuthor" : "credits.noMeta"), "", ""));
		return makeGroup(m.name, people);
	}

	function fill():Void {
		for (m in grpItems.members)
			if (m != null)
				m.destroy();
		grpItems.clear();

		var labels:Array<String> = level == 0 ? [for (g in groups) g.title] : [for (p in groups[catSel].people) p.name];
		for (i in 0...labels.length) {
			var t = new Alphabet(0, 70 * i + 30, labels[i]);
			if (t.members.length == 0)
				t = new Alphabet(0, 70 * i + 30, "?");
			t.isMenuItem = true;
			t.targetY = i;
			grpItems.add(t);
		}
		title.text = level == 0 ? Lang.get("credits.title") : groups[catSel].title;
	}

	function change(d:Int):Void {
		var n = grpItems.members.length;
		if (n == 0)
			return;
		if (d != 0)
			FlxG.sound.play(Paths.sfx("menu/scroll"), 0.4);
		cur = (cur + d + n) % n;
		var i = 0;
		for (item in grpItems.members) {
			item.targetY = i - cur;
			i++;
			item.alpha = item.targetY == 0 ? 1 : 0.6;
		}
		updateInfo();
	}

	function updateInfo():Void {
		if (level == 0) {
			roleTxt.text = "";
			linkTxt.text = "";
			return;
		}
		var p = groups[catSel].people[cur];
		var r = p.role;
		if (r.length > MAX_INFO)
			r = r.substr(0, MAX_INFO) + "...";
		roleTxt.text = r;
		linkTxt.text = p.link;
	}

	function accept():Void {
		if (level == 0) {
			FlxG.sound.play(Paths.sfx("menu/confirm"), 0.7);
			catSel = cur;
			level = 1;
			cur = 0;
			fill();
			change(0);
			return;
		}
		var l = groups[catSel].people[cur].link;
		if (l != "") {
			FlxG.sound.play(Paths.sfx("menu/confirm"), 0.7);
			FlxG.openURL(l);
		}
	}

	function goBack():Void {
		FlxG.sound.play(Paths.sfx("menu/cancel"), 0.6);
		if (level == 1) {
			level = 0;
			cur = catSel;
			fill();
			change(0);
			return;
		}
		leaving = true;
		TransitionSubState.go(new MainMenuState());
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		if (leaving)
			return;

		if (Controls.next)
			change(1);
		if (Controls.prev)
			change(-1);
		if (Controls.swipeRight || Controls.back) {
			goBack();
			return;
		}
		if (Controls.tap && Controls.tapY > TOP_H && Controls.tapY < FlxG.height - BOTTOM_H) {
			for (i in 0...grpItems.members.length) {
				var it = grpItems.members[i];
				if (Math.abs(Controls.tapY - (it.y + it.height / 2)) < 55) {
					if (i == cur)
						accept();
					else
						change(i - cur);
					break;
				}
			}
		}
	}
}

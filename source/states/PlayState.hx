package states;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;

typedef NoteData = {t:Float, d:Int, sus:Float, p:Bool, ch:Int};

@:keep
class PlayState extends FlxState {
	public static var songId:String = "demo";
	public static var instance:PlayState;

	public var camHUD:FlxCamera;
	public var chart:Dynamic;
	public var speed:Float = 2;
	public var bf:Character;
	public var dad:Character;
	public var chars:Array<Character> = [];
	public var health:Float = 1;
	public var score:Int = 0;
	public var combo:Int = 0;
	public var misses:Int = 0;
	public var songName:String = "";
	public var inst:FlxSound;
	public var voices:FlxSound;
	public var notes:FlxTypedGroup<Note>;
	public var sustains:FlxTypedGroup<FlxSprite>;
	public var splashes:FlxTypedGroup<NoteSplash>;

	public var downscroll:Bool = false;
	public var playerStrums:Array<Strum> = [];
	public var oppStrums:Array<Strum> = [];

	var hits:Float = 0;
	var total:Int = 0;
	var unspawn:Array<NoteData> = [];

	var unspawnIdx:Int = 0;

	var killList:Array<Note> = [];
	var hitbox:Array<FlxSprite> = [];
	var camTop:FlxCamera;

	public var healthBar:FlxBar;
	public var healthBarBG:FlxSprite;
	public var iconP1:FlxSprite;
	public var iconP2:FlxSprite;
	public var scoreTxt:FlxText;
	public var watermark:FlxText;
	public var accuracy:Float = 0;
	var camFollow:FlxObject;
	public var defaultZoom:Float = 0.9;
	var camSlot:Int = -1;
	var evList:Array<{t:Float, e:String, v1:String, v2:String}> = [];
	var evIdx:Int = 0;
	var bpmStep:Float = 0;
	var bpmTime:Float = 0;
	var zoomTw:FlxTween;
	var started:Bool = false;
	var dead:Bool = false;
	var lastTime:Float = -1;
	var curStep:Int = -9999;
	public var scripts:Array<Script> = [];
	var pxMs:Float = 0.9;

	override function create():Void {
		super.create();
		instance = this;
		downscroll = Options.downscroll;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		var chartFile:Dynamic = Paths.json('songs/$songId/chart.json');
		chart = (chartFile.song != null && !Std.isOfType(chartFile.song, String)) ? chartFile.song : chartFile;
		songName = Std.string(chart.song);
		speed = chart.speed != null ? chart.speed : 2;
		pxMs = 0.45 * speed;
		Conductor.setBpm(chart.bpm);
		Conductor.songPosition = -Conductor.crochet * 4;

		camHUD = new FlxCamera();
		camHUD.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(camHUD, false);

		loadScripts();
		callScript("onCreate");

		var stageName:String = chart.stage != null ? chart.stage : "default";
		var stageData:Dynamic = Paths.json('data/stages/$stageName.json');
		defaultZoom = stageData.zoom != null ? stageData.zoom : 0.9;
		FlxG.camera.zoom = defaultZoom;
		var front:Array<FlxSprite> = [];
		var objs:Array<Dynamic> = stageData.objects;
		for (o in objs) {
			if (Options.lowQuality && o.lowQuality == false)
				continue;
			var g = Paths.image(o.image);
			if (g == null)
				continue;
			var s = new FlxSprite(o.x, o.y, g);
			var sc:Float = o.scroll != null ? o.scroll : 1;
			s.scrollFactor.set(sc, sc);
			if (o.scale != null) {
				s.scale.set(o.scale, o.scale);
				s.updateHitbox();
			}
			s.antialiasing = Options.antialiasing;
			if (o.front == true)
				front.push(s);
			else
				add(s);
		}
		var dadPos:Array<Float> = stageData.dad;
		var bfPos:Array<Float> = stageData.bf;
		dad = new Character(dadPos[0], dadPos[1], chart.player2, false);
		bf = new Character(bfPos[0], bfPos[1], chart.player1, true);
		chars = [dad, bf];
		var exArr:Array<Dynamic> = chart.chars != null ? chart.chars : [];
		var ax:Float = stageData.gf != null ? stageData.gf[0] : (dadPos[0] + bfPos[0]) / 2;
		var ay:Float = stageData.gf != null ? stageData.gf[1] : Math.min(dadPos[1], bfPos[1]);
		for (ec in exArr) {
			var ox:Float = ec.dx != null ? ec.dx : 0;
			var oy:Float = ec.dy != null ? ec.dy : 0;
			var c = new Character(ax + ox, ay + oy, Std.string(ec.id), false);
			chars.push(c);
			add(c);
		}
		add(dad);
		add(bf);
		for (s in front)
			add(s);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		FlxG.camera.follow(camFollow, LOCKON, 0.04);
		moveCam(true);
		FlxG.camera.focusOn(camFollow.getPosition());
		var instSnd = Paths.audio('songs/$songId/Inst.ogg');
		if (instSnd == null)
			instSnd = Paths.music("freakyMenu");
		inst = FlxG.sound.load(instSnd);
		inst.onComplete = endSong;
		var voiceSnd = Paths.audio('songs/$songId/Voices.ogg');
		if (voiceSnd != null)
			voices = FlxG.sound.load(voiceSnd);
		if (Controls.showHitbox) {
			var laneW = FlxG.width / 4;
			var laneColors = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];

			camTop = new FlxCamera();
			camTop.bgColor = FlxColor.TRANSPARENT;
			FlxG.cameras.add(camTop, false);
			for (i in 0...4) {
				var h = new FlxSprite(laneW * i, 0).makeGraphic(Std.int(laneW), FlxG.height, laneColors[i]);
				h.alpha = 0;
				h.scrollFactor.set(0, 0);
				h.cameras = [camTop];
				hitbox.push(h);
				add(h);
			}
		}
		for (i in 0...4) {
			var sy:Float = downscroll ? FlxG.height - 150 : 50;
			var oppStrum = new Strum(50 + Note.WIDTH * i, sy, i);
			var plrStrum = new Strum(50 + Note.WIDTH * i + FlxG.width / 2, sy, i);
			var slide:Float = downscroll ? -10 : 10;
			for (strum in [oppStrum, plrStrum]) {
				strum.cameras = [camHUD];
				strum.y -= slide;
				strum.alpha = 0;
				FlxTween.tween(strum, {y: strum.y + slide, alpha: 1}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + 0.2 * i});
				add(strum);
			}
			oppStrums.push(oppStrum);
			playerStrums.push(plrStrum);
		}
		sustains = new FlxTypedGroup<FlxSprite>();
		notes = new FlxTypedGroup<Note>();
		splashes = new FlxTypedGroup<NoteSplash>();
		sustains.cameras = [camHUD];
		notes.cameras = [camHUD];
		splashes.cameras = [camHUD];
		add(sustains);
		add(notes);
		add(splashes);
		loadNotes();
		loadEvents();

		var hbBG = healthBarBG = new FlxSprite(0, downscroll ? FlxG.height * 0.1 : FlxG.height * 0.9, Paths.image("game/healthBar"));
		hbBG.screenCenter(X);
		hbBG.cameras = [camHUD];
		add(hbBG);
		healthBar = new FlxBar(hbBG.x + 4, hbBG.y + 4, FlxBarFillDirection.RIGHT_TO_LEFT, Std.int(hbBG.width - 8), Std.int(hbBG.height - 8), this, "health", 0, 2);
		healthBar.createFilledBar(0xFFFF0000, 0xFF66FF33);
		healthBar.cameras = [camHUD];
		add(healthBar);
		iconP1 = new HealthIcon(bf.icon, true);
		iconP2 = new HealthIcon(dad.icon, false);
		iconP1.cameras = [camHUD];
		iconP2.cameras = [camHUD];
		add(iconP2);
		add(iconP1);
		scoreTxt = new FlxText(hbBG.x + hbBG.width / 2 - 235, hbBG.y + 50, 0, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.borderSize = 1.25;
		scoreTxt.cameras = [camHUD];
		add(scoreTxt);
		updateScore();
		var wmark = watermark = new FlxText(4, hbBG.y + 50, 0, songName + " - NORMAL | Poop Engine", 16);
		wmark.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		wmark.borderSize = 1.25;
		wmark.cameras = [camHUD];
		add(wmark);

		callScript("onCreatePost");
	}

	function loadScripts():Void {
		var stageName:String = chart.stage != null ? chart.stage : "default";
		var paths:Array<String> = ["scripts/global.hx"];
		paths = paths.concat(Paths.list("scripts/global", "hx"));
		paths.push("data/hud.hx");
		paths = paths.concat(['stages/$stageName.hx', 'songs/$songId/script.hx', 'songs/$songId/modchart.hx']);
		paths = paths.concat(Paths.list('songs/$songId/scripts', "hx"));
		for (p in paths) {
			var code = Paths.getText(p);
			if (code != null)
				scripts.push(new Script(code, p, this));
		}
	}
	public function callScript(fn:String, ?args:Array<Dynamic>):Bool
		return Script.callAll(scripts, fn, args);

	function loadNotes():Void {
		var secs:Array<Dynamic> = chart.notes;
		for (sec in secs) {
			var must:Bool = sec.mustHitSection == true;
			var sn:Array<Dynamic> = sec.sectionNotes;
			for (n in sn) {
				var d:Int = Std.int(n[1]);
				if (d < 0)
					continue;
				var sus:Float = n[2] != null ? n[2] : 0;
				var na:Array<Dynamic> = n;
				var chv:Int = (na.length > 3 && na[3] != null) ? Std.int(na[3]) : -1;
				unspawn.push({t: n[0], d: d % 4, sus: sus > 0 ? sus : 0, p: d < 4 ? must : !must, ch: chv});
			}
		}
		unspawn.sort(function(a, b) return Std.int(a.t - b.t));
	}

	public function singer(mustPress:Bool, ch:Int):Character
		return (ch >= 0 && ch < chars.length) ? chars[ch] : (mustPress ? bf : dad);

	function num(s:String, d:Float):Float {
		var v = Std.parseFloat(s);
		return Math.isNaN(v) ? d : v;
	}

	function loadEvents():Void {
		var raw:Array<Dynamic> = chart.events != null ? chart.events : [];
		for (e in raw)
			evList.push({t: e.t, e: Std.string(e.e), v1: e.v1 != null ? Std.string(e.v1) : "", v2: e.v2 != null ? Std.string(e.v2) : ""});
		evList.sort(function(a, b) return a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));
	}

	function swapChar(slot:Int, id:String):Void {
		if (slot < 0 || slot >= chars.length || id == null || id == "")
			return;
		var old = chars[slot];
		var nu = new Character(old.x, old.y, id, old.isPlayer);
		var idx = members.indexOf(old);
		remove(old, true);
		insert(idx < 0 ? members.length : idx, nu);
		old.destroy();
		chars[slot] = nu;
		if (slot == 0)
			dad = nu;
		if (slot == 1)
			bf = nu;
		if (slot < 2) {
			var oi = slot == 1 ? iconP1 : iconP2;
			var ni = new HealthIcon(nu.icon, slot == 1);
			ni.cameras = [camHUD];
			var ii = members.indexOf(oi);
			remove(oi, true);
			insert(ii < 0 ? members.length : ii, ni);
			oi.destroy();
			if (slot == 1)
				iconP1 = ni;
			else
				iconP2 = ni;
		}
	}

	function fireEvent(name:String, v1:String, v2:String, t:Float):Void {
		if (callScript("onEvent", [name, v1, v2]))
			return;
		switch (name) {
			case "Camera Focus":
				camSlot = Std.int(num(v1, -1));
				moveCam(sectionMustHit(Std.int(Math.max(0, curStep) / 16)));
			case "Camera Zoom":
				var z = num(v1, defaultZoom);
				var d = num(v2, 0);
				if (zoomTw != null)
					zoomTw.cancel();
				if (d <= 0) {
					defaultZoom = z;
					FlxG.camera.zoom = z;
				} else
					zoomTw = FlxTween.num(defaultZoom, z, d, {ease: FlxEase.quadInOut}, function(v:Float) defaultZoom = v);
			case "Zoom Bump":
				FlxG.camera.zoom += num(v1, 0.03);
				camHUD.zoom += num(v2, 0.05);
			case "Camera Shake":
				FlxG.camera.shake(num(v1, 0.01), num(v2, 0.3));
			case "Camera Flash":
				var col:Null<FlxColor> = FlxColor.fromString("#" + v1);
				camHUD.flash(col == null ? FlxColor.WHITE : col, num(v2, 0.5));
			case "HUD Alpha":
				var a = num(v1, 1);
				var d = num(v2, 0);
				if (d <= 0)
					camHUD.alpha = a;
				else
					FlxTween.num(camHUD.alpha, a, d, null, function(v:Float) camHUD.alpha = v);
			case "Change BPM":
				var b = num(v1, 0);
				if (b > 0) {
					bpmStep += (t - bpmTime) / Conductor.stepCrochet;
					bpmTime = t;
					Conductor.setBpm(b);
				}
			case "Scroll Speed":
				var sp = num(v1, speed);
				var d = num(v2, 0);
				if (d <= 0) {
					speed = sp;
					pxMs = 0.45 * sp;
				} else
					FlxTween.num(speed, sp, d, {ease: FlxEase.quadInOut}, function(v:Float) {
						speed = v;
						pxMs = 0.45 * v;
					});
			case "Change Character":
				swapChar(Std.int(num(v1, 1)), v2);
			case "Play Anim":
				var i = Std.int(num(v1, 1));
				if (i >= 0 && i < chars.length)
					chars[i].playAnim(v2);
			default:
		}
	}

	function startSong():Void {
		started = true;
		Conductor.songPosition = 0;
		inst.play();
		if (voices != null)
			voices.play();
		lastTime = -1;
		callScript("onSongStart");
	}

	function endSong():Void {
		if (callScript("onSongEnd"))
			return;
		Highscore.save(songId, score);
		TransitionSubState.go(new FreeplayState());
	}

	override function openSubState(s:flixel.FlxSubState):Void {
		callScript(dead ? "onGameOver" : "onPause");
		if (started && !dead) {
			inst.pause();
			if (voices != null)
				voices.pause();
		}
		super.openSubState(s);
	}

	override function closeSubState():Void {
		super.closeSubState();
		callScript("onResume");
		if (started && !dead) {
			inst.resume();
			if (voices != null)
				voices.resume();
			lastTime = -1;
		}
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		if (Controls.back || (Controls.tap && Controls.inPauseZone(Controls.tapX, Controls.tapY))) {
			openSubState(new PauseSubState(camHUD));
			return;
		}

		if (!started) {
			Conductor.songPosition += elapsed * 1000;
			if (Conductor.songPosition >= 0)
				startSong();
		} else {
			if (inst.time != lastTime) {
				lastTime = inst.time;
				Conductor.songPosition = inst.time;
			} else
				Conductor.songPosition += elapsed * 1000;
			if (voices != null && Math.abs(voices.time - inst.time) > 40)
				voices.time = inst.time;
		}

		while (evIdx < evList.length && evList[evIdx].t <= Conductor.songPosition) {
			var ev = evList[evIdx++];
			fireEvent(ev.e, ev.v1, ev.v2, ev.t);
		}
		var step = Math.floor(bpmStep + (Conductor.songPosition - bpmTime) / Conductor.stepCrochet + 0.001);
		if (step != curStep) {
			curStep = step;
			stepHit(step);
			if (step % 4 == 0)
				beatHit(Std.int(step / 4));
		}
		while (unspawnIdx < unspawn.length && unspawn[unspawnIdx].t - Conductor.songPosition < 1800 / speed) {
			var d = unspawn[unspawnIdx++];
			var n = new Note(d.t, d.d, d.sus, d.p);
			n.ch = d.ch;
			notes.add(n);
			if (n.sustain != null)
				sustains.add(n.sustain);
			if (n.tail != null)
				sustains.add(n.tail);
			callScript("onNoteSpawn", [n]);
		}

		handleInput();
		updateNotes(elapsed);
		updateHud(elapsed);
		callScript("onUpdate", [elapsed]);
		callScript("onUpdatePost", [elapsed]);

		if (health <= 0 && !dead) {
			dead = true;
			inst.pause();
			if (voices != null)
				voices.pause();
			persistentUpdate = false;
			persistentDraw = false;
			var m = bf.getMidpoint();
			camFollow.setPosition(m.x - 100, m.y - 100);
			openSubState(new GameOverSubState(bf.x, bf.y, camFollow));
		}
	}

	function stepHit(s:Int):Void {
		if (s >= 0 && s % 16 == 0)
			moveCam(sectionMustHit(Std.int(s / 16)));
		callScript("onStepHit", [s]);
	}
	function beatHit(b:Int):Void {
		if (b < 0)
			countdown(b + 4);
		if (b % 2 == 0) {
			for (c in chars)
				c.danceIfIdle();
		}
		if (b >= 0 && b % 4 == 0 && Options.camZooming) {
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;
		}
		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);
		callScript("onBeatHit", [b]);
	}
	function countdown(i:Int):Void {
		if (callScript("onCountdown", [i]))
			return;
		var snd = ["intro3", "intro2", "intro1", "introGo"];
		var img = [null, "ready", "set", "go"];
		var s = Paths.sfx(snd[i]);
		if (s != null)
			FlxG.sound.play(s, 0.6);
		if (img[i] != null) {
			var spr = new FlxSprite(0, 0, Paths.image("game/" + img[i]));
			spr.screenCenter();
			spr.cameras = [camHUD];
			add(spr);
			FlxTween.tween(spr, {alpha: 0, y: spr.y + 100}, Conductor.crochet / 1000, {ease: FlxEase.cubeInOut, onComplete: function(_) {
				remove(spr);
				spr.destroy();
			}});
		}
	}
	function sectionMustHit(i:Int):Bool {
		var secs:Array<Dynamic> = chart.notes;
		return i < secs.length ? secs[i].mustHitSection == true : true;
	}
	function moveCam(mustHit:Bool):Void {
		if (callScript("onCameraMove", [mustHit]))
			return;
		var c:Character = (camSlot >= 0 && camSlot < chars.length) ? chars[camSlot] : (mustHit ? bf : dad);
		var m = c.getMidpoint();
		camFollow.setPosition(m.x + (c == bf ? -100 : (c == dad ? 150 : 0)), m.y - 100);
	}
	function handleInput():Void {
		for (i in 0...4) {
			var strum = playerStrums[i];
			if (Controls.justPressed[i]) {
				var target:Note = null;
				for (n in notes.members) {
					if (n == null || !n.alive || !n.mustPress || n.wasHit || n.tooLate || n.lane != i)
						continue;
					if (Math.abs(n.strumTime - Conductor.songPosition) > 160)
						continue;
					if (target == null || n.strumTime < target.strumTime)
						target = n;
				}
				if (target != null)
					goodHit(target);
				else if (Options.ghostTapping)
					strum.play("press");
				else {
					strum.play("press");
					callScript("onGhostTap", [i]);
					ghostMiss(i);
				}
			}
			if (Controls.released[i])
				strum.play("static");
		}
	}
	function ghostMiss(lane:Int):Void {
		health -= 0.04;
		combo = 0;
		misses++;
		score -= 10;
		bf.sing(lane, true);
		if (voices != null)
			voices.volume = 0;
		FlxG.sound.play(Paths.sfx("missnote" + FlxG.random.int(1, 3)), 0.2);
		updateScore();
	}
	function goodHit(n:Note):Void {
		var diff = Math.abs(n.strumTime - Conductor.songPosition);
		var r = diff <= 45 ? "sick" : (diff <= 90 ? "good" : (diff <= 135 ? "bad" : "shit"));
		if (callScript("onNoteHitPre", [n, r]))
			return;
		var pts = switch (r) {
			case "sick": 350;
			case "good": 200;
			case "bad": 100;
			default: 50;
		}
		hits += switch (r) {
			case "sick": 1.0;
			case "good": 0.75;
			case "bad": 0.5;
			default: 0.25;
		}
		health += switch (r) {
			case "sick": 0.04;
			case "good": 0.02;
			case "bad": 0.0;
			default: -0.03;
		}
		total++;
		score += pts;
		combo++;
		n.wasHit = true;
		n.visible = false;
		playerStrums[n.lane].play("confirm");
		singer(true, n.ch).sing(n.lane);
		if (voices != null)
			voices.volume = 1;
		popup(r);
		if (r == "sick")
			spawnSplash(n, playerStrums[n.lane]);
		updateScore();
		callScript("onNoteHit", [n, r]);
	}

	function missNote(n:Note):Void {
		n.tooLate = true;
		if (callScript("onMissPre", [n]))
			return;
		health -= 0.0475;
		combo = 0;
		misses++;
		total++;
		score -= 10;
		singer(true, n.ch).sing(n.lane, true);
		if (voices != null)
			voices.volume = 0;
		FlxG.sound.play(Paths.sfx("missnote" + FlxG.random.int(1, 3)), 0.2);
		updateScore();
		callScript("onMiss", [n]);
	}

	public function spawnSplash(n:Note, strum:Strum):Void {
		if (!Options.splashes || Options.lowQuality)
			return;
		var sp:NoteSplash = splashes.recycle(NoteSplash);
		sp.revive();
		sp.setup(strum, n.lane);
		if (callScript("onSplash", [sp, n]))
			sp.kill();
	}

	function opponentHit(n:Note):Void {
		n.wasHit = true;
		singer(false, n.ch).sing(n.lane);
		oppStrums[n.lane].play("confirm");
		oppStrums[n.lane].resetTimer = 0.15;
		if (voices != null)
			voices.volume = 1;
		callScript("onOpponentHit", [n]);
	}

	function updateNotes(elapsed:Float):Void {
		var kill = killList;
		kill.resize(0);
		for (n in notes.members) {
			if (n == null || !n.alive)
				continue;
			var strum = (n.mustPress ? playerStrums : oppStrums)[n.lane];
			var end = n.strumTime + n.sustainLength;
			n.x = strum.x + (strum.width - n.width) / 2;
			if (!n.wasHit)
				n.y = strum.y + (n.strumTime - Conductor.songPosition) * pxMs * (downscroll ? -1 : 1);
			n.visible = !n.wasHit;
			n.alpha = n.tooLate ? 0.35 : 1;

			if (!n.mustPress && !n.wasHit && n.strumTime <= Conductor.songPosition)
				opponentHit(n);
			if (n.mustPress && !n.wasHit && !n.tooLate && Conductor.songPosition - n.strumTime > 160)
				missNote(n);

			if (n.sustain != null)
				layoutSustain(n, strum, end);

			if (n.wasHit) {
				if (n.mustPress && n.sustainLength > 0 && Conductor.songPosition < end) {
					if (Controls.pressed[n.lane]) {
						n.held = true;
						var hc = singer(true, n.ch);
						hc.holdTimer = 0;
						if (hc.animation.curAnim == null || hc.animation.curAnim.name != Character.SING[n.lane])
							hc.sing(n.lane);
						health = Math.min(2, health + 0.05 * elapsed);
					} else if (Conductor.songPosition < end - 100) {
						kill.push(n);
						continue;
					}
				} else if (!n.mustPress && n.sustainLength > 0 && Conductor.songPosition < end) {
					singer(false, n.ch).holdTimer = 0;
					oppStrums[n.lane].resetTimer = 0.1;
				}
				if (Conductor.songPosition >= end)
					kill.push(n);
			} else if (n.tooLate && Conductor.songPosition - end > (downscroll ? FlxG.height - strum.y + 200 : strum.y + 200) / pxMs)
				kill.push(n);
		}
		for (n in kill) {
			notes.remove(n, true);
			if (n.sustain != null) {
				sustains.remove(n.sustain, true);
				n.sustain.destroy();
			}
			if (n.tail != null) {
				sustains.remove(n.tail, true);
				n.tail.destroy();
			}
			n.destroy();
		}
	}
	function layoutSustain(n:Note, strum:Strum, end:Float):Void {
		var s = n.sustain;
		var t = n.tail;
		var center:Float;
		var len:Float;
		if (n.wasHit) {
			center = strum.y + strum.height / 2;
			len = (end - Conductor.songPosition) * pxMs;
		} else {
			center = n.y + n.height / 2;
			len = n.sustainLength * pxMs;
		}
		var a = n.tooLate ? 0.25 : 0.6;
		if (len <= 2) {
			s.visible = false;
			if (t != null)
				t.visible = false;
			return;
		}
		var tailBase:Float = t == null ? 0 : t.frameHeight * Note.SCALE;
		var tailLen:Float = Math.min(tailBase, len);
		var pieceLen:Float = len - tailLen;
		s.visible = pieceLen > 0.5;
		if (s.visible) {
			s.alpha = a;
			s.scale.y = (pieceLen + 1) / s.frameHeight;
			s.updateHitbox();
			s.x = n.x + (n.width - s.width) / 2;
			s.y = downscroll ? center - pieceLen - 1 : center;
		}
		if (t != null) {
			t.visible = true;
			t.alpha = a;
			t.flipY = downscroll;
			t.scale.set(Note.SCALE, Note.SCALE * tailLen / tailBase);
			t.updateHitbox();
			t.x = n.x + (n.width - t.width) / 2;
			t.y = downscroll ? center - pieceLen - tailLen : center + pieceLen;
		}
	}
	function popup(r:String):Void {
		if (callScript("onPopup", [r]))
			return;
		var coolX = FlxG.width * 0.55 - 125;
		var parts:Array<FlxSprite> = [];
		var rating = new FlxSprite(0, 0, Paths.image('game/score/$r'));
		rating.screenCenter();
		rating.x = coolX - 40;
		rating.y -= 60;
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);
		rating.setGraphicSize(Std.int(rating.width * 0.7));
		rating.updateHitbox();
		rating.antialiasing = Options.antialiasing;
		parts.push(rating);
		if (combo >= 10) {
			var comboSpr = new FlxSprite(0, 0, Paths.image("game/score/combo"));
			comboSpr.screenCenter();
			comboSpr.x = coolX;
			comboSpr.y += 20;
			comboSpr.acceleration.y = 600;
			comboSpr.velocity.y -= 150;
			comboSpr.velocity.x += FlxG.random.int(1, 10);
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
			comboSpr.updateHitbox();
			comboSpr.antialiasing = Options.antialiasing;
			parts.push(comboSpr);
			var cs = Std.string(combo);
			while (cs.length < 3)
				cs = "0" + cs;
			for (i in 0...cs.length) {
				var num = new FlxSprite(0, 0, Paths.image('game/score/num' + cs.charAt(i)));
				num.screenCenter();
				num.x = coolX + 43 * i - 90;
				num.y += 80;
				num.setGraphicSize(Std.int(num.width * 0.5));
				num.updateHitbox();
				num.antialiasing = Options.antialiasing;
				num.acceleration.y = FlxG.random.int(200, 300);
				num.velocity.y -= FlxG.random.int(140, 160);
				num.velocity.x = FlxG.random.float(-5, 5);
				parts.push(num);
			}
		}
		for (p in parts) {
			p.cameras = [camHUD];
			add(p);
			FlxTween.tween(p, {alpha: 0}, 0.2, {
				startDelay: Conductor.crochet * 0.002,
				onComplete: function(_) {
					remove(p);
					p.destroy();
				}
			});
		}
	}

	function updateScore():Void {
		var acc = total > 0 ? hits / total * 100 : 0;
		accuracy = acc;
		if (callScript("onUpdateScore", [score, misses, acc]))
			return;
		scoreTxt.text = Lang.get("game.score") + ':$score | ' + Lang.get("game.breaks") + ':$misses | ' + Lang.get("game.accuracy") + ':' + FlxMath.roundDecimal(acc, 2) + '%';
	}
	function updateHud(elapsed:Float):Void {
		health = FlxMath.bound(health, 0, 2);
		for (i in 0...hitbox.length)
			hitbox[i].alpha = Controls.pressed[i] ? 0.22 : Math.max(0, hitbox[i].alpha - elapsed * 2);

		if (!callScript("onUpdateIcons", [elapsed])) {
			var cx = healthBar.x + healthBar.width * (1 - health / 2);
			var iy = healthBar.y - 75;
			iconP1.setPosition(cx - 26, iy);
			iconP2.setPosition(cx - iconP2.frameWidth + 26, iy);
		}
		iconP1.animation.play(health < 0.4 ? "l" : "n");
		iconP2.animation.play(health > 1.6 ? "l" : "n");
		var k = Math.exp(-elapsed * 9);
		iconP1.scale.set(FlxMath.lerp(1, iconP1.scale.x, k), FlxMath.lerp(1, iconP1.scale.x, k));
		iconP2.scale.set(FlxMath.lerp(1, iconP2.scale.x, k), FlxMath.lerp(1, iconP2.scale.x, k));

		var z = Math.exp(-elapsed * 3.125);
		FlxG.camera.zoom = FlxMath.lerp(defaultZoom, FlxG.camera.zoom, z);
		camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, z);
	}

	override function destroy():Void {
		callScript("onDestroy");
		instance = null;
		super.destroy();
	}
}

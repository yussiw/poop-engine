package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.geom.Rectangle;
import openfl.media.Sound;
#if sys
import sys.io.File;
#end

/** Nota do editor. step e sus ficam em STEPS (16 por secao); convertidos pra ms so ao salvar. lane 0-3 = oponente, 4-7 = jogador (absoluto). */
typedef EdNote = {step:Float, lane:Int, sus:Float};

/** Botao do editor. st: 0 normal, 1 principal, 2 perigo, 3 segmento/aba (act = selecionado), 4 liga/desliga (act = ligado). tab: -1 sempre visivel, 0..2 so na aba da direita. */
typedef EdBtn = {
	spr:FlxSprite,
	txt:FlxText,
	x:Float,
	y:Float,
	w:Float,
	h:Float,
	cb:Void->Void,
	st:Int,
	tab:Int,
	en:Void->Bool,
	act:Bool,
	on:Bool
};

typedef EdTabText = {t:FlxText, tab:Int};
typedef EdPool = {arr:Array<FlxSprite>, grp:FlxTypedGroup<FlxSprite>, n:Int};
typedef EdSnap = {notes:Array<EdNote>, must:Array<Bool>};
typedef EdExtra = {t:Float, arr:Array<Dynamic>};
typedef EdClip = {d:Float, lane:Int, sus:Float};

/**
 * Editor de chart pensado pra toque, no estilo "linha do tempo continua" (como o da Codename):
 *  - a grade rola sem parar; os receptores ficam fixos e a musica passa por eles ao tocar
 *  - cada celula da grade e um QUADRADO (1 step de altura x 1 coluna de largura); notas e receptores ocupam a celula inteira
 *  - colunas absolutas: esquerda = OPONENTE (0-3), direita = JOGADOR (4-7)
 *  - a faixa da esquerda da grade e o FOCO DA CAMERA de cada secao (era o "mustHitSection"); tocar nela alterna
 *  - snap (1/4 ... 1/64), zoom (a grade inteira escala junto, entao continua quadrada), desfazer/refazer, selecao, copiar/colar, mover
 *  - arrastar uma nota pra baixo cria o sustain; arrastar no vazio rola a grade
 * Salva em <mod ativo>/songs/<id>/chart.json (formato Kade/vanilla) e inclui a musica no songlist.json do mod.
 */
class ChartEditorState extends FlxState {
	public static var songId:String = "demo";
	public static var isNew:Bool = false;
	public static var newName:String = "Nova Musica";

	/** aba aberta no painel da direita (lembrada enquanto o app estiver aberto). */
	static var rightTab:Int = 0;

	// ---- layout (1280x720)
	static inline var CELL:Int = 44; // lado da celula com zoom 100%
	static inline var CAMW:Int = 36; // largura da faixa do foco da camera
	static inline var CX:Int = 640; // centro horizontal da grade
	static inline var GY0:Int = 56; // topo da area da grade
	static inline var GH:Int = 640; // altura da area da grade
	static inline var PH:Int = 176; // y da linha de tempo atual (topo da celula dos receptores)
	static inline var STEPS:Int = 16; // steps por secao
	static inline var LX:Int = 16; // painel esquerdo
	static inline var LW:Int = 292;
	static inline var RX:Int = 968; // painel direito
	static inline var RW:Int = 252;
	static inline var SEEK_X:Int = 1232; // minimapa
	static inline var SEEK_W:Int = 28;

	// ---- paleta
	static inline var C_BG:Int = 0xFF0E0F13;
	static inline var C_PANEL:Int = 0xFF15161B;
	static inline var C_BTN:Int = 0xFF1F2128;
	static inline var C_ACCENT:Int = 0xFF4C8DFF;
	static inline var C_ACCENT_DIM:Int = 0xFF1F3A66;
	static inline var C_TEXT:Int = 0xFFE8EAF0;
	static inline var C_MUTED:Int = 0xFF8B90A0;
	static inline var C_DANGER:Int = 0xFFFF7B72;
	static inline var C_SEL:Int = 0x66FFD84D;

	static final LANE_COLORS:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
	static final QUANTS:Array<Int> = [4, 8, 12, 16, 24, 32, 48, 64];
	static final ZOOMS:Array<Float> = [0.75, 1.0, 1.25, 1.5];
	static final NUM_KEYS:Array<FlxKey> = [FlxKey.ONE, FlxKey.TWO, FlxKey.THREE, FlxKey.FOUR, FlxKey.FIVE, FlxKey.SIX, FlxKey.SEVEN, FlxKey.EIGHT];

	// ---- dados
	var songObj:Dynamic;
	var songName:String = "";
	var bpm:Float = 102;
	var speed:Float = 2;
	var notes:Array<EdNote> = [];
	var extras:Array<EdExtra> = []; // eventos / notas fora da grade: preservados ao salvar
	var must:Array<Bool> = [true]; // foco da camera por secao (true = jogador)
	var sel:Array<EdNote> = [];
	var clip:Array<EdClip> = [];
	var undoS:Array<EdSnap> = [];
	var redoS:Array<EdSnap> = [];

	// ---- estado
	var curT:Float = 0; // ms
	var zoomIdx:Int = 1;
	var cw:Float = CELL; // lado da celula (largura da coluna = altura de um step)
	var gx:Float = CX - 4 * CELL; // x da borda esquerda das 8 colunas
	var quantIdx:Int = 3;
	var tool:Int = 0; // 0 nota, 1 selecao, 2 caixa
	var dirty:Bool = false;
	var exitArmed:Bool = false;
	var playing:Bool = false;
	var hasInst:Bool = false;
	var lastT:Float = 0;
	var songLenMs:Float = 60000;
	var mapDirty:Bool = true;
	var needRedraw:Bool = true;
	var metroOn:Bool = false;
	var hitOn:Bool = true;
	var voicesOn:Bool = true;
	var instOn:Bool = true;

	// ---- audio
	var inst:FlxSound;
	var voices:FlxSound;
	var hitSnd:Sound;
	var metroSnd:Sound;

	// ---- visual
	var bgPool:EdPool;
	var linePool:EdPool;
	var camPool:EdPool;
	var ringPool:EdPool;
	var susPool:EdPool;
	var camTexts:Array<FlxText> = [];
	var camTextN:Int = 0;
	var camTxtGrp:FlxTypedGroup<FlxText>;
	var heads:Array<Array<FlxSprite>> = [];
	var headN:Array<Int> = [];
	var headGrp:FlxTypedGroup<FlxSprite>;
	var strums:Array<Strum> = [];
	var strumW:Array<Float> = [];
	var hdrIcons:Array<HealthIcon> = [];
	var hdrLbls:Array<FlxText> = [];
	var playLine:FlxSprite;
	var boxSpr:FlxSprite;
	var mini:FlxSprite;
	var viewMark:FlxSprite;
	var btns:Array<EdBtn> = [];
	var tabTexts:Array<EdTabText> = [];
	var titleTxt:FlxText;
	var modTxt:FlxText;
	var timeTxt:FlxText;
	var infoTxt:FlxText;
	var statusTxt:FlxText;
	var bpmTxt:FlxText;
	var speedTxt:FlxText;
	var playBtn:EdBtn;
	var snapBtn:EdBtn;
	var zoomBtn:EdBtn;
	var toolBtns:Array<EdBtn> = [];
	var tabBtns:Array<EdBtn> = [];
	var metroBtn:EdBtn;
	var hitBtn:EdBtn;
	var voicesBtn:EdBtn;
	var instBtn:EdBtn;
	var focusBtn:EdBtn;

	// ---- ponteiro (um dedo / mouse)
	var activeId:Int = -99;
	var px:Float = 0;
	var py:Float = 0;
	var pJust:Bool = false;
	var pHeld:Bool = false;
	var pUp:Bool = false;
	var gKind:Int = 0; // 0 nada, 1 botao, 2 barra de busca, 3 grade
	var gMode:Int = 0; // 0 pendente, 1 rolar, 2 sustain, 3 caixa
	var gSX:Float = 0;
	var gSY:Float = 0;
	var gSCurT:Float = 0;
	var gNote:EdNote = null;
	var pressedBtn:EdBtn = null;
	var seekResume:Bool = false;
	var scrollVel:Float = 0;

	override function create():Void {
		super.create();
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		loadChart();
		Conductor.setBpm(bpm);

		hitSnd = Paths.sfx("menu/volume");
		metroSnd = Paths.sfx("tick");

		var bg = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, C_BG, true);
		add(bg);

		// ---- audio
		var snd = Paths.audio('songs/$songId/Inst.ogg');
		hasInst = snd != null;
		if (snd == null)
			snd = Paths.music("freakyMenu");
		inst = FlxG.sound.load(snd);
		var vs = Paths.audio('songs/$songId/Voices.ogg');
		if (vs != null)
			voices = FlxG.sound.load(vs);

		// ---- grade (ordem de desenho: fundo, linhas, foco, selecao, sustains, receptores, notas, linha atual)
		bgPool = mkPool();
		linePool = mkPool();
		camPool = mkPool();
		camTxtGrp = new FlxTypedGroup<FlxText>();
		add(camTxtGrp);
		ringPool = mkPool();
		susPool = mkPool();
		for (i in 0...8) {
			var s = new Strum(0, 0, i % 4);
			strumW.push(s.frameWidth);
			s.alpha = 0.95;
			add(s);
			strums.push(s);
		}
		headGrp = new FlxTypedGroup<FlxSprite>();
		add(headGrp);
		for (i in 0...8) {
			heads.push([]);
			headN.push(0);
		}
		playLine = new FlxSprite(0, PH - 1).makeGraphic(1, 2, 0xFFFFFFFF);
		playLine.alpha = 0.8;
		add(playLine);
		boxSpr = new FlxSprite(0, 0).makeGraphic(1, 1, 0xFFFFFFFF);
		boxSpr.color = C_ACCENT;
		boxSpr.alpha = 0.3;
		boxSpr.visible = false;
		add(boxSpr);

		buildUi();
		applyZoom();
		rebuildMap();
		setTime(0);

		var mod = Paths.currentMod();
		var dir = (mod == "" ? "<seu mod>" : mod) + "/songs/" + songId + "/";
		if (!hasInst)
			setStatus("Sem Inst.ogg: usando a música do menu (102 BPM) só pra testar. Ponha Inst.ogg (e Voices.ogg) em mods/" + dir);
		else
			setStatus("Pronto. Toque na grade pra pôr/tirar notas, arraste no vazio pra rolar.");
	}

	// ------------------------------------------------------------------ carregar
	function loadChart():Void {
		var raw:Dynamic = isNew ? null : Paths.json('songs/$songId/chart.json');
		if (raw == null) {
			songObj = {
				song: newName,
				bpm: 102,
				speed: 2.0,
				player1: "bf",
				player2: "dad",
				stage: "default",
				notes: []
			};
		} else
			songObj = (raw.song != null && !Std.isOfType(raw.song, String)) ? raw.song : raw;

		songName = songObj.song != null ? Std.string(songObj.song) : songId;
		bpm = songObj.bpm != null ? songObj.bpm : 102;
		speed = songObj.speed != null ? songObj.speed : 2;
		var sc = stepMs();

		must = [];
		notes = [];
		extras = [];
		var secs:Array<Dynamic> = songObj.notes != null ? songObj.notes : [];
		for (sec in secs) {
			var m:Bool = sec.mustHitSection == true;
			must.push(m);
			var sn:Array<Dynamic> = sec.sectionNotes;
			if (sn == null)
				continue;
			for (n in sn) {
				var lane = Std.int(n[1]);
				if (lane < 0 || lane > 7) {
					extras.push({t: n[0], arr: n}); // eventos: ficam guardados e voltam no save
					continue;
				}
				var isP = lane < 4 ? m : !m; // mesma regra do PlayState
				var sus:Float = (n[2] != null && n[2] > 0) ? n[2] / sc : 0;
				notes.push({step: n[0] / sc, lane: (isP ? 4 : 0) + lane % 4, sus: sus});
			}
		}
		if (must.length == 0)
			must.push(true);
	}

	function stepMs():Float
		return 60000 / bpm / 4;

	/** altura de um step = lado da celula (a grade e quadrada). */
	function stepH():Float
		return cw;

	function snapStep():Float
		return STEPS / QUANTS[quantIdx];

	function curStep():Float
		return curT / stepMs();

	function yOfStep(s:Float):Float
		return PH + (s - curStep()) * stepH();

	function stepOfY(y:Float):Float
		return curStep() + (y - PH) / stepH();

	/** arredonda pro snap mais proximo (usado em colar / sustain). */
	function snapRound(v:Float):Float {
		var ss = snapStep();
		return Math.round(v / ss) * ss;
	}

	/** arredonda pra baixo (pro topo da celula tocada). */
	function snapFloor(v:Float):Float {
		var ss = snapStep();
		return Math.floor(v / ss + 0.0001) * ss;
	}

	function onSnap(s:Float):Bool {
		var r = s / snapStep();
		return Math.abs(r - Math.round(r)) < 0.001;
	}

	function mustAt(sec:Int):Bool
		return sec < must.length ? must[sec] : must[must.length - 1];

	function ensureSection(i:Int):Void {
		while (must.length <= i)
			must.push(must[must.length - 1]);
	}

	function curSection():Int
		return Std.int(Math.max(0, Math.floor(curStep() / STEPS)));

	// ------------------------------------------------------------------ zoom / layout da grade
	function applyZoom():Void {
		cw = CELL * ZOOMS[zoomIdx];
		gx = CX - 4 * cw;
		for (i in 0...8) {
			var s = strums[i];
			var k = (cw - 2) / strumW[i];
			s.scale.set(k, k);
			s.updateHitbox();
			s.setPosition(gx + i * cw + cw / 2 - s.width / 2, PH + cw / 2 - s.height / 2);
		}
		for (i in 0...2) {
			var c = gx + (i * 4 + 2) * cw;
			hdrIcons[i].setPosition(c - 56, 12);
			hdrLbls[i].setPosition(c - 18, 18);
		}
		playLine.setGraphicSize(CAMW + 8 * cw, 2);
		playLine.updateHitbox();
		playLine.setPosition(gx - CAMW, PH - 1);
		needRedraw = true;
	}

	// ------------------------------------------------------------------ pools
	function mkPool():EdPool {
		var g = new FlxTypedGroup<FlxSprite>();
		add(g);
		return {arr: [], grp: g, n: 0};
	}

	function poolBegin(p:EdPool):Void
		p.n = 0;

	function poolRect(p:EdPool, x:Float, y:Float, w:Float, h:Float, col:Int):Void {
		var s:FlxSprite;
		if (p.n >= p.arr.length) {
			s = new FlxSprite().makeGraphic(1, 1, 0xFFFFFFFF);
			s.active = false;
			p.grp.add(s);
			p.arr.push(s);
		} else
			s = p.arr[p.n];
		p.n++;
		s.visible = true;
		s.color = col & 0xFFFFFF;
		s.alpha = ((col >>> 24) & 0xFF) / 255;
		s.setGraphicSize(Math.max(1, w), Math.max(1, h));
		s.updateHitbox();
		s.setPosition(x, y);
	}

	function poolEnd(p:EdPool):Void {
		for (i in p.n...p.arr.length)
			p.arr[i].visible = false;
	}

	function getCamText():FlxText {
		var t:FlxText;
		if (camTextN >= camTexts.length) {
			t = new FlxText(0, 0, CAMW, "", 11);
			t.setFormat(Paths.font("ui.ttf"), 11, C_TEXT, FlxTextAlign.CENTER);
			t.antialiasing = true;
			camTxtGrp.add(t);
			camTexts.push(t);
		} else
			t = camTexts[camTextN];
		camTextN++;
		t.visible = true;
		return t;
	}

	function getHead(lane:Int):FlxSprite {
		var arr = heads[lane];
		var i = headN[lane]++;
		if (i >= arr.length) {
			var s = new FlxSprite();
			var f = Paths.sparrow("game/notes/default");
			if (f != null) {
				s.frames = f;
				s.animation.addByPrefix("n", Note.COLORS[lane % 4] + "0", 24, true);
				s.animation.play("n");
			} else
				s.makeGraphic(20, 20, LANE_COLORS[lane % 4]);
			s.antialiasing = true;
			headGrp.add(s);
			arr.push(s);
		}
		var h = arr[i];
		h.visible = true;
		return h;
	}

	// ------------------------------------------------------------------ desenho
	function redraw():Void {
		needRedraw = false;
		var sh = stepH();
		var cs = curStep();
		var topStep = cs - (PH - GY0) / sh;
		var botStep = cs + (GY0 + GH - PH) / sh;
		var gw = 8 * cw;

		// fundo alternando por beat (4 steps = 4 quadrados)
		poolBegin(bgPool);
		var b0 = Math.floor(topStep / 4);
		var b1 = Math.ceil(botStep / 4);
		for (b in b0...(b1 + 1)) {
			var col = b < 0 ? 0xFF090A0D : ((b % 2 == 0) ? 0xFF1B1D24 : 0xFF171920);
			poolRect(bgPool, gx, yOfStep(b * 4), gw, 4 * sh, col);
		}
		poolEnd(bgPool);

		// linhas: colunas, steps (cada quadrado), beats, secoes e subdivisoes do snap
		poolBegin(linePool);
		for (i in 0...9) {
			if (i == 4)
				poolRect(linePool, gx + i * cw - 1, GY0 - 40, 2, GH + 80, 0xFF6B7084);
			else
				poolRect(linePool, gx + i * cw, GY0 - 40, 1, GH + 80, 0xFF2B2E3A);
		}
		var s0 = Math.floor(topStep);
		var s1 = Math.ceil(botStep);
		for (i in s0...(s1 + 1)) {
			if (i < 0)
				continue;
			var y = yOfStep(i);
			if (i % STEPS == 0)
				poolRect(linePool, gx, y - 1, gw, 2, 0xFFB8BCD0);
			else if (i % 4 == 0)
				poolRect(linePool, gx, y, gw, 1, 0xFF4A4E60);
			else
				poolRect(linePool, gx, y, gw, 1, 0xFF2B2E3A);
		}
		var ss = snapStep();
		if (Math.abs(ss - 1) > 0.001) {
			var k0 = Math.floor(topStep / ss);
			var k1 = Math.ceil(botStep / ss);
			for (k in k0...(k1 + 1)) {
				var st = k * ss;
				if (st < 0)
					continue;
				if (ss < 1 && Math.abs(st - Math.round(st)) < 0.001)
					continue; // ja tem a linha do step
				poolRect(linePool, gx, yOfStep(st), gw, 1, ss < 1 ? 0xFF22252F : 0xFF5A6078);
			}
		}
		poolEnd(linePool);

		// foco da camera por secao
		poolBegin(camPool);
		camTextN = 0;
		var sc0 = Std.int(Math.max(0, Math.floor(topStep / STEPS)));
		var sc1 = Math.floor(botStep / STEPS);
		for (s in sc0...(sc1 + 1)) {
			var m = mustAt(s);
			var y = yOfStep(s * STEPS);
			var h = STEPS * sh;
			poolRect(camPool, gx - CAMW + 2, y + 2, CAMW - 4, h - 4, m ? 0xFF223F66 : 0xFF5A2A45);
			var t = getCamText();
			t.text = (s + 1) + "\n" + (m ? "JOG" : "OPO");
			var ty = Math.max(y + 6, GY0 + 6);
			ty = Math.min(ty, y + h - 32);
			t.setPosition(gx - CAMW, ty);
		}
		poolEnd(camPool);
		for (i in camTextN...camTexts.length)
			camTexts[i].visible = false;

		// notas: cada uma ocupa a celula logo abaixo da linha do seu step (o mesmo lugar do receptor quando passa pelo playhead)
		poolBegin(ringPool);
		poolBegin(susPool);
		for (i in 0...8)
			headN[i] = 0;
		var size = cw - 2;
		var bw = Math.max(6, cw * 0.22);
		for (n in notes) {
			var y = yOfStep(n.step);
			var yEnd = n.sus > 0 ? yOfStep(n.step + n.sus) : y;
			if (yEnd + sh < GY0 - 4 || y > GY0 + GH + 4)
				continue;
			var cx = gx + n.lane * cw + cw / 2;
			var cy = y + cw / 2;
			var rgb = LANE_COLORS[n.lane % 4] & 0xFFFFFF;
			if (n.sus > 0) {
				var y1 = yEnd + cw / 2;
				poolRect(susPool, cx - bw / 2, cy, bw, y1 - cy, 0xCC000000 | rgb);
				poolRect(susPool, cx - bw, y1 - 3, bw * 2, 3, 0xFF000000 | rgb);
			}
			if (sel.indexOf(n) >= 0)
				poolRect(ringPool, gx + n.lane * cw, y, cw, cw, C_SEL);
			var hd = getHead(n.lane);
			var k = size / hd.frameWidth;
			hd.scale.set(k, k);
			hd.updateHitbox();
			hd.setPosition(cx - hd.width / 2, cy - hd.height / 2);
		}
		poolEnd(ringPool);
		poolEnd(susPool);
		for (l in 0...8)
			for (i in headN[l]...heads[l].length)
				heads[l][i].visible = false;

		// marcador de posicao na barra de busca
		var topT = topStep * stepMs();
		var spanT = (GH / sh) * stepMs();
		viewMark.setGraphicSize(SEEK_W - 2, Math.max(4, spanT / songLenMs * GH));
		viewMark.updateHitbox();
		viewMark.setPosition(SEEK_X + 1, GY0 + Math.max(0, Math.min(1, topT / songLenMs)) * GH);
	}

	/** Recalcula o tamanho da musica e redesenha o minimapa (barra da direita). */
	function rebuildMap():Void {
		mapDirty = false;
		var lastMs = 0.0;
		var sm = stepMs();
		for (n in notes)
			lastMs = Math.max(lastMs, (n.step + n.sus) * sm);
		var len = inst != null ? inst.length : 0;
		songLenMs = Math.max(Math.max(len, lastMs + STEPS * sm * 2), STEPS * sm * 4);
		var bd = mini.pixels;
		bd.fillRect(new Rectangle(0, 0, bd.width, bd.height), C_PANEL);
		for (n in notes) {
			var y = Std.int(Math.min(GH - 2, n.step * sm / songLenMs * GH));
			bd.fillRect(new Rectangle(2 + n.lane * 3, y, 2, 2), LANE_COLORS[n.lane % 4]);
		}
		mini.dirty = true;
	}

	// ------------------------------------------------------------------ UI
	function mk(x:Float, y:Float, w:Float, h:Float, text:String, cb:Void->Void, st:Int = 0, size:Int = 15, tab:Int = -1):EdBtn {
		var s = new FlxSprite().makeGraphic(1, 1, 0xFFFFFFFF);
		s.setGraphicSize(w, h);
		s.updateHitbox();
		s.setPosition(x, y);
		s.color = C_BTN;
		var t = new FlxText(x, y, w, text, size);
		t.setFormat(Paths.font("ui.ttf"), size, C_TEXT, FlxTextAlign.CENTER);
		t.antialiasing = true;
		t.y = y + (h - t.height) / 2;
		add(s);
		add(t);
		var b:EdBtn = {
			spr: s,
			txt: t,
			x: x,
			y: y,
			w: w,
			h: h,
			cb: cb,
			st: st,
			tab: tab,
			en: null,
			act: false,
			on: true
		};
		btns.push(b);
		return b;
	}

	/** define quando o botao esta habilitado (desabilitado = apagado e sem resposta ao toque). */
	function enableWhen(b:EdBtn, f:Void->Bool):EdBtn {
		b.en = f;
		return b;
	}

	function panel(x:Float, y:Float, w:Float, h:Float, color:Int):FlxSprite {
		var s = new FlxSprite().makeGraphic(1, 1, 0xFFFFFFFF);
		s.setGraphicSize(w, h);
		s.updateHitbox();
		s.setPosition(x, y);
		s.color = color & 0xFFFFFF;
		s.alpha = ((color >>> 24) & 0xFF) / 255;
		add(s);
		return s;
	}

	function label(x:Float, y:Float, w:Float, size:Int, color:Int, align:FlxTextAlign, tab:Int = -1):FlxText {
		var t = new FlxText(x, y, w, "", size);
		t.setFormat(Paths.font("ui.ttf"), size, color, align);
		t.antialiasing = true;
		add(t);
		if (tab >= 0)
			tabTexts.push({t: t, tab: tab});
		return t;
	}

	function charIcon(id:Dynamic):String {
		var cj:Dynamic = id != null ? Paths.json('data/characters/' + Std.string(id) + '.json') : null;
		return (cj != null && cj.icon != null) ? Std.string(cj.icon) : "face";
	}

	function buildUi():Void {
		// coberturas (escondem o que sai da area da grade) + paineis laterais
		panel(0, 0, FlxG.width, GY0, C_BG);
		panel(0, GY0 - 1, FlxG.width, 1, 0xFF22242C);
		panel(0, GY0 + GH, FlxG.width, FlxG.height - GY0 - GH, C_BG);
		panel(0, GY0, LX + LW + 16, GH, C_PANEL);
		panel(RX - 8, GY0, RW + 16, GH, C_PANEL);

		// ---- topo: voltar, titulo, icones das colunas, testar / salvar
		mk(12, 8, 40, 40, "←", leave, 0, 20);
		titleTxt = label(64, 8, 300, 16, C_TEXT, FlxTextAlign.LEFT);
		modTxt = label(64, 30, 300, 11, C_MUTED, FlxTextAlign.LEFT);
		var names = ["Oponente", "Jogador"];
		var ids = [songObj.player2, songObj.player1];
		for (i in 0...2) {
			var ic = new HealthIcon(charIcon(ids[i]), false);
			ic.setGraphicSize(32, 32);
			ic.updateHitbox();
			add(ic);
			hdrIcons.push(ic);
			var l = label(0, 0, 100, 14, C_TEXT, FlxTextAlign.LEFT);
			l.text = names[i];
			hdrLbls.push(l);
		}
		mk(1060, 8, 88, 40, "Testar", testSong, 0, 15);
		mk(1156, 8, 96, 40, "Salvar", function() {
			save();
		}, 1, 15);

		// ---- painel esquerdo: transporte, ferramentas, grade, edicao
		playBtn = mk(LX, 68, LW, 48, "Reproduzir", togglePlay, 1, 18);
		timeTxt = label(LX, 124, LW, 22, C_TEXT, FlxTextAlign.LEFT);
		infoTxt = label(LX, 152, LW, 12, C_MUTED, FlxTextAlign.LEFT);
		var third = (LW - 16) / 3;
		mk(LX, 194, third, 36, "Início", function() navTo(0));
		mk(LX + third + 8, 194, third, 36, "‹ Seção", function() navSection(-1));
		mk(LX + 2 * (third + 8), 194, third, 36, "Seção ›", function() navSection(1));

		label(LX, 246, LW, 11, C_MUTED, FlxTextAlign.LEFT).text = "FERRAMENTA";
		var tn = ["Nota", "Seleção", "Caixa"];
		for (i in 0...3) {
			var ti = i;
			toolBtns.push(mk(LX + i * (third + 8), 264, third, 36, tn[i], function() setTool(ti), 3));
		}

		label(LX, 316, LW, 11, C_MUTED, FlxTextAlign.LEFT).text = "GRADE";
		mk(LX, 334, 48, 36, "‹", function() changeQuant(-1));
		snapBtn = mk(LX + 56, 334, LW - 112, 36, "", function() changeQuant(1));
		mk(LX + LW - 48, 334, 48, 36, "›", function() changeQuant(1));
		mk(LX, 378, 48, 36, "−", function() changeZoom(-1));
		zoomBtn = mk(LX + 56, 378, LW - 112, 36, "", function() setZoom(1));
		mk(LX + LW - 48, 378, 48, 36, "+", function() changeZoom(1));

		label(LX, 430, LW, 11, C_MUTED, FlxTextAlign.LEFT).text = "EDIÇÃO";
		var half = (LW - 8) / 2;
		enableWhen(mk(LX, 448, half, 36, "Desfazer", undo), function() return undoS.length > 0);
		enableWhen(mk(LX + half + 8, 448, half, 36, "Refazer", redo), function() return redoS.length > 0);
		enableWhen(mk(LX, 492, third, 36, "Copiar", copySel), function() return sel.length > 0);
		enableWhen(mk(LX + third + 8, 492, third, 36, "Colar", pasteSel), function() return clip.length > 0);
		enableWhen(mk(LX + 2 * (third + 8), 492, third, 36, "Apagar", deleteSel, 2), function() return sel.length > 0);
		var quarter = (LW - 24) / 4;
		var mv = ["↑", "↓", "←", "→"];
		for (i in 0...4) {
			var mi = i;
			enableWhen(mk(LX + i * (quarter + 8), 536, quarter, 36, mv[i], function() {
				if (mi == 0)
					moveSel(-snapStep(), 0);
				else if (mi == 1)
					moveSel(snapStep(), 0);
				else
					moveSel(0, mi == 2 ? -1 : 1);
			}, 0, 17), function() return sel.length > 0);
		}
		label(LX, 590, LW, 12, C_MUTED, FlxTextAlign.LEFT).text = "Toque: põe/tira nota\nArraste a nota para baixo: sustain\nArraste no vazio: rolar a grade\nToque na faixa à esquerda: foco da câmera";

		// ---- painel direito: abas
		var tw = (RW - 16) / 3;
		var tabNames = ["Seção", "Áudio", "Música"];
		for (i in 0...3) {
			var ti = i;
			tabBtns.push(mk(RX + i * (tw + 8), 68, tw, 36, tabNames[i], function() setRightTab(ti), 3));
		}
		// aba 0: secao
		focusBtn = mk(RX, 120, RW, 44, "", toggleFocusHere, 0, 15, 0);
		enableWhen(mk(RX, 172, RW, 40, "Copiar da seção anterior", copyPrev, 0, 15, 0), function() return curSection() > 0);
		mk(RX, 220, RW, 40, "Selecionar seção", selectSection, 0, 15, 0);
		mk(RX, 268, RW, 40, "Limpar seção", clearSection, 2, 15, 0);
		label(RX, 326, RW, 12, C_MUTED, FlxTextAlign.LEFT, 0).text = "A faixa colorida à esquerda da grade mostra para quem a câmera aponta em cada seção (azul = jogador, rosa = oponente). As notas não mudam de lado.";
		// aba 1: audio
		metroBtn = mk(RX, 120, RW, 40, "", function() {
			metroOn = !metroOn;
		}, 4, 15, 1);
		hitBtn = mk(RX, 168, RW, 40, "", function() {
			hitOn = !hitOn;
		}, 4, 15, 1);
		voicesBtn = mk(RX, 216, RW, 40, "", function() {
			voicesOn = !voicesOn;
			applyVolumes();
		}, 4, 15, 1);
		instBtn = mk(RX, 264, RW, 40, "", function() {
			instOn = !instOn;
			applyVolumes();
		}, 4, 15, 1);
		// aba 2: musica
		label(RX, 120, RW, 11, C_MUTED, FlxTextAlign.LEFT, 2).text = "BPM";
		bpmTxt = label(RX, 138, RW, 26, C_TEXT, FlxTextAlign.LEFT, 2);
		var q4 = (RW - 24) / 4;
		var bd = [-10, -1, 1, 10];
		var bl = ["−10", "−1", "+1", "+10"];
		for (i in 0...4) {
			var v = bd[i];
			mk(RX + i * (q4 + 8), 176, q4, 36, bl[i], function() changeBpm(v), 0, 14, 2);
		}
		label(RX, 236, RW, 11, C_MUTED, FlxTextAlign.LEFT, 2).text = "VELOCIDADE";
		speedTxt = label(RX, 254, RW, 26, C_TEXT, FlxTextAlign.LEFT, 2);
		var h2 = (RW - 8) / 2;
		mk(RX, 292, h2, 36, "−", function() changeSpeed(-0.1), 0, 17, 2);
		mk(RX + h2 + 8, 292, h2, 36, "+", function() changeSpeed(0.1), 0, 17, 2);
		setRightTab(rightTab);

		// ---- barra de busca (minimapa)
		mini = new FlxSprite(SEEK_X, GY0).makeGraphic(SEEK_W, GH, C_PANEL, true);
		add(mini);
		viewMark = new FlxSprite(SEEK_X, GY0).makeGraphic(1, 1, 0xFFFFFFFF);
		viewMark.alpha = 0.3;
		add(viewMark);

		// ---- rodape
		statusTxt = label(16, GY0 + GH + 4, 1248, 12, C_MUTED, FlxTextAlign.LEFT);
	}

	function setRightTab(i:Int):Void {
		rightTab = i;
		for (b in btns)
			if (b.tab >= 0)
				b.on = b.tab == i;
		for (t in tabTexts)
			t.t.visible = t.tab == i;
	}

	function playSnd(snd:Sound, vol:Float):Void {
		if (snd != null)
			FlxG.sound.play(snd, vol);
	}

	function setStatus(msg:String, warn:Bool = false):Void {
		statusTxt.text = msg;
		statusTxt.color = warn ? C_DANGER : C_MUTED;
	}

	function fmtTime(ms:Float):String {
		var m = Math.floor(ms / 60000);
		var s = Math.floor(ms / 1000) % 60;
		var d = Math.floor(ms / 100) % 10;
		return m + ":" + (s < 10 ? "0" : "") + s + "." + d;
	}

	function shortName(s:String, max:Int):String
		return s.length > max ? s.substr(0, max - 1) + "…" : s;

	function onOff(b:Bool, name:String):String
		return (b ? "●  " : "○  ") + name;

	function paintBtn(b:EdBtn):Void {
		b.spr.visible = b.txt.visible = b.on;
		if (!b.on)
			return;
		var enabled = b.en == null || b.en();
		var bg = C_BTN;
		var fg = C_TEXT;
		switch (b.st) {
			case 1:
				bg = C_ACCENT;
				fg = 0xFFFFFFFF;
			case 2:
				fg = C_DANGER;
			case 3:
				bg = b.act ? C_ACCENT : C_BTN;
				fg = b.act ? 0xFFFFFFFF : C_MUTED;
			case 4:
				bg = b.act ? C_ACCENT_DIM : C_BTN;
				fg = b.act ? C_TEXT : C_MUTED;
			default:
		}
		b.spr.color = bg;
		b.txt.color = fg;
		var a:Float = enabled ? 1 : 0.35;
		if (b == pressedBtn)
			a = 0.65;
		b.spr.alpha = a;
		b.txt.alpha = a;
	}

	function updateHud():Void {
		var sec = curSection();
		var mod = Paths.currentMod();
		titleTxt.text = shortName(songName, 30) + (dirty ? "  ●" : "");
		modTxt.text = (mod == "" ? "Sem mod ativo (não salva)" : "Mod: " + mod) + "  ·  " + songId;
		timeTxt.text = fmtTime(curT) + " / " + fmtTime(songLenMs);
		infoTxt.text = "Passo " + Math.floor(curStep()) + "  ·  Beat " + Math.floor(curStep() / 4) + "  ·  Seção " + (sec + 1) + "\n" + "Notas " + notes.length
			+ (sel.length > 0 ? "  ·  " + sel.length + " selecionada(s)" : "");
		bpmTxt.text = Std.string(Math.round(bpm * 100) / 100);
		speedTxt.text = Std.string(Math.round(speed * 10) / 10);
		snapBtn.txt.text = "Snap 1/" + QUANTS[quantIdx];
		zoomBtn.txt.text = "Zoom " + Math.round(ZOOMS[zoomIdx] * 100) + "%";
		focusBtn.txt.text = "Câmera: " + (mustAt(sec) ? "Jogador" : "Oponente");
		playBtn.txt.text = playing ? "Pausar" : "Reproduzir";
		metroBtn.txt.text = onOff(metroOn, "Metrônomo");
		hitBtn.txt.text = onOff(hitOn, "Som ao passar nas notas");
		voicesBtn.txt.text = onOff(voicesOn, "Vozes");
		instBtn.txt.text = onOff(instOn, "Instrumental");
		metroBtn.act = metroOn;
		hitBtn.act = hitOn;
		voicesBtn.act = voicesOn;
		instBtn.act = instOn;
		for (i in 0...3) {
			toolBtns[i].act = tool == i;
			tabBtns[i].act = rightTab == i;
		}
		for (b in btns)
			paintBtn(b);
	}

	function markDirty():Void {
		dirty = true;
		exitArmed = false;
		mapDirty = true;
		needRedraw = true;
	}

	// ------------------------------------------------------------------ desfazer / refazer
	function snapshot():EdSnap {
		var c:Array<EdNote> = [];
		for (n in notes)
			c.push({step: n.step, lane: n.lane, sus: n.sus});
		return {notes: c, must: must.copy()};
	}

	function pushUndo():Void {
		undoS.push(snapshot());
		if (undoS.length > 100)
			undoS.shift();
		redoS = [];
	}

	function restore(s:EdSnap):Void {
		notes = s.notes;
		must = s.must;
		sel = [];
		markDirty();
	}

	function undo():Void {
		if (undoS.length == 0) {
			setStatus("Nada pra desfazer.");
			return;
		}
		redoS.push(snapshot());
		restore(undoS.pop());
		setStatus("Desfeito.");
	}

	function redo():Void {
		if (redoS.length == 0) {
			setStatus("Nada pra refazer.");
			return;
		}
		undoS.push(snapshot());
		restore(redoS.pop());
		setStatus("Refeito.");
	}

	// ------------------------------------------------------------------ navegacao
	function setTime(t:Float):Void {
		curT = Math.max(0, Math.min(songLenMs, t));
		needRedraw = true;
	}

	function navTo(step:Float):Void {
		var was = playing;
		if (was)
			stopPlay();
		scrollVel = 0;
		setTime(step * stepMs());
		if (was)
			startPlay();
	}

	function navSection(d:Int):Void {
		var cs = curStep() / STEPS;
		var target = d > 0 ? Math.floor(cs + 0.001) + 1 : Math.ceil(cs - 0.001) - 1;
		navTo(Math.max(0, target) * STEPS);
	}

	function setTool(t:Int):Void {
		tool = t;
		setStatus(t == 0 ? "Nota: toque põe/tira nota. Arraste uma nota pra baixo = sustain." : (t == 1 ? "Seleção: toque numa nota pra marcar/desmarcar." : "Caixa: arraste um retângulo pra selecionar notas."));
	}

	function changeQuant(d:Int):Void {
		quantIdx = (quantIdx + d + QUANTS.length) % QUANTS.length;
		needRedraw = true;
	}

	function setZoom(i:Int):Void {
		zoomIdx = Std.int(Math.max(0, Math.min(ZOOMS.length - 1, i)));
		applyZoom();
	}

	function changeZoom(d:Int):Void
		setZoom(zoomIdx + d);

	function applyVolumes():Void {
		inst.volume = instOn ? 1 : 0;
		if (voices != null)
			voices.volume = voicesOn ? 1 : 0;
	}

	// ------------------------------------------------------------------ edicao
	function changeBpm(d:Float):Void {
		if (playing)
			stopPlay();
		var st = curStep();
		bpm = Math.max(20, Math.min(400, bpm + d));
		Conductor.setBpm(bpm);
		curT = st * stepMs();
		markDirty();
		setStatus("BPM mudou: as notas continuam nos mesmos steps (o tempo em ms muda).");
	}

	function changeSpeed(d:Float):Void {
		speed = Math.max(0.5, Math.min(6, Math.round((speed + d) * 10) / 10));
		dirty = true;
		exitArmed = false;
	}

	function toggleFocusHere():Void {
		toggleFocus(curSection());
	}

	function toggleFocus(sec:Int):Void {
		pushUndo();
		ensureSection(sec);
		must[sec] = !must[sec];
		markDirty();
		setStatus("Câmera da seção " + (sec + 1) + ": " + (must[sec] ? "jogador" : "oponente") + " (as notas não mudam de lado).");
	}

	function inSection(n:EdNote, sec:Int):Bool
		return n.step >= sec * STEPS - 0.01 && n.step < (sec + 1) * STEPS - 0.01;

	function clearSection():Void {
		var sec = curSection();
		pushUndo();
		var keep:Array<EdNote> = [];
		for (n in notes)
			if (!inSection(n, sec))
				keep.push(n);
		notes = keep;
		sel = [];
		markDirty();
		setStatus("Seção " + (sec + 1) + " limpa.");
	}

	function copyPrev():Void {
		var sec = curSection();
		if (sec == 0) {
			setStatus("Não tem seção anterior.");
			return;
		}
		pushUndo();
		var keep:Array<EdNote> = [];
		var added:Array<EdNote> = [];
		for (n in notes) {
			if (inSection(n, sec))
				continue;
			keep.push(n);
			if (inSection(n, sec - 1))
				added.push({step: n.step + STEPS, lane: n.lane, sus: n.sus});
		}
		notes = keep.concat(added);
		ensureSection(sec);
		must[sec] = must[sec - 1];
		sel = [];
		markDirty();
		setStatus("Copiado da seção anterior.");
	}

	/**
	 * Nota que esta na celula tocada (rawStep = posicao tocada em steps) na coluna `lane`.
	 * Notas alinhadas ao snap casam pelo topo da celula; notas fora do snap (charts importados) casam por conter o ponto.
	 */
	function noteAtTap(lane:Int, rawStep:Float):EdNote {
		var target = snapFloor(rawStep);
		var best:EdNote = null;
		var bd = 1e9;
		for (n in notes)
			if (n.lane == lane) {
				if (Math.abs(n.step - target) < 0.01)
					return n;
				if (!onSnap(n.step) && rawStep >= n.step && rawStep < n.step + 1) {
					var d = rawStep - n.step;
					if (d < bd) {
						best = n;
						bd = d;
					}
				}
			}
		return best;
	}

	function toggleNoteAt(lane:Int, rawStep:Float):Void {
		var ex = noteAtTap(lane, rawStep);
		pushUndo();
		if (ex != null) {
			notes.remove(ex);
			sel.remove(ex);
		} else {
			var st = snapFloor(rawStep);
			if (st < 0) {
				undoS.pop();
				return;
			}
			notes.push({step: st, lane: lane, sus: 0});
			if (hitOn)
				playSnd(hitSnd, 0.3);
		}
		markDirty();
	}

	function placeAtPlayhead(lane:Int):Void
		toggleNoteAt(lane, snapRound(curStep()));

	function selectSection():Void {
		var sec = curSection();
		sel = [];
		for (n in notes)
			if (inSection(n, sec))
				sel.push(n);
		needRedraw = true;
		setStatus(sel.length + " notas selecionadas (seção " + (sec + 1) + ").");
	}

	function copySel():Void {
		if (sel.length == 0) {
			setStatus("Nada selecionado.");
			return;
		}
		var m = 1e9;
		for (n in sel)
			m = Math.min(m, n.step);
		clip = [];
		for (n in sel)
			clip.push({d: n.step - m, lane: n.lane, sus: n.sus});
		setStatus(clip.length + " notas copiadas. Role até o destino e toque em Colar.");
	}

	function pasteSel():Void {
		if (clip.length == 0) {
			setStatus("Área de cópia vazia.");
			return;
		}
		pushUndo();
		var base = snapRound(curStep());
		sel = [];
		for (c in clip) {
			var n:EdNote = {step: base + c.d, lane: c.lane, sus: c.sus};
			notes.push(n);
			sel.push(n);
		}
		markDirty();
		setStatus(clip.length + " notas coladas no step " + Math.round(base) + ".");
	}

	function deleteSel():Void {
		if (sel.length == 0) {
			setStatus("Nada selecionado.");
			return;
		}
		pushUndo();
		for (n in sel)
			notes.remove(n);
		setStatus(sel.length + " notas apagadas.");
		sel = [];
		markDirty();
	}

	function moveSel(dStep:Float, dLane:Int):Void {
		if (sel.length == 0) {
			setStatus("Selecione notas primeiro (ferramenta Seleção ou Caixa).");
			return;
		}
		for (n in sel)
			if (n.step + dStep < -0.001 || n.lane + dLane < 0 || n.lane + dLane > 7) {
				setStatus("Não dá pra mover mais nessa direção.");
				return;
			}
		pushUndo();
		for (n in sel) {
			n.step += dStep;
			n.lane += dLane;
		}
		markDirty();
	}

	// ------------------------------------------------------------------ ponteiro
	function readPointer():Void {
		pJust = false;
		pUp = false;
		if (activeId == -99) {
			pHeld = false;
			for (t in FlxG.touches.list)
				if (t.justPressed) {
					activeId = t.touchPointID;
					px = t.screenX;
					py = t.screenY;
					pJust = true;
					pHeld = true;
					return;
				}
			#if !mobile
			if (FlxG.mouse.justPressed) {
				activeId = -1;
				px = FlxG.mouse.screenX;
				py = FlxG.mouse.screenY;
				pJust = true;
				pHeld = true;
			}
			#end
			return;
		}
		var found = false;
		for (t in FlxG.touches.list)
			if (t.touchPointID == activeId) {
				found = true;
				px = t.screenX;
				py = t.screenY;
				if (t.justReleased)
					pUp = true;
				break;
			}
		#if !mobile
		if (activeId == -1) {
			found = true;
			px = FlxG.mouse.screenX;
			py = FlxG.mouse.screenY;
			if (FlxG.mouse.justReleased)
				pUp = true;
		}
		#end
		if (!found)
			pUp = true;
		if (pUp) {
			pHeld = false;
			activeId = -99;
		}
	}

	function inGrid(x:Float, y:Float):Bool
		return x >= gx - CAMW && x < gx + 8 * cw && y >= GY0 && y < GY0 + GH;

	function btnHit(b:EdBtn, x:Float, y:Float):Bool
		return b.on && (b.en == null || b.en()) && x >= b.x && x <= b.x + b.w && y >= b.y && y <= b.y + b.h;

	function seekTo(y:Float):Void {
		setTime((y - GY0) / GH * songLenMs);
		scrollVel = 0;
	}

	function handlePointer(elapsed:Float):Void {
		readPointer();
		if (pJust) {
			gKind = 0;
			pressedBtn = null;
			for (b in btns)
				if (btnHit(b, px, py)) {
					pressedBtn = b;
					gKind = 1;
					break;
				}
			if (gKind == 0 && px >= SEEK_X && py >= GY0 && py < GY0 + GH) {
				gKind = 2;
				seekResume = playing;
				if (playing)
					stopPlay();
			} else if (gKind == 0 && inGrid(px, py)) {
				gKind = 3;
				gSX = px;
				gSY = py;
				gSCurT = curT;
				gMode = 0;
				scrollVel = 0;
				gNote = null;
				if (px >= gx && tool == 0)
					gNote = noteAtTap(Std.int(Math.max(0, Math.min(7, Math.floor((px - gx) / cw)))), stepOfY(py));
			}
		}
		if (gKind == 1) {
			if (pUp) {
				var b = pressedBtn;
				pressedBtn = null;
				gKind = 0;
				if (b != null && btnHit(b, px, py))
					b.cb();
			}
		} else if (gKind == 2) {
			if (pHeld || pUp)
				seekTo(py);
			if (pUp) {
				gKind = 0;
				if (seekResume)
					startPlay();
			}
		} else if (gKind == 3)
			gridGesture(elapsed);
	}

	function gridGesture(elapsed:Float):Void {
		var dx = px - gSX;
		var dy = py - gSY;
		if (gMode == 0 && (pHeld || pUp) && dx * dx + dy * dy > 144) {
			if (tool == 0 && gNote != null && dy > 0) {
				gMode = 2;
				pushUndo();
			} else if (tool == 2)
				gMode = 3;
			else {
				gMode = 1;
				if (playing)
					stopPlay();
			}
		}
		if (gMode == 1) {
			var old = curT;
			setTime(gSCurT - dy / stepH() * stepMs());
			if (elapsed > 0)
				scrollVel = scrollVel * 0.6 + 0.4 * ((curT - old) / elapsed);
		} else if (gMode == 2) {
			// o sustain termina no centro da celula onde o dedo esta
			var len = stepOfY(py) - 0.5 - gNote.step;
			gNote.sus = len < snapStep() * 0.5 ? 0 : Math.max(snapStep(), snapRound(len));
			needRedraw = true;
			dirty = true;
			mapDirty = false;
			setStatus("Sustain: " + (Math.round(gNote.sus * 100) / 100) + " steps");
		} else if (gMode == 3) {
			var x0 = Math.min(gSX, px);
			var y0 = Math.min(gSY, py);
			boxSpr.visible = true;
			boxSpr.setGraphicSize(Math.max(1, Math.abs(dx)), Math.max(1, Math.abs(dy)));
			boxSpr.updateHitbox();
			boxSpr.setPosition(x0, y0);
		}
		if (pUp) {
			var m = gMode;
			gKind = 0;
			gMode = 0;
			if (m == 0)
				tapGrid(px, py);
			else if (m == 2) {
				markDirty();
				gNote = null;
			} else if (m == 3) {
				boxSpr.visible = false;
				applyBox(Math.min(gSX, px), Math.min(gSY, py), Math.max(gSX, px), Math.max(gSY, py));
			}
		}
	}

	function applyBox(x0:Float, y0:Float, x1:Float, y1:Float):Void {
		sel = [];
		for (n in notes) {
			var cx = gx + n.lane * cw + cw / 2;
			var cy = yOfStep(n.step) + cw / 2;
			if (cx >= x0 && cx <= x1 && cy >= y0 && cy <= y1)
				sel.push(n);
		}
		needRedraw = true;
		setStatus(sel.length + " notas selecionadas.");
	}

	function tapGrid(x:Float, y:Float):Void {
		var rawStep = stepOfY(y);
		if (x < gx) {
			if (rawStep >= 0)
				toggleFocus(Std.int(Math.floor(rawStep / STEPS)));
			return;
		}
		var lane = Std.int(Math.max(0, Math.min(7, Math.floor((x - gx) / cw))));
		if (tool == 0)
			toggleNoteAt(lane, rawStep);
		else {
			var n = noteAtTap(lane, rawStep);
			if (n == null)
				sel = [];
			else if (sel.indexOf(n) >= 0)
				sel.remove(n);
			else
				sel.push(n);
			needRedraw = true;
		}
	}

	// ------------------------------------------------------------------ audio
	function togglePlay():Void {
		if (playing)
			stopPlay();
		else
			startPlay();
	}

	function startPlay():Void {
		if (curT >= songLenMs - 100) {
			setStatus("Fim da música: volte ao início ou role pra trás.");
			return;
		}
		applyVolumes();
		inst.play(true, curT);
		if (voices != null)
			voices.play(true, curT);
		lastT = curT;
		playing = true;
		scrollVel = 0;
	}

	function stopPlay():Void {
		inst.pause();
		if (voices != null)
			voices.pause();
		playing = false;
		needRedraw = true;
	}

	function updatePlayback():Void {
		var t = inst.time;
		var sm = stepMs();
		if (t < lastT)
			lastT = t;
		var hit = false;
		for (n in notes) {
			var nt = n.step * sm;
			if (nt > lastT && nt <= t) {
				hit = true;
				var s = strums[n.lane];
				s.play("confirm");
				s.resetTimer = 0.12;
			}
		}
		if (hit && hitOn)
			playSnd(hitSnd, 0.35);
		var bm = sm * 4;
		if (metroOn && Math.floor(t / bm) != Math.floor(lastT / bm))
			playSnd(metroSnd, 0.5);
		lastT = t;
		curT = Math.min(t, songLenMs);
		needRedraw = true;
		if (!inst.playing)
			stopPlay();
	}

	// ------------------------------------------------------------------ salvar / testar / sair
	function save():Bool {
		#if sys
		var mod = Paths.currentMod();
		if (mod == "" || !Paths.externalReady) {
			setStatus("Escolha um MOD antes de salvar (menu principal: deslize pra esquerda). A base não é alterada.", true);
			return false;
		}
		try {
			var sm = stepMs();
			var secMs = STEPS * sm;
			var lastSec = 0;
			for (n in notes)
				lastSec = Std.int(Math.max(lastSec, Math.floor((n.step + 0.001) / STEPS)));
			for (e in extras)
				lastSec = Std.int(Math.max(lastSec, Math.floor(e.t / secMs)));
			var count = Std.int(Math.max(lastSec + 1, must.length));
			ensureSection(count - 1);

			var secs:Array<Dynamic> = [];
			var sns:Array<Array<Dynamic>> = [];
			for (i in 0...count) {
				var sn:Array<Dynamic> = [];
				sns.push(sn);
				secs.push({mustHitSection: must[i], sectionNotes: sn});
			}
			for (n in notes) {
				var si = Std.int(Math.floor((n.step + 0.001) / STEPS));
				var t = Math.round(n.step * sm * 100) / 100;
				var sus = n.sus > 0 ? Math.round(n.sus * sm * 100) / 100 : 0;
				var isPlayer = n.lane >= 4;
				var d = n.lane % 4;
				var fileLane = (isPlayer == must[si]) ? d : d + 4; // inverso do que o PlayState faz
				sns[si].push([t, fileLane, sus]);
			}
			for (e in extras)
				sns[Std.int(Math.floor(e.t / secMs))].push(e.arr);
			for (sn in sns)
				sn.sort(function(a:Dynamic, b:Dynamic) return a[0] < b[0] ? -1 : (a[0] > b[0] ? 1 : 0));

			var out:Dynamic = {};
			for (f in Reflect.fields(songObj))
				Reflect.setField(out, f, Reflect.field(songObj, f));
			Reflect.setField(out, "song", songName);
			Reflect.setField(out, "bpm", bpm);
			Reflect.setField(out, "speed", speed);
			Reflect.setField(out, "notes", secs);

			var dir = Paths.modsDir() + mod + "/songs/" + songId + "/";
			if (!Paths.ensureDir(dir))
				throw "não consegui criar " + dir;
			File.saveContent(dir + "chart.json", Json.stringify({song: out}));
			addToSongList(mod);
			dirty = false;
			isNew = false;
			setStatus("Salvo! " + notes.length + " notas em " + dir + "chart.json");
			return true;
		} catch (e:Dynamic) {
			setStatus("ERRO ao salvar: " + Std.string(e), true);
			return false;
		}
		#else
		return false;
		#end
	}

	#if sys
	/** Garante que a musica aparece no Freeplay: acrescenta no songlist.json do mod (copiando o atual se o mod ainda nao tem um). */
	function addToSongList(mod:String):Void {
		var list:Array<Dynamic> = Paths.json("data/songlist.json");
		if (list == null)
			list = [];
		for (e in list)
			if (e.id == songId)
				return;
		list.push({id: songId, name: songName, icon: "face"});
		var dir = Paths.modsDir() + mod + "/data/";
		if (!Paths.ensureDir(dir))
			return;
		File.saveContent(dir + "songlist.json", Json.stringify(list, null, " "));
	}
	#end

	function testSong():Void {
		if (playing)
			stopPlay();
		if (!save())
			return;
		inst.stop();
		if (voices != null)
			voices.stop();
		PlayState.songId = songId;
		TransitionSubState.go(new PlayState());
	}

	function leave():Void {
		if (dirty && !exitArmed) {
			exitArmed = true;
			setStatus("ALTERAÇÕES NÃO SALVAS! Toque em voltar (←) de novo pra sair sem salvar.", true);
			return;
		}
		inst.stop();
		if (voices != null)
			voices.stop();
		TransitionSubState.go(new ChartPickState());
	}

	// ------------------------------------------------------------------ loop
	function handleKeys():Void {
		var k = FlxG.keys;
		if (k.justPressed.SPACE)
			togglePlay();
		if (k.justPressed.RIGHT)
			navSection(1);
		if (k.justPressed.LEFT)
			navSection(-1);
		if (k.justPressed.DOWN) {
			if (playing)
				stopPlay();
			setTime(curT + snapStep() * stepMs());
		}
		if (k.justPressed.UP) {
			if (playing)
				stopPlay();
			setTime(curT - snapStep() * stepMs());
		}
		if (k.justPressed.DELETE)
			deleteSel();
		if (k.pressed.CONTROL) {
			if (k.justPressed.Z) {
				if (k.pressed.SHIFT)
					redo();
				else
					undo();
			}
			if (k.justPressed.Y)
				redo();
			if (k.justPressed.S)
				save();
			if (k.justPressed.C)
				copySel();
			if (k.justPressed.V)
				pasteSel();
		}
		for (i in 0...8)
			if (FlxG.keys.anyJustPressed([NUM_KEYS[i]]))
				placeAtPlayhead(i);
		#if !mobile
		if (FlxG.mouse.wheel != 0) {
			if (playing)
				stopPlay();
			setTime(curT - FlxG.mouse.wheel * stepMs() * snapStep() * 2);
		}
		#end
	}

	override function update(elapsed:Float):Void {
		Controls.update();
		super.update(elapsed);
		if (Controls.back) {
			leave();
			return;
		}
		handleKeys();
		handlePointer(elapsed);
		if (playing)
			updatePlayback();
		else if (!(gKind == 3 && gMode == 1) && Math.abs(scrollVel) > 30) {
			// inercia depois de soltar o dedo
			setTime(curT + scrollVel * elapsed);
			scrollVel *= Math.exp(-5 * elapsed);
			if (curT <= 0 || curT >= songLenMs)
				scrollVel = 0;
		} else if (!(gKind == 3 && gMode == 1))
			scrollVel = 0;
		if (mapDirty && !(gKind == 3 && gMode == 2))
			rebuildMap();
		if (needRedraw)
			redraw();
		updateHud();
	}
}

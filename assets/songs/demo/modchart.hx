// ============================================================================
//  MODCHART (assets/songs/<id>/modchart.hx  ou  <mod>/songs/<id>/modchart.hx)
//  Mexe nas setas (strums) e nas notas pela linha do tempo, estilo NotITG.
//  Os valores sao calculados a partir da posicao da musica, entao ficam
//  sempre certos (sem depender de tweens soltos).
//
//  Como usar: edite a funcao modchart() la embaixo com chamadas de at():
//
//    at(beat, "mod", valor, duracaoEmBeats, "ease", lado)
//
//      beat     = em que beat comeca (aceita decimal, ex.: 16.5)
//      valor    = valor final do mod (0 = desligado)
//      duracao  = beats que leva ate chegar no valor (0 = instantaneo)
//      ease     = "linear" "quadIn" "quadOut" "quadInOut" "cubeIn" "cubeOut"
//                 "sineInOut" "backOut" "elasticOut" "bounceOut"
//      lado     = 0 os dois (padrao) | 1 so oponente | 2 so jogador
//
//  Mods:
//    drunk   setas e notas balancam de lado (1 = normal)
//    tipsy   setas sobem e descem em ondas
//    wave    notas serpenteiam conforme se aproximam
//    beat    setas dao um tranco pro lado a cada beat
//    spin    setas e notas giram (1 = meia volta por segundo)
//    flip    espelha as colunas (1 = totalmente espelhado)
//    invert  troca as colunas de 2 em 2
//    center  leva as setas pro centro da tela (1 = centralizado)
//    hide    some com as setas/notas (1 = invisivel)
//    moveX   desloca em pixels no eixo X
//    moveY   desloca em pixels no eixo Y
//    sway    balanca a camera do HUD
//
//  Atalhos:  set(beat, "mod", valor, lado)   -> muda na hora
//            reset(beat, duracao)            -> volta todos os mods pra 0
//  (Obs.: o jogo nao tem downscroll, entao nao existe mod "reverse".)
// ============================================================================

// --- estado (as variaveis ficam ANTES das funcoes de proposito) ---
var NAMES = ["drunk", "tipsy", "wave", "beat", "spin", "flip", "invert", "center", "hide", "moveX", "moveY", "sway"];
var N = 12;
var M_DRUNK = 0;
var M_TIPSY = 1;
var M_WAVE = 2;
var M_BEAT = 3;
var M_SPIN = 4;
var M_FLIP = 5;
var M_INVERT = 6;
var M_CENTER = 7;
var M_HIDE = 8;
var M_MOVEX = 9;
var M_MOVEY = 10;
var M_SWAY = 11;
var tl = []; // tl[lado*N + mod] = lista de eventos (lado 0 = oponente, 1 = jogador)
var bx = [[], []]; // x base de cada coluna
var by = [0.0, 0.0]; // y base de cada lado
var vals = [[], []]; // valor atual de cada mod
var dxs = [];
var dys = [];
var seq = 0;
var swayWas = false;
for (i in 0...(N * 2))
	tl.push([]);
for (i in 0...8) {
	dxs.push(0.0);
	dys.push(0.0);
}

// ---------------------------------------------------------------- api
function idx(name) {
	for (i in 0...N)
		if (NAMES[i] == name)
			return i;
	trace("[modchart] mod desconhecido: " + name);
	return -1;
}

function put(lado, m, ev) {
	var list = tl[lado * N + m];
	list.push(ev);
	list.sort(function(a, b) {
		if (a.s < b.s) return -1;
		if (a.s > b.s) return 1;
		return a.q - b.q;
	});
}

function at(beat, name, to, dur, ease, side) {
	var m = idx(name);
	if (m < 0)
		return;
	if (dur == null) dur = 0;
	if (ease == null) ease = "linear";
	if (side == null) side = 0;
	seq++;
	var ev = {s: beat * 4, d: dur * 4, to: to, ease: ease, q: seq};
	if (side != 2) put(0, m, ev);
	if (side != 1) put(1, m, ev);
}

function set(beat, name, to, side) {
	at(beat, name, to, 0, "linear", side);
}

function reset(beat, dur) {
	for (i in 0...N)
		at(beat, NAMES[i], 0, dur, "quadOut", 0);
}

// ---------------------------------------------------------------- easing
function ease(n, t) {
	if (n == "linear") return t;
	if (n == "quadIn") return t * t;
	if (n == "quadOut") return t * (2 - t);
	if (n == "quadInOut") return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
	if (n == "cubeIn") return t * t * t;
	if (n == "cubeOut") {
		var u = t - 1;
		return u * u * u + 1;
	}
	if (n == "sineInOut") return -(Math.cos(Math.PI * t) - 1) / 2;
	if (n == "backOut") {
		var u = t - 1;
		return 1 + 2.70158 * u * u * u + 1.70158 * u * u;
	}
	if (n == "elasticOut") {
		if (t <= 0) return 0;
		if (t >= 1) return 1;
		return Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * (2 * Math.PI / 3)) + 1;
	}
	if (n == "bounceOut") {
		var a = 7.5625;
		var d = 2.75;
		if (t < 1 / d) return a * t * t;
		if (t < 2 / d) {
			t -= 1.5 / d;
			return a * t * t + 0.75;
		}
		if (t < 2.5 / d) {
			t -= 2.25 / d;
			return a * t * t + 0.9375;
		}
		t -= 2.625 / d;
		return a * t * t + 0.984375;
	}
	return t;
}

function evalTl(list, st) {
	var prev = 0.0;
	for (e in list) {
		if (st < e.s)
			break;
		if (e.d <= 0 || st >= e.s + e.d) {
			prev = e.to;
			continue;
		}
		return prev + (e.to - prev) * ease(e.ease, (st - e.s) / e.d);
	}
	return prev;
}

// ---------------------------------------------------------------- calculo
function inv(i) {
	return i % 2 == 0 ? i + 1 : i - 1;
}

function drunkAt(lane, y, t, v) {
	return Math.sin(t * 2 + lane * 0.6 + y * 0.012) * 55 * v[M_DRUNK];
}

function onCreatePost() {
	for (side in 0...2) {
		var strums = side == 0 ? game.oppStrums : game.playerStrums;
		bx[side] = [];
		for (i in 0...4)
			bx[side].push(strums[i].x);
		by[side] = strums[0].y;
		vals[side] = [];
		for (m in 0...N)
			vals[side].push(0.0);
	}
	modchart();
}

function onUpdate(elapsed) {
	var st = Conductor.songPosition / Conductor.stepCrochet;
	var t = Conductor.songPosition / 1000;
	var bt = Conductor.songPosition / Conductor.crochet;
	var env = Math.pow(1 - (bt - Math.floor(bt)), 3);

	for (side in 0...2) {
		var v = vals[side];
		for (m in 0...N)
			v[m] = evalTl(tl[side * N + m], st);
		var strums = side == 0 ? game.oppStrums : game.playerStrums;
		var b = bx[side];
		var w = b[1] - b[0];
		var a = 1 - v[M_HIDE];
		if (a < 0) a = 0;
		for (i in 0...4) {
			var s = strums[i];
			var y = by[side] + v[M_MOVEY] + Math.cos(t * 1.8 + i * 0.7) * 40 * v[M_TIPSY];
			var x = b[i] + (b[3 - i] - b[i]) * v[M_FLIP] + (b[inv(i)] - b[i]) * v[M_INVERT];
			x += ((FlxG.width / 2 - 2 * w + i * w) - b[i]) * v[M_CENTER];
			x += v[M_MOVEX] + (i % 2 == 0 ? 1 : -1) * env * 30 * v[M_BEAT] + drunkAt(i, y, t, v);
			dxs[side * 4 + i] = x - s.x;
			dys[side * 4 + i] = y - s.y;
			s.x = x;
			s.y = y;
			s.angle = v[M_SPIN] * t * 180;
			s.alpha = a;
		}
	}

	// as notas ja foram posicionadas neste frame com a seta antiga: corrige pelo delta
	for (n in game.notes.members) {
		if (n == null || !n.alive)
			continue;
		var side = n.mustPress ? 1 : 0;
		var v = vals[side];
		var k = side * 4 + n.lane;
		var s = (side == 1 ? game.playerStrums : game.oppStrums)[n.lane];
		var ox = n.x;
		var oy = n.y;
		var hit = n.wasHit;
		n.x += dxs[k];
		if (!hit)
			n.y += dys[k];
		n.x += drunkAt(n.lane, n.y, t, v) - drunkAt(n.lane, s.y, t, v);
		n.x += Math.sin((n.y - s.y) * 0.02 + t * 3) * 40 * v[M_WAVE];
		n.angle = s.angle;
		var a = 1 - v[M_HIDE];
		if (a < 0) a = 0;
		n.alpha *= a;
		if (n.sustain != null) {
			n.sustain.x += n.x - ox;
			n.sustain.y += hit ? dys[k] : n.y - oy;
		}
	}

	var sw = vals[1][M_SWAY];
	if (sw != 0 || swayWas) {
		game.camHUD.angle = Math.sin(bt * Math.PI) * 3 * sw;
		swayWas = sw != 0;
	}
}

// ---------------------------------------------------------------- SUA LINHA DO TEMPO
// A demo tem ~95 beats (102 BPM). Apague/edite a vontade.
function modchart() {
	// intro: setas balancando de leve
	at(8, "drunk", 0.5, 4, "sineInOut");
	at(16, "drunk", 0, 4, "quadOut");

	// oponente espelhado, jogador com ondas nas notas
	at(16, "flip", 1, 2, "quadInOut", 1);
	at(16, "wave", 1, 4, "linear", 2);
	at(24, "flip", 0, 2, "quadInOut", 1);
	at(24, "wave", 0, 2, "linear", 2);

	// seta do oponente some e o jogador vai pro meio (estilo middlescroll)
	at(32, "hide", 1, 2, "linear", 1);
	at(32, "center", 1, 2, "quadInOut", 2);
	at(48, "hide", 0, 2, "linear", 1);
	at(48, "center", 0, 2, "quadInOut", 2);

	// tranco no beat + tipsy
	at(48, "beat", 1, 0);
	at(48, "tipsy", 1, 4, "sineInOut");
	at(64, "beat", 0, 0);
	at(64, "tipsy", 0, 4, "sineInOut");

	// giro e camera balancando
	at(64, "sway", 1, 4, "linear");
	at(72, "spin", 1, 2, "quadIn");
	at(76, "spin", 0, 1, "quadOut");
	at(76, "invert", 1, 1, "backOut");

	// final: tudo volta ao normal
	reset(88, 2);
}

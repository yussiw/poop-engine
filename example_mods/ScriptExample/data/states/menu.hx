// Exemplo: customizando o menu principal (data/states/menu.hx dentro do mod).
// Copie a pasta ScriptExample inteira pra <pasta externa>/mods/ e escolha o mod no menu.
//
// Eventos: onCreate (antes de montar) | onCreatePost (depois) | onUpdate(elapsed) | onUpdatePost
//          onChange(indice, id) | onSelect(indice, id) [cancelEvent() = voce cuida da acao] | onDestroy
// Variaveis: state (o MainMenuState), menuItems, itemStartY, itemSpacing, items (grupo de sprites), bg, magenta,
//            camFollow, versionTxt, cur ... tudo do state tambem vale direto (ex.: `bg`, `items`).

import flixel.text.FlxText;

function onCreate() {
	// aumenta/diminui o espacamento e adiciona um item que abre a selecao de mods
	itemStartY = 40;
	itemSpacing = 130;
	menuItems.push({
		id: "mods",
		file: "options", // atlas de images/menus/mainmenu/<file>.xml (do jogo base ou do mod)
		idle: "options basic",
		selected: "options white",
		action: "mods" // nome de state ou uma funcao
	});
}

function onCreatePost() {
	bg.color = rgb(150, 210, 255);

	var t = createText(0, FlxG.height - 90, FlxG.width, "Menu customizado por script!", 24);
	t.alignment = FlxTextAlign.CENTER;
	t.scrollFactor.set();
	add(t);
}

function onChange(i, id) {
	trace("selecionado: " + id);
}

function onSelect(i, id) {
	if (id == "credits") {
		cancelEvent(); // nao faz a acao padrao
		FlxG.camera.flash(rgb(255, 255, 255), 0.4);
		playSound("menu/cancel", 0.6);
	}
}

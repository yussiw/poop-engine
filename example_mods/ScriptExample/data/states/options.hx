// Exemplo: adicionando uma categoria/opcao propria no menu de opcoes.
// Leia o valor em qualquer script com option("meuModBrilho") ou Options.get("meuModBrilho").
function onCreate() {
	Options.register({
		id: "meuModBrilho",
		category: "meumod", // categoria nova aparece no fim da lista (nome: Lang "cat.meumod" ou o proprio id)
		type: "bool", // "bool" | "int" (min/max/step/suffix) | "choice" (choices: [...])
		def: true,
		name: "brilho do mod"
	});
	Options.register({id: "meuModNivel", category: "meumod", type: "int", def: 3, min: 0, max: 10, step: 1, name: "nivel"});
}

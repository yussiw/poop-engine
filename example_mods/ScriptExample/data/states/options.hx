function onCreate() {
	Options.register({
		id: "meuModBrilho",
		category: "meumod",
		type: "bool",
		def: true,
		name: "brilho do mod"
	});
	Options.register({id: "meuModNivel", category: "meumod", type: "int", def: 3, min: 0, max: 10, step: 1, name: "nivel"});
}

/*
 * Mock of DefinirValoresIniciais / NormalizarDados: the new customer is active and its data are normalized.
 */
module.exports = {
	async onBeforeAddEntry(keyValues, data) {
		Object.assign(data, {
			ClienteAtivo: true,
			ScoreCliente: "50",
			Cpf: String(data.Cpf || "").replace(/\D/g, ""),
			Telefone: String(data.Telefone || "").replace(/\D/g, ""),
			Email: String(data.Email || "").trim().toLowerCase()
		});
	}
};

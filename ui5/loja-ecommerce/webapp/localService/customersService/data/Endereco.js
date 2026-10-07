/*
 * Mock of the determination PreencherEnderecoViaCep: completes the address from the CEP and makes the first
 * address of the customer the principal one.
 */
module.exports = {
	async onBeforeAddEntry(keyValues, data) {
		const sCep = String(data.Cep || "").replace(/\D/g, "");

		Object.assign(data, {
			Cep: sCep,
			Logradouro: "Rua de Demonstração",
			Bairro: "Centro",
			Cidade: "Recife",
			Uf: "PE",
			Estado: "Pernambuco",
			CepStatus: "VALIDADO",
			EnderecoPrincipal: true
		});
	}
};

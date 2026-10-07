/*
 * Mock of the behavior of ZR_PC_PEDIDO used by the shop (draft + Activate are handled by the mock server):
 * early numbering, initial status, and the actions SimularPagamento and CancelarPedido.
 * Payment rule of ZCL_PC_PAGAMENTO_SIM: CVV 000 is refused, anything else is approved.
 */
const oCounter = {last: 0};

module.exports = {
	async onBeforeAddEntry(keyValues, data) {
		oCounter.last += 1;
		Object.assign(data, {
			NumeroPedido: String(oCounter.last).padStart(10, "0"),
			StatusPedido: "ABERTO",
			StatusPagamento: "PENDENTE",
			Currency: "BRL",
			ValorTotal: "0.00"
		});
	},

	async executeAction(actionDefinition, actionData, keys, odataRequest) {
		const sName = actionDefinition.name;
		let mChanges;

		if (sName === "SimularPagamento") {
			const sCvv = String(actionData.Cvv || "").replace(/\D/g, "");
			const sNumber = String(actionData.NumeroCartao || "").replace(/\D/g, "");

			if (!["CARTAO_CREDITO", "CARTAO_DEBITO"].includes(actionData.MetodoPagamento)) {
				this.throwError("método de pagamento inválido", 400);
			}
			if (sNumber.length < 13 || sNumber.length > 19 || sCvv.length < 3 || !/^\d\d\/\d\d$/.test(actionData.Validade)) {
				this.throwError("Dados do cartão inválidos.", 400);
			}
			const bApproved = sCvv !== "000";
			mChanges = bApproved
				? {StatusPagamento: "APROVADO", StatusPedido: "AGUARDANDO_APROVACAO"}
				: {StatusPagamento: "RECUSADO", StatusPedido: "ABERTO"};
		} else if (sName === "CancelarPedido") {
			mChanges = {StatusPedido: "CANCELADO", MotivoCancelamento: actionData.MotivoCancelamento};
		}
		if (!mChanges) {
			return undefined;
		}
		await this.base.updateEntry(keys, mChanges, odataRequest);

		return (await this.base.fetchEntries(keys, odataRequest))[0];
	}
};

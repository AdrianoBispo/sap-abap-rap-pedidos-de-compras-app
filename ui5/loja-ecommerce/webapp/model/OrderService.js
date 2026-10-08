sap.ui.define([
	"./Backend",
	"sap/ui/model/Filter",
	"sap/ui/model/FilterOperator"
], (Backend, Filter, FilterOperator) => {
	"use strict";

	// namespace of the actions of the ZUI_PC_PEDIDOS_COMPRAS service (see its $metadata)
	const sNamespace = "com.sap.gateway.srvd.zui_pc_pedidos_compras.v0001";
	// order notes have 500 characters in the back-end
	const iNoteLength = 500;
	const sGroup = Backend.group;
	const onlyDigits = Backend.onlyDigits;
	const errorText = Backend.errorText;

	function formatCpf(sDigits) {
		return sDigits.length === 11
			? `${sDigits.slice(0, 3)}.${sDigits.slice(3, 6)}.${sDigits.slice(6, 9)}-${sDigits.slice(9)}`
			: sDigits;
	}

	/**
	 * Note of the order in the back-end. The Pedido has no field for the delivery type, so it goes in the note.
	 * @param {string} sDelivery delivery type text
	 * @param {string} sNote note typed by the customer
	 * @returns {string} note, limited to the size of the field
	 */
	function buildNote(sDelivery, sNote) {
		return ["Loja virtual", sDelivery, (sNote || "").trim()].filter(Boolean).join(" | ").slice(0, iNoteLength);
	}

	function bindAction(oModel, sAction, oContext) {
		return Backend.bindAction(oModel, sNamespace, sAction, oContext);
	}

	return {
		onlyDigits,
		formatCpf,
		errorText,
		buildNote,

		/**
		 * Looks for the (active) customer with the CPF in the value help of the order service.
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the order service
		 * @param {string} sCpf CPF, with or without punctuation
		 * @returns {Promise<object|undefined>} customer (ClienteUUID, Nome, Cidade, Uf) or undefined
		 */
		async findCustomer(oModel, sCpf) {
			const sDigits = onlyDigits(sCpf);
			// the back-end keeps the CPF as digits; the formatted value is tried too
			const oBinding = oModel.bindList("/ClienteVH", null, [], [new Filter({
				and: false,
				filters: [new Filter("Cpf", FilterOperator.EQ, sDigits),
					new Filter("Cpf", FilterOperator.EQ, formatCpf(sDigits))]
			})], {$select: ["ClienteUUID", "Cpf", "Nome", "Email", "Cidade", "Uf"]});

			try {
				const [oContext] = await oBinding.requestContexts(0, 1);

				return oContext && {...oContext.getObject()};
			} finally {
				oBinding.destroy();
			}
		},

		/**
		 * Registers the order: creates the draft of the Pedido for the customer, creates the items, validates
		 * (Prepare) and activates it. The activation reserves the stock and gives the order number; the order
		 * is then ABERTO and waits for the payment. When a step fails, the draft is discarded.
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the order service
		 * @param {object} oOrder customerId, items [{ItemUUID, Quantity}] and note
		 * @returns {Promise<{binding: sap.ui.model.odata.v4.ODataContextBinding, context: sap.ui.model.odata.v4.Context,
		 *    number: string, status: string, total: string, currency: string}>} the active order; call release()
		 *    when it is no longer needed
		 */
		async createOrder(oModel, oOrder) {
			const oPedidos = oModel.bindList("/Pedido", null, [], [], {$$updateGroupId: sGroup});
			const oDraft = oPedidos.create({ClienteUUID: oOrder.customerId, Observacao: oOrder.note}, true);

			try {
				await oDraft.created();

				const oItens = oModel.bindList("_Itens", oDraft, [], [], {$$updateGroupId: sGroup});
				for (const oItem of oOrder.items) {
					await oItens.create({ItemUUID: oItem.ItemUUID, QtdeItemPedido: oItem.Quantity}, true).created();
				}

				await Backend.invoke(bindAction(oModel, "Prepare", oDraft));
				const oActivation = bindAction(oModel, "Activate", oDraft);
				await Backend.invoke(oActivation);

				const oData = oActivation.getBoundContext().getObject();

				// the activated order gets its own binding: the context of the activation result belongs to the
				// draft, which is destroyed with the list binding below
				const oActiveBinding = oModel.bindContext(`/Pedido(PedidoUUID=${oData.PedidoUUID},IsActiveEntity=true)`);
				await oActiveBinding.requestObject();

				return {
					binding: oActiveBinding,
					context: oActiveBinding.getBoundContext(),
					number: oData.NumeroPedido,
					status: oData.StatusPedido,
					total: oData.ValorTotal,
					currency: oData.Currency
				};
			} catch (oError) {
				await Backend.discardDraft(oModel, sNamespace, oDraft);
				throw oError;
			} finally {
				oPedidos.destroy();
			}
		},

		/**
		 * Releases the binding of an order returned by createOrder.
		 * @param {{binding: sap.ui.model.odata.v4.ODataContextBinding}} oPlaced the order
		 */
		release(oPlaced) {
			oPlaced.binding.destroy();
		},

		/**
		 * Pays the order (action SimularPagamento). The card data are only sent to the back-end action, which does
		 * not store them. The back-end answers with the payment status; a refusal is not an error.
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the order service
		 * @param {sap.ui.model.odata.v4.Context} oActive context of the active order
		 * @param {object} oPayment method (CARTAO_CREDITO or CARTAO_DEBITO), number, expiry (MM/AAAA) and cvv
		 * @returns {Promise<{approved: boolean, paymentStatus: string, status: string}>} result of the payment
		 */
		async pay(oModel, oActive, oPayment) {
			const oAction = bindAction(oModel, "SimularPagamento", oActive);
			const [sMonth, sYear] = oPayment.expiry.split("/");

			oAction.setParameter("MetodoPagamento", oPayment.method);
			oAction.setParameter("NumeroCartao", oPayment.number);
			// the action takes the validity as MM/AA
			oAction.setParameter("Validade", `${sMonth}/${String(sYear).slice(-2)}`);
			oAction.setParameter("Cvv", oPayment.cvv);
			await Backend.invoke(oAction);

			const oData = oAction.getBoundContext().getObject();

			return {
				approved: oData.StatusPagamento === "APROVADO",
				paymentStatus: oData.StatusPagamento,
				status: oData.StatusPedido
			};
		},

		/**
		 * Cancels an order that was registered but not paid (the customer gave up), which releases the stock.
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the order service
		 * @param {sap.ui.model.odata.v4.Context} oActive context of the active order
		 * @param {string} sReason reason stored in the order
		 */
		async cancel(oModel, oActive, sReason) {
			const oAction = bindAction(oModel, "CancelarPedido", oActive);

			oAction.setParameter("MotivoCancelamento", sReason);
			await Backend.invoke(oAction);
		}
	};
});

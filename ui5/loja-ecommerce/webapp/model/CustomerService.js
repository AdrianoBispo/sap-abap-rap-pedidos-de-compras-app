sap.ui.define([
	"./Backend"
], (Backend) => {
	"use strict";

	// namespace of the actions of the ZUI_PC_CLIENTES service (see its $metadata)
	const sNamespace = "com.sap.gateway.srvd.zui_pc_clientes.v0001";

	return {
		/**
		 * Registers a new customer in the back-end (app Gestão de Clientes): draft of the Cliente with its first
		 * address, validation (Prepare) and activation. The back-end completes the address from the CEP, sets the
		 * first address as the principal one and makes the customer active. A failed step discards the draft.
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the customer service
		 * @param {object} oCustomer Cpf, Nome, Email, Telefone, DataNascimento (yyyy-MM-dd), Cep, Numero, Complemento
		 * @returns {Promise<{id: string, name: string}>} the registered customer
		 */
		async register(oModel, oCustomer) {
			const oClientes = oModel.bindList("/Cliente", null, [], [], {$$updateGroupId: Backend.group});
			const oDraft = oClientes.create({
				Cpf: Backend.onlyDigits(oCustomer.Cpf),
				Nome: oCustomer.Nome,
				Email: oCustomer.Email,
				Telefone: Backend.onlyDigits(oCustomer.Telefone),
				DataNascimento: oCustomer.DataNascimento
			}, true);

			try {
				await oDraft.created();

				const oEnderecos = oModel.bindList("_Endereco", oDraft, [], [], {$$updateGroupId: Backend.group});
				await oEnderecos.create({
					Cep: Backend.onlyDigits(oCustomer.Cep),
					Numero: oCustomer.Numero,
					Complemento: oCustomer.Complemento || ""
				}, true).created();

				await Backend.bindAction(oModel, sNamespace, "Prepare", oDraft).invoke(Backend.group);
				const oActivation = Backend.bindAction(oModel, sNamespace, "Activate", oDraft);
				await oActivation.invoke(Backend.group);

				const oData = oActivation.getBoundContext().getObject();

				return {id: oData.ClienteUUID, name: oData.Nome};
			} catch (oError) {
				await Backend.discardDraft(oModel, sNamespace, oDraft);
				throw oError;
			} finally {
				oClientes.destroy();
			}
		}
	};
});

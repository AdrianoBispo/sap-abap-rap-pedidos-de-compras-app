sap.ui.define([
	"./Backend",
	"sap/ui/model/Filter",
	"sap/ui/model/FilterOperator"
], (Backend, Filter, FilterOperator) => {
	"use strict";

	const onlyDigits = Backend.onlyDigits;

	// e-mails are compared without case and without spaces (the back-end normalizes them when saving)
	function normalizeEmail(sValue) {
		return String(sValue || "").toLowerCase().replace(/\s+/g, "");
	}

	// phones are compared by their digits; a leading country code (55) is accepted
	function normalizePhone(sValue) {
		const sDigits = onlyDigits(sValue);

		return sDigits.length > 11 && sDigits.startsWith("55") ? sDigits.slice(2) : sDigits;
	}

	return {
		/**
		 * Does the second factor typed by the customer match the registered data?
		 * @param {{Email: string, Telefone: string}} oCustomer customer as registered in the back-end
		 * @param {string} sMethod "EMAIL" or "TELEFONE"
		 * @param {string} sValue e-mail or phone typed by the customer
		 * @returns {boolean} true when it matches
		 */
		matches(oCustomer, sMethod, sValue) {
			if (sMethod === "TELEFONE") {
				const sPhone = normalizePhone(sValue);

				return sPhone.length >= 10 && sPhone === normalizePhone(oCustomer.Telefone);
			}
			const sEmail = normalizeEmail(sValue);

			return sEmail.length > 0 && sEmail === normalizeEmail(oCustomer.Email);
		},

		/**
		 * Login with the CPF and the e-mail (or the phone) of the customer. The customer is read from the service of
		 * Gestão de Clientes (active and enabled customers only) and the e-mail/phone is checked here. The same
		 * answer is given for an unknown CPF and for a wrong e-mail/phone.
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the customer service
		 * @param {{cpf: string, method: string, value: string}} oCredentials CPF, "EMAIL"/"TELEFONE" and its value
		 * @returns {Promise<object|undefined>} the customer for the session, or undefined when the login is refused
		 */
		async login(oModel, oCredentials) {
			const oBinding = oModel.bindList("/Cliente", null, [], [
				new Filter("IsActiveEntity", FilterOperator.EQ, true),
				new Filter("ClienteAtivo", FilterOperator.EQ, true),
				new Filter("Cpf", FilterOperator.EQ, onlyDigits(oCredentials.cpf))
			], {$select: ["ClienteUUID", "Cpf", "Nome", "Email", "Telefone", "CidadePrincipal", "UfPrincipal"]});

			try {
				const [oContext] = await oBinding.requestContexts(0, 1);
				const oCustomer = oContext && oContext.getObject();

				if (!oCustomer || !this.matches(oCustomer, oCredentials.method, oCredentials.value)) {
					return undefined;
				}

				// only what the shop needs stays in the session (no e-mail/phone)
				return {
					ClienteUUID: oCustomer.ClienteUUID,
					Cpf: oCustomer.Cpf,
					Nome: oCustomer.Nome,
					Cidade: oCustomer.CidadePrincipal,
					Uf: oCustomer.UfPrincipal
				};
			} finally {
				oBinding.destroy();
			}
		}
	};
});

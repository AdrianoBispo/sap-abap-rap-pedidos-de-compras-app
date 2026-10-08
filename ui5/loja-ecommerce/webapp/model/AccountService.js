sap.ui.define([
	"./Backend",
	"sap/ui/model/Filter",
	"sap/ui/model/FilterOperator"
], (Backend, Filter, FilterOperator) => {
	"use strict";

	const onlyDigits = Backend.onlyDigits;

	// namespace of the actions of the ZUI_PC_CLIENTES service (see its $metadata)
	const sNamespace = "com.sap.gateway.srvd.zui_pc_clientes.v0001";

	// reads every row of a list binding (the customer has a handful of addresses)
	async function readAll(oModel, sPath, aFilters, aSelect) {
		const oBinding = oModel.bindList(sPath, null, [], aFilters, {$select: aSelect});

		try {
			return (await oBinding.requestContexts(0, 100)).map((oContext) => ({...oContext.getObject()}));
		} finally {
			oBinding.destroy();
		}
	}

	// e-mails are compared without case and without spaces (the back-end normalizes them when saving)
	function normalizeEmail(sValue) {
		return String(sValue || "").toLowerCase().replace(/\s+/g, "");
	}

	// phones are compared by their digits; a leading country code (55) is accepted
	function normalizePhone(sValue) {
		const sDigits = onlyDigits(sValue);

		return sDigits.length > 11 && sDigits.startsWith("55") ? sDigits.slice(2) : sDigits;
	}

	/**
	 * Changes the active customer through its draft: Edit, the change, Prepare and Activate. A failed step
	 * discards the draft. The draft actions ignore the ETag (see Backend.invoke).
	 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the customer service
	 * @param {string} sCustomerId ClienteUUID
	 * @param {function(sap.ui.model.odata.v4.Context): Promise} fnChange applies the change to the draft
	 */
	async function editCustomer(oModel, sCustomerId, fnChange) {
		const oActiveBinding = oModel.bindContext(`/Cliente(ClienteUUID=${sCustomerId},IsActiveEntity=true)`);
		const oDraftBinding = oModel.bindContext(`/Cliente(ClienteUUID=${sCustomerId},IsActiveEntity=false)`);

		try {
			await oActiveBinding.requestObject();

			const oEdit = Backend.bindAction(oModel, sNamespace, "Edit", oActiveBinding.getBoundContext());
			oEdit.setParameter("PreserveChanges", true);
			await Backend.invoke(oEdit);

			await oDraftBinding.requestObject();
			const oDraft = oDraftBinding.getBoundContext();
			try {
				await fnChange(oDraft);
				await Backend.invoke(Backend.bindAction(oModel, sNamespace, "Prepare", oDraft));
				await Backend.invoke(Backend.bindAction(oModel, sNamespace, "Activate", oDraft));
			} catch (oError) {
				await Backend.discardDraft(oModel, sNamespace, oDraft);
				throw oError;
			}
		} finally {
			oDraftBinding.destroy();
			oActiveBinding.destroy();
		}
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
		},

		/**
		 * Complete data of the customer: personal data and all addresses (active data only).
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the customer service
		 * @param {string} sCustomerId ClienteUUID
		 * @returns {Promise<{customer: object, addresses: object[]}>} the data; customer is undefined when not found
		 */
		async loadProfile(oModel, sCustomerId) {
			const [oCustomer] = await readAll(oModel, "/Cliente", [
				new Filter("IsActiveEntity", FilterOperator.EQ, true),
				new Filter("ClienteUUID", FilterOperator.EQ, sCustomerId)
			], ["ClienteUUID", "Cpf", "Nome", "Email", "Telefone", "Genero", "GeneroTexto", "DataNascimento",
				"ClienteAtivo", "ScoreCliente", "CreatedAt"]);
			const aAddresses = await readAll(oModel, "/Endereco", [
				new Filter("IsActiveEntity", FilterOperator.EQ, true),
				new Filter("ClienteUUID", FilterOperator.EQ, sCustomerId)
			], ["EnderecoUUID", "Cep", "Logradouro", "Numero", "Complemento", "Bairro", "Cidade", "Uf", "Estado",
				"EnderecoPrincipal"]);

			// the main address first
			aAddresses.sort((a, b) => Number(b.EnderecoPrincipal) - Number(a.EnderecoPrincipal));

			return {customer: oCustomer, addresses: aAddresses};
		},

		/**
		 * Deactivates the account: the customer is edited as a draft (ClienteAtivo = false), validated and
		 * activated, like in Gestão de Clientes. An inactive customer cannot log in and cannot place new orders;
		 * orders that already exist are kept. A failed step discards the draft.
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the customer service
		 * @param {string} sCustomerId ClienteUUID
		 */
		deactivate(oModel, sCustomerId) {
			return editCustomer(oModel, sCustomerId, (oDraft) => oDraft.setProperty("ClienteAtivo", false, Backend.group));
		},

		/**
		 * Changes the profile photo (same draft flow). The image goes to the stream property FotoCliente of the
		 * draft; the back-end only accepts JPEG, PNG or WebP whose content matches the type and the file name.
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the customer service
		 * @param {string} sCustomerId ClienteUUID
		 * @param {Blob} oImage the image (image/jpeg, image/png or image/webp)
		 * @param {string} sFileName file name with a matching extension, e.g. "perfil.jpg"
		 */
		updatePhoto(oModel, sCustomerId, oImage, sFileName) {
			const sDraft = `Cliente(ClienteUUID=${sCustomerId},IsActiveEntity=false)`;

			return editCustomer(oModel, sCustomerId, async () => {
				await Backend.rawRequest(oModel, "PUT", `${sDraft}/FotoCliente`, oImage, oImage.type);
				await Backend.rawRequest(oModel, "PATCH", sDraft, JSON.stringify({FotoFileName: sFileName}),
					"application/json");
			});
		},

		/**
		 * Profile photo of the customer as a URL for an image control (object URL; the photo needs the session of
		 * the user, so it is read with fetch). Release it with URL.revokeObjectURL.
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the customer service
		 * @param {string} sCustomerId ClienteUUID
		 * @returns {Promise<string>} the URL, or an empty string when the customer has no photo
		 */
		async loadPhoto(oModel, sCustomerId) {
			try {
				const oResponse = await fetch(`${oModel.getServiceUrl()}Cliente(ClienteUUID=${sCustomerId},IsActiveEntity=true)/FotoCliente`,
					{credentials: "same-origin"});
				const oBlob = oResponse.ok ? await oResponse.blob() : null;

				return oBlob && oBlob.size > 0 && oBlob.type.startsWith("image/") ? URL.createObjectURL(oBlob) : "";
			} catch {
				return "";
			}
		}
	};
});

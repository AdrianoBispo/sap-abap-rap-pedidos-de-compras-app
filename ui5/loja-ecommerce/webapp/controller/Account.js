sap.ui.define([
	"sap/ui/base/Object",
	"sap/ui/core/Fragment",
	"sap/ui/model/json/JSONModel",
	"sap/m/MessageToast",
	"../model/AccountService",
	"../model/OrderService",
	"../model/types/CpfType"
], (BaseObject, Fragment, JSONModel, MessageToast, AccountService, OrderService, CpfType) => {
	"use strict";

	const oInitialLogin = () => ({cpf: "", cpfState: "None", method: "EMAIL", value: "", error: "", busy: false,
		canLogin: false});

	/**
	 * Login of the customer (CPF + e-mail or CPF + phone) and the account popover. Owned by the component, which
	 * keeps the customer of the session in the "session" model.
	 */
	return BaseObject.extend("lojaecommerce.controller.Account", {
		constructor: function(oComponent) {
			BaseObject.call(this);
			this._oComponent = oComponent;
			this._oLoginModel = new JSONModel(oInitialLogin());
		},

		/**
		 * Opens the login dialog, or the account popover when the customer is already logged in.
		 * @param {sap.ui.core.Control} oOpener control the popover opens at
		 * @returns {Promise} resolves when the dialog or popover is open
		 */
		async open(oOpener) {
			if (this._oComponent.getCustomer()) {
				const oPopover = await this._load("_pPopover", "AccountPopover", "accountPopover");

				return oPopover.openBy(oOpener);
			}
			this._oLoginModel.setData(oInitialLogin());
			const oDialog = await this._load("_pDialog", "LoginDialog", "loginDialog");

			return oDialog.open();
		},

		async _load(sPromise, sFragment, sId) {
			if (!this[sPromise]) {
				this[sPromise] = Fragment.load({
					id: "account" + sId,
					name: "lojaecommerce.view." + sFragment,
					controller: this
				}).then((oControl) => {
					oControl.setModel(this._oLoginModel, "login");
					oControl.setModel(this._oComponent.getModel("session"), "session");
					oControl.setModel(this._oComponent.getModel("i18n"), "i18n");
					oControl.addStyleClass(this._oComponent.getContentDensityClass());

					return oControl;
				});
			}

			return this[sPromise];
		},

		formatCpf(sCpf) {
			return OrderService.formatCpf(String(sCpf || ""));
		},

		onLoginCpfLiveChange(oEvent) {
			// 000.000.000-00
			const sDigits = oEvent.getParameter("value").replace(/\D/g, "").slice(0, 11);
			let sMasked = sDigits.slice(0, 3);

			if (sDigits.length > 3) {
				sMasked += "." + sDigits.slice(3, 6);
			}
			if (sDigits.length > 6) {
				sMasked += "." + sDigits.slice(6, 9);
			}
			if (sDigits.length > 9) {
				sMasked += "-" + sDigits.slice(9);
			}

			this._oLoginModel.setProperty("/cpf", sMasked);
			this._updateLogin();
		},

		onLoginValueLiveChange() {
			this._updateLogin();
		},

		onLoginMethodChange() {
			this._oLoginModel.setProperty("/value", "");
			this._updateLogin();
		},

		_updateLogin() {
			const oModel = this._oLoginModel;
			const sDigits = oModel.getProperty("/cpf").replace(/\D/g, "");
			const bCpfOk = CpfType.isValidCpf(sDigits);

			oModel.setProperty("/cpfState", sDigits.length === 11 && !bCpfOk ? "Error" : "None");
			oModel.setProperty("/error", "");
			oModel.setProperty("/canLogin", bCpfOk && oModel.getProperty("/value").trim().length > 0);
		},

		async onLogin() {
			const oModel = this._oLoginModel;
			const oBundle = await this._oComponent.getModel("i18n").getResourceBundle();

			if (!oModel.getProperty("/canLogin") || oModel.getProperty("/busy")) {
				return;
			}
			oModel.setProperty("/busy", true);
			try {
				const oCustomer = await AccountService.login(this._oComponent.getModel("customers"), {
					cpf: oModel.getProperty("/cpf"),
					method: oModel.getProperty("/method"),
					value: oModel.getProperty("/value")
				});

				if (!oCustomer) {
					// the same answer for an unknown CPF and for a wrong e-mail/phone
					oModel.setProperty("/error", oBundle.getText("loginRefused"));

					return;
				}
				this._oComponent.setCustomer(oCustomer);
				(await this._pDialog).close();
				MessageToast.show(oBundle.getText("loginWelcome", [oCustomer.Nome]));
			} catch (oError) {
				oModel.setProperty("/error", oBundle.getText("loginError") + " " + OrderService.errorText(oError));
			} finally {
				oModel.setProperty("/busy", false);
			}
		},

		async onLoginCancel() {
			(await this._pDialog).close();
		},

		async onLogout() {
			const oBundle = await this._oComponent.getModel("i18n").getResourceBundle();

			(await this._pPopover).close();
			this._oComponent.logout();
			MessageToast.show(oBundle.getText("accountLoggedOut"));
		},

		destroy() {
			["_pDialog", "_pPopover"].forEach(async (sPromise) => {
				if (this[sPromise]) {
					(await this[sPromise]).destroy();
				}
			});
			BaseObject.prototype.destroy.call(this);
		}
	});
});

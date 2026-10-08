sap.ui.define([
	"sap/ui/base/Object",
	"sap/ui/core/Fragment",
	"sap/ui/model/json/JSONModel",
	"sap/m/MessageToast",
	"sap/m/MessageBox",
	"sap/ui/core/format/DateFormat",
	"../model/AccountService",
	"../model/ImageService",
	"../model/OrderService",
	"../model/types/CpfType"
], (BaseObject, Fragment, JSONModel, MessageToast, MessageBox, DateFormat, AccountService, ImageService, OrderService,
		CpfType) => {
	"use strict";

	const oInitialProfile = () => ({busy: false, error: "", customer: {}, addresses: []});

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
			this._oProfileModel = new JSONModel(oInitialProfile());
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
					oControl.setModel(this._oProfileModel, "profile");
					oControl.setModel(this._oComponent.getModel("account"), "account");
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

		// initials of the name for the avatar when there is no photo
		initials(sName) {
			return String(sName || "").split(/\s+/).filter(Boolean).slice(0, 2).map((s) => s.charAt(0).toUpperCase()).join("");
		},

		formatPhone(sPhone) {
			const sDigits = String(sPhone || "").replace(/\D/g, "");

			if (sDigits.length === 11) {
				return `(${sDigits.slice(0, 2)}) ${sDigits.slice(2, 7)}-${sDigits.slice(7)}`;
			}

			return sDigits.length === 10 ? `(${sDigits.slice(0, 2)}) ${sDigits.slice(2, 6)}-${sDigits.slice(6)}` : sPhone;
		},

		formatCep(sCep) {
			const sDigits = String(sCep || "").replace(/\D/g, "");

			return sDigits.length === 8 ? `${sDigits.slice(0, 5)}-${sDigits.slice(5)}` : sCep;
		},

		// date (yyyy-MM-dd) or timestamp of the back-end, in the language of the user
		formatDate(sValue) {
			if (!sValue) {
				return "";
			}
			const bDateOnly = /^\d{4}-\d{2}-\d{2}$/.test(sValue);

			return DateFormat.getDateInstance({style: "medium", UTC: bDateOnly}).format(new Date(sValue));
		},

		// ---- settings: complete data and deactivation ----

		/**
		 * Opens the settings dialog with the complete data of the logged in customer.
		 */
		async onSettings() {
			(await this._pPopover).close();
			this._oProfileModel.setData(oInitialProfile());
			const oDialog = await this._load("_pSettings", "AccountSettingsDialog", "settingsDialog");

			oDialog.open();
			await this._loadProfile();
		},

		async _loadProfile() {
			const oModel = this._oProfileModel;
			const oBundle = await this._oComponent.getModel("i18n").getResourceBundle();
			const oCustomer = this._oComponent.getCustomer();

			oModel.setProperty("/busy", true);
			try {
				const oProfile = await AccountService.loadProfile(this._oComponent.getModel("customers"),
					oCustomer.ClienteUUID);

				oModel.setProperty("/customer", oProfile.customer || {});
				oModel.setProperty("/addresses", oProfile.addresses);
				if (!oProfile.customer) {
					oModel.setProperty("/error", oBundle.getText("settingsNotFound"));
				}
			} catch (oError) {
				oModel.setProperty("/error", oBundle.getText("settingsLoadError") + " " + OrderService.errorText(oError));
			} finally {
				oModel.setProperty("/busy", false);
			}
		},

		/**
		 * Changes the profile photo: the picture is cropped to a square JPEG and sent to the customer in the back-end.
		 * @param {sap.ui.base.Event} oEvent change event of the file uploader
		 */
		async onPhotoChange(oEvent) {
			const oUploader = oEvent.getSource();
			const oFile = (oEvent.getParameter("files") || [])[0];
			const oModel = this._oProfileModel;
			const oBundle = await this._oComponent.getModel("i18n").getResourceBundle();

			if (!oFile) {
				return;
			}
			oModel.setProperty("/busy", true);
			oModel.setProperty("/error", "");
			try {
				const oImage = await ImageService.toSquareJpeg(oFile);

				await AccountService.updatePhoto(this._oComponent.getModel("customers"),
					this._oComponent.getCustomer().ClienteUUID, oImage, "perfil.jpg");
				this._oComponent.setPhotoUrl(URL.createObjectURL(oImage));
				MessageToast.show(oBundle.getText("settingsPhotoUpdated"));
			} catch (oError) {
				oModel.setProperty("/error", oBundle.getText("settingsPhotoError") + " " + OrderService.errorText(oError));
			} finally {
				oUploader.clear();
				oModel.setProperty("/busy", false);
			}
		},

		async onPhotoInvalid() {
			const oBundle = await this._oComponent.getModel("i18n").getResourceBundle();

			this._oProfileModel.setProperty("/error", oBundle.getText("settingsPhotoInvalid"));
		},

		async onSettingsClose() {
			(await this._pSettings).close();
		},

		/**
		 * Asks for confirmation (with the open orders, which stay) and deactivates the account.
		 */
		async onDeactivate() {
			const oModel = this._oProfileModel;
			const oBundle = await this._oComponent.getModel("i18n").getResourceBundle();
			const oCustomer = this._oComponent.getCustomer();
			let iOpenOrders = 0;

			try {
				iOpenOrders = await OrderService.countOpenOrders(this._oComponent.getModel("orders"), oCustomer.ClienteUUID);
			} catch {
				// the warning about open orders is only informative
			}
			const sMessage = oBundle.getText("settingsDeactivateConfirm")
				+ (iOpenOrders ? "\n\n" + oBundle.getText("settingsDeactivateOpenOrders", [iOpenOrders]) : "");

			MessageBox.warning(sMessage, {
				title: oBundle.getText("settingsDeactivateTitle"),
				actions: [oBundle.getText("settingsDeactivateButton"), MessageBox.Action.CANCEL],
				emphasizedAction: MessageBox.Action.CANCEL,
				onClose: async (sAction) => {
					if (sAction !== oBundle.getText("settingsDeactivateButton")) {
						return;
					}
					oModel.setProperty("/busy", true);
					oModel.setProperty("/error", "");
					try {
						await AccountService.deactivate(this._oComponent.getModel("customers"), oCustomer.ClienteUUID);
						(await this._pSettings).close();
						this._oComponent.logout();
						MessageBox.success(oBundle.getText("settingsDeactivated"));
					} catch (oError) {
						oModel.setProperty("/error", oBundle.getText("settingsDeactivateError") + " "
							+ OrderService.errorText(oError));
					} finally {
						oModel.setProperty("/busy", false);
					}
				}
			});
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
			["_pDialog", "_pPopover", "_pSettings"].forEach(async (sPromise) => {
				if (this[sPromise]) {
					(await this[sPromise]).destroy();
				}
			});
			BaseObject.prototype.destroy.call(this);
		}
	});
});

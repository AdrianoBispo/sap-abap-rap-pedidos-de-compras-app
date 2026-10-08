sap.ui.define([
	"./BaseController",
	"../model/types/EmailType",
	"../model/types/CpfType",
	"../model/formatter",
	"../model/OrderService",
	"../model/CustomerService",
	"sap/m/MessageBox",
	"sap/m/MessageItem",
	"sap/m/MessagePopover",
	"sap/m/MessageToast",
	"sap/ui/core/Messaging",
	"sap/ui/model/json/JSONModel",
	"sap/base/security/encodeXML"
], (BaseController, EmailType, CpfType, formatter, OrderService, CustomerService, MessageBox, MessageItem,
		MessagePopover, MessageToast, Messaging, JSONModel, encodeXML) => {
	"use strict";

	const sCartModel = "cartProducts";

	// fields of the registration form of a new customer (shown when the CPF is not registered)
	const aRegistrationInputs = ["customerName", "customerEmail", "customerPhone", "customerBirth", "customerCep",
		"customerNumero"];

	const oInitialData = () => ({
		SelectedPayment: "CARTAO_CREDITO",
		SelectedDeliveryMethod: "PADRAO",
		Note: "",
		Today: new Date(),
		Customer: {
			Cpf: "", LoggedIn: false, Searched: false, Found: false, ClienteUUID: "", Display: "",
			Nome: "", Email: "", Telefone: "", DataNascimento: "", Cep: "", Numero: "", Complemento: ""
		},
		Card: {Name: "", Number: "", SecurityCode: "", Expire: ""}
	});

	return BaseController.extend("lojaecommerce.controller.Checkout", {
		types: {
			email: new EmailType(),
			cpf: new CpfType()
		},

		formatter,

		onInit() {
			this.setModel(new JSONModel(oInitialData()));
			this.setModel(Messaging.getMessageModel(), "message");

			this._iLookup = 0;

			// the customer of the session (login) fills the customer step; it follows login and logout
			this._oSessionBinding = this.getOwnerComponent().getModel("session").bindProperty("/customer");
			this._oSessionBinding.attachChange(this._syncCustomer, this);
			this._syncCustomer();
			// order registered in the back-end but not paid yet (payment refused): a new try pays the same order
			this._oPlaced = null;

			// single column view for the checkout process; the view is created while the route is being displayed,
			// so the layout is also set here (the route was matched before the view existed)
			this.getRouter().getRoute("checkout").attachMatched(this._onCheckoutMatched, this);
			this._onCheckoutMatched();

			// set the focus to the "Return to Shop" button each time the view is shown
			const oReturnToShopButton = this.byId("returnToShopButton");
			this.getView().addEventDelegate({
				onAfterShow() {
					oReturnToShopButton.focus();
				}
			});
		},

		onExit() {
			this._oSessionBinding.detachChange(this._syncCustomer, this);
			this._oSessionBinding.destroy();
		},

		_onCheckoutMatched() {
			this._setLayout("One");
			this.byId("wizardNavContainer").to(this.byId("wizardContentPage"));
		},

		/**
		 * Only validation on client side; the back-end validates again when the order is registered.
		 * @param {sap.ui.base.Event} oEvent press event of the button that displays the MessagePopover
		 */
		onShowMessagePopoverPress(oEvent) {
			if (!this._oMessagePopover) {
				this._oMessagePopover = new MessagePopover({
					items: {
						path: "message>/",
						template: new MessageItem({
							type: "{message>type}",
							title: "{message>message}",
							subtitle: "{message>additionalText}"
						})
					}
				});
				this.getView().addDependent(this._oMessagePopover);
			}
			this._oMessagePopover.openBy(oEvent.getSource());
		},

		// ---- customer ----

		/**
		 * Looks for the customer with the CPF in the back-end. Found customers are used as they are registered
		 * (the order is delivered to their main address); an unknown CPF opens the registration form.
		 */
		async onCpfChange() {
			const oModel = this.getModel();
			const iLookup = ++this._iLookup;

			oModel.setProperty("/Customer/Searched", false);
			oModel.setProperty("/Customer/Found", false);
			oModel.setProperty("/Customer/ClienteUUID", "");
			this.byId("shoppingCartWizard").invalidateStep(this.byId("customerStep"));

			// an invalid CPF is reported by the input itself
			if (this._checkInputFields(["customerCpf"])) {
				return;
			}

			const oView = this.getView();
			oView.setBusy(true);
			try {
				const oCustomer = await OrderService.findCustomer(this.getOwnerComponent().getModel("orders"),
					oModel.getProperty("/Customer/Cpf"));

				if (iLookup !== this._iLookup) {
					return;
				}
				// a registered CPF is not used without login: the customer has to log in (CPF + e-mail or phone)
				oModel.setProperty("/Customer/Found", !!oCustomer);
				oModel.setProperty("/Customer/Searched", true);
			} catch (oError) {
				MessageBox.error((await this.requestResourceBundle()).getText("checkoutCustomerLookupError"),
					{details: OrderService.errorText(oError)});
			} finally {
				oView.setBusy(false);
			}
			this.checkCustomerStep();
		},

		/**
		 * The customer step is complete when the customer is logged in, or when the CPF is new and the
		 * registration form is valid. A registered CPF without login is not enough.
		 */
		checkCustomerStep() {
			const oModel = this.getModel();
			const oWizard = this.byId("shoppingCartWizard");
			const oStep = this.byId("customerStep");

			if (oModel.getProperty("/Customer/LoggedIn")) {
				oWizard.validateStep(oStep);
			} else if (!oModel.getProperty("/Customer/Searched") || oModel.getProperty("/Customer/Found")) {
				oWizard.invalidateStep(oStep);
			} else {
				this._checkStep("customerStep", ["customerCpf", ...aRegistrationInputs]);
			}
		},

		/**
		 * Puts the customer of the session in the customer step (or clears the step after a logout).
		 */
		_syncCustomer() {
			const oModel = this.getModel();
			const oCustomer = this.getOwnerComponent().getCustomer();

			if (oCustomer) {
				oModel.setProperty("/Customer/LoggedIn", true);
				oModel.setProperty("/Customer/ClienteUUID", oCustomer.ClienteUUID);
				oModel.setProperty("/Customer/Display", oCustomer.Cidade
					? `${oCustomer.Nome} (${oCustomer.Cidade}/${oCustomer.Uf})` : oCustomer.Nome);
				oModel.setProperty("/Customer/Cpf", OrderService.formatCpf(oCustomer.Cpf));
				oModel.setProperty("/Customer/Searched", true);
				oModel.setProperty("/Customer/Found", true);
			} else if (oModel.getProperty("/Customer/LoggedIn")) {
				oModel.setProperty("/Customer", oInitialData().Customer);
			}
			this.checkCustomerStep();
		},

		onLoginPress(oEvent) {
			this.getOwnerComponent().openAccount(oEvent.getSource());
		},

		onLogoutPress() {
			this.getOwnerComponent().logout();
		},

		onCepLiveChange(oEvent) {
			// keeps only digits and puts the hyphen after the fifth one (00000-000)
			const oInput = oEvent.getSource();
			const sDigits = oInput.getValue().replace(/\D/g, "").slice(0, 8);
			const sMasked = sDigits.length > 5 ? sDigits.slice(0, 5) + "-" + sDigits.slice(5) : sDigits;

			if (sMasked !== oInput.getValue()) {
				oInput.setValue(sMasked);
			}
		},

		// ---- order ----

		/**
		 * Called from the order summary: asks for confirmation and cancels the checkout.
		 */
		async handleWizardCancel() {
			const sText = (await this.requestResourceBundle()).getText("checkoutControllerAreYouSureCancel");

			this._handleSubmitOrCancel(sText, "warning", async () => {
				await this._cancelPendingOrder();
				this.getRouter().navTo("home");
			});
		},

		/**
		 * Called from the order summary: asks for confirmation and places the order.
		 */
		async handleWizardSubmit() {
			const sText = (await this.requestResourceBundle()).getText("checkoutControllerAreYouSureSubmit");

			this._handleSubmitOrCancel(sText, "confirm", () => this._placeOrder());
		},

		/**
		 * Places the order in the back-end:
		 * 1. reads the stock again and corrects the cart when something changed (back to the first step);
		 * 2. registers the customer when the CPF was not registered (service of Gestão de Clientes);
		 * 3. creates and activates the Pedido (the activation reserves the stock);
		 * 4. pays it (action SimularPagamento). A refused payment keeps the order open for a new try.
		 */
		async _placeOrder() {
			const oComponent = this.getOwnerComponent();
			const oBundle = await this.requestResourceBundle();
			const oCartModel = oComponent.getModel(sCartModel);
			const oModel = this.getModel();
			const oView = this.getView();

			oView.setBusy(true);
			try {
				if (!this._oPlaced) {
					const oCatalog = await oComponent.loadCatalog(true);
					const aProblems = this.cart.syncWithCatalog(oCartModel, oCatalog.Products, oBundle);

					if (aProblems.length) {
						this._navToWizardStep(this.byId("contentsStep"));
						MessageBox.warning(oBundle.getText("checkoutProblemsTitle"), {
							details: "<ul>" + aProblems.map((s) => `<li>${encodeXML(s)}</li>`).join("") + "</ul>"
						});

						return;
					}
					await this._ensureCustomer(oComponent);
					this._oPlaced = await OrderService.createOrder(oComponent.getModel("orders"), {
						customerId: oModel.getProperty("/Customer/ClienteUUID"),
						items: Object.values(oCartModel.getProperty("/cartEntries"))
							.map((oEntry) => ({ItemUUID: oEntry.ItemUUID, Quantity: oEntry.Quantity})),
						note: OrderService.buildNote(
							oBundle.getText(oModel.getProperty("/SelectedDeliveryMethod") === "EXPRESSA"
								? "checkoutDeliveryTypeExpress" : "checkoutDeliveryTypeStandard"),
							oModel.getProperty("/Note"))
					});
				}

				const oCard = oModel.getProperty("/Card");
				const oPayment = await OrderService.pay(oComponent.getModel("orders"), this._oPlaced.context, {
					method: oModel.getProperty("/SelectedPayment"),
					number: oCard.Number,
					expiry: oCard.Expire,
					cvv: oCard.SecurityCode
				});

				if (!oPayment.approved) {
					MessageBox.warning(oBundle.getText("checkoutPaymentRefused", [this._oPlaced.number]), {
						title: oBundle.getText("checkoutPaymentRefusedTitle")
					});
					this._navToWizardStep(this.byId("cardStep"));

					return;
				}
				const sOrderNumber = this._oPlaced.number;

				OrderService.release(this._oPlaced);
				this._oPlaced = null;
				this._resetWizard();
				this.getRouter().navTo("ordercompleted", {orderId: sOrderNumber});
			} catch (oError) {
				MessageBox.error(oBundle.getText("checkoutOrderError"), {details: OrderService.errorText(oError)});
			} finally {
				oView.setBusy(false);
			}
		},

		/**
		 * Registers the customer when the CPF was not found (registered only once, a retry reuses the new customer).
		 * @param {sap.ui.core.Component} oComponent the component
		 */
		async _ensureCustomer(oComponent) {
			const oModel = this.getModel();

			if (oModel.getProperty("/Customer/ClienteUUID")) {
				return;
			}
			const oCustomer = await CustomerService.register(oComponent.getModel("customers"),
				oModel.getProperty("/Customer"));

			// the new customer is logged in: the next purchase starts with the data already known
			oComponent.setCustomer({
				ClienteUUID: oCustomer.id,
				Cpf: OrderService.onlyDigits(oModel.getProperty("/Customer/Cpf")),
				Nome: oCustomer.name,
				Cidade: oCustomer.city,
				Uf: oCustomer.state
			});
		},

		/**
		 * An order that was registered but not paid is cancelled when the customer gives up (releases the stock).
		 */
		async _cancelPendingOrder() {
			if (!this._oPlaced) {
				return;
			}
			const oBundle = await this.requestResourceBundle();
			const oPlaced = this._oPlaced;

			this._oPlaced = null;
			try {
				await OrderService.cancel(this.getOwnerComponent().getModel("orders"), oPlaced.context,
					oBundle.getText("checkoutCancelReason"));
				MessageToast.show(oBundle.getText("checkoutOrderCancelled", [oPlaced.number]));
			} catch (oError) {
				MessageBox.error(oBundle.getText("checkoutCancelError", [oPlaced.number]),
					{details: OrderService.errorText(oError)});
			} finally {
				OrderService.release(oPlaced);
			}
		},

		backToWizardContent() {
			this.byId("wizardNavContainer").backToPage(this.byId("wizardContentPage").getId());
		},

		_clearMessages() {
			Messaging.removeAllMessages();
		},

		/**
		 * Checks the step after its activation to decide whether the user can proceed or has to correct the input.
		 * @param {sap.ui.base.Event} oEvent activate event of the step
		 */
		onCheckStepActivation(oEvent) {
			this._clearMessages();
			switch (oEvent.getSource().getId()) {
				case this.createId("customerStep"):
					this.checkCustomerStep();
					break;
				case this.createId("cardStep"):
					this.checkCardStep();
					break;
				default:
					break;
			}
		},

		checkCardStep() {
			this._checkStep("cardStep", ["cardHolderName", "cardNumber", "cardSecurityCode", "cardExpiration"]);
		},

		/**
		 * Checks if one or more of the inputs hold invalid data (empty counts as invalid).
		 * @param {string[]} aInputIds ids of the inputs
		 * @returns {boolean} whether at least one input is invalid
		 */
		_checkInputFields(aInputIds) {
			const oView = this.getView();

			return aInputIds.some((sInputId) => {
				const oInput = oView.byId(sInputId);
				const oBinding = oInput.getBinding("value");

				try {
					oBinding.getType().validateValue(oInput.getValue());
				} catch {
					return true;
				}

				return false;
			});
		},

		/**
		 * Enables the "next" button of a step only when all its inputs are valid.
		 * @param {string} sStepName id of the step
		 * @param {string[]} aInputIds ids of the inputs to check
		 */
		_checkStep(sStepName, aInputIds) {
			const oWizard = this.byId("shoppingCartWizard");
			const oStep = this.byId(sStepName);
			const bEmptyInputs = this._checkInputFields(aInputIds);
			const bValidationError = !!Messaging.getMessageModel().getData().length;

			if (!bValidationError && !bEmptyInputs) {
				oWizard.validateStep(oStep);
			} else {
				oWizard.invalidateStep(oStep);
			}
		},

		/**
		 * Called when the wizard is completed: shows the summary page unless there are errors.
		 */
		async checkCompleted() {
			if (Messaging.getMessageModel().getData().length > 0) {
				MessageBox.error((await this.requestResourceBundle()).getText("popOverMessageText"));
			} else {
				this.byId("wizardNavContainer").to(this.byId("summaryPage"));
			}
		},

		async onReturnToShopButtonPress() {
			await this._cancelPendingOrder();
			this._setLayout("Two");
			this.getRouter().navTo("home");
		},

		// ---- helpers ----

		/**
		 * Asks for confirmation, then runs the action.
		 * @param {string} sMessage message text
		 * @param {string} sMessageBoxType message box type (warning, confirm)
		 * @param {function} fnAction called when the user confirms
		 */
		_handleSubmitOrCancel(sMessage, sMessageBoxType, fnAction) {
			MessageBox[sMessageBoxType](sMessage, {
				actions: [MessageBox.Action.YES, MessageBox.Action.NO],
				onClose: (oAction) => {
					if (oAction === MessageBox.Action.YES) {
						fnAction();
					}
				}
			});
		},

		/**
		 * Resets the wizard and empties the cart after the order was placed.
		 */
		_resetWizard() {
			const oWizard = this.byId("shoppingCartWizard");

			this._navToWizardStep(this.byId("contentsStep"));
			oWizard.discardProgress(oWizard.getSteps()[0]);
			this.getModel().setData(oInitialData());
			this._syncCustomer();
			this._clearMessages();
			this.getOwnerComponent().getModel(sCartModel).setProperty("/cartEntries", {});
		},

		/**
		 * Goes back to a wizard step from the summary page.
		 * @param {sap.ui.base.Event} oEvent press event of the edit button
		 */
		_navBackToStep(oEvent) {
			this._navToWizardStep(this.byId(oEvent.getSource().data("navBackTo")));
		},

		_navToWizardStep(oStep) {
			const oNavContainer = this.byId("wizardNavContainer");
			const fnAfterNavigate = () => {
				this.byId("shoppingCartWizard").goToStep(oStep);
				// detaches itself after navigation
				oNavContainer.detachAfterNavigate(fnAfterNavigate);
			};

			oNavContainer.attachAfterNavigate(fnAfterNavigate);
			oNavContainer.to(this.byId("wizardContentPage"));
		}
	});
});

sap.ui.define([
	"sap/ui/core/mvc/Controller",
	"sap/m/MessageToast",
	"sap/ui/core/UIComponent",
	"sap/ui/core/routing/History",
	"../model/cart"
], (Controller, MessageToast, UIComponent, History, cart) => {
	"use strict";

	return Controller.extend("lojaecommerce.controller.BaseController", {
		cart,

		/**
		 * @returns {sap.ui.core.routing.Router} the router of the component
		 */
		getRouter() {
			return UIComponent.getRouterFor(this);
		},

		getModel(sName) {
			return this.getView().getModel(sName);
		},

		setModel(oModel, sName) {
			return this.getView().setModel(oModel, sName);
		},

		/**
		 * @returns {Promise<sap.base.i18n.ResourceBundle>} the resource bundle of the "i18n" model
		 */
		requestResourceBundle() {
			return this.getOwnerComponent().getModel("i18n").getResourceBundle();
		},

		/**
		 * The shop has no user management yet: the avatar button only explains that.
		 */
		async onAvatarPress() {
			MessageToast.show((await this.requestResourceBundle()).getText("avatarButtonMessageToastText"));
		},

		/**
		 * React to FlexibleColumnLayout resize events: hides navigation buttons and switches the layout.
		 * @param {sap.ui.base.Event} oEvent the stateChange event
		 */
		onStateChange(oEvent) {
			const sLayout = oEvent.getParameter("layout");
			const iColumns = oEvent.getParameter("maxColumnsCount");

			if (iColumns === 1) {
				this.getModel("appView").setProperty("/smallScreenMode", true);
			} else {
				this.getModel("appView").setProperty("/smallScreenMode", false);
				// switch back to two column mode when the window is resized (e.g. orientation change); the one column
				// layout set by the app itself (checkout) is kept
				if (sLayout === "OneColumn" && oEvent.getParameter("isResize")) {
					this._setLayout("Two");
				}
			}
		},

		/**
		 * Sets the flexible column layout to one, two, or three columns.
		 * @param {string} sColumns "One", "Two" or "Three"
		 */
		_setLayout(sColumns) {
			if (sColumns) {
				// taken from the root view: in onInit the controller's own view is not yet connected to it
				this.getOwnerComponent().getRootControl().getModel("appView").setProperty("/layout",
					sColumns + "Column" + (sColumns === "One" ? "" : "sMidExpanded"));
			}
		},

		/**
		 * Navigates back in the browser history or to the home screen.
		 */
		onBack() {
			if (History.getInstance().getPreviousHash() !== undefined) {
				window.history.go(-1);
			} else {
				this.getRouter().navTo("home");
			}
		},

		/**
		 * Adds the product of the pressed control to the cart.
		 * @param {sap.ui.base.Event} oEvent the press event
		 */
		onAddToCart(oEvent) {
			const oEntry = oEvent.getSource().getBindingContext().getObject();
			cart.addToCart(this.requestResourceBundle(), oEntry, this.getOwnerComponent().getModel("cartProducts"));
		},

		_clearComparison() {
			this.getOwnerComponent().getModel("comparison").setData({
				category: "",
				item1: "",
				item2: ""
			});
		}
	});
});

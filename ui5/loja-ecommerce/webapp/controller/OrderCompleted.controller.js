sap.ui.define([
	"./BaseController",
	"sap/ui/model/json/JSONModel"
], (BaseController, JSONModel) => {
	"use strict";

	return BaseController.extend("lojaecommerce.controller.OrderCompleted", {
		onInit() {
			this.setModel(new JSONModel({orderId: ""}), "order");
			this.getRouter().getRoute("ordercompleted").attachPatternMatched((oEvent) => {
				this.getModel("order").setProperty("/orderId", oEvent.getParameter("arguments").orderId);
			});
		},

		onReturnToShopButtonPress() {
			this._setLayout("Two");
			this.getRouter().navTo("home");
		}
	});
});

sap.ui.define([
	"./BaseController",
	"../model/formatter"
], (BaseController, formatter) => {
	"use strict";

	return BaseController.extend("lojaecommerce.controller.Comparison", {
		formatter,

		onInit() {
			this._oRouter = this.getRouter();
			["comparison", "comparisonCart"].forEach((sRoute) => {
				this._oRouter.getRoute(sRoute).attachPatternMatched(this._onRoutePatternMatched, this);
			});
		},

		async _onRoutePatternMatched(oEvent) {
			const oContainer = this.byId("comparisonContainer");
			const oParameters = oEvent.getParameter("arguments");
			const oPlaceholder = this.byId("placeholder");
			const oCatalog = await this.getOwnerComponent().loadCatalog();
			const oComparison = this.getModel("comparison");

			// save category and current products
			oComparison.setProperty("/category", oParameters.id);
			oComparison.setProperty("/item1", oParameters.item1Id);
			oComparison.setProperty("/item2", oParameters.item2Id);

			oPlaceholder.setVisible(false);
			[oParameters.item1Id, oParameters.item2Id].forEach((sId, iWhich) => {
				const oPanel = oContainer.getItems()[iWhich];
				const iIndex = oCatalog.Products.findIndex((oProduct) => oProduct.ProductId === sId);

				if (sId && iIndex >= 0) {
					oPanel.bindElement({path: "/Products/" + iIndex});
					oPanel.setVisible(true);
				} else {
					oPanel.unbindElement();
					oPanel.setVisible(false);
					oPlaceholder.setVisible(true);
				}
			});
		},

		onRemoveComparison(oEvent) {
			const oComparison = this.getModel("comparison");
			const bRemoveFirst = oComparison.getProperty("/item1") === oEvent.getSource().getBindingContext().getObject().ProductId;
			const sRemainingItemId = oComparison.getProperty("/item" + (bRemoveFirst ? 2 : 1));

			// navigate to the comparison without the removed product
			this.getRouter().navTo("comparison", {
				id: oComparison.getProperty("/category"),
				item1Id: sRemainingItemId
			}, true);
		},

		onToggleCart(oEvent) {
			const oComparison = this.getModel("comparison");
			const bPressed = oEvent.getParameter("pressed");

			this._setLayout(bPressed ? "Three" : "Two");
			this.getRouter().navTo(bPressed ? "comparisonCart" : "comparison", {
				id: oComparison.getProperty("/category"),
				item1Id: oComparison.getProperty("/item1"),
				item2Id: oComparison.getProperty("/item2")
			});
		}
	});
});

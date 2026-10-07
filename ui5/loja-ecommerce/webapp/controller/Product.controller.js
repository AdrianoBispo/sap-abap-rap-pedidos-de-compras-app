sap.ui.define([
	"./BaseController",
	"../model/formatter"
], (BaseController, formatter) => {
	"use strict";

	return BaseController.extend("lojaecommerce.controller.Product", {
		formatter,

		onInit() {
			this._router = this.getOwnerComponent().getRouter();
			["product", "productCart"].forEach((sRoute) => {
				this._router.getRoute(sRoute).attachPatternMatched(this._routePatternMatched, this);
			});
		},

		/**
		 * Binds the page to the product of the route, or shows the not-found page.
		 * @param {sap.ui.base.Event} oEvent the pattern matched event
		 */
		async _routePatternMatched(oEvent) {
			const sProductId = oEvent.getParameter("arguments").productId;
			const oView = this.getView();

			oView.setBusy(true);
			try {
				const oCatalog = await this.getOwnerComponent().loadCatalog();
				const iIndex = oCatalog.Products.findIndex((oProduct) => oProduct.ProductId === sProductId);

				if (iIndex < 0) {
					this._router.getTargets().display("notFound");
				} else {
					oView.bindElement("/Products/" + iIndex);
				}
			} catch {
				this._router.getTargets().display("notFound");
			} finally {
				oView.setBusy(false);
			}
		},

		/**
		 * Opens or closes the cart column.
		 * @param {sap.ui.base.Event} oEvent the press event of the toggle button
		 */
		onToggleCart(oEvent) {
			const oEntry = this.getView().getBindingContext().getObject();
			const bPressed = oEvent.getParameter("pressed");

			this._setLayout(bPressed ? "Three" : "Two");
			this.getRouter().navTo(bPressed ? "productCart" : "product", {
				id: oEntry.Category,
				productId: oEntry.ProductId
			});
		}
	});
});

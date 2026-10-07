sap.ui.define([
	"sap/m/MessageBox",
	"sap/m/MessageToast"
], (MessageBox, MessageToast) => {
	"use strict";

	return {
		/**
		 * Puts a product in the cart. Products without stock cannot be bought: the back-end blocks orders with
		 * items that have no stock, and the quantity in the cart never exceeds the available quantity.
		 * @param {Promise<object>|object} vBundle promise of (or) the i18n resource bundle
		 * @param {object} oProduct product that is added to the cart
		 * @param {sap.ui.model.json.JSONModel} oCartModel cart model
		 */
		async addToCart(vBundle, oProduct, oCartModel) {
			const oBundle = await vBundle;

			if (oProduct.Status === "O" || oProduct.Status === "D") {
				MessageBox.show(oBundle.getText(oProduct.Status === "O" ? "productStatusOutOfStockMsg" : "productStatusDiscontinuedMsg"), {
					icon: MessageBox.Icon.ERROR,
					title: oBundle.getText(oProduct.Status === "O" ? "productStatusOutOfStockTitle" : "productStatusDiscontinuedTitle"),
					actions: [MessageBox.Action.CLOSE]
				});

				return;
			}

			this._updateCartItem(oBundle, oProduct, oCartModel);
		},

		/**
		 * Adds one unit of the product, or increases the quantity of the existing entry (up to the stock).
		 * @param {object} oBundle i18n bundle
		 * @param {object} oProduct product that is added
		 * @param {sap.ui.model.json.JSONModel} oCartModel cart model
		 */
		_updateCartItem(oBundle, oProduct, oCartModel) {
			const oEntries = {...oCartModel.getData().cartEntries};
			const oEntry = oEntries[oProduct.ProductId];

			if (oEntry === undefined) {
				oEntries[oProduct.ProductId] = {...oProduct, Quantity: 1};
			} else if (oEntry.Quantity >= oProduct.Available) {
				MessageToast.show(oBundle.getText("productMsgStockLimit", [oProduct.Available, oProduct.Name]));

				return;
			} else {
				oEntries[oProduct.ProductId] = {...oEntry, ...oProduct, Quantity: oEntry.Quantity + 1};
			}
			oCartModel.setProperty("/cartEntries", oEntries);
			MessageToast.show(oBundle.getText("productMsgAddedToCart", [oProduct.Name]));
		},

		/**
		 * Changes the quantity of an entry. Values below 1 or above the stock are corrected.
		 * @param {sap.ui.model.json.JSONModel} oCartModel cart model
		 * @param {string} sProductId product id
		 * @param {number} iQuantity requested quantity
		 */
		setQuantity(oCartModel, sProductId, iQuantity) {
			const oEntries = {...oCartModel.getData().cartEntries};
			const oEntry = oEntries[sProductId];
			if (!oEntry) {
				return;
			}
			const iQuantityWanted = Math.max(1, Math.floor(iQuantity) || 1);
			oEntries[sProductId] = {...oEntry, Quantity: Math.min(iQuantityWanted, Math.max(oEntry.Available, 1))};
			oCartModel.setProperty("/cartEntries", oEntries);
		},

		/**
		 * Compares the cart with the current catalog (price, stock and availability). Entries that cannot be
		 * bought as they are get a problem text; the cart is updated with the current price and quantity limit.
		 * @param {sap.ui.model.json.JSONModel} oCartModel cart model
		 * @param {object[]} aProducts current catalog
		 * @param {object} oBundle i18n bundle
		 * @returns {string[]} messages of the entries that need attention
		 */
		syncWithCatalog(oCartModel, aProducts, oBundle) {
			const mProducts = Object.fromEntries(aProducts.map((oProduct) => [oProduct.ProductId, oProduct]));
			const oEntries = {...oCartModel.getData().cartEntries};
			const aProblems = [];

			Object.keys(oEntries).forEach((sProductId) => {
				const oEntry = oEntries[sProductId];
				const oCurrent = mProducts[sProductId];

				if (!oCurrent) {
					aProblems.push(oBundle.getText("checkoutProblemRemoved", [oEntry.Name]));
					delete oEntries[sProductId];
				} else if (oCurrent.Available <= 0) {
					aProblems.push(oBundle.getText("checkoutProblemNoStock", [oEntry.Name]));
					delete oEntries[sProductId];
				} else {
					let iQuantity = oEntry.Quantity;
					if (iQuantity > oCurrent.Available) {
						aProblems.push(oBundle.getText("checkoutProblemQuantity", [oEntry.Name, oCurrent.Available]));
						iQuantity = oCurrent.Available;
					}
					if (oCurrent.Price !== oEntry.Price) {
						aProblems.push(oBundle.getText("checkoutProblemPrice", [oEntry.Name]));
					}
					oEntries[sProductId] = {...oCurrent, Quantity: iQuantity};
				}
			});
			oCartModel.setProperty("/cartEntries", oEntries);

			return aProblems;
		}
	};
});

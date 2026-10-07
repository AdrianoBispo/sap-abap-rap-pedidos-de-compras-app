sap.ui.define([
	"./BaseController",
	"sap/ui/model/json/JSONModel",
	"sap/ui/Device",
	"../model/formatter",
	"sap/m/MessageBox",
	"sap/m/MessageToast"
], (BaseController, JSONModel, Device, formatter, MessageBox, MessageToast) => {
	"use strict";

	const sCartModelName = "cartProducts";
	const sSavedForLaterEntries = "savedForLaterEntries";
	const sCartEntries = "cartEntries";

	return BaseController.extend("lojaecommerce.controller.Cart", {
		formatter,

		onInit() {
			this._oRouter = this.getRouter();
			["cart", "productCart", "comparisonCart"].forEach((sRoute) => {
				this._oRouter.getRoute(sRoute).attachPatternMatched(this._routePatternMatched, this);
			});
			// set initial ui configuration model
			this.getView().setModel(new JSONModel({}), "cfg");
			this._toggleCfgModel();

			const oEditButton = this.byId("editButton");
			oEditButton.addEventDelegate({
				onAfterRendering() {
					oEditButton.focus();
				}
			});
		},

		_routePatternMatched() {
			this._setLayout("Three");
			this.byId("entryList").removeSelections();
		},

		onEditOrDoneButtonPress() {
			this._toggleCfgModel();
		},

		async _toggleCfgModel() {
			const oCfgModel = this.getView().getModel("cfg");
			const oData = oCfgModel.getData();
			const oBundle = await this.requestResourceBundle();
			const bInDelete = Object.prototype.hasOwnProperty.call(oData, "inDelete") ? oData.inDelete : true;

			const sPhoneMode = Device.system.phone ? "None" : "SingleSelectMaster";
			const sPhoneType = Device.system.phone ? "Active" : "Inactive";

			oCfgModel.setData({
				inDelete: !bInDelete,
				notInDelete: bInDelete,
				listMode: bInDelete ? sPhoneMode : "Delete",
				listItemType: bInDelete ? sPhoneType : "Inactive",
				pageTitle: bInDelete ? oBundle.getText("appTitle") : oBundle.getText("cartTitleEdit")
			});
		},

		onEntryListPress(oEvent) {
			this._showProduct(oEvent.getSource());
		},

		onEntryListSelect(oEvent) {
			this._showProduct(oEvent.getParameter("listItem"));
		},

		/**
		 * Changes the quantity of a cart entry; the value is limited to the available stock.
		 * @param {sap.ui.base.Event} oEvent the change event of the step input
		 */
		onQuantityChange(oEvent) {
			const oContext = oEvent.getSource().getBindingContext(sCartModelName);

			this.cart.setQuantity(oContext.getModel(), oContext.getObject().ProductId, oEvent.getParameter("value"));
		},

		onSaveForLater(oEvent) {
			this._changeList(sSavedForLaterEntries, sCartEntries,
				oEvent.getSource().getBindingContext(sCartModelName));
		},

		onAddBackToBasket(oEvent) {
			this._changeList(sCartEntries, sSavedForLaterEntries,
				oEvent.getSource().getBindingContext(sCartModelName));
		},

		/**
		 * Moves a product from one list to the other.
		 * @param {string} sListToAddItem name of the list the item is moved to
		 * @param {string} sListToDeleteItem name of the list the item is removed from
		 * @param {sap.ui.model.Context} oBindingContext binding context of the product
		 */
		_changeList(sListToAddItem, sListToDeleteItem, oBindingContext) {
			const oCartModel = oBindingContext.getModel();
			const oProduct = oBindingContext.getObject();
			const oModelData = oCartModel.getData();
			// the lists are cloned, because the JSON model only notices changed references
			const oListToAddItem = {...oModelData[sListToAddItem]};
			const oListToDeleteItem = {...oModelData[sListToDeleteItem]};

			if (oListToAddItem[oProduct.ProductId] === undefined) {
				oListToAddItem[oProduct.ProductId] = {...oProduct};
			}
			delete oListToDeleteItem[oProduct.ProductId];
			oCartModel.setProperty("/" + sListToAddItem, oListToAddItem);
			oCartModel.setProperty("/" + sListToDeleteItem, oListToDeleteItem);
		},

		_showProduct(oItem) {
			const oEntry = oItem.getBindingContext(sCartModelName).getObject();
			let bCartVisible = false;

			// close the cart when showing a product on phone
			if (Device.system.phone) {
				this._setLayout("Two");
			} else {
				bCartVisible = this.getModel("appView").getProperty("/layout").startsWith("Three");
			}
			this._oRouter.navTo(bCartVisible ? "productCart" : "product", {
				id: oEntry.Category,
				productId: oEntry.ProductId
			}, !Device.system.phone);
		},

		onCartEntriesDelete(oEvent) {
			this._deleteProduct(sCartEntries, oEvent);
		},

		onSaveForLaterDelete(oEvent) {
			this._deleteProduct(sSavedForLaterEntries, oEvent);
		},

		/**
		 * Removes an entry of the cart or of the saved items after a confirmation.
		 * @param {string} sCollection the collection name
		 * @param {sap.ui.base.Event} oEvent the delete event of the list
		 */
		async _deleteProduct(sCollection, oEvent) {
			const oBindingContext = oEvent.getParameter("listItem").getBindingContext(sCartModelName);
			const oBundle = await this.requestResourceBundle();
			const sEntryId = oBindingContext.getProperty("ProductId");
			const sEntryName = oBindingContext.getProperty("Name");

			MessageBox.show(oBundle.getText("cartDeleteDialogMsg"), {
				title: oBundle.getText("cartDeleteDialogTitle"),
				actions: [MessageBox.Action.DELETE, MessageBox.Action.CANCEL],
				onClose(oAction) {
					if (oAction !== MessageBox.Action.DELETE) {
						return;
					}
					const oCartModel = oBindingContext.getModel();
					const oCollectionEntries = {...oCartModel.getData()[sCollection]};

					delete oCollectionEntries[sEntryId];
					oCartModel.setProperty("/" + sCollection, oCollectionEntries);
					MessageToast.show(oBundle.getText("cartDeleteDialogConfirmDeleteMsg", [sEntryName]));
				}
			});
		},

		onProceedButtonPress() {
			this.getRouter().navTo("checkout");
		}
	});
});

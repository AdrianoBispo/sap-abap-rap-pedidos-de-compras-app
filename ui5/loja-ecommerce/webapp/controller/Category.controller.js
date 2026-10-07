sap.ui.define([
	"./BaseController",
	"../model/formatter",
	"sap/ui/Device",
	"sap/ui/model/Filter",
	"sap/ui/model/FilterOperator",
	"sap/ui/model/Sorter",
	"sap/ui/model/json/JSONModel",
	"sap/ui/core/Fragment"
], (BaseController, formatter, Device, Filter, FilterOperator, Sorter, JSONModel, Fragment) => {
	"use strict";

	// availability filters of the dialog and the product status they select
	const mAvailabilityStatus = {
		Available: ["A"],
		LastUnits: ["L"],
		OutOfStock: ["O"]
	};

	return BaseController.extend("lojaecommerce.controller.Category", {
		formatter,

		onInit() {
			this.getView().setModel(new JSONModel({MaxPrice: 100}), "view");
			this._oRouter = this.getOwnerComponent().getRouter();
			["category", "product", "productCart", "comparison", "comparisonCart"].forEach((sRoute) => {
				this._oRouter.getRoute(sRoute).attachMatched(this._loadCategory, this);
			});
			this._aUiFilters = [];
			this._oSorter = new Sorter("Name", false);
			this._fPriceLow = 0;
			this._fPriceHigh = 0;
		},

		/**
		 * Binds the page to the category of the route and filters the product list.
		 * @param {sap.ui.base.Event} oEvent the route matched event
		 */
		async _loadCategory(oEvent) {
			const sRouteName = oEvent.getParameter("name");
			const sCategoryId = oEvent.getParameter("arguments").id;
			const sProductId = oEvent.getParameter("arguments").productId;
			const oComponent = this.getOwnerComponent();

			// switch to first column in full screen mode for category route on small devices
			if (sRouteName === "category") {
				this._setLayout(this.getModel("appView").getProperty("/smallScreenMode") ? "One" : "Two");
			}
			this._clearComparison();

			const oCatalog = await oComponent.loadCatalog();
			const iIndex = oCatalog.Categories.findIndex((oCategory) => oCategory.Category === sCategoryId);
			const oView = this.getView();

			if (iIndex < 0) {
				oView.unbindElement();
				this._oRouter.getTargets().display("notFound");

				return;
			}
			oView.bindElement("/Categories/" + iIndex);

			if (this._sCategoryId !== sCategoryId) {
				this._sCategoryId = sCategoryId;
				this._resetFilters(oCatalog.Products.filter((oProduct) => oProduct.Category === sCategoryId));
			}
			this._applyBinding();

			// select the product that is shown in the detail column
			const oList = this.byId("productList");
			const oSelected = oList.getItems().find((oItem) => oItem.getBindingContext().getObject().ProductId === sProductId);
			if (oSelected) {
				oList.setSelectedItem(oSelected);
			} else {
				oList.removeSelections();
			}
		},

		/**
		 * Clears the filters of the previous category and sets the price range to the prices of this category.
		 * @param {object[]} aProducts products of the category
		 */
		_resetFilters(aProducts) {
			const fMax = Math.ceil(Math.max(1, ...aProducts.map((oProduct) => oProduct.Price)) / 10) * 10;

			this._aUiFilters = [];
			this._oSorter = new Sorter("Name", false);
			this._fPriceLow = 0;
			this._fPriceHigh = fMax;
			this.getModel("view").setProperty("/MaxPrice", fMax);
			this.byId("categoryInfoToolbar").setVisible(false);
		},

		/**
		 * Applies the category filter, the filters of the dialog and the sorting to the product list.
		 */
		_applyBinding() {
			const oBinding = this.byId("productList").getBinding("items");
			oBinding.filter(new Filter({
				and: true,
				filters: [new Filter("Category", FilterOperator.EQ, this._sCategoryId), ...this._aUiFilters]
			}));
			oBinding.sort(this._oSorter);
		},

		onProductListSelect(oEvent) {
			this._showProduct(oEvent.getParameter("listItem"));
		},

		/**
		 * Opens the product details, keeping the cart open when it is visible.
		 * @param {sap.ui.base.Event} oEvent the select or press event
		 */
		onProductDetails(oEvent) {
			const oSource = oEvent.getSource();
			const oItem = Device.system.phone ? oSource : oSource.getSelectedItem();

			this._showProduct(oItem);
		},

		_showProduct(oItem) {
			const oProduct = oItem.getBindingContext().getObject();
			const bCartVisible = this.getModel("appView").getProperty("/layout").startsWith("Three");

			this._setLayout("Two");
			this._oRouter.navTo(bCartVisible ? "productCart" : "product", {
				id: oProduct.Category,
				productId: oProduct.ProductId
			}, !Device.system.phone);
		},

		/**
		 * Applies the filters and the sorting chosen in the dialog and updates the info toolbar.
		 * @param {sap.ui.base.Event} oEvent the confirm event of the dialog
		 */
		async _applyFilter(oEvent) {
			const oBundle = await this.requestResourceBundle();
			const oSlider = this.byId("rangeSlider");
			const aSelectedItems = oEvent.getParameter("filterItems");
			const aAvailabilityFilters = [];
			const aTexts = [];

			aSelectedItems.forEach((oItem) => {
				const aStatus = mAvailabilityStatus[oItem.getKey()];
				if (aStatus) {
					aStatus.forEach((sStatus) => aAvailabilityFilters.push(new Filter("Status", FilterOperator.EQ, sStatus)));
				}
			});
			this._aUiFilters = [];
			if (aAvailabilityFilters.length) {
				this._aUiFilters.push(new Filter({and: false, filters: aAvailabilityFilters}));
				aTexts.push(oBundle.getText("availabilityFilterTitle"));
			}
			if (oSlider.getValue() !== oSlider.getMin() || oSlider.getValue2() !== oSlider.getMax()) {
				this._aUiFilters.push(new Filter("Price", FilterOperator.BT, oSlider.getValue(), oSlider.getValue2()));
				aTexts.push(oBundle.getText("priceFilterTitle", [oSlider.getValue(), oSlider.getValue2()]));
			}

			const oSortItem = oEvent.getParameter("sortItem");
			this._oSorter = new Sorter(oSortItem ? oSortItem.getKey() : "Name", oEvent.getParameter("sortDescending"));

			this.byId("categoryInfoToolbar").setVisible(aTexts.length > 0);
			this.byId("categoryInfoToolbarTitle").setText(aTexts.length
				? oBundle.getText("filterByText") + " " + aTexts.join(", ")
				: "");
			this._applyBinding();
		},

		/**
		 * Opens the filter and sort dialog.
		 */
		onFilter() {
			if (!this._pCategoryFilterDialog) {
				this._pCategoryFilterDialog = Fragment.load({
					id: this.getView().getId(),
					name: "lojaecommerce.view.CategoryFilterDialog",
					controller: this
				}).then((oDialog) => {
					this.getView().addDependent(oDialog);
					oDialog.addStyleClass(this.getOwnerComponent().getContentDensityClass());

					return oDialog;
				});
			}
			this._pCategoryFilterDialog.then((oDialog) => oDialog.open());
		},

		/**
		 * Remembers the slider values after confirming, so that cancel can restore them.
		 * @param {sap.ui.base.Event} oEvent the confirm event of the dialog
		 */
		async handleConfirm(oEvent) {
			const oSlider = this.byId("rangeSlider");

			this._fPriceLow = oSlider.getValue();
			this._fPriceHigh = oSlider.getValue2();
			await this._applyFilter(oEvent);
		},

		/**
		 * Restores the slider values of the last confirmed filter.
		 */
		handleCancel() {
			const oSlider = this.byId("rangeSlider");

			oSlider.setValue(this._fPriceLow).setValue2(this._fPriceHigh);
			this._updatePriceFilterCount();
		},

		handleChange() {
			this._updatePriceFilterCount();
		},

		handleResetFilters() {
			const oSlider = this.byId("rangeSlider");

			oSlider.setValue(oSlider.getMin());
			oSlider.setValue2(oSlider.getMax());
			this._updatePriceFilterCount();
		},

		_updatePriceFilterCount() {
			const oSlider = this.byId("rangeSlider");
			const bChanged = oSlider.getValue() !== oSlider.getMin() || oSlider.getValue2() !== oSlider.getMax();

			this.byId("priceFilterItem").setFilterCount(bChanged ? 1 : 0);
		},

		/**
		 * Opens the comparison of the product with the one already chosen for comparison.
		 * @param {sap.ui.base.Event} oEvent the press event of the link in the list item
		 */
		compareProducts(oEvent) {
			const oProduct = oEvent.getSource().getBindingContext().getObject();
			const oComparison = this.getOwnerComponent().getModel("comparison");
			const sItem1Id = oComparison.getProperty("/item1");
			const sItem2Id = oComparison.getProperty("/item2");

			this._oRouter.navTo("comparison", {
				id: oProduct.Category,
				item1Id: sItem1Id || oProduct.ProductId,
				item2Id: sItem1Id && sItem1Id !== oProduct.ProductId ? oProduct.ProductId : sItem2Id
			}, true);
		},

		/**
		 * Always navigates back to the category overview
		 * @override
		 */
		onBack() {
			this.getRouter().navTo("categories");
		}
	});
});

sap.ui.define([
	"./BaseController",
	"../model/formatter",
	"sap/ui/model/Filter",
	"sap/ui/model/FilterOperator",
	"sap/ui/Device"
], (BaseController, formatter, Filter, FilterOperator, Device) => {
	"use strict";

	return BaseController.extend("lojaecommerce.controller.Home", {
		formatter,

		onInit() {
			this._router = this.getOwnerComponent().getRouter();
			this._router.getRoute("categories").attachMatched(this._onRouteMatched, this);
		},

		_onRouteMatched() {
			if (this.getModel("appView").getProperty("/smallScreenMode")) {
				this._setLayout("One");
			}
		},

		onSearch() {
			this._search();
		},

		async onRefresh() {
			try {
				await this.getOwnerComponent().loadCatalog(true);
			} finally {
				this.byId("pullToRefresh").hide();
			}
		},

		/**
		 * Shows the search result instead of the categories while a search text is entered.
		 * The search looks at name, SKU and description of the product.
		 */
		_search() {
			const sQuery = this.byId("searchField").getValue();
			const bShowSearchResults = sQuery.length !== 0;
			const oBinding = this.byId("productList").getBinding("items");

			this.byId("productList").setVisible(bShowSearchResults);
			this.byId("categoryList").setVisible(!bShowSearchResults);

			if (!oBinding) {
				return;
			}
			if (bShowSearchResults) {
				oBinding.filter([new Filter({
					and: false,
					filters: ["Name", "ProductId", "ShortDescription"]
						.map((sPath) => new Filter(sPath, FilterOperator.Contains, sQuery))
				})]);
			} else {
				oBinding.filter([]);
			}
		},

		onCategoryListItemPress(oEvent) {
			const sCategoryId = oEvent.getSource().getBindingContext().getProperty("Category");

			this._router.navTo("category", {id: sCategoryId});
		},

		onProductListSelect(oEvent) {
			this._showProduct(oEvent.getParameter("listItem"));
		},

		onProductListItemPress(oEvent) {
			this._showProduct(oEvent.getSource());
		},

		_showProduct(oItem) {
			const oEntry = oItem.getBindingContext().getObject();

			this._router.navTo("product", {
				id: oEntry.Category,
				productId: oEntry.ProductId
			}, !Device.system.phone);
		},

		/**
		 * Always navigates back to home
		 * @override
		 */
		onBack() {
			this.getRouter().navTo("home");
		}
	});
});

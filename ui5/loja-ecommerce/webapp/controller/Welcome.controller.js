sap.ui.define([
	"./BaseController",
	"sap/ui/model/json/JSONModel",
	"../model/formatter"
], (BaseController, JSONModel, formatter) => {
	"use strict";

	return BaseController.extend("lojaecommerce.controller.Welcome", {
		_iCarouselTimeout: 0, // a pointer to the current timeout

		_iCarouselLoopTime: 8000, // loop to next page after 8 seconds

		formatter,

		onInit() {
			this.getRouter().attachRouteMatched(this._onRouteMatched, this);

			// start with a random banner
			const oWelcomeCarousel = this.byId("welcomeCarousel");
			const iRandomIndex = Math.floor(Math.random() * oWelcomeCarousel.getPages().length);
			oWelcomeCarousel.setActivePage(oWelcomeCarousel.getPages()[iRandomIndex]);
		},

		onAfterRendering() {
			this.onCarouselPageChanged();
		},

		onExit() {
			clearTimeout(this._iCarouselTimeout);
		},

		_onRouteMatched(oEvent) {
			// always display two columns for home screen
			if (oEvent.getParameter("name") === "home") {
				this._setLayout("Two");
			}
		},

		/**
		 * Clears the previous timer and loops the banners.
		 */
		onCarouselPageChanged() {
			clearTimeout(this._iCarouselTimeout);
			this._iCarouselTimeout = setTimeout(() => {
				const oWelcomeCarousel = this.byId("welcomeCarousel");
				if (oWelcomeCarousel) {
					oWelcomeCarousel.next();
					this.onCarouselPageChanged();
				}
			}, this._iCarouselLoopTime);
		},

		/**
		 * Opens the product whose link or picture was pressed.
		 * @param {sap.ui.base.Event} oEvent the press event
		 */
		onSelectProduct(oEvent) {
			const oProduct = oEvent.getSource().getBindingContext().getObject();

			this.getRouter().navTo("product", {
				id: oProduct.Category,
				productId: oProduct.ProductId
			});
		},

		onShowCategories() {
			this.getRouter().navTo("categories");
		},

		onToggleCart(oEvent) {
			const bPressed = oEvent.getParameter("pressed");

			this._setLayout(bPressed ? "Three" : "Two");
			this.getRouter().navTo(bPressed ? "cart" : "home");
		}
	});
});

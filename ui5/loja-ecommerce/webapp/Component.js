sap.ui.define([
	"sap/ui/core/UIComponent",
	"sap/ui/model/json/JSONModel",
	"./model/LocalStorageModel",
	"./model/models",
	"./model/Catalog",
	"./controller/Account",
	"sap/ui/Device"
], (UIComponent, JSONModel, LocalStorageModel, models, Catalog, Account, Device) => {
	"use strict";

	return UIComponent.extend("lojaecommerce.Component", {
		metadata: {
			interfaces: ["sap.ui.core.IAsyncContentCreation"],
			manifest: "json",
			config: {fullWidth: true}
		},

		/**
		 * Creates the models (catalog, cart, comparison, device) and starts the router.
		 * @override
		 */
		init() {
			// catalog: products and categories read from the stock service (filled by loadCatalog)
			const oCatalogModel = new JSONModel({Products: [], Categories: [], Promoted: [], LastUnits: [], Newest: []});
			oCatalogModel.setSizeLimit(10000);
			this.setModel(oCatalogModel);

			// shopping cart and items saved for later
			this.setModel(new LocalStorageModel("LOJA_SHOPPING_CART", {
				cartEntries: {},
				savedForLaterEntries: {}
			}), "cartProducts");

			// customer of the session (login by CPF + e-mail or phone)
			this.setModel(new LocalStorageModel("LOJA_SESSION", {customer: null}), "session");
			this._oAccount = new Account(this);

			// product comparison
			this.setModel(new LocalStorageModel("LOJA_PRODUCT_COMPARISON", {
				category: "",
				item1: "",
				item2: ""
			}), "comparison");

			this.setModel(models.createDeviceModel(), "device");

			UIComponent.prototype.init.apply(this, arguments);

			this.getRouter().initialize();

			this.getRouter().attachTitleChanged((oEvent) => {
				document.title = oEvent.getParameter("title");
			});
		},

		exit() {
			this._oAccount.destroy();
		},

		/**
		 * @returns {object|null} the customer of the session (ClienteUUID, Cpf, Nome, Cidade, Uf), or null
		 */
		getCustomer() {
			return this.getModel("session").getProperty("/customer");
		},

		setCustomer(oCustomer) {
			this.getModel("session").setProperty("/customer", oCustomer);
		},

		logout() {
			this.setCustomer(null);
		},

		/**
		 * Opens the login dialog (or the account popover, when the customer is logged in).
		 * @param {sap.ui.core.Control} oOpener control the popover opens at
		 * @returns {Promise} resolves when it is open
		 */
		openAccount(oOpener) {
			return this._oAccount.open(oOpener);
		},

		/**
		 * Loads the catalog from the stock service once; the same promise is returned to every caller.
		 * @param {boolean} [bForce] reads the service again (e.g. to check the stock before an order)
		 * @returns {Promise<object>} resolves with the catalog data
		 */
		loadCatalog(bForce) {
			if (!this._pCatalog || bForce) {
				this._pCatalog = Catalog.load(this.getModel("service")).then((oData) => {
					this.getModel().setData({...oData, ...this._createHighlights(oData.Products)});

					return oData;
				});
				// a failed read can be retried by the next call
				this._pCatalog.catch(() => {
					this._pCatalog = null;
				});
			}

			return this._pCatalog;
		},

		/**
		 * Selections shown on the welcome page: two random products in stock (promoted), the products with the
		 * last units and the most recently created ones.
		 * @param {object[]} aProducts catalog products
		 * @returns {object} lists for the welcome page
		 */
		_createHighlights(aProducts) {
			const aBuyable = aProducts.filter((oProduct) => oProduct.Status === "A" || oProduct.Status === "L");
			const aShuffled = [...aBuyable].sort(() => Math.random() - 0.5);

			return {
				Promoted: aShuffled.slice(0, 2),
				LastUnits: aProducts.filter((oProduct) => oProduct.Status === "L").slice(0, 2),
				Newest: [...aBuyable].sort((a, b) => String(b.CreatedAt).localeCompare(String(a.CreatedAt))).slice(0, 2)
			};
		},

		/**
		 * Returns the product with the given id (SKU) from the loaded catalog.
		 * @param {string} sProductId SKU
		 * @returns {object|undefined} product
		 */
		findProduct(sProductId) {
			return this.getModel().getProperty("/Products").find((oProduct) => oProduct.ProductId === sProductId);
		},

		/**
		 * Determines whether the sapUiSizeCompact or sapUiSizeCozy design mode class should be set.
		 * @returns {string} css class, or an empty string if the launchpad has already set one
		 */
		getContentDensityClass() {
			if (this._sContentDensityClass === undefined) {
				if (document.body.classList.contains("sapUiSizeCozy") || document.body.classList.contains("sapUiSizeCompact")) {
					this._sContentDensityClass = "";
				} else if (!Device.support.touch) {
					this._sContentDensityClass = "sapUiSizeCompact";
				} else {
					this._sContentDensityClass = "sapUiSizeCozy";
				}
			}

			return this._sContentDensityClass;
		}
	});
});

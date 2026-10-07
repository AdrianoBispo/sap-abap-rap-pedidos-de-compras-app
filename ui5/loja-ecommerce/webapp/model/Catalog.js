sap.ui.define([
	"sap/ui/model/Filter",
	"sap/ui/model/FilterOperator",
	"sap/ui/model/Sorter"
], (Filter, FilterOperator, Sorter) => {
	"use strict";

	const PAGE_SIZE = 200;

	// colors (gradient) of the generated picture and icon of every category defined in the back-end codelist CATEGORIA
	const mCategoryStyle = {
		ELETRONICOS: {icon: "sap-icon://iphone-2", from: "#0a6ed1", to: "#5b9bd5"},
		INFORMATICA: {icon: "sap-icon://laptop", from: "#6b3fa0", to: "#a077d0"},
		ESCRITORIO: {icon: "sap-icon://business-card", from: "#c25e00", to: "#e9a04f"},
		CASA: {icon: "sap-icon://home", from: "#107e3e", to: "#58b07a"},
		VESTUARIO: {icon: "sap-icon://wallet", from: "#bb0000", to: "#e56a6a"},
		ALIMENTOS: {icon: "sap-icon://meal", from: "#8d5a2b", to: "#c79a6b"},
		OUTROS: {icon: "sap-icon://product", from: "#475e75", to: "#8396a9"}
	};
	const mDefaultStyle = mCategoryStyle.OUTROS;

	const aSelect = ["ItemUUID", "Sku", "Nome", "Descricao", "Categoria", "CategoriaTexto", "QtdeDisponivel",
		"StatusEstoque", "Currency", "PrecoUnitario", "FotoMimeType", "CreatedAt"];

	function styleOf(sCategory) {
		return mCategoryStyle[sCategory] || mDefaultStyle;
	}

	function initialsOf(sName) {
		return sName.split(/\s+/).filter((s) => /^\p{L}/u.test(s)).slice(0, 2)
			.map((s) => s.charAt(0).toUpperCase()).join("");
	}

	/**
	 * Generated picture (SVG data URI) for products that have no photo in the back-end.
	 * @param {string} sName product name
	 * @param {string} sCategory category code
	 * @returns {string} data URI
	 */
	function placeholderPicture(sName, sCategory) {
		const {from, to} = styleOf(sCategory);
		const sSvg = "<svg xmlns='http://www.w3.org/2000/svg' width='400' height='400' viewBox='0 0 400 400'>"
			+ `<defs><linearGradient id='g' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='${from}'/>`
			+ `<stop offset='1' stop-color='${to}'/></linearGradient></defs><rect width='400' height='400' fill='url(#g)'/>`
			+ "<text x='200' y='240' font-family='Arial, Helvetica, sans-serif' font-size='150' font-weight='700' "
			+ `fill='#ffffff' fill-opacity='0.92' text-anchor='middle'>${initialsOf(sName)}</text></svg>`;

		return "data:image/svg+xml;charset=utf-8," + encodeURIComponent(sSvg);
	}

	/**
	 * Availability of the product in the shop:
	 * A = available, L = last units (back-end status ACABANDO), O = out of stock, D = no longer sold.
	 * @param {object} oItem item as read from the stock service
	 * @returns {string} status code
	 */
	function statusOf(oItem) {
		if (oItem.QtdeDisponivel <= 0 || oItem.StatusEstoque === "SEM_ESTOQUE") {
			return "O";
		}

		return oItem.StatusEstoque === "ACABANDO" ? "L" : "A";
	}

	/**
	 * Maps an item of the stock service (ZC_PC_ITEM_APP) to the product shown in the shop.
	 * @param {object} oItem item as read from the stock service
	 * @param {string} sServiceUrl service root URL, ending with "/"
	 * @returns {object} product
	 */
	function toProduct(oItem, sServiceUrl) {
		const bHasPhoto = !!oItem.FotoMimeType;

		return {
			ProductId: oItem.Sku,
			ItemUUID: oItem.ItemUUID,
			Name: oItem.Nome,
			ShortDescription: oItem.Descricao,
			Category: oItem.Categoria,
			CategoryName: oItem.CategoriaTexto || oItem.Categoria,
			Price: parseFloat(oItem.PrecoUnitario),
			CurrencyCode: oItem.Currency,
			Available: oItem.QtdeDisponivel,
			Status: statusOf(oItem),
			CreatedAt: oItem.CreatedAt,
			PictureUrl: bHasPhoto
				? `${sServiceUrl}Item(ItemUUID=${oItem.ItemUUID},IsActiveEntity=true)/FotoItem`
				: placeholderPicture(oItem.Nome, oItem.Categoria)
		};
	}

	function toCategories(aProducts) {
		const mCategories = {};
		aProducts.forEach((oProduct) => {
			const oCategory = mCategories[oProduct.Category]
				|| (mCategories[oProduct.Category] = {
					Category: oProduct.Category,
					CategoryName: oProduct.CategoryName,
					NumberOfProducts: 0,
					Icon: styleOf(oProduct.Category).icon
				});
			oCategory.NumberOfProducts += 1;
		});

		return Object.values(mCategories).sort((a, b) => a.CategoryName.localeCompare(b.CategoryName, "pt-BR"));
	}

	return {
		styleOf,
		statusOf,
		toProduct,
		toCategories,
		placeholderPicture,

		/**
		 * Reads the active, sellable items (ItemAtivo) of the stock service and builds the catalog.
		 * Drafts are skipped (IsActiveEntity). Reads page by page, so the number of items is not limited.
		 * @param {sap.ui.model.odata.v4.ODataModel} oServiceModel model of the ZUI_PC_ESTOQUE_O4 service
		 * @returns {Promise<{Products: object[], Categories: object[]}>} the catalog
		 */
		async load(oServiceModel) {
			const sServiceUrl = oServiceModel.getServiceUrl();
			const oBinding = oServiceModel.bindList("/Item", null, [new Sorter("Nome")], [
				new Filter("IsActiveEntity", FilterOperator.EQ, true),
				new Filter("ItemAtivo", FilterOperator.EQ, true)
			], {$select: aSelect});
			const aItems = [];

			try {
				for (let iStart = 0; ; iStart += PAGE_SIZE) {
					const aContexts = await oBinding.requestContexts(iStart, PAGE_SIZE);
					aContexts.forEach((oContext) => aItems.push(oContext.getObject()));
					if (aContexts.length < PAGE_SIZE) {
						break;
					}
				}
			} finally {
				oBinding.destroy();
			}

			const aProducts = aItems.map((oItem) => toProduct(oItem, sServiceUrl));

			return {Products: aProducts, Categories: toCategories(aProducts)};
		}
	};
});

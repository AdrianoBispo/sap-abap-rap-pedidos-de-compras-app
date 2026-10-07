sap.ui.define([
	"lojaecommerce/model/cart",
	"sap/ui/model/json/JSONModel"
], (cart, JSONModel) => {
	"use strict";

	const oBundle = {getText: (sKey, aArgs) => sKey + (aArgs ? ":" + aArgs.join("|") : "")};
	const oProduct = (mChanges) => ({
		ProductId: "SKU-1", Name: "Mouse", Price: 10, CurrencyCode: "BRL", Available: 2, Status: "A", ...mChanges
	});
	const oModel = () => new JSONModel({cartEntries: {}, savedForLaterEntries: {}});

	QUnit.module("cart - adicionar");

	QUnit.test("adiciona o produto e soma a quantidade", (assert) => {
		const oCart = oModel();

		cart._updateCartItem(oBundle, oProduct(), oCart);
		cart._updateCartItem(oBundle, oProduct(), oCart);

		assert.strictEqual(oCart.getProperty("/cartEntries/SKU-1/Quantity"), 2);
	});

	QUnit.test("a quantidade não passa do estoque disponível", (assert) => {
		const oCart = oModel();

		cart._updateCartItem(oBundle, oProduct(), oCart);
		cart._updateCartItem(oBundle, oProduct(), oCart);
		cart._updateCartItem(oBundle, oProduct(), oCart);

		assert.strictEqual(oCart.getProperty("/cartEntries/SKU-1/Quantity"), 2, "continua no limite");
	});

	QUnit.test("produto sem estoque não entra no carrinho", async (assert) => {
		const oCart = oModel();

		// the message box is only opened for products that cannot be bought; here the cart must stay empty
		const oOpen = sap.ui.require("sap/m/MessageBox");
		const fnShow = oOpen.show;
		let bShown = false;
		oOpen.show = () => {
			bShown = true;
		};
		await cart.addToCart(Promise.resolve(oBundle), oProduct({Status: "O", Available: 0}), oCart);
		oOpen.show = fnShow;

		assert.ok(bShown, "avisa o cliente");
		assert.deepEqual(oCart.getProperty("/cartEntries"), {});
	});

	QUnit.module("cart - quantidade");

	QUnit.test("corrige quantidade menor que 1 e acima do estoque", (assert) => {
		const oCart = oModel();
		cart._updateCartItem(oBundle, oProduct({Available: 5}), oCart);

		cart.setQuantity(oCart, "SKU-1", 0);
		assert.strictEqual(oCart.getProperty("/cartEntries/SKU-1/Quantity"), 1);

		cart.setQuantity(oCart, "SKU-1", 99);
		assert.strictEqual(oCart.getProperty("/cartEntries/SKU-1/Quantity"), 5);
	});

	QUnit.module("cart - conferência com o catálogo");

	QUnit.test("remove item sem estoque ou fora do catálogo, ajusta quantidade e preço", (assert) => {
		const oCart = oModel();
		oCart.setProperty("/cartEntries", {
			"SKU-1": oProduct({Quantity: 3}),
			"SKU-2": oProduct({ProductId: "SKU-2", Name: "Teclado", Quantity: 1}),
			"SKU-3": oProduct({ProductId: "SKU-3", Name: "Monitor", Quantity: 1}),
			"SKU-4": oProduct({ProductId: "SKU-4", Name: "Webcam", Quantity: 1})
		});
		const aProblems = cart.syncWithCatalog(oCart, [
			oProduct({Available: 2}), // quantidade 3 > 2
			oProduct({ProductId: "SKU-2", Name: "Teclado", Available: 0, Status: "O"}), // sem estoque
			oProduct({ProductId: "SKU-4", Name: "Webcam", Price: 12}) // preço mudou
		], oBundle);

		assert.strictEqual(aProblems.length, 4, "um aviso por problema");
		assert.deepEqual(Object.keys(oCart.getProperty("/cartEntries")).sort(), ["SKU-1", "SKU-4"]);
		assert.strictEqual(oCart.getProperty("/cartEntries/SKU-1/Quantity"), 2, "quantidade ajustada");
		assert.strictEqual(oCart.getProperty("/cartEntries/SKU-4/Price"), 12, "preço atualizado");
	});

	QUnit.test("carrinho sem problemas não gera avisos", (assert) => {
		const oCart = oModel();
		oCart.setProperty("/cartEntries", {"SKU-1": oProduct({Quantity: 1})});

		assert.deepEqual(cart.syncWithCatalog(oCart, [oProduct()], oBundle), []);
	});
});

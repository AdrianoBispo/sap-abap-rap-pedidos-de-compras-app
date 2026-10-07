sap.ui.define([
	"lojaecommerce/model/formatter"
], (formatter) => {
	"use strict";

	QUnit.module("formatter");

	QUnit.test("preço no formato pt-BR", (assert) => {
		assert.strictEqual(formatter.price(3499.9), "3.499,90");
		assert.strictEqual(formatter.price("89.9"), "89,90");
	});

	QUnit.test("total e quantidade do carrinho", (assert) => {
		const oEntries = {a: {Price: 10, Quantity: 2}, b: {Price: 5.5, Quantity: 1}};

		assert.strictEqual(formatter.totalValue(oEntries), 25.5);
		assert.strictEqual(formatter.lineTotal(10, 2), "20,00");
		assert.strictEqual(formatter.cartCount(oEntries), "3");
		assert.strictEqual(formatter.cartCount({}), "", "carrinho vazio não mostra selo");
	});

	QUnit.test("status e disponibilidade", (assert) => {
		assert.strictEqual(formatter.statusState("A"), "Success");
		assert.strictEqual(formatter.statusState("L"), "Warning");
		assert.strictEqual(formatter.statusState("O"), "Error");
		assert.ok(formatter.isBuyable("A") && formatter.isBuyable("L"));
		assert.notOk(formatter.isBuyable("O"));
	});

	QUnit.test("hasItems", (assert) => {
		assert.ok(formatter.hasItems({a: 1}, {}));
		assert.notOk(formatter.hasItems({}, undefined));
	});
});

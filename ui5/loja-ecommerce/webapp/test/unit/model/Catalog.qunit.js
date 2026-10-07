sap.ui.define([
	"lojaecommerce/model/Catalog"
], (Catalog) => {
	"use strict";

	const oItem = (mChanges) => ({
		ItemUUID: "5a1b0000-0000-0000-0000-000000000001",
		Sku: "SKU-INF-5000000001",
		Nome: "Mouse sem fio Básico",
		Descricao: "Mouse óptico sem fio",
		Categoria: "INFORMATICA",
		CategoriaTexto: "Informática",
		QtdeDisponivel: 40,
		StatusEstoque: "EM_ESTOQUE",
		Currency: "BRL",
		PrecoUnitario: "89.90",
		FotoMimeType: "",
		CreatedAt: "2026-10-01T09:00:00Z",
		...mChanges
	});

	QUnit.module("Catalog - status");

	QUnit.test("status vem do status de estoque do back-end", (assert) => {
		assert.strictEqual(Catalog.statusOf(oItem()), "A", "em estoque");
		assert.strictEqual(Catalog.statusOf(oItem({StatusEstoque: "ACABANDO", QtdeDisponivel: 5})), "L", "acabando");
		assert.strictEqual(Catalog.statusOf(oItem({StatusEstoque: "SEM_ESTOQUE", QtdeDisponivel: 0})), "O", "sem estoque");
	});

	QUnit.test("quantidade zero é sem estoque mesmo com status desatualizado", (assert) => {
		assert.strictEqual(Catalog.statusOf(oItem({QtdeDisponivel: 0})), "O");
	});

	QUnit.module("Catalog - produto");

	QUnit.test("mapeia o item do serviço de estoque", (assert) => {
		const oProduct = Catalog.toProduct(oItem(), "/service/");

		assert.strictEqual(oProduct.ProductId, "SKU-INF-5000000001", "o SKU é o id do produto");
		assert.strictEqual(oProduct.Name, "Mouse sem fio Básico");
		assert.strictEqual(oProduct.Price, 89.9, "preço como número");
		assert.strictEqual(oProduct.CurrencyCode, "BRL");
		assert.strictEqual(oProduct.Available, 40);
		assert.strictEqual(oProduct.CategoryName, "Informática");
	});

	QUnit.test("sem foto no back-end usa a imagem gerada", (assert) => {
		const oProduct = Catalog.toProduct(oItem(), "/service/");

		assert.ok(oProduct.PictureUrl.startsWith("data:image/svg+xml"), "imagem gerada");
		assert.ok(decodeURIComponent(oProduct.PictureUrl).includes(">MS<"), "iniciais do nome");
	});

	QUnit.test("com foto no back-end aponta para o stream do item ativo", (assert) => {
		const oProduct = Catalog.toProduct(oItem({FotoMimeType: "image/png"}), "/service/");

		assert.strictEqual(oProduct.PictureUrl,
			"/service/Item(ItemUUID=5a1b0000-0000-0000-0000-000000000001,IsActiveEntity=true)/FotoItem");
	});

	QUnit.module("Catalog - categorias");

	QUnit.test("conta os produtos por categoria e ordena pelo nome", (assert) => {
		const aProducts = [
			Catalog.toProduct(oItem(), "/s/"),
			Catalog.toProduct(oItem({Sku: "SKU-INF-2"}), "/s/"),
			Catalog.toProduct(oItem({Sku: "SKU-CAS-1", Categoria: "CASA", CategoriaTexto: "Casa e decoração"}), "/s/")
		];
		const aCategories = Catalog.toCategories(aProducts);

		assert.deepEqual(aCategories.map((o) => [o.Category, o.NumberOfProducts]), [["CASA", 1], ["INFORMATICA", 2]]);
		assert.ok(aCategories[0].Icon.startsWith("sap-icon://"), "ícone da categoria");
	});
});

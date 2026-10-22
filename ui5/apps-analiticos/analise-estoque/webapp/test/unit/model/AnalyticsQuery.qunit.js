/*global QUnit*/
sap.ui.define([
    "analiseestoque/model/AnalyticsQuery",
    "analiseestoque/model/Scenarios"
], function (AnalyticsQuery, Scenarios) {
    "use strict";

    var fnText = function (sKey) { return "T:" + sKey; };

    QUnit.module("AnalyticsQuery - consultas");

    QUnit.test("cenário com duas medidas agrega as duas", function (assert) {
        var oQuery = AnalyticsQuery.buildScenarioQuery(Scenarios.getScenario("EstDisponivelPorCategoria"), {});
        assert.strictEqual(oQuery.entitySet, "ItemAnalise");
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate), ["QtdeReservada", "QtdeDisponivel"]);
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["Categoria", "CategoriaTexto"]);
        assert.deepEqual(oQuery.filters, []);
    });

    QUnit.test("valor em estoque não agrupa por Currency", function (assert) {
        var oQuery = AnalyticsQuery.buildScenarioQuery(Scenarios.getScenario("EstValorPorCategoria"), {});
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["Categoria", "CategoriaTexto"]);
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate), ["ValorEstoque"]);
    });

    QUnit.test("KPIs: aggregate sem dimensão", function (assert) {
        var oQuery = AnalyticsQuery.buildKpiQuery(Scenarios.domain, {});
        assert.strictEqual(oQuery.entitySet, "ItemAnalise");
        assert.deepEqual(oQuery.aggregation.group, {});
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate),
            ["QtdeItens", "QtdeEstoque", "QtdeReservada", "QtdeDisponivel", "ValorEstoque"]);
    });

    QUnit.test("valores de filtro: grupo do campo com o texto", function (assert) {
        var oDomain = Scenarios.domain;
        var oQuery = AnalyticsQuery.buildFilterValuesQuery(oDomain, oDomain.filters[1]);
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["StatusEstoque", "StatusEstoqueTexto"]);
        assert.deepEqual(oQuery.filters, []);
    });

    QUnit.module("AnalyticsQuery - filtros");

    QUnit.test("list e search", function (assert) {
        var aDefs = Scenarios.domain.filters;
        var aFilters = AnalyticsQuery.buildFilters({ Categoria: ["LIVROS", "ELETRONICOS"], Sku: " ELE " }, aDefs);
        assert.deepEqual(aFilters, [
            { path: "Categoria", operator: "EQ", values: ["LIVROS", "ELETRONICOS"] },
            { path: "Sku", operator: "Contains", values: ["ELE"] }
        ]);
        assert.deepEqual(AnalyticsQuery.buildFilters({ Categoria: [], Nome: "  " }, aDefs), []);
        assert.deepEqual(AnalyticsQuery.buildFilters(undefined, aDefs), []);
    });

    QUnit.test("campos que não são filtros da app são ignorados", function (assert) {
        assert.deepEqual(AnalyticsQuery.buildFilters({ Uf: ["SP"] }, Scenarios.domain.filters), []);
    });

    QUnit.module("AnalyticsQuery - linhas");

    QUnit.test("texto da dimensão: descrição e vazio", function (assert) {
        assert.strictEqual(AnalyticsQuery.dimensionText("Categoria", { Categoria: "LIVROS", CategoriaTexto: "Livros" }, fnText), "Livros");
        assert.strictEqual(AnalyticsQuery.dimensionText("Categoria", { Categoria: "LIVROS", CategoriaTexto: "" }, fnText), "LIVROS");
        assert.strictEqual(AnalyticsQuery.dimensionText("Nome", { Nome: null }, fnText), "-");
    });

    QUnit.test("shapeRows limita ao top do cenário", function (assert) {
        var aRaw = [];
        for (var i = 1; i <= 15; i++) {
            aRaw.push({ Nome: "Item " + i, QtdeReservada: i });
        }
        var aRows = AnalyticsQuery.shapeRows(Scenarios.getScenario("EstMaisReservados"), aRaw, fnText);
        assert.strictEqual(aRows.length, 10);
        assert.strictEqual(aRows[0].label, "Item 15");
        assert.strictEqual(aRows[9].label, "Item 6");
    });

    QUnit.test("shapeRows ordena o estoque por Disponível, não pela 1ª medida", function (assert) {
        var aRows = AnalyticsQuery.shapeRows(Scenarios.getScenario("EstDisponivelPorCategoria"), [
            { Categoria: "A", CategoriaTexto: "A", QtdeReservada: 100, QtdeDisponivel: 1 },
            { Categoria: "B", CategoriaTexto: "B", QtdeReservada: 1, QtdeDisponivel: 50 }
        ], fnText);
        assert.deepEqual(aRows.map(function (o) { return o.key; }), ["B", "A"]);
    });

    QUnit.test("shapeRows soma linhas da mesma chave", function (assert) {
        var aRows = AnalyticsQuery.shapeRows(Scenarios.getScenario("EstValorPorCategoria"), [
            { Categoria: "LIVROS", CategoriaTexto: "Livros", ValorEstoque: "10.25" },
            { Categoria: "LIVROS", CategoriaTexto: "Livros", ValorEstoque: 4.75 }
        ], fnText);
        assert.strictEqual(aRows.length, 1);
        assert.strictEqual(aRows[0].values.ValorEstoque, 15);
    });

    QUnit.test("shapeRows sem dados devolve lista vazia", function (assert) {
        assert.deepEqual(AnalyticsQuery.shapeRows(Scenarios.getScenario("EstItensPorCategoria"), undefined, fnText), []);
    });

    QUnit.test("shapeKpis soma as linhas", function (assert) {
        var oKpis = AnalyticsQuery.shapeKpis(Scenarios.domain, [
            { QtdeItens: 3, QtdeEstoque: 30, QtdeReservada: 5, QtdeDisponivel: 25, ValorEstoque: "999.90" }
        ]);
        assert.deepEqual(oKpis.values, { QtdeItens: 3, QtdeEstoque: 30, QtdeReservada: 5, QtdeDisponivel: 25, ValorEstoque: 999.9 });
        var oEmpty = AnalyticsQuery.shapeKpis(Scenarios.domain, []);
        assert.deepEqual(oEmpty.values, { QtdeItens: 0, QtdeEstoque: 0, QtdeReservada: 0, QtdeDisponivel: 0, ValorEstoque: 0 });
    });

    QUnit.test("opções de filtro: ordenadas pelo texto", function (assert) {
        var aStatus = AnalyticsQuery.shapeFilterValues({ field: "StatusEstoque", type: "list" }, [
            { StatusEstoque: "SEM_ESTOQUE", StatusEstoqueTexto: "Sem estoque" },
            { StatusEstoque: "EM_ESTOQUE", StatusEstoqueTexto: "Em estoque" }
        ], fnText);
        assert.deepEqual(aStatus.map(function (o) { return o.key; }), ["EM_ESTOQUE", "SEM_ESTOQUE"]);
    });
});

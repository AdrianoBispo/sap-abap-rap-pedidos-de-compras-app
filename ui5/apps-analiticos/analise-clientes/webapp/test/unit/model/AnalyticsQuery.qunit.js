/*global QUnit*/
sap.ui.define([
    "analiseclientes/model/AnalyticsQuery",
    "analiseclientes/model/Scenarios"
], function (AnalyticsQuery, Scenarios) {
    "use strict";

    var fnText = function (sKey) { return "T:" + sKey; };

    QUnit.module("AnalyticsQuery - consultas");

    QUnit.test("cenário agrupa por dimensão e texto, sem Currency", function (assert) {
        var oQuery = AnalyticsQuery.buildScenarioQuery(Scenarios.getScenario("CliPorGenero"), {});
        assert.strictEqual(oQuery.entitySet, "ClienteAnalise");
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["Genero", "GeneroTexto"]);
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate), ["QtdeClientes"]);
        assert.deepEqual(oQuery.filters, []);
    });

    QUnit.test("cenário de média agrega o score", function (assert) {
        var oQuery = AnalyticsQuery.buildScenarioQuery(Scenarios.getScenario("CliScorePorUf"), {});
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["Uf"]);
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate), ["ScoreMedio"]);
    });

    QUnit.test("KPIs: aggregate sem dimensão e sem moeda", function (assert) {
        var oQuery = AnalyticsQuery.buildKpiQuery(Scenarios.domain, {});
        assert.strictEqual(oQuery.entitySet, "ClienteAnalise");
        assert.deepEqual(oQuery.aggregation.group, {});
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate), ["QtdeClientes", "ScoreMedio"]);
    });

    QUnit.test("valores de filtro: grupo do campo com o texto", function (assert) {
        var oDomain = Scenarios.domain;
        var oQuery = AnalyticsQuery.buildFilterValuesQuery(oDomain, oDomain.filters[0]);
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["Genero", "GeneroTexto"]);
        assert.deepEqual(oQuery.filters, []);
    });

    QUnit.module("AnalyticsQuery - filtros");

    QUnit.test("list vira OR dentro do campo; vazio não filtra", function (assert) {
        var aDefs = Scenarios.domain.filters;
        var aFilters = AnalyticsQuery.buildFilters({ Genero: ["F", "M"], Uf: [] }, aDefs);
        assert.deepEqual(aFilters, [{ path: "Genero", operator: "EQ", values: ["F", "M"] }]);
        assert.deepEqual(AnalyticsQuery.buildFilters(undefined, aDefs), []);
    });

    QUnit.test("boolean e search", function (assert) {
        var aDefs = Scenarios.domain.filters;
        var aFilters = AnalyticsQuery.buildFilters({ ClienteAtivo: "false", Nome: "  ana " }, aDefs);
        assert.deepEqual(aFilters, [
            { path: "ClienteAtivo", operator: "EQ", values: [false] },
            { path: "Nome", operator: "Contains", values: ["ana"] }
        ]);
        assert.deepEqual(AnalyticsQuery.buildFilters({ ClienteAtivo: "", Nome: "   " }, aDefs), []);
    });

    QUnit.test("campos que não são filtros da app são ignorados", function (assert) {
        assert.deepEqual(AnalyticsQuery.buildFilters({ StatusPedido: ["ABERTO"] }, Scenarios.domain.filters), []);
    });

    QUnit.module("AnalyticsQuery - linhas");

    QUnit.test("texto da dimensão: descrição, mês, faixa, sim/não e vazio", function (assert) {
        assert.strictEqual(AnalyticsQuery.dimensionText("Genero", { Genero: "F", GeneroTexto: "Feminino" }, fnText), "Feminino");
        assert.strictEqual(AnalyticsQuery.dimensionText("MesCadastro", { MesCadastro: "202610" }, fnText), "10/2026");
        assert.strictEqual(AnalyticsQuery.dimensionText("FaixaScore", { FaixaScore: "ALTO" }, fnText), "T:faixaALTO");
        assert.strictEqual(AnalyticsQuery.dimensionText("ClienteAtivo", { ClienteAtivo: false }, fnText), "T:no");
        assert.strictEqual(AnalyticsQuery.dimensionText("Uf", { Uf: "" }, fnText), "-");
    });

    QUnit.test("shapeRows ordena por medida decrescente", function (assert) {
        var aRows = AnalyticsQuery.shapeRows(Scenarios.getScenario("CliPorUf"), [
            { Uf: "RJ", QtdeClientes: 3 },
            { Uf: "SP", QtdeClientes: 9 },
            { Uf: "MG", QtdeClientes: 5 }
        ], fnText);
        assert.deepEqual(aRows.map(function (o) { return o.key; }), ["SP", "MG", "RJ"]);
    });

    QUnit.test("shapeRows ordena meses cronologicamente", function (assert) {
        var aRows = AnalyticsQuery.shapeRows(Scenarios.getScenario("CliCadastrosPorMes"), [
            { MesCadastro: "202611", QtdeClientes: 2 },
            { MesCadastro: "202510", QtdeClientes: 9 },
            { MesCadastro: "202610", QtdeClientes: 5 }
        ], fnText);
        assert.deepEqual(aRows.map(function (o) { return o.label; }), ["10/2025", "10/2026", "11/2026"]);
    });

    QUnit.test("shapeRows tira a média do score ao juntar linhas da mesma chave", function (assert) {
        var aRows = AnalyticsQuery.shapeRows(Scenarios.getScenario("CliScorePorUf"), [
            { Uf: "SP", ScoreMedio: "40" },
            { Uf: "SP", ScoreMedio: "60" }
        ], fnText);
        assert.strictEqual(aRows.length, 1);
        assert.strictEqual(aRows[0].values.ScoreMedio, 50);
    });

    QUnit.test("shapeRows sem dados devolve lista vazia", function (assert) {
        assert.deepEqual(AnalyticsQuery.shapeRows(Scenarios.getScenario("CliPorGenero"), undefined, fnText), []);
    });

    QUnit.test("shapeKpis sem moeda; vazio zera os totais", function (assert) {
        var oKpis = AnalyticsQuery.shapeKpis(Scenarios.domain, [{ QtdeClientes: 12, ScoreMedio: "55.5" }]);
        assert.deepEqual(oKpis.values, { QtdeClientes: 12, ScoreMedio: 55.5 });
        assert.strictEqual(oKpis.currency, "");
        var oEmpty = AnalyticsQuery.shapeKpis(Scenarios.domain, []);
        assert.deepEqual(oEmpty.values, { QtdeClientes: 0, ScoreMedio: 0 });
    });

    QUnit.test("opções de filtro: faixas pelo texto traduzido", function (assert) {
        var aFaixas = AnalyticsQuery.shapeFilterValues({ field: "FaixaScore", type: "list" }, [
            { FaixaScore: "MEDIO" }, { FaixaScore: "ALTO" }, { FaixaScore: "BAIXO" }
        ], fnText);
        assert.deepEqual(aFaixas.map(function (o) { return o.text; }), ["T:faixaALTO", "T:faixaBAIXO", "T:faixaMEDIO"]);
        assert.deepEqual(aFaixas.map(function (o) { return o.key; }), ["ALTO", "BAIXO", "MEDIO"]);
    });
});

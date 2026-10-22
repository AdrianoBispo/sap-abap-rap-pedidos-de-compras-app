/*global QUnit*/
sap.ui.define([
    "analisereembolsos/model/AnalyticsQuery",
    "analisereembolsos/model/Scenarios"
], function (AnalyticsQuery, Scenarios) {
    "use strict";

    var fnText = function (sKey) { return "T:" + sKey; };

    QUnit.module("AnalyticsQuery - consultas");

    QUnit.test("cenário com medida monetária agrupa por dimensão, texto e Currency", function (assert) {
        var oQuery = AnalyticsQuery.buildScenarioQuery(Scenarios.getScenario("ReeValorPorStatus"), {});
        assert.strictEqual(oQuery.entitySet, "ReembolsoAnalise");
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["StatusReembolso", "StatusReembolsoTexto", "Currency"]);
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate), ["ValorReembolso"]);
        assert.deepEqual(oQuery.filters, []);
    });

    QUnit.test("cenário de quantidade não agrupa por Currency", function (assert) {
        var oQuery = AnalyticsQuery.buildScenarioQuery(Scenarios.getScenario("ReePorMotivo"), {});
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["MotivoSolicitacao"]);
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate), ["QtdeReembolsos"]);
    });

    QUnit.test("KPIs: aggregate sem dimensão, por moeda", function (assert) {
        var oQuery = AnalyticsQuery.buildKpiQuery(Scenarios.domain, { StatusReembolso: ["PENDENTE"] });
        assert.strictEqual(oQuery.entitySet, "ReembolsoAnalise");
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["Currency"]);
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate), ["QtdeReembolsos", "ValorReembolso"]);
        assert.deepEqual(oQuery.filters, [{ path: "StatusReembolso", operator: "EQ", values: ["PENDENTE"] }]);
    });

    QUnit.test("valores de filtro: grupo do campo com o texto", function (assert) {
        var oDomain = Scenarios.domain;
        var oQuery = AnalyticsQuery.buildFilterValuesQuery(oDomain, oDomain.filters[0]);
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["StatusReembolso", "StatusReembolsoTexto"]);
        assert.deepEqual(oQuery.filters, []);
    });

    QUnit.module("AnalyticsQuery - filtros");

    QUnit.test("list vira OR dentro do campo; AND entre campos", function (assert) {
        var aDefs = Scenarios.domain.filters;
        var aFilters = AnalyticsQuery.buildFilters({ StatusReembolso: ["APROVADO", "REJEITADO"], Uf: ["SP"], MesSolicitacao: [] }, aDefs);
        assert.deepEqual(aFilters, [
            { path: "StatusReembolso", operator: "EQ", values: ["APROVADO", "REJEITADO"] },
            { path: "Uf", operator: "EQ", values: ["SP"] }
        ]);
        assert.deepEqual(AnalyticsQuery.buildFilters(undefined, aDefs), []);
    });

    QUnit.test("campos que não são filtros da app são ignorados", function (assert) {
        assert.deepEqual(AnalyticsQuery.buildFilters({ Genero: ["F"] }, Scenarios.domain.filters), []);
    });

    QUnit.module("AnalyticsQuery - linhas");

    QUnit.test("texto da dimensão: descrição, mês, texto livre e vazio", function (assert) {
        assert.strictEqual(AnalyticsQuery.dimensionText("StatusReembolso", { StatusReembolso: "PENDENTE", StatusReembolsoTexto: "Pendente" }, fnText), "Pendente");
        assert.strictEqual(AnalyticsQuery.dimensionText("MesSolicitacao", { MesSolicitacao: "202607" }, fnText), "07/2026");
        assert.strictEqual(AnalyticsQuery.dimensionText("MotivoSolicitacao", { MotivoSolicitacao: "Produto com defeito" }, fnText), "Produto com defeito");
        assert.strictEqual(AnalyticsQuery.dimensionText("MotivoSolicitacao", { MotivoSolicitacao: "" }, fnText), "-");
    });

    QUnit.test("shapeRows ordena meses cronologicamente", function (assert) {
        var aRows = AnalyticsQuery.shapeRows(Scenarios.getScenario("ReeValorPorMes"), [
            { MesSolicitacao: "202611", ValorReembolso: 2, Currency: "BRL" },
            { MesSolicitacao: "202510", ValorReembolso: 9, Currency: "BRL" },
            { MesSolicitacao: "202610", ValorReembolso: 5, Currency: "BRL" }
        ], fnText);
        assert.deepEqual(aRows.map(function (o) { return o.label; }), ["10/2025", "10/2026", "11/2026"]);
    });

    QUnit.test("shapeRows soma moedas diferentes da mesma chave e ordena por valor", function (assert) {
        var aRows = AnalyticsQuery.shapeRows(Scenarios.getScenario("ReeValorPorUf"), [
            { Uf: "RJ", ValorReembolso: "10.50", Currency: "BRL" },
            { Uf: "SP", ValorReembolso: "5", Currency: "BRL" },
            { Uf: "SP", ValorReembolso: "7", Currency: "USD" }
        ], fnText);
        assert.deepEqual(aRows.map(function (o) { return o.key; }), ["SP", "RJ"]);
        assert.strictEqual(aRows[0].values.ValorReembolso, 12);
        assert.strictEqual(aRows[0].currency, "BRL");
    });

    QUnit.test("shapeRows sem dados devolve lista vazia", function (assert) {
        assert.deepEqual(AnalyticsQuery.shapeRows(Scenarios.getScenario("ReeQtdePorStatus"), undefined, fnText), []);
    });

    QUnit.test("shapeKpis soma entre moedas e usa a primeira moeda", function (assert) {
        var oKpis = AnalyticsQuery.shapeKpis(Scenarios.domain, [
            { QtdeReembolsos: 2, ValorReembolso: "100", Currency: "BRL" },
            { QtdeReembolsos: 1, ValorReembolso: "50", Currency: "USD" }
        ]);
        assert.deepEqual(oKpis.values, { QtdeReembolsos: 3, ValorReembolso: 150 });
        assert.strictEqual(oKpis.currency, "BRL");
        var oEmpty = AnalyticsQuery.shapeKpis(Scenarios.domain, []);
        assert.deepEqual(oEmpty.values, { QtdeReembolsos: 0, ValorReembolso: 0 });
    });

    QUnit.test("opções de filtro: meses cronológicos, demais por texto", function (assert) {
        var aMonths = AnalyticsQuery.shapeFilterValues({ field: "MesSolicitacao", type: "list" }, [
            { MesSolicitacao: "202701" }, { MesSolicitacao: "202612" }
        ], fnText);
        assert.deepEqual(aMonths.map(function (o) { return o.key; }), ["202612", "202701"]);
        var aUf = AnalyticsQuery.shapeFilterValues({ field: "Uf", type: "list" }, [{ Uf: "SP" }, { Uf: "BA" }], fnText);
        assert.deepEqual(aUf.map(function (o) { return o.text; }), ["BA", "SP"]);
    });
});

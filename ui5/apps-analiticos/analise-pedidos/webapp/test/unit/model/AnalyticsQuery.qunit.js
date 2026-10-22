/*global QUnit*/
sap.ui.define([
    "analisepedidos/model/AnalyticsQuery",
    "analisepedidos/model/Scenarios"
], function (AnalyticsQuery, Scenarios) {
    "use strict";

    var fnText = function (sKey) { return "T:" + sKey; };

    QUnit.module("AnalyticsQuery - consultas");

    QUnit.test("cenário com medida monetária agrupa por dimensão, texto e Currency", function (assert) {
        var oQuery = AnalyticsQuery.buildScenarioQuery(Scenarios.getScenario("PedValorPorStatus"), {});
        assert.strictEqual(oQuery.entitySet, "PedidoAnalise");
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["StatusPedido", "StatusPedidoTexto", "Currency"]);
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate), ["ValorTotal"]);
        assert.deepEqual(oQuery.filters, []);
    });

    QUnit.test("cenário de quantidade não agrupa por Currency", function (assert) {
        var oQuery = AnalyticsQuery.buildScenarioQuery(Scenarios.getScenario("PedPorMes"), {});
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["MesCriacao"]);
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate), ["QtdePedidos"]);
    });

    QUnit.test("cenário aplica os filtros escolhidos", function (assert) {
        var oQuery = AnalyticsQuery.buildScenarioQuery(Scenarios.getScenario("PedValorPorUf"), { Uf: ["SP"] });
        assert.deepEqual(oQuery.filters, [{ path: "Uf", operator: "EQ", values: ["SP"] }]);
    });

    QUnit.test("KPIs: aggregate sem dimensão, por moeda", function (assert) {
        var oQuery = AnalyticsQuery.buildKpiQuery(Scenarios.domain, {});
        assert.strictEqual(oQuery.entitySet, "PedidoAnalise");
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["Currency"]);
        assert.deepEqual(Object.keys(oQuery.aggregation.aggregate), ["ValorTotal", "QtdePedidos", "ValorMedio"]);
    });

    QUnit.test("valores de filtro: grupo do campo com o texto", function (assert) {
        var oDomain = Scenarios.domain;
        var oQuery = AnalyticsQuery.buildFilterValuesQuery(oDomain, oDomain.filters[0]);
        assert.deepEqual(Object.keys(oQuery.aggregation.group), ["StatusPedido", "StatusPedidoTexto"]);
        assert.deepEqual(oQuery.filters, []);
    });

    QUnit.module("AnalyticsQuery - filtros");

    QUnit.test("list vira OR dentro do campo; vazio não filtra", function (assert) {
        var aDefs = Scenarios.domain.filters;
        var aFilters = AnalyticsQuery.buildFilters({ StatusPedido: ["ABERTO", "CANCELADO"], Uf: [] }, aDefs);
        assert.deepEqual(aFilters, [{ path: "StatusPedido", operator: "EQ", values: ["ABERTO", "CANCELADO"] }]);
        assert.deepEqual(AnalyticsQuery.buildFilters(undefined, aDefs), []);
    });

    QUnit.test("campos que não são filtros da app são ignorados", function (assert) {
        assert.deepEqual(AnalyticsQuery.buildFilters({ Genero: ["F"] }, Scenarios.domain.filters), []);
    });

    QUnit.module("AnalyticsQuery - linhas");

    QUnit.test("texto da dimensão: descrição, mês e vazio", function (assert) {
        assert.strictEqual(AnalyticsQuery.dimensionText("StatusPedido", { StatusPedido: "ABERTO", StatusPedidoTexto: "Aberto" }, fnText), "Aberto");
        assert.strictEqual(AnalyticsQuery.dimensionText("MesCriacao", { MesCriacao: "202610" }, fnText), "10/2026");
        assert.strictEqual(AnalyticsQuery.dimensionText("Uf", { Uf: "" }, fnText), "-");
        assert.strictEqual(AnalyticsQuery.dimensionText("Uf", { Uf: "SP" }, fnText), "SP");
    });

    QUnit.test("shapeRows ordena por medida decrescente", function (assert) {
        var aRows = AnalyticsQuery.shapeRows(Scenarios.getScenario("PedValorPorUf"), [
            { Uf: "RJ", ValorTotal: "10.50", Currency: "BRL" },
            { Uf: "SP", ValorTotal: "99", Currency: "BRL" },
            { Uf: "MG", ValorTotal: 30, Currency: "BRL" }
        ], fnText);
        assert.deepEqual(aRows.map(function (o) { return o.key; }), ["SP", "MG", "RJ"]);
        assert.strictEqual(aRows[2].values.ValorTotal, 10.5, "decimal vem como string");
        assert.strictEqual(aRows[0].currency, "BRL");
    });

    QUnit.test("shapeRows ordena meses cronologicamente", function (assert) {
        var aRows = AnalyticsQuery.shapeRows(Scenarios.getScenario("PedPorMes"), [
            { MesCriacao: "202611", QtdePedidos: 2 },
            { MesCriacao: "202510", QtdePedidos: 9 },
            { MesCriacao: "202610", QtdePedidos: 5 }
        ], fnText);
        assert.deepEqual(aRows.map(function (o) { return o.label; }), ["10/2025", "10/2026", "11/2026"]);
    });

    QUnit.test("shapeRows soma linhas da mesma chave (moedas diferentes) e tira a média das médias", function (assert) {
        var aSum = AnalyticsQuery.shapeRows(Scenarios.getScenario("PedValorPorStatus"), [
            { StatusPedido: "ABERTO", StatusPedidoTexto: "Aberto", ValorTotal: 10, Currency: "BRL" },
            { StatusPedido: "ABERTO", StatusPedidoTexto: "Aberto", ValorTotal: 5, Currency: "USD" }
        ], fnText);
        assert.strictEqual(aSum.length, 1);
        assert.strictEqual(aSum[0].values.ValorTotal, 15);

        var aAvg = AnalyticsQuery.shapeRows(Scenarios.getScenario("PedTicketMedio"), [
            { StatusPedido: "ABERTO", StatusPedidoTexto: "Aberto", ValorMedio: 10, Currency: "BRL" },
            { StatusPedido: "ABERTO", StatusPedidoTexto: "Aberto", ValorMedio: 20, Currency: "USD" }
        ], fnText);
        assert.strictEqual(aAvg[0].values.ValorMedio, 15);
    });

    QUnit.test("shapeRows sem dados devolve lista vazia", function (assert) {
        assert.deepEqual(AnalyticsQuery.shapeRows(Scenarios.getScenario("PedPorMes"), undefined, fnText), []);
    });

    QUnit.test("shapeKpis soma entre moedas e usa a primeira moeda", function (assert) {
        var oKpis = AnalyticsQuery.shapeKpis(Scenarios.domain, [
            { ValorTotal: "100", QtdePedidos: 2, ValorMedio: "50", Currency: "BRL" }
        ]);
        assert.deepEqual(oKpis.values, { ValorTotal: 100, QtdePedidos: 2, ValorMedio: 50 });
        assert.strictEqual(oKpis.currency, "BRL");
        var oEmpty = AnalyticsQuery.shapeKpis(Scenarios.domain, []);
        assert.deepEqual(oEmpty.values, { ValorTotal: 0, QtdePedidos: 0, ValorMedio: 0 });
        assert.strictEqual(oEmpty.currency, "");
    });

    QUnit.test("opções de filtro: meses cronológicos, demais por texto", function (assert) {
        var oMonth = { field: "MesCriacao", type: "list" };
        var aMonths = AnalyticsQuery.shapeFilterValues(oMonth, [
            { MesCriacao: "202701" }, { MesCriacao: "202612" }
        ], fnText);
        assert.deepEqual(aMonths.map(function (o) { return o.key; }), ["202612", "202701"]);
        var oStatus = { field: "StatusPedido", type: "list" };
        var aStatus = AnalyticsQuery.shapeFilterValues(oStatus, [
            { StatusPedido: "B", StatusPedidoTexto: "Zeta" }, { StatusPedido: "A", StatusPedidoTexto: "Alfa" }
        ], fnText);
        assert.deepEqual(aStatus.map(function (o) { return o.text; }), ["Alfa", "Zeta"]);
    });
});

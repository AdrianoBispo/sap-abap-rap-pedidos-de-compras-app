/*global QUnit*/
sap.ui.define([
    "sap/base/i18n/ResourceBundle",
    "analiseclientes/model/Scenarios"
], function (ResourceBundle, Scenarios) {
    "use strict";

    QUnit.module("Scenarios");

    QUnit.test("5 cenários com ids únicos", function (assert) {
        assert.strictEqual(Scenarios.scenarios.length, 5);
        var aIds = Scenarios.scenarios.map(function (oScenario) { return oScenario.id; });
        assert.strictEqual(new Set(aIds).size, 5, "ids únicos");
        assert.strictEqual(Scenarios.getScenario(aIds[0]), Scenarios.scenarios[0]);
        assert.strictEqual(Scenarios.getScenario("inexistente"), undefined);
    });

    QUnit.test("cenários, filtros e KPIs só usam dimensões e medidas conhecidas", function (assert) {
        Scenarios.scenarios.forEach(function (oScenario) {
            assert.ok(Scenarios.dimensions[oScenario.dimension], oScenario.id + ": dimensão");
            oScenario.measures.forEach(function (sMeasure) {
                assert.ok(Scenarios.measures[sMeasure], oScenario.id + ": medida " + sMeasure);
            });
            assert.ok(["column", "bar", "line", "donut"].indexOf(oScenario.chart) >= 0, oScenario.id + ": gráfico");
        });
        Scenarios.domain.filters.forEach(function (oFilter) {
            assert.ok(Scenarios.dimensions[oFilter.field], "filtro " + oFilter.field);
            assert.ok(["list", "boolean", "search"].indexOf(oFilter.type) >= 0, "tipo do filtro " + oFilter.field);
        });
        Scenarios.domain.kpis.forEach(function (sMeasure) {
            assert.ok(Scenarios.measures[sMeasure], "KPI " + sMeasure);
        });
        assert.ok(/^ZPC\w+-manage$/.test(Scenarios.domain.manage.intent), "intent do app de gestão");
    });

    QUnit.test("todas as chaves de i18n usadas existem", function (assert) {
        var done = assert.async();
        ResourceBundle.create({
            url: sap.ui.require.toUrl("analiseclientes/i18n/i18n.properties"),
            async: true,
            supportedLocales: [""],
            fallbackLocale: ""
        }).then(function (oBundle) {
            var aKeys = ["appTitle", "flpTitle", "flpSubtitle", "openManageTooltip", "yes", "no"];
            Object.keys(Scenarios.measures).forEach(function (s) { aKeys.push(Scenarios.measures[s].labelKey); });
            Object.keys(Scenarios.dimensions).forEach(function (s) {
                aKeys.push(Scenarios.dimensions[s].labelKey);
                if (Scenarios.dimensions[s].kind === "faixa") {
                    ["BAIXO", "MEDIO", "ALTO"].forEach(function (sFaixa) { aKeys.push("faixa" + sFaixa); });
                }
            });
            Scenarios.scenarios.forEach(function (oScenario) {
                aKeys.push(oScenario.id + ".title", oScenario.id + ".sub");
            });
            ["column", "bar", "line", "donut"].forEach(function (s) { aKeys.push("chartType" + s); });
            aKeys.forEach(function (sKey) {
                assert.ok(oBundle.hasText(sKey), sKey);
            });
            done();
        });
    });
});

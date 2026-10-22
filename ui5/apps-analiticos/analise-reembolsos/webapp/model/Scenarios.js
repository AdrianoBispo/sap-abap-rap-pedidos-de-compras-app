/*
 * Catálogo da Análise de Pedidos de Reembolsos: o entity set ReembolsoAnalise do serviço
 * ZUI_PC_ANALITICO, os filtros, os indicadores (KPIs) e os 5 cenários de gráfico.
 *
 * Os campos vêm do $metadata de ZUI_PC_ANALITICO_O4. As medidas usam a agregação padrão do
 * backend (@Aggregation.default; no OData são "custom aggregates"), por isso o $apply é
 * aggregate(Medida) sem método explícito.
 */
sap.ui.define([], function () {
    "use strict";

    // Medidas: kind define a formatação; avg indica média (não soma) ao juntar linhas duplicadas;
    // currency indica que a medida depende de Currency (Currency entra no groupby).
    var MEASURES = {
        ValorReembolso: { kind: "money", currency: true, labelKey: "measureValorReembolso" },
        QtdeReembolsos: { kind: "int", labelKey: "measureQtdeReembolsos" }
    };

    // Dimensões: text = campo com a descrição; kind = month (AAAAMM) | faixa (BAIXO/MEDIO/ALTO) | boolean.
    var DIMENSIONS = {
        StatusReembolso: { text: "StatusReembolsoTexto", labelKey: "dimStatusReembolso" },
        MotivoSolicitacao: { labelKey: "dimMotivo" },
        MesSolicitacao: { kind: "month", labelKey: "dimMesSolicitacao" },
        Uf: { labelKey: "dimUf" }
    };

    // Entity set, app de gestão (intent no launchpad, BSP fora dele), filtros (UI.SelectionFields
    // do serviço) e KPIs. type: list = valores distintos lidos do serviço; boolean = Todos/Sim/Não;
    // search = contém.
    var DOMAIN = {
        entitySet: "ReembolsoAnalise",
        manage: { intent: "ZPCReembolso-manage", bsp: "zpc_reembolsos" },
        filters: [
            { field: "StatusReembolso", type: "list" },
            { field: "Uf", type: "list" },
            { field: "MesSolicitacao", type: "list" }
        ],
        kpis: ["QtdeReembolsos", "ValorReembolso"]
    };

    // Cenários. sort: by = "measure" (1ª medida, ou sort.measure) ou "dimension"; desc; top limita as linhas.
    function sc(id, dimension, measures, chart, sort, top) {
        return {
            id: id,
            dimension: dimension,
            measures: measures,
            chart: chart,
            sort: sort,
            top: top || 0
        };
    }
    var BY_MEASURE = { by: "measure", desc: true };
    var BY_DIMENSION = { by: "dimension", desc: false };

    var SCENARIOS = [
        sc("ReeValorPorStatus", "StatusReembolso", ["ValorReembolso"], "column", BY_MEASURE),
        sc("ReeQtdePorStatus", "StatusReembolso", ["QtdeReembolsos"], "donut", BY_MEASURE),
        sc("ReeValorPorMes", "MesSolicitacao", ["ValorReembolso"], "column", BY_DIMENSION),
        sc("ReeValorPorUf", "Uf", ["ValorReembolso"], "column", BY_MEASURE),
        sc("ReePorMotivo", "MotivoSolicitacao", ["QtdeReembolsos"], "column", BY_MEASURE)
    ];

    return {
        measures: MEASURES,
        dimensions: DIMENSIONS,
        domain: DOMAIN,
        scenarios: SCENARIOS,

        getScenario: function (sId) {
            return SCENARIOS.find(function (oScenario) { return oScenario.id === sId; });
        }
    };
});

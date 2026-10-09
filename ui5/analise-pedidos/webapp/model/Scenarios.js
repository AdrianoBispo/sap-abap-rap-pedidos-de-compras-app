/*
 * Catálogo da Análise de Pedidos de Compras: o entity set PedidoAnalise do serviço
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
        ValorTotal: { kind: "money", currency: true, labelKey: "measureValorTotal" },
        ValorMedio: { kind: "money", currency: true, avg: true, labelKey: "measureValorMedio" },
        QtdePedidos: { kind: "int", labelKey: "measureQtdePedidos" }
    };

    // Dimensões: text = campo com a descrição; kind = month (AAAAMM) | faixa (BAIXO/MEDIO/ALTO) | boolean.
    var DIMENSIONS = {
        StatusPedido: { text: "StatusPedidoTexto", labelKey: "dimStatusPedido" },
        StatusPagamento: { text: "StatusPagamentoTexto", labelKey: "dimStatusPagamento" },
        MesCriacao: { kind: "month", labelKey: "dimMesCriacao" },
        Uf: { labelKey: "dimUf" }
    };

    // Entity set, app de gestão (intent no launchpad, BSP fora dele), filtros (UI.SelectionFields
    // do serviço) e KPIs. type: list = valores distintos lidos do serviço; boolean = Todos/Sim/Não;
    // search = contém.
    var DOMAIN = {
        entitySet: "PedidoAnalise",
        manage: { intent: "ZPCPedidoCompra-manage", bsp: "zpc_pedidos" },
        filters: [
            { field: "StatusPedido", type: "list" },
            { field: "StatusPagamento", type: "list" },
            { field: "Uf", type: "list" },
            { field: "MesCriacao", type: "list" }
        ],
        kpis: ["ValorTotal", "QtdePedidos", "ValorMedio"]
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
        sc("PedValorPorStatus", "StatusPedido", ["ValorTotal"], "column", BY_MEASURE),
        sc("PedPorMes", "MesCriacao", ["QtdePedidos"], "column", BY_DIMENSION),
        sc("PedValorPorUf", "Uf", ["ValorTotal"], "column", BY_MEASURE),
        sc("PedPorPagamento", "StatusPagamento", ["QtdePedidos"], "donut", BY_MEASURE),
        sc("PedTicketMedio", "StatusPedido", ["ValorMedio"], "column", BY_MEASURE)
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

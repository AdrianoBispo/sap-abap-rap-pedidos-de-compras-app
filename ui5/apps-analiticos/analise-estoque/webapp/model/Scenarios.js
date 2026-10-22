/*
 * Catálogo da Análise de Itens do Estoque: o entity set ItemAnalise do serviço
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
        QtdeItens: { kind: "int", labelKey: "measureQtdeItens" },
        QtdeEstoque: { kind: "int", labelKey: "measureQtdeEstoque" },
        QtdeReservada: { kind: "int", labelKey: "measureQtdeReservada" },
        QtdeDisponivel: { kind: "int", labelKey: "measureQtdeDisponivel" },
        ValorEstoque: { kind: "money", labelKey: "measureValorEstoque" }
    };

    // Dimensões: text = campo com a descrição; kind = month (AAAAMM) | faixa (BAIXO/MEDIO/ALTO) | boolean.
    var DIMENSIONS = {
        Categoria: { text: "CategoriaTexto", labelKey: "dimCategoria" },
        StatusEstoque: { text: "StatusEstoqueTexto", labelKey: "dimStatusEstoque" },
        Nome: { labelKey: "dimNome" },
        Sku: { labelKey: "dimSku" }
    };

    // Entity set, app de gestão (intent no launchpad, BSP fora dele), filtros (UI.SelectionFields
    // do serviço) e KPIs. type: list = valores distintos lidos do serviço; boolean = Todos/Sim/Não;
    // search = contém.
    var DOMAIN = {
        entitySet: "ItemAnalise",
        manage: { intent: "ZPCItemEstoque-manage", bsp: "zpc_estoque" },
        filters: [
            { field: "Categoria", type: "list" },
            { field: "StatusEstoque", type: "list" },
            { field: "Nome", type: "search" },
            { field: "Sku", type: "search" }
        ],
        kpis: ["QtdeItens", "QtdeEstoque", "QtdeReservada", "QtdeDisponivel", "ValorEstoque"]
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

    var SCENARIOS = [
        sc("EstDisponivelPorCategoria", "Categoria", ["QtdeReservada", "QtdeDisponivel"], "column", { by: "measure", desc: true, measure: "QtdeDisponivel" }),
        sc("EstItensPorSituacao", "StatusEstoque", ["QtdeItens"], "donut", BY_MEASURE),
        sc("EstValorPorCategoria", "Categoria", ["ValorEstoque"], "column", BY_MEASURE),
        sc("EstMaisReservados", "Nome", ["QtdeReservada"], "column", BY_MEASURE, 10),
        sc("EstItensPorCategoria", "Categoria", ["QtdeItens"], "donut", BY_MEASURE)
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

/*
 * Catálogo da Análise de Clientes: o entity set ClienteAnalise do serviço
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
        QtdeClientes: { kind: "int", labelKey: "measureQtdeClientes" },
        ScoreMedio: { kind: "dec", avg: true, labelKey: "measureScoreMedio" }
    };

    // Dimensões: text = campo com a descrição; kind = month (AAAAMM) | faixa (BAIXO/MEDIO/ALTO) | boolean.
    var DIMENSIONS = {
        Genero: { text: "GeneroTexto", labelKey: "dimGenero" },
        FaixaScore: { kind: "faixa", labelKey: "dimFaixaScore" },
        MesCadastro: { kind: "month", labelKey: "dimMesCadastro" },
        Uf: { labelKey: "dimUf" },
        ClienteAtivo: { kind: "boolean", labelKey: "dimClienteAtivo" },
        Nome: { labelKey: "dimNome" }
    };

    // Entity set, app de gestão (intent no launchpad, BSP fora dele), filtros (UI.SelectionFields
    // do serviço) e KPIs. type: list = valores distintos lidos do serviço; boolean = Todos/Sim/Não;
    // search = contém.
    var DOMAIN = {
        entitySet: "ClienteAnalise",
        manage: { intent: "ZPCCliente-manage", bsp: "zpc_clientes" },
        filters: [
            { field: "Genero", type: "list" },
            { field: "ClienteAtivo", type: "boolean" },
            { field: "Uf", type: "list" },
            { field: "FaixaScore", type: "list" },
            { field: "Nome", type: "search" }
        ],
        kpis: ["QtdeClientes", "ScoreMedio"]
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
        sc("CliPorGenero", "Genero", ["QtdeClientes"], "donut", BY_MEASURE),
        sc("CliPorUf", "Uf", ["QtdeClientes"], "column", BY_MEASURE),
        sc("CliPorFaixaScore", "FaixaScore", ["QtdeClientes"], "donut", BY_MEASURE),
        sc("CliCadastrosPorMes", "MesCadastro", ["QtdeClientes"], "column", BY_DIMENSION),
        sc("CliScorePorUf", "Uf", ["ScoreMedio"], "column", BY_MEASURE)
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

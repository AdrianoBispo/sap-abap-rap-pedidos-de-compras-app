/*
 * Catálogo das análises: 4 domínios (um entity set cada, do serviço ZUI_PC_ANALITICO) e os
 * 20 cenários de gráfico que antes eram apps separados (analise-* e painel-compras).
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
        QtdePedidos: { kind: "int", labelKey: "measureQtdePedidos" },
        QtdeClientes: { kind: "int", labelKey: "measureQtdeClientes" },
        ScoreMedio: { kind: "dec", avg: true, labelKey: "measureScoreMedio" },
        QtdeEstoque: { kind: "int", labelKey: "measureQtdeEstoque" },
        QtdeReservada: { kind: "int", labelKey: "measureQtdeReservada" },
        QtdeDisponivel: { kind: "int", labelKey: "measureQtdeDisponivel" },
        ValorEstoque: { kind: "money", labelKey: "measureValorEstoque" },
        QtdeItens: { kind: "int", labelKey: "measureQtdeItens" },
        ValorReembolso: { kind: "money", currency: true, labelKey: "measureValorReembolso" },
        QtdeReembolsos: { kind: "int", labelKey: "measureQtdeReembolsos" }
    };

    // Dimensões: text = campo com a descrição; kind = month (AAAAMM) | faixa (BAIXO/MEDIO/ALTO).
    var DIMENSIONS = {
        StatusPedido: { text: "StatusPedidoTexto", labelKey: "dimStatusPedido" },
        StatusPagamento: { text: "StatusPagamentoTexto", labelKey: "dimStatusPagamento" },
        MesCriacao: { kind: "month", labelKey: "dimMesCriacao" },
        Genero: { text: "GeneroTexto", labelKey: "dimGenero" },
        FaixaScore: { kind: "faixa", labelKey: "dimFaixaScore" },
        MesCadastro: { kind: "month", labelKey: "dimMesCadastro" },
        Categoria: { text: "CategoriaTexto", labelKey: "dimCategoria" },
        StatusEstoque: { text: "StatusEstoqueTexto", labelKey: "dimStatusEstoque" },
        Nome: { labelKey: "dimNome" },
        Sku: { labelKey: "dimSku" },
        StatusReembolso: { text: "StatusReembolsoTexto", labelKey: "dimStatusReembolso" },
        MotivoSolicitacao: { labelKey: "dimMotivo" },
        MesSolicitacao: { kind: "month", labelKey: "dimMesSolicitacao" },
        Uf: { labelKey: "dimUf" },
        ClienteAtivo: { kind: "boolean", labelKey: "dimClienteAtivo" }
    };

    // Campos de filtro de cada domínio (UI.SelectionFields do serviço).
    // type: list = valores distintos lidos do serviço; boolean = Todos/Sim/Não; search = contém.
    var DOMAINS = [
        {
            key: "pedidos",
            entitySet: "PedidoAnalise",
            icon: "sap-icon://sales-order",
            manage: { intent: "ZPCPedidoCompra-manage", bsp: "zpc_pedidos" },
            filters: [
                { field: "StatusPedido", type: "list" },
                { field: "StatusPagamento", type: "list" },
                { field: "Uf", type: "list" },
                { field: "MesCriacao", type: "list" }
            ],
            kpis: ["ValorTotal", "QtdePedidos", "ValorMedio"]
        },
        {
            key: "clientes",
            entitySet: "ClienteAnalise",
            icon: "sap-icon://customer",
            manage: { intent: "ZPCCliente-manage", bsp: "zpc_clientes" },
            filters: [
                { field: "Genero", type: "list" },
                { field: "ClienteAtivo", type: "boolean" },
                { field: "Uf", type: "list" },
                { field: "FaixaScore", type: "list" },
                { field: "Nome", type: "search" }
            ],
            kpis: ["QtdeClientes", "ScoreMedio"]
        },
        {
            key: "estoque",
            entitySet: "ItemAnalise",
            icon: "sap-icon://product",
            manage: { intent: "ZPCItemEstoque-manage", bsp: "zpc_estoque" },
            filters: [
                { field: "Categoria", type: "list" },
                { field: "StatusEstoque", type: "list" },
                { field: "Nome", type: "search" },
                { field: "Sku", type: "search" }
            ],
            kpis: ["QtdeItens", "QtdeEstoque", "QtdeReservada", "QtdeDisponivel", "ValorEstoque"]
        },
        {
            key: "reembolsos",
            entitySet: "ReembolsoAnalise",
            icon: "sap-icon://money-bills",
            manage: { intent: "ZPCReembolso-manage", bsp: "zpc_reembolsos" },
            filters: [
                { field: "StatusReembolso", type: "list" },
                { field: "Uf", type: "list" },
                { field: "MesSolicitacao", type: "list" }
            ],
            kpis: ["QtdeReembolsos", "ValorReembolso"]
        }
    ];

    // Cenários. sort: by = "measure" (1ª medida) ou "dimension"; desc; top limita as linhas.
    function sc(id, domain, dimension, measures, chart, sort, top) {
        return {
            id: id,
            domain: domain,
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
        sc("PedValorPorStatus", "pedidos", "StatusPedido", ["ValorTotal"], "column", BY_MEASURE),
        sc("PedPorMes", "pedidos", "MesCriacao", ["QtdePedidos"], "column", BY_DIMENSION),
        sc("PedValorPorUf", "pedidos", "Uf", ["ValorTotal"], "column", BY_MEASURE),
        sc("PedPorPagamento", "pedidos", "StatusPagamento", ["QtdePedidos"], "donut", BY_MEASURE),
        sc("PedTicketMedio", "pedidos", "StatusPedido", ["ValorMedio"], "column", BY_MEASURE),

        sc("CliPorGenero", "clientes", "Genero", ["QtdeClientes"], "donut", BY_MEASURE),
        sc("CliPorUf", "clientes", "Uf", ["QtdeClientes"], "column", BY_MEASURE),
        sc("CliPorFaixaScore", "clientes", "FaixaScore", ["QtdeClientes"], "donut", BY_MEASURE),
        sc("CliCadastrosPorMes", "clientes", "MesCadastro", ["QtdeClientes"], "column", BY_DIMENSION),
        sc("CliScorePorUf", "clientes", "Uf", ["ScoreMedio"], "column", BY_MEASURE),

        sc("EstDisponivelPorCategoria", "estoque", "Categoria", ["QtdeReservada", "QtdeDisponivel"], "column", { by: "measure", desc: true, measure: "QtdeDisponivel" }),
        sc("EstItensPorSituacao", "estoque", "StatusEstoque", ["QtdeItens"], "donut", BY_MEASURE),
        sc("EstValorPorCategoria", "estoque", "Categoria", ["ValorEstoque"], "column", BY_MEASURE),
        sc("EstMaisReservados", "estoque", "Nome", ["QtdeReservada"], "column", BY_MEASURE, 10),
        sc("EstItensPorCategoria", "estoque", "Categoria", ["QtdeItens"], "donut", BY_MEASURE),

        sc("ReeValorPorStatus", "reembolsos", "StatusReembolso", ["ValorReembolso"], "column", BY_MEASURE),
        sc("ReeQtdePorStatus", "reembolsos", "StatusReembolso", ["QtdeReembolsos"], "donut", BY_MEASURE),
        sc("ReeValorPorMes", "reembolsos", "MesSolicitacao", ["ValorReembolso"], "column", BY_DIMENSION),
        sc("ReeValorPorUf", "reembolsos", "Uf", ["ValorReembolso"], "column", BY_MEASURE),
        sc("ReePorMotivo", "reembolsos", "MotivoSolicitacao", ["QtdeReembolsos"], "column", BY_MEASURE)
    ];

    return {
        measures: MEASURES,
        dimensions: DIMENSIONS,
        domains: DOMAINS,
        scenarios: SCENARIOS,

        getDomain: function (sKey) {
            return DOMAINS.find(function (oDomain) { return oDomain.key === sKey; });
        },
        getScenario: function (sId) {
            return SCENARIOS.find(function (oScenario) { return oScenario.id === sId; });
        },
        getScenariosOf: function (sDomain) {
            return SCENARIOS.filter(function (oScenario) { return oScenario.domain === sDomain; });
        }
    };
});

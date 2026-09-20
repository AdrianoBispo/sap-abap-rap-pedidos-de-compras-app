@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pedido - Projection (App Pedidos de Compras)'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'NumeroPedido' ]
define root view entity ZC_PC_PEDIDO_APP
  provider contract transactional_query
  as projection on ZR_PC_PEDIDO
{
  key PedidoUUID,

      @Search.defaultSearchElement: true
      NumeroPedido,

      @ObjectModel.text.element: [ 'NomeCliente' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_CLIENTE_VALUEHELP', element: 'ClienteUUID' },
                                           useForValidation: true }]
      ClienteUUID,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      _Cliente.Nome                   as NomeCliente,

      @Search.defaultSearchElement: true
      _Cliente.Cpf                    as CpfCliente,

      @ObjectModel.text.element: [ 'EnderecoPrincipalCompleto' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_ENDERECO_VALUEHELP', element: 'EnderecoUUID' },
                                           additionalBinding: [{ localElement: 'ClienteUUID',
                                                                 element:      'ClienteUUID',
                                                                 usage:        #FILTER }] }]
      EnderecoUUID,
      EnderecoPrincipalCompleto,

      @ObjectModel.text.element: [ 'StatusPedidoTexto' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_STATUSPED_VALUEHELP', element: 'Codigo' } }]
      StatusPedido,
      _StatusPedidoTxt.Descricao      as StatusPedidoTexto,
      _StatusPedidoTxt.Criticality    as StatusPedidoCriticality,

      @ObjectModel.text.element: [ 'StatusPagamentoTexto' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_STATUSPAG_VALUEHELP', element: 'Codigo' } }]
      StatusPagamento,
      _StatusPagamentoTxt.Descricao   as StatusPagamentoTexto,
      _StatusPagamentoTxt.Criticality as StatusPagamentoCriticality,

      Observacao,
      Currency,
      ValorTotal,
      DataFinalizacao,
      MotivoCancelamento,
      DataCancelamento,
      CanceladoPor,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associações */
      _Itens           : redirected to composition child ZC_PC_ITEM_PEDIDO_APP,
      _Pagamento       : redirected to composition child ZC_PC_PAGAMENTO_APP,
      _ClienteSnapshot : redirected to composition child ZC_PC_PED_CLI_SNAP_APP,
      _ItensSnapshot   : redirected to composition child ZC_PC_PED_ITEM_SNAP_APP
}

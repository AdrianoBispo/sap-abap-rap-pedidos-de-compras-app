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

      /* Navegação entre apps (FLP): link para a app Gestão de Clientes */
      @Consumption.semanticObject: 'ZPCCliente'
      @ObjectModel.text.element: [ 'NomeCliente' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_CLIENTE_VH', element: 'ClienteUUID' },
                                           useForValidation: true }]
      ClienteUUID,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Consumption.semanticObject: 'ZPCCliente'
      _Cliente.Nome                   as NomeCliente,

      @Search.defaultSearchElement: true
      _Cliente.Cpf                    as CpfCliente,

      /* Dados do cliente exibidos na seção "Dados do Cliente" enquanto o pedido
         não foi encerrado (depois vêm do snapshot) */
      _Cliente.Email                  as EmailCliente,
      _Cliente.Telefone               as TelefoneCliente,
      _Cliente._GeneroTxt.Descricao   as GeneroCliente,
      _Cliente.DataNascimento         as DataNascimentoCliente,

      @ObjectModel.text.element: [ 'EnderecoPrincipalCompleto' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_ENDERECO_VH', element: 'EnderecoUUID' },
                                           additionalBinding: [{ localElement: 'ClienteUUID',
                                                                 element:      'ClienteUUID',
                                                                 usage:        #FILTER }] }]
      EnderecoUUID,
      EnderecoPrincipalCompleto,

      @ObjectModel.text.element: [ 'StatusPedidoTexto' ]
      @UI.textArrangement: #TEXT_ONLY
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_STATUSPED_VH', element: 'Codigo' } }]
      StatusPedido,
      _StatusPedidoTxt.Descricao      as StatusPedidoTexto,
      _StatusPedidoTxt.Criticality    as StatusPedidoCriticality,

      /* Personalização dinâmica da Object Page: Itens (ativos) só faz sentido
         enquanto o pedido não foi encerrado; Histórico (snapshots) só existe
         a partir do encerramento (FINALIZADO/CANCELADO). Calculados na view
         básica ZR_PC_PEDIDO (projections aqui não suportam CASE/CAST). */
      PedidoEncerrado,
      PedidoAtivoSemHistorico,
      PedidoNaoFinalizado,
      PedidoNaoCancelado,

      @ObjectModel.text.element: [ 'StatusPagamentoTexto' ]
      @UI.textArrangement: #TEXT_ONLY
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_STATUSPAG_VH', element: 'Codigo' } }]
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

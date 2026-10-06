@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pedidos - consulta analítica'
@Metadata.allowExtensions: true
@Analytics.dataCategory: #CUBE
@ObjectModel.modelingPattern: #ANALYTICAL_CUBE
@ObjectModel.supportedCapabilities: [ #ANALYTICAL_PROVIDER ]

define view entity ZC_PC_PEDIDO_ANALISE
  as select from ZI_PC_PEDIDO_CUBE
{
  key PedidoUUID,
      NumeroPedido,
      @ObjectModel.text.element: [ 'StatusPedidoTexto' ]
      StatusPedido,
      StatusPedidoTexto,
      @ObjectModel.text.element: [ 'StatusPagamentoTexto' ]
      StatusPagamento,
      StatusPagamentoTexto,
      ClienteUUID,
      Uf,
      MesCriacao,
      Currency,
      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'Currency'
      ValorTotal,
      @Aggregation.default: #SUM
      QtdePedidos
}

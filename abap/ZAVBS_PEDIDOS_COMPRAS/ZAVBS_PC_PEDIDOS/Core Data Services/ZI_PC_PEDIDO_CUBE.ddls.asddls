@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pedidos - cubo analítico'
@Metadata.ignorePropagatedAnnotations: true
@Analytics.dataCategory: #CUBE
@ObjectModel.modelingPattern: #ANALYTICAL_CUBE
@ObjectModel.supportedCapabilities: [ #ANALYTICAL_PROVIDER ]

define view entity ZI_PC_PEDIDO_CUBE
  as select from ZR_PC_PEDIDO
{
  key PedidoUUID,
      NumeroPedido,

      @ObjectModel.text.element: [ 'StatusPedidoTexto' ]
      StatusPedido,
      _StatusPedidoTxt.Descricao        as StatusPedidoTexto,

      @ObjectModel.text.element: [ 'StatusPagamentoTexto' ]
      StatusPagamento,
      _StatusPagamentoTxt.Descricao     as StatusPagamentoTexto,

      ClienteUUID,
      _Cliente._EnderecoPrincipal.Uf    as Uf,

      @Semantics.calendar.yearMonth: true
      cast( left( cast( tstmp_to_dats( cast( CreatedAt as abap.dec(15,0) ), 'UTC', $session.client, 'NULL' ) as abap.char(8) ), 6 ) as abap.numc(6) ) as MesCriacao,

      Currency,

      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'Currency'
      ValorTotal,

      /* Ticket médio: média do valor por pedido */
      @Aggregation.default: #AVG
      @Semantics.amount.currencyCode: 'Currency'
      ValorTotal                        as ValorMedio,

      @Aggregation.default: #SUM
      cast( 1 as abap.int4 )            as QtdePedidos
}

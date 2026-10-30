@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reembolsos - cubo analítico'
@Metadata.ignorePropagatedAnnotations: true
@Analytics.dataCategory: #CUBE
@ObjectModel.modelingPattern: #ANALYTICAL_CUBE
@ObjectModel.supportedCapabilities: [ #ANALYTICAL_PROVIDER ]

define view entity ZI_PC_REEMB_CUBE
  as select from ZR_PC_REEMBOLSO
{
  key ReembolsoUUID,
      NumeroPedido,

      @ObjectModel.text.element: [ 'StatusReembolsoTexto' ]
      StatusReembolso,
      _StatusTxt.Descricao              as StatusReembolsoTexto,

      MotivoSolicitacao,
      _Cliente._EnderecoPrincipal.Uf    as Uf,

      @Semantics.calendar.yearMonth: true
      cast( left( cast( tstmp_to_dats( cast( DataSolicitacao as abap.dec(15,0) ), 'UTC', $session.client, 'NULL' ) as abap.char(8) ), 6 ) as abap.numc(6) ) as MesSolicitacao,

      Currency,

      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'Currency'
      ValorReembolso,

      @Aggregation.default: #SUM
      cast( 1 as abap.int4 )            as QtdeReembolsos
}

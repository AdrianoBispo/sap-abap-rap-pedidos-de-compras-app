@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reembolsos - consulta analítica'
@Metadata.allowExtensions: true
@Analytics.dataCategory: #CUBE
@ObjectModel.modelingPattern: #ANALYTICAL_CUBE
@ObjectModel.supportedCapabilities: [ #ANALYTICAL_PROVIDER ]

define view entity ZC_PC_REEMB_ANALISE
  as select from ZI_PC_REEMB_CUBE
{
  key ReembolsoUUID,
      NumeroPedido,
      @ObjectModel.text.element: [ 'StatusReembolsoTexto' ]
      StatusReembolso,
      StatusReembolsoTexto,
      Uf,
      MesSolicitacao,
      Currency,
      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'Currency'
      ValorReembolso,
      @Aggregation.default: #SUM
      QtdeReembolsos
}

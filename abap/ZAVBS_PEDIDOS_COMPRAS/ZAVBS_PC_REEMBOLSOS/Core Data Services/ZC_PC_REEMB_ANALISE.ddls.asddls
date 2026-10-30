@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reembolsos - consulta analítica'
@Metadata.allowExtensions: true
@OData.applySupportedForAggregation: #FULL

define view entity ZC_PC_REEMB_ANALISE
  as select from ZI_PC_REEMB_CUBE
{
  key ReembolsoUUID,
      NumeroPedido,
      @ObjectModel.text.element: [ 'StatusReembolsoTexto' ]
      StatusReembolso,
      StatusReembolsoTexto,
      MotivoSolicitacao,
      Uf,
      MesSolicitacao,
      Currency,
      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'Currency'
      ValorReembolso,
      @Aggregation.default: #SUM
      QtdeReembolsos
}

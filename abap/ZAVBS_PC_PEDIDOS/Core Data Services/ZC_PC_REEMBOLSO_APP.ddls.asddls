@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reembolso - Projection (somente leitura)'
@Metadata.allowExtensions: true
define view entity ZC_PC_REEMBOLSO_APP
  as projection on ZR_PC_REEMBOLSO
{
  key ReembolsoUUID,
      PedidoUUID,

      @ObjectModel.text.element: [ 'StatusReembolsoTexto' ]
      StatusReembolso,
      _StatusTxt.Descricao   as StatusReembolsoTexto,
      _StatusTxt.Criticality as StatusReembolsoCriticality,

      StatusPedidoAnterior,

      Currency,
      ValorReembolso,

      MotivoSolicitacao,
      DataSolicitacao,
      SolicitadoPor,

      MotivoDecisao,
      DataDecisao,
      DecididoPor,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associações */
      _Pedido : redirected to parent ZC_PC_PEDIDO_APP
}

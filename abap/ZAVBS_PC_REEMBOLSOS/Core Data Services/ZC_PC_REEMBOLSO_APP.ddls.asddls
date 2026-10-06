@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reembolso - Projection (App Gestão de Reembolsos)'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'NumeroPedido' ]
define root view entity ZC_PC_REEMBOLSO_APP
  provider contract transactional_query
  as projection on ZR_PC_REEMBOLSO
{
  key ReembolsoUUID,
      PedidoUUID,

      @Search.defaultSearchElement: true
      NumeroPedido,

      @ObjectModel.text.element: [ 'NomeCliente' ]
      ClienteUUID,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      _Cliente.Nome          as NomeCliente,

      @ObjectModel.text.element: [ 'StatusReembolsoTexto' ]
      @UI.textArrangement: #TEXT_ONLY
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_STATUSREEMB_VH', element: 'Codigo' } }]
      StatusReembolso,
      _StatusTxt.Descricao   as StatusReembolsoTexto,
      _StatusTxt.Criticality as StatusReembolsoCriticality,

      StatusPedidoAnterior,

      Currency,
      ValorReembolso,

      @Search.defaultSearchElement: true
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
      _Cliente,
      _StatusTxt
}

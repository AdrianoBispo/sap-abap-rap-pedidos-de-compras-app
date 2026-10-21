@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reembolso do pedido - BO root'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_PC_REEMBOLSO
  as select from zta_pc_reembolso
  association [0..1] to ZR_PC_PEDIDO  as _Pedido  on $projection.PedidoUUID  = _Pedido.PedidoUUID
  association [0..1] to ZR_PC_CLIENTE as _Cliente on $projection.ClienteUUID = _Cliente.ClienteUUID
  association [0..1] to ZR_PC_CODELIST as _StatusTxt on  _StatusTxt.Lista  = 'STATUS_REEMBOLSO'
                                                    and _StatusTxt.Codigo = $projection.StatusReembolso
{
  key reembolso_uuid         as ReembolsoUUID,
      pedido_uuid            as PedidoUUID,
      numero_pedido          as NumeroPedido,
      cliente_uuid           as ClienteUUID,
      status_reembolso       as StatusReembolso,
      status_pedido_anterior as StatusPedidoAnterior,
      currency               as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      valor_reembolso        as ValorReembolso,
      motivo_solicitacao     as MotivoSolicitacao,
      data_solicitacao       as DataSolicitacao,
      solicitado_por         as SolicitadoPor,
      motivo_decisao         as MotivoDecisao,
      data_decisao           as DataDecisao,
      decidido_por           as DecididoPor,
      @Semantics.user.createdBy: true
      created_by             as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at             as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by        as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at        as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at  as LocalLastChangedAt,

      /* Associações */
      _Pedido,
      _Cliente,
      _StatusTxt
}

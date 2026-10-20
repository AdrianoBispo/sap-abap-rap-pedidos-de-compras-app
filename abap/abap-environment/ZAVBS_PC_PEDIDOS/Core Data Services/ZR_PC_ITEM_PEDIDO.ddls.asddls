@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item do pedido - BO child'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_PC_ITEM_PEDIDO
  as select from zta_pc_item_ped
  association        to parent ZR_PC_PEDIDO as _Pedido on $projection.PedidoUUID = _Pedido.PedidoUUID
  association [0..1] to ZR_PC_ITEM          as _Item   on $projection.ItemUUID   = _Item.ItemUUID
{
  key item_pedido_uuid      as ItemPedidoUUID,
      pedido_uuid           as PedidoUUID,
      item_uuid             as ItemUUID,
      qtde_item_pedido      as QtdeItemPedido,
      currency              as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      preco_unitario_snap   as PrecoUnitarioSnapshot,
      @Semantics.amount.currencyCode: 'Currency'
      valor_total           as ValorTotal,
      observacao            as Observacao,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      /* Associações */
      _Pedido,
      _Item
}

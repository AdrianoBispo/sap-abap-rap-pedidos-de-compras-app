@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Snapshot dos itens - BO child'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_PC_PED_ITEM_SNAP
  as select from zta_pc_snap_itm
  association to parent ZR_PC_PEDIDO as _Pedido on $projection.PedidoUUID = _Pedido.PedidoUUID
{
  key snapshot_item_uuid    as SnapshotItemUUID,
      pedido_uuid           as PedidoUUID,
      item_pedido_uuid      as ItemPedidoUUID,
      item_uuid             as ItemUUID,
      sku                   as Sku,
      nome                  as Nome,
      descricao             as Descricao,
      categoria             as Categoria,
      quantidade            as Quantidade,
      currency              as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      preco_unitario        as PrecoUnitario,
      @Semantics.amount.currencyCode: 'Currency'
      valor_total           as ValorTotal,
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
      _Pedido
}

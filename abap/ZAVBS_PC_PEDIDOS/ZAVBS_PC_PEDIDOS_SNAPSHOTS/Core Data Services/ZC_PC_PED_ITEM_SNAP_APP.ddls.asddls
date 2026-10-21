@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Snapshot dos itens - Projection (somente leitura)'
@Metadata.allowExtensions: true
define view entity ZC_PC_PED_ITEM_SNAP_APP
  as projection on ZR_PC_PED_ITEM_SNAP
{
  key SnapshotItemUUID,
      PedidoUUID,
      ItemPedidoUUID,
      /* Navegação entre apps (FLP): nome e SKU do snapshot abrem o item na
         app Gestão de Estoque (pedidos FINALIZADO/CANCELADO) */
      @Consumption.semanticObject: 'ZPCItemEstoque'
      ItemUUID,
      @Consumption.semanticObject: 'ZPCItemEstoque'
      Sku,
      @Consumption.semanticObject: 'ZPCItemEstoque'
      Nome,
      Descricao,
      Categoria,
      Quantidade,
      Currency,
      PrecoUnitario,
      ValorTotal,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associações */
      _Pedido : redirected to parent ZC_PC_PEDIDO_APP
}

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item do pedido - Projection'
@Metadata.allowExtensions: true
define view entity ZC_PC_ITEM_PEDIDO_APP
  as projection on ZR_PC_ITEM_PEDIDO
{
  key ItemPedidoUUID,
      PedidoUUID,

      /* Navegação entre apps (FLP): link para a app Gestão de Estoque */
      @Consumption.semanticObject: 'ZPCItemEstoque'
      @ObjectModel.text.element: [ 'NomeItem' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_ITEM_VH', element: 'ItemUUID' },
                                           useForValidation: true }]
      ItemUUID,
      @Consumption.semanticObject: 'ZPCItemEstoque'
      _Item.Sku            as Sku,
      _Item.Nome           as NomeItem,
      _Item.QtdeDisponivel as QtdeDisponivelAtual,

      QtdeItemPedido,
      Currency,
      PrecoUnitarioSnapshot,
      ValorTotal,
      Observacao,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associações */
      _Pedido : redirected to parent ZC_PC_PEDIDO_APP
}

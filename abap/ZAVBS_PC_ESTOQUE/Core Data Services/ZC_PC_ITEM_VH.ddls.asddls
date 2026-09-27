@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Itens ativos - Value Help'
@Search.searchable: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #M, dataClass: #MASTER }
@Metadata.ignorePropagatedAnnotations: true

/* View reutilizável consumida pela aplicação Pedidos de Compras.
   Somente itens ativos; preço e disponibilidade são informativos -
   a validação definitiva ocorre no backend (ConfirmarPedido).        */

define view entity ZC_PC_ITEM_VH
  as select from ZR_PC_ITEM
{
      @UI.hidden: true
      @ObjectModel.text.element: [ 'Nome' ]
  key ItemUUID,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'SKU'
      Sku,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Semantics.text: true
      @EndUserText.label: 'Item'
      Nome,

      @EndUserText.label: 'Categoria'
      Categoria,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Preço unitário'
      PrecoUnitario,

      @UI.hidden: true
      Currency,

      @EndUserText.label: 'Qtde disponível'
      QtdeDisponivel,

      @EndUserText.label: 'Status do estoque'
      StatusEstoque
}
where
  ItemAtivo = 'X'

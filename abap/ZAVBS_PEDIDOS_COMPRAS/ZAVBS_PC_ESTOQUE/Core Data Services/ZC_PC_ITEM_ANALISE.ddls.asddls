@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Estoque - consulta analítica'
@Metadata.allowExtensions: true
@OData.applySupportedForAggregation: #FULL

define view entity ZC_PC_ITEM_ANALISE
  as select from ZI_PC_ITEM_CUBE
{
  key ItemUUID,
      Sku,
      Nome,
      @ObjectModel.text.element: [ 'CategoriaTexto' ]
      Categoria,
      CategoriaTexto,
      @ObjectModel.text.element: [ 'StatusEstoqueTexto' ]
      StatusEstoque,
      StatusEstoqueTexto,
      ItemAtivo,
      Currency,
      @Aggregation.default: #SUM
      QtdeEstoque,
      @Aggregation.default: #SUM
      QtdeReservada,
      @Aggregation.default: #SUM
      QtdeDisponivel,
      @Aggregation.default: #SUM
      ValorEstoque,
      @Aggregation.default: #SUM
      QtdeItens
}

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Estoque - cubo analítico'
@Metadata.ignorePropagatedAnnotations: true
@Analytics.dataCategory: #CUBE
@ObjectModel.modelingPattern: #ANALYTICAL_CUBE
@ObjectModel.supportedCapabilities: [ #ANALYTICAL_PROVIDER ]

define view entity ZI_PC_ITEM_CUBE
  as select from ZR_PC_ITEM
{
  key ItemUUID,
      Sku,
      Nome,

      @ObjectModel.text.element: [ 'CategoriaTexto' ]
      Categoria,
      _CategoriaTxt.Descricao      as CategoriaTexto,

      @ObjectModel.text.element: [ 'StatusEstoqueTexto' ]
      StatusEstoque,
      _StatusEstoqueTxt.Descricao  as StatusEstoqueTexto,

      ItemAtivo,
      Currency,

      @Aggregation.default: #SUM
      QtdeEstoque,

      @Aggregation.default: #SUM
      QtdeReservada,

      @Aggregation.default: #SUM
      QtdeDisponivel,

      /* Valor do estoque físico: preço unitário x quantidade em estoque */
      @Aggregation.default: #SUM
      cast( cast( PrecoUnitario as abap.dec( 15, 2 ) ) * QtdeEstoque as abap.dec( 17, 2 ) ) as ValorEstoque,

      @Aggregation.default: #SUM
      cast( 1 as abap.int4 )       as QtdeItens
}

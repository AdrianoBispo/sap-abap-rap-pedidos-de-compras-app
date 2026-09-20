@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item - Projection (App Gestão de Estoque)'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'Sku' ]
define root view entity ZC_PC_ITEM_APP
  provider contract transactional_query
  as projection on ZR_PC_ITEM
{
  key ItemUUID,

      FotoItem,
      FotoMimeType,
      FotoFileName,

      @Search.defaultSearchElement: true
      Sku,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Nome,

      Descricao,

      @ObjectModel.text.element: [ 'CategoriaTexto' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_CATEGORIA_VALUEHELP', element: 'Codigo' },
                                           useForValidation: true }]
      Categoria,
      _CategoriaTxt.Descricao          as CategoriaTexto,

      QtdeEstoque,
      QtdeReservada,
      QtdeDisponivel,

      @ObjectModel.text.element: [ 'StatusEstoqueTexto' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_STATUSEST_VALUEHELP', element: 'Codigo' } }]
      StatusEstoque,
      _StatusEstoqueTxt.Descricao      as StatusEstoqueTexto,
      _StatusEstoqueTxt.Criticality    as StatusEstoqueCriticality,

      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CurrencyStdVH', element: 'Currency' },
                                           useForValidation: true }]
      Currency,
      PrecoUnitario,

      Peso,
      Altura,
      Largura,
      Profundidade,

      ItemAtivo,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt
}

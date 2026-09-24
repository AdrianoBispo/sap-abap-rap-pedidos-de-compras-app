@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item de estoque - BO root'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_PC_ITEM
  as select from zta_pc_item
  association [0..1] to ZI_PC_CODELIST as _CategoriaTxt on  _CategoriaTxt.Lista  = 'CATEGORIA'
                                                       and _CategoriaTxt.Codigo = $projection.Categoria
  association [0..1] to ZI_PC_CODELIST as _StatusEstoqueTxt on  _StatusEstoqueTxt.Lista  = 'STATUS_ESTOQUE'
                                                           and _StatusEstoqueTxt.Codigo = $projection.StatusEstoque
{
  key item_uuid             as ItemUUID,
      @Semantics.largeObject: { mimeType: 'FotoMimeType',
                                fileName: 'FotoFileName',
                                acceptableMimeTypes: [ 'image/jpeg', 'image/png' ],
                                contentDispositionPreference: #INLINE }
      foto_item             as FotoItem,
      @Semantics.mimeType: true
      foto_mime_type        as FotoMimeType,
      foto_file_name        as FotoFileName,
      sku                   as Sku,
      nome                  as Nome,
      descricao             as Descricao,
      categoria             as Categoria,
      qtde_estoque          as QtdeEstoque,
      qtde_reservada        as QtdeReservada,
      qtde_disponivel       as QtdeDisponivel,
      status_estoque        as StatusEstoque,
      currency              as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      preco_unitario        as PrecoUnitario,
      peso                  as Peso,
      altura                as Altura,
      largura               as Largura,
      profundidade          as Profundidade,
      item_ativo            as ItemAtivo,
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
      _CategoriaTxt,
      _StatusEstoqueTxt
}

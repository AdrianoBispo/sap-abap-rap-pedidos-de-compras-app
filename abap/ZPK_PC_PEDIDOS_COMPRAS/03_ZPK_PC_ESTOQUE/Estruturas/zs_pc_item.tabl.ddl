/* Campos de negócio de ZTA_PC_ITEM (sem a chave, declarada na tabela).
   abap_boolean e timestampl continuam como tipos padrão: o RAP os expõe
   como Edm.Boolean e Edm.DateTimeOffset, o que um domínio próprio perderia. */
@EndUserText.label : 'Item de estoque - dados de negócio'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zs_pc_item {

  foto_item       : zde_pc_foto_item;
  foto_mime_type  : zde_pc_mime_type;
  foto_file_name  : zde_pc_nome_arquivo;
  sku             : zde_pc_sku;
  nome            : zde_pc_nome_item;
  descricao       : zde_pc_descricao_item;
  categoria       : zde_pc_categoria;
  qtde_estoque    : zde_pc_qtde_estoque;
  qtde_reservada  : zde_pc_qtde_reservada;
  qtde_disponivel : zde_pc_qtde_disponivel;
  status_estoque  : zde_pc_status_estoque;
  currency        : zde_pc_moeda;
  @Semantics.amount.currencyCode : 'zs_pc_item.currency'
  preco_unitario  : zde_pc_preco_unitario;
  peso            : zde_pc_peso;
  altura          : zde_pc_altura;
  largura         : zde_pc_largura;
  profundidade    : zde_pc_profundidade;
  item_ativo      : abap_boolean;

}
